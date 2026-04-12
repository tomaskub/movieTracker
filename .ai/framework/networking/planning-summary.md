# Networking Framework — Planning Summary

## Decisions

1. The Networking framework dispatches HTTP requests generically and decodes `Decodable` responses. Endpoint construction, domain assembly, and domain error mapping are service-layer concerns.
2. The framework provides a separate image-fetching method returning `Data`, as a second method on the same interface. View layer is not responsible for fetching image data.
3. API key authentication uses a query parameter (not Bearer token) for MVP.
4. The framework exposes a single interface with two methods. `HTTPRequest` type/interface and interface constraints are defined in the framework; instantiation and construction of `HTTPRequest` values is the service layer's responsibility. No lower-level raw-data interface.
5. `HTTPRequest` is a value type or intreface. The service layer owns construction; the framework owns the definition.
6. A thin `URLSession` wrapper is sufficient for MVP. No interceptor pipeline, no request queue.
7. Retry logic is not a framework concern. Consumers call the framework again on user-triggered retry.
8. `NetworkError` is a typed enum with five cases including a dedicated `.noConnectivity` case.
9. TMDB server error bodies are not decoded by the framework. Non-2xx responses surface as `.serverError(statusCode: Int)`; interpretation is the service layer's responsibility.
10. The execution and threading model — including how results are delivered to callers and how concurrent access is managed — is deferred to each architectural implementation variant.
11. Strict concurrency enforcement is not addressed at this layer and is tracked as a separate initiative.
12. `NetworkConfiguration` is a value type injected at construction time. The app target is responsible for instantiating it (reading the API key from `.xcconfig`-backed configuration).
13. Test support (mocks/stubs) is a per-implementation decision. Not a shared framework concern.

---

## Matched Recommendations

1. **Thin transport wrapper** — matched to decision 6. A single interface backed by a `URLSession` concrete type is the right depth given five simple REST endpoints, first-page-only responses, and no auth refresh.
2. **API key as query parameter** — matched to decision 3. Injected once at construction via `NetworkConfiguration`; the concrete implementation appends it to every request automatically.
3. **`HTTPRequest` as a plain `struct` or `interface`** — matched to decisions 4 and 5. Path, query items, HTTP method, and optional body. Type/interface defined by the framework; constructed by the service layer.
4. **`NetworkError` enum with five cases** — matched to decisions 8 and 9. `.noConnectivity`, `.serverError(statusCode: Int)`, `.decodingError(DecodingError)`, `.transportError(URLError)`, `.invalidURL`.
5. **No retry in the framework** — matched to decision 7. PRD specifies only a manual UI retry affordance; service layer re-calls the framework.
6. **No image fetching via platform image-loading components** — matched to decision 2. A dedicated second method on the interface returns raw image data; the view layer is decoupled from fetching logic.
7. **`NetworkConfiguration` value type** — matched to decision 12. Holds `baseURL` and `apiKey`; constructed by the app target from `.xcconfig`-backed `Info.plist` entry.
8. **Test support per-implementation** — matched to decision 13. MVVM and VIPER variants likely to add stubs/mocks; TCA likely to opt out.

---

## Summary

### a. Responsibility and Boundaries

**In scope:**
- Constructing and dispatching HTTP requests via `URLSession`
- Decoding `Decodable` JSON responses generically
- Fetching image data as raw `Data` from a given URL
- Injecting the API key as a query parameter on every request
- Mapping transport and HTTP failures to a typed `NetworkError`

**Explicitly out of scope (service layer and above):**
- Endpoint path and query parameter construction — service layer concern
- `URLRequest` construction — service layer concern
- Domain-level error mapping — service layer concern
- Domain model assembly (e.g. composing `MovieDetail` from two responses) — service layer concern
- TMDB server error body decoding — service layer concern
- Retry logic — consumer/feature concern
- Image caching — not required by PRD; deferred

### b. Interface Design

A single public interface exposes two operations:

- **Generic JSON decode** — accepts an `HTTPRequest` and returns a decoded, typed response value.
- **Image data fetch** — accepts a URL and returns raw image bytes.

