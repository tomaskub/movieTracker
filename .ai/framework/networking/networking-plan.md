# Networking Framework Plan for Movie Tracker

## 1. Overview

The Networking framework is a thin, generic HTTP transport layer that sits directly above `URLSession` and below the service layer in the Movie Tracker stack. It has one concern: take a caller-constructed request description, dispatch it over the network, and return either a decoded typed value or raw image bytes — or a typed error if anything goes wrong along the way.

The framework is shared across all three architectural implementations (MVVM, VIPER, TCA). It defines the contract those implementations consume, but prescribes nothing about how they wire, schedule, or isolate calls. It has no knowledge of TMDB endpoints, domain models, or business rules.

Constraints from the tech stack that shape the design:

- iOS 17 minimum deployment target; `URLSession` is available across the full supported range.
- TMDB REST v3, authenticated via an API key appended as a query parameter; no OAuth or Bearer token for MVP.
- API key is read from a build-time `.xcconfig`-backed configuration; it must never be hardcoded in source or stored in SwiftData.
- No third-party networking SDK; only platform APIs.

---

## 2. Responsibility & Boundary

### In Scope

- Assembling a `URL` from a `NetworkConfiguration` base URL, an `HTTPRequest` path, framework-injected API key query item, and caller-provided query items.
- Constructing and dispatching a `URLRequest` via `URLSession`.
- Validating the HTTP status code and mapping non-2xx responses to `NetworkError.serverError(statusCode:)`.
- Decoding a `Decodable` response body from the raw response `Data`.
- Fetching raw `Data` for an arbitrary URL (image use case).
- Mapping all transport-level and decoding failures to the `NetworkError` enum.
- Appending the TMDB API key as a query parameter on every request dispatched through the framework's generic JSON method.

### Out of Scope

| Concern | Owning Layer |
|---|---|
| Endpoint path and query parameter construction | Service layer |
| Domain model assembly (e.g. composing `MovieDetail` from two responses) | Service layer |
| Domain-level error mapping (`NetworkError` → feature-specific error) | Service layer |
| TMDB error response body decoding (`status_message`, `status_code`) | Service layer |
| Retry logic | Consumer / feature layer |
| Image caching | Deferred (not required by PRD) |
| Actor isolation strategy, MainActor constraints, threading guarantees | Each architectural implementation |
| Strict Swift concurrency enforcement | Separate initiative |
| Mock/stub implementations for unit testing | Each architectural implementation |

The boundary at the service layer is justified because endpoint knowledge and domain assembly require product-specific context that must not leak into a generic infrastructure component. The boundary at callers for retry is justified because the PRD specifies only manual, UI-triggered retry; the framework re-executes cleanly when called again.

---

## 3. Public API Surface

### 3.1 `HTTPMethod`

- **Kind**: `enum` with `String` raw value
- **Purpose**: Represents an HTTP verb. Callers use it when describing an outbound request.
- **Cases**: `get`, `post`, `put`, `delete`, `patch`

All current TMDB endpoints are `GET`. The remaining cases are defined for completeness of the generic infrastructure contract.

---

### 3.2 `HTTPRequest`

- **Kind**: abstraction or concrete type
- **Purpose**: Describes an outbound HTTP request. The framework owns the definition; the service layer owns construction.
- **Required information** a request description must carry:

| Field | Type | Notes |
|---|---|---|
| HTTP method | `HTTPMethod` | HTTP verb |
| Path | `String` | Relative to `NetworkConfiguration.baseURL` (e.g. `/trending/movie/week`) |
| Query items | `[URLQueryItem]` | Caller-provided; the framework appends the API key item |
| Headers | `[String: String]` | Per-request headers; empty by default |
| Body | `Data?` | Request body; `nil` for all current TMDB endpoints |

---

### 3.3 `NetworkConfiguration`

- **Kind**: `struct`
- **Purpose**: Immutable configuration injected into the client at construction time. Carries the base URL and API key so neither is hardcoded in the framework.
- **Properties**:

| Property | Type | Notes |
|---|---|---|
| `baseURL` | `URL` | `https://api.themoviedb.org/3` for production |
| `apiKey` | `String` | TMDB API key read from build-time configuration |

---

### 3.4 `NetworkError`

- **Kind**: `enum`
- **Purpose**: Typed error surface for all infrastructure-level failures. Owned exclusively by the Networking framework; callers receive and inspect these values.
- **Cases**:

