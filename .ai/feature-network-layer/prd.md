# PRD — Networking Layer

## 1. Purpose and scope

This PRD defines a standalone, domain-agnostic networking layer. It provides the typed primitives and transport protocol that any API client in this project uses to make HTTP requests and receive decoded responses.

The layer has no knowledge of TMDB, domain models, or any consumer. It defines:

- `Request<Response>` — a typed value describing an HTTP request and its expected decoded response.
- `ImageRequest` — a value describing an image fetch.
- `HTTPClient` interface — the transport seam consumers depend on.
- `HTTPClient implementation` — the concrete `URLSession`-backed implementation.

Any client (e.g. `TMDBClient`) depends on the `HTTPClient` interface, builds `Request` values, and passes them to the network layer for execution. The client has no knowledge of `URLSession` or transport details.

---

## 2. Architecture

```
[Consumer / API Client]
        │  builds Request<Response> / ImageRequest
        │  depends on
        ▼
  HTTP client interface       ← transport seam; this PRD's public contract
        │  conforms
        ▼
  HTTP client implementation  ← this PRD's concrete implementation
        │
        ├── URLSession        ← injectable; defaults to .shared
        ├── JSONDecoder       ← snake_case strategy; decodes Response
        └── ErrorMapper       ← collapses all failures → NetworkError
```

Two independent testability seams:

- **Consumer / API Client tests**: inject a mock conforming to interface; assert that the correct `Request` was constructed for each operation.
- **Client implementation tests**: inject a mock `URLSession`; assert transport, auth injection, decoding, and error mapping behavior.

---

## 3. Types

### 3.1 `Request<Response: Decodable>`

A value type describing a single HTTP request and the expected decoded response type.

| Field | Type | Notes |
|-------|------|-------|
| `path` | `String` | URL path, relative to the base URL provided at implementation initialisation (e.g. `/trending/movie/week`) |
| `method` | `HTTPMethod` | Initially `.get` only |
| `queryItems` | `[URLQueryItem]` | Additional query parameters; auth is not included here |

`HTTPMethod` is an enum with at least the case `.get`. Additional cases may be added later without breaking existing call sites.

### 3.2 `ImageRequest`

A value type describing an image fetch. Kept separate from `Request<Response>` because image responses are not JSON-decoded.

| Field | Type | Notes |
|-------|------|-------|
| `path` | `String` | Relative image path as stored on a domain model (e.g. `/abc123.jpg`) |
| `sizeVariant` | `String` | Opaque size token interpolated directly into the image URL; the caller is solely responsible for supplying the correct value |

The networking layer has no knowledge of what `sizeVariant` values mean. It places the string as-is into the image URL: `{imageBaseURL}/{sizeVariant}/{path}`. Any mapping from a higher-level size concept (e.g. small, medium, large) to a concrete token is the caller's responsibility.

### 3.3 `NetworkError`

Two cases only.

| Case | When |
|------|------|
| `networkUnavailable` | No connectivity or transport failure (`URLError.notConnectedToInternet`, `.networkConnectionLost`, etc.) |
| `serverError` | HTTP 4xx/5xx, JSON decoding failure, corrupt image data, or any other fault |

The original underlying error is not surfaced to callers.

---

## 4. `HTTPClient` interface

The `HTTPClient` interface is the transport seam. Consumers depend on it exclusively; they never reference `HTTPClient implementation` directly. Both methods throw `NetworkError` exclusively and must not block the main thread.

#### Function `execute`
- **input:** `request` — a `Request<Response>` where `Response` is `Decodable`
- **throws:** yes — `NetworkError`
- **returns:** a decoded value of type `Response`

#### Function `fetchImage`
- **input:** `request` — an `ImageRequest`
- **throws:** yes — `NetworkError`
- **returns:** raw `Data` of the image response body

---

## 5. `HTTPClient implementation` — functional requirements

### 5.1 Construction

| Parameter | Type | Notes |
|-----------|------|-------|
| `baseURL` | `URL` | Root URL prepended to every `Request.path` (e.g. `https://api.themoviedb.org/3`) |
| `imageBaseURL` | `URL` | Root URL for image requests (e.g. `https://image.tmdb.org/t/p`) |
| `apiKey` | `String` | Appended as `api_key=<value>` query parameter on every request; never exposed publicly |
| `session` | `URLSession` | Defaults to `.shared`; overridable for tests |

### 5.2 Request execution

- Construct a full URL by appending `Request.path` to `baseURL`.
- Append `Request.queryItems` and the `api_key` query parameter to the URL. The API key is added by `HTTPClient implementation`; callers must not include it in `Request.queryItems`.
- Execute the request with `URLSession`. Any non-2xx HTTP response maps to `NetworkError.serverError`.
- Decode the response body with `JSONDecoder` using `keyDecodingStrategy = .convertFromSnakeCase` into `Response`.
- Map all errors to `NetworkError` per section 3.3.
- No retry logic; no timeout override beyond system defaults.

### 5.3 Image execution

- Construct the full image URL internally: `{imageBaseURL}/{sizeVariant}/{path}`, using `ImageRequest.sizeVariant` as-is.
- Fetch with `URLSession`. Return the raw response body as `Data`.
- An empty response body maps to `NetworkError.serverError`.
- The API key is **not** appended to image requests.
- Map all other errors to `NetworkError` per section 3.3.

### 5.4 Concurrency

- All stored properties are immutable after initialisation.
- Methods must not block the main thread.

---

## 6. Non-functional requirements

| Concern | Requirement |
|---------|-------------|
| Swift version | Swift 5.9 |
| Platform | iOS 17+ |
| Dependencies | `Foundation` only; no third-party libraries |
| Isolation | No dependency on any domain model, design system, or consumer target |
| API key safety | Key must not appear in log output, crash reports, or any public interface |

---

## 7. Out of scope

- Caching (memory or disk) for any response or image.
- Retry, backoff, or circuit-breaker logic.
- Pagination parameters.
- Authentication mechanisms other than `api_key` query parameter.
- Any domain models, endpoint paths, or TMDB-specific knowledge.
- Any UI or SwiftUI components.
- How any consumer wires or uses this library.

---

## 8. Acceptance criteria

| # | Criterion |
|---|-----------|
| AC-1 | `execute(_:)` returns a correctly decoded `Response` given a 2xx response with valid JSON. |
| AC-2 | `execute(_:)` throws `NetworkError.serverError` for any HTTP 4xx or 5xx response. |
| AC-3 | `execute(_:)` throws `NetworkError.networkUnavailable` for `URLError.notConnectedToInternet`. |
| AC-4 | `execute(_:)` throws `NetworkError.serverError` for a malformed JSON body. |
| AC-5 | `fetchImage(_:)` returns the raw `Data` of the response body given a 2xx response. |
| AC-6 | `fetchImage(_:)` throws `NetworkError.serverError` for an empty response body. |
| AC-7 | `HTTPClient implementation` appends `api_key` to every `execute` request and never to image requests. |
| AC-8 | A consumer depending only on the `HTTPClient` interface can be fully tested by injecting a mock without importing `HTTPClient implementation`. |