`HTTPRequest` is a value type defined by the Networking framework. It encapsulates HTTP method, path, query items, and headers. The service layer is responsible for constructing `HTTPRequest` values; the framework owns the type definition and all URL assembly.

No lower-level raw-data interface is exposed to callers. Both operations surface errors as a typed `NetworkError`; the exact error-propagation mechanism (thrown error, result type, callback, reactive stream, etc.) is an implementation concern.

### c. Abstraction Depth

**Decision: thin `URLSession` wrapper.**

Rationale: five REST endpoints, first-page-only responses, no pagination, no auth refresh, no background prefetch. A richer abstraction (interceptor pipeline, request queue) is not justified by the MVP product requirements. Each of the three architectural variants can layer additional behavior above this interface without modifying the framework.

### d. Third-Party SDK Isolation

No third-party networking SDK is used. `URLSession` is a platform API wrapped directly. No wrapper protocol beyond the framework's own interface is required.

### e. Testability Strategy

The framework's public interface is the test seam for all layers above. Each architectural implementation decides independently whether to provide a stub or mock conformance:
- MVVM and VIPER variants are likely to provide stub/mock implementations for unit-testing service and view-model layers.
- TCA variant is likely to use its own effect-stubbing mechanism and opt out of a shared mock.

No shared `NetworkingTestSupport` target is provided by the framework itself.

### f. Execution and Threading Model

How the framework delivers results to callers — including threading guarantees, the concrete type that backs the interface, and how concurrent access is managed — is deferred to each architectural implementation. The framework plan does not prescribe these. Each variant adopts the model consistent with its architecture (MVVM, TCA, VIPER).

Strict concurrency enforcement is explicitly out of scope for this framework and is tracked as a separate initiative.

### g. Error Types and Propagation

The framework owns and vends a `NetworkError` enum:

| Case | Trigger |
|---|---|
| `.noConnectivity` | `URLError.notConnectedToInternet` |
| `.serverError(statusCode: Int)` | Non-2xx HTTP response |
| `.decodingError(DecodingError)` | Response JSON does not match expected `Decodable` shape |
| `.transportError(URLError)` | All other `URLError` failures (timeout, SSL, DNS, etc.) |
| `.invalidURL` | Malformed URL at request construction time |

TMDB error response bodies (`status_message`, `status_code`) are not decoded by the framework. The service layer interprets `.serverError(statusCode:)` and maps it to domain errors as appropriate.

### h. Initialization and Configuration

A `NetworkConfiguration` value type (`struct`) is injected into the framework at construction time. It holds:
- `baseURL: URL` — `https://api.themoviedb.org/3`
- `apiKey: String` — TMDB API key

The app target is responsible for constructing `NetworkConfiguration`, reading the API key from the `.xcconfig`-backed build configuration (e.g. via `Info.plist` entry). The key is never hardcoded in the framework or stored in SwiftData. The framework appends the key as a query parameter (`?api_key=…`) to every outbound request.

### i. OS Version and Platform Constraints

- **Minimum deployment target**: iOS 17 (aligned with project-wide constraint).
- The underlying HTTP transport API is available on all supported platform versions; no back-deployment shim is required.
- SwiftData (used by the Persistence layer) is iOS 17-only; the Networking framework has no SwiftData dependency and is unaffected.
- No additional platform API gates apply to this framework.

### j. Deferred to a Later Iteration

| Aspect | Reason |
|---|---|
| Image caching | Not required by PRD; platform image loading or a raw data fetch is sufficient for MVP |
| Bearer token / OAuth auth | API key query parameter is sufficient for TMDB MVP; Bearer is TMDB's recommended long-term approach |
| Automatic retry | PRD specifies manual UI retry only; automatic retry adds complexity not yet justified |
| Interceptor / middleware pipeline | No use case in the current feature set |
| Shared test-support target | Per-implementation decision; TCA likely opts out |
| Strict concurrency enforcement | Tracked as a separate initiative |

---

## Unresolved Issues

None. All planning questions have been resolved and all decisions are recorded above.