| Case | Trigger |
|---|---|
| `.invalidURL` | URL assembly from `NetworkConfiguration.baseURL` + `HTTPRequest.path` + query items produces an invalid URL |
| `.noConnectivity` | `URLError.notConnectedToInternet` |
| `.serverError(statusCode: Int)` | HTTP response with status code outside the 2xx range |
| `.decodingError(DecodingError)` | Response body does not conform to the expected `Decodable` shape |
| `.transportError(URLError)` | All other `URLError` failures (timeout, SSL, DNS, etc.) |

- **Conformances**: `Error`

---

### 3.5 HTTP Client Interface

- **Kind**: Abstraction
- **Purpose**: The primary interface for all callers. Isolates the rest of the codebase from `URLSession` and from the production implementation. Each architectural variant supplies its own production implementation and, where needed, its own test double.
- **Operations** the interface must expose:
  - A generic JSON-fetch operation that accepts a request description and returns a decoded, typed response value, or a `NetworkError` on failure.
  - An image-data operation that accepts a URL and returns raw `Data`, or a `NetworkError` on failure. The API key is not appended for this operation.
- The exact call signature — including how results and errors are delivered to the caller — is an implementation decision (see §7 Concurrency Model).

---

### 3.6 Production Client

- **Purpose**: The production implementation of the HTTP client interface. Wraps `URLSession` and `NetworkConfiguration`. This is the only point in the framework that touches `URLSession` directly.
- The Swift kind (class, struct, actor) and precise initializer signature are implementation decisions. The implementation must accept a `NetworkConfiguration` at construction time and must allow a substitute `URLSession` to be injected for testing (see §6).

---

## 4. Abstraction Depth

**Decision: thin `URLSession` wrapper.**

A single client interface over a single production implementation is the right depth for this product. Rationale:

- Five REST endpoints, all GET, first-page-only responses. There is no request queue, no auth refresh, no token rotation, no request deduplication, and no pagination that would justify a richer abstraction.
- The three architectural variants sit above this layer and can each introduce whatever scheduling, caching, or composition they need without requiring changes to the framework.
- A thinner contract is easier to replace or evolve. If a future iteration introduces pagination or a middleware pipeline, the client interface is the extension point — not the internals of this framework.

The one deliberate affordance beyond a raw `URLSession` call is typed error mapping: the framework converts `URLError` and `DecodingError` into the `NetworkError` domain so that callers do not need to downcast untyped `Error` values. This is a minimal convenience that every caller would otherwise duplicate.

---

## 5. Third-Party SDK Isolation

No third-party networking SDK is used. The framework wraps `URLSession` directly, which is a first-party Apple platform API with a stable interface across the supported deployment range.

No additional abstraction beyond the framework's own client interface is required for SDK isolation purposes.

---

## 6. Testability

The client interface is the test seam for all layers above the framework.

**Shared test-support target**: not provided by the framework itself. This is a per-implementation decision:

- The MVVM and VIPER variants are expected to provide test doubles (stubs or mocks) for the client interface in their own test targets.
- The TCA variant is expected to use its own effect-stubbing mechanism and likely opts out of a shared test double.

**What each test double needs to cover**: both operations — generic JSON fetch and image data fetch — with configurable return values or recorded invocations.

**Framework-level unit tests**: the production client implementation can be tested in isolation by injecting a custom `URLSession` configured with a `URLProtocol` subclass that intercepts requests and returns fixture data. This approach exercises the full URL assembly, status-code validation, and decoding path without real network access.

---

## 7. Concurrency Model

The exact mechanism for async execution and result delivery is an implementation decision for each architectural variant. The framework plan does not prescribe it.

**Non-blocking requirement**: the PRD requires that network calls do not block the main UI. The framework implementation must ensure its operations do not block the calling thread; how that is achieved is an implementation concern.

**Shared mutable state**: the production client holds only its injected `NetworkConfiguration` and `URLSession` after construction. The implementation must not introduce shared mutable state that requires external synchronisation.

**URL assembly**: assembling the final URL from `NetworkConfiguration.baseURL`, the request path, and query items must be a pure function of those inputs with no retained mutable state involved.

---

## 8. Error Handling

The framework owns one error type: `NetworkError`.

| Error type | Failure domain | Cases | Propagation | Recoverability |
|---|---|---|---|---|
| `NetworkError` | HTTP transport and JSON decoding | `.invalidURL`, `.noConnectivity`, `.serverError(statusCode:)`, `.decodingError(DecodingError)`, `.transportError(URLError)` | Callers receive a `NetworkError` value directly — the propagation mechanism (thrown error, `Result`, publisher failure, callback) is an implementation decision | See below |

**Recoverability from the caller's perspective**:

- `.noConnectivity` — **recoverable**; user can restore connectivity and retry.
- `.serverError(statusCode:)` — **conditionally recoverable**; depends on the status code. 5xx are transient and worth retrying; 4xx (except 429) typically indicate a logic error. The service layer interprets the code.
- `.transportError(URLError)` — **recoverable** for transient conditions (timeout, DNS); less so for SSL failures. The service layer decides.
- `.decodingError(DecodingError)` — **not recoverable by the user**; indicates a contract mismatch between the framework's expected type and the server response. Surfaces as a non-retryable error in the UI; logged for diagnostics.
- `.invalidURL` — **not recoverable at runtime**; indicates a programming error in the service layer's `HTTPRequest` construction. Should not occur in production.

TMDB error response bodies (`status_message`, `status_code` JSON fields) are not decoded by the framework. `.serverError(statusCode:)` carries only the HTTP status code; interpretation is the service layer's responsibility.

---

## 9. Initialization & Configuration

**Bootstrap sequence**:

1. The app target reads the TMDB API key from the `.xcconfig`-backed build configuration (e.g. via an `Info.plist` entry keyed `TMDB_API_KEY`).
2. The app composition root constructs a `NetworkConfiguration` value with the base URL and API key.
3. The composition root constructs the production client, passing the `NetworkConfiguration` and optionally a substitute `URLSession` (e.g. configured with a custom timeout).
4. The client is injected into the service layer via the DI mechanism specific to each architectural variant (initializer injection, environment value, factory closure, or equivalent).

**DI-agnosticism**: the production client must require only its `NetworkConfiguration` and `URLSession` dependencies at construction time. It must not reference any global, singleton, or DI container, so any variant can inject it without modifying the framework.

**Lazy initialization**: not used. The client is fully ready after initialization; no deferred setup or registration step is required.

---

## 10. Platform & OS Constraints

- **Minimum deployment target**: iOS 17. `URLSession` is available across the full supported range; no back-deployment shim is required.
- **App Transport Security (ATS)**: TMDB's base URL is HTTPS. ATS is enabled by default; no exception keys are needed.
- **Entitlements**: outbound HTTPS requires no special entitlement on iOS.
- **Background execution**: the framework does not use background `URLSession` configurations. All requests run in the foreground session. This aligns with the PRD's requirement that network calls be non-blocking to the main UI while not requiring background delivery.
- **Privacy manifest**: the Networking framework itself does not access any privacy-sensitive system APIs. The app-level `PrivacyInfo.xcprivacy` entry for network access is sufficient; no framework-specific privacy manifest is required.
- **SwiftData dependency**: none. The Networking framework is entirely independent of the Persistence layer.

---

## 11. Deferred / Out of Scope for MVP

| Deferred item | Rationale | Trigger to revisit |
|---|---|---|
| Image caching | Not required by PRD; poster images load on demand via the image-data operation and are not cached. Platform image loading views handle display. | PRD adds an offline image requirement or image-loading performance becomes a measured problem. |
| Bearer token / OAuth authentication | TMDB API key query parameter is sufficient for this product's scope. Bearer is TMDB's recommended long-term approach. | Product requirement changes, or TMDB deprecates query-parameter auth. |
| Automatic retry with back-off | PRD specifies only manual UI-triggered retry. Automatic retry adds complexity not yet justified. | PRD introduces reliability SLA or a background sync feature. |
| Interceptor / middleware pipeline | No current use case (no auth refresh, no request signing, no logging middleware required). | Multiple cross-cutting request concerns emerge that cannot be composed cleanly above the framework. |
| Shared `NetworkingTestSupport` target | Test double strategy is per-implementation; TCA likely opts out. Sharing would create a dependency between test targets across variants. | Convergence on a single test strategy across all three implementations. |
| Strict Swift concurrency enforcement (`Sendable` audit, `@preconcurrency`) | Tracked as a separate initiative; does not block the MVP framework contract. | Strict concurrency initiative is scheduled. |
| Background `URLSession` configuration | No PRD requirement for background network delivery. | A future feature requires background prefetch or download continuation after app suspension. |

---

## 12. Open Questions / Unresolved Decisions

None. All planning questions have been resolved and all decisions are recorded in the planning summary (`networking-planning-notes.md`).
