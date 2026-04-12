# TMDBClient Service Plan for Movie Tracker

## 1. Overview

`TMDBClient` is the single service layer module that owns all communication with the TMDB REST API v3. It translates HTTP responses into domain types, shields all callers from transport and encoding details, and exposes a single typed protocol to the feature layer.

It consumes the Networking framework (`HTTPClient`) and has no dependency on SwiftData or any persistence layer. The same module is shared across the MVVM, VIPER, and TCA branches without modification.

---

## 2. Domain Capability & Responsibility Boundary

**Domain capability**: provide typed, domain-level access to TMDB movie data.

### In Scope

- Fetch trending movies — `GET /trending/movie/week`
- Search movies — `GET /search/movie?query={query}`
- Fetch movie detail — `GET /movie/{id}` → returns `MovieDetail` with `cast: .notRetrieved`
- Fetch credits — `GET /movie/{id}/credits` → returns full `[CastMember]`
- Fetch genres — `GET /genre/movie/list` with in-memory session cache
- Fetch poster image data — given a `Movie` or a `posterPath: String` and a `PosterSize`
- Map `NetworkError` to `TMDBError`
- Construct all `HTTPRequest` values (paths, query items)
- Resolve poster base URL and size segment from a `PosterSize` enum value

### Explicitly Out of Scope

| Concern | Owner |
|---|---|
| Composing `MovieDetail` from `fetchMovie` + `fetchCredits` | Feature layer |
| Slicing cast to top-three for display | Feature layer |
| Non-fatal cast failure degradation logic | Feature layer |
| Choosing `PosterSize` enum case for a given context | Feature layer |
| Concurrency delivery mechanism | Each architectural implementation plan |
| `WatchlistEntry` and `Review` persistence | Persistence / repo layer |

---

## 3. Framework Dependencies

| Framework | Interface consumed | Requirement |
|---|---|---|
| Networking | `HTTPClient` protocol | Generic JSON fetch (`HTTPRequest` → `Decodable`); image data fetch (URL → `Data`) |
| Networking | `HTTPRequest` | Path, query items, HTTP method construction |
| Networking | `NetworkError` | Mapped internally to `TMDBError`; never exposed to callers |
| Networking | `NetworkConfiguration` | Base URL and API key injected at construction via `HTTPClient`; `TMDBClient` does not reference `NetworkConfiguration` directly |

No other framework dependencies. No SwiftData or persistence dependency.

---

## 4. Business Rules

- **Genre cache guard**: a failed genre fetch does not overwrite a previously successful cache. A nil or empty result from a failed fetch is discarded; the cached value is preserved and the next call re-attempts.
- **Force refresh**: `fetchGenres(force:)` accepts `force: Bool`. When `force: true` the cache is bypassed and a live request is dispatched regardless of current cache state.
- **`TMDBError.invalidRequest` is a programming error**: triggers `assertionFailure` in debug builds. It must never occur in production. It indicates malformed `HTTPRequest` construction inside `TMDBClient` itself — a defect, not a runtime condition.
- **Read-only service**: `TMDBClient` never writes to SwiftData or any other persistence store. It has no mutation responsibilities with respect to domain state.

---

## 5. Public Interface

A single protocol `TMDBClientProtocol` is exposed to the feature layer. All operations are request/response only — there are no observable state streams.

```swift
protocol TMDBClientProtocol {
    func fetchTrending() async throws -> [Movie]
    func fetchSearch(query: String) async throws -> [Movie]
    func fetchMovie(id: Int) async throws -> MovieDetail
    func fetchCredits(id: Int) async throws -> [CastMember]
    func fetchGenres(force: Bool) async throws -> [Genre]
    func fetchPosterData(movie: Movie, size: PosterSize) async throws -> Data
    func fetchPosterData(posterPath: String, size: PosterSize) async throws -> Data
}
```

All operations throw `TMDBError`. The exact call signature (async throws, `Result<T, TMDBError>`, Combine `AnyPublisher`) is determined per architectural implementation plan. The protocol above uses async throws as the reference form; each implementation adapts the signature to its concurrency delivery mechanism.

### `PosterSize`

```swift
enum PosterSize {
    case thumbnail  // resolves to w185
    case full       // resolves to w500
}
```

The TMDB image base URL (`https://image.tmdb.org/t/p/`) and the size segment mapping are baked into `TMDBClient`. Callers supply only the `PosterSize` enum case.

---

## 6. State Ownership

| State | Type | Scope | Lifecycle |
|---|---|---|---|
| Genre list cache | `[Genre]?` | In-memory, session-scoped | Populated on first successful `fetchGenres` call; preserved across subsequent calls; cleared on app termination; forcibly re-fetchable via `fetchGenres(force: true)` |

All other operations are stateless request/response. No other state is held by the service.

The genre cache write must be safe under the chosen concurrency model. For an actor-isolated implementation the actor's executor provides safety automatically. For a class-based implementation a mutex, serial queue, or equivalent must guard the property.

---

## 7. Data Transformation & Mapping

| Endpoint | Decode target | Private type | Mapping |
|---|---|---|---|
| `GET /trending/movie/week` | `[Movie]` directly via `CodingKeys` | None | None — domain struct is the decode target; `results` envelope is a private wrapper |
| `GET /search/movie` | `[Movie]` directly via `CodingKeys` | None | None — same paged-results envelope as trending |
| `GET /genre/movie/list` | Private `GenreListResponse` | `GenreListResponse { genres: [Genre] }` | Extract `genres` array; return `[Genre]` |
| `GET /movie/{id}` | Private `MovieDetailResponse` | `MovieDetailResponse` | Map to `MovieDetail(movie:genres:cast:.notRetrieved)` |
| `GET /movie/{id}/credits` | Private `CreditsResponse` | `CreditsResponse { cast: [CastMember] }` | Extract `cast` array; return `[CastMember]` |
| Image data | Raw `Data` via `HTTPClient` image operation | — | No transformation; return as-is |

`MovieDetailResponse` is the only DTO that requires an explicit mapping step. The detail endpoint returns full `Genre` objects and additional fields that differ from the list `Movie` shape; a private struct isolates those differences.

All private envelope types (`GenreListResponse`, `CreditsResponse`, `MovieDetailResponse`) are defined inside the service module and are never visible to callers.

`CodingKeys` on `Movie` and `CastMember` handle snake_case-to-camelCase mapping (e.g., `poster_path` → `posterPath`, `vote_average` → `voteAverage`).

---

## 8. Caching Strategy

| Operation | Cache | Invalidation | Stale-data handling |
|---|---|---|---|
| `fetchGenres` | In-memory `[Genre]?`, session-scoped | App termination; `fetchGenres(force: true)` | Failed fetch does not poison the cache; previous value is preserved |
| All other operations | None | N/A | Each call dispatches a live network request |

No image caching is provided by this service. Image loading views in the feature layer are responsible for any display-level caching.

---

## 9. Offline & Sync Behavior

`TMDBClient` does not degrade gracefully by design. When the device is offline, `HTTPClient` returns `NetworkError.noConnectivity`, which `TMDBClient` maps to `TMDBError.offline` and propagates to the caller.

The feature layer owns all retry affordances, consistent with the PRD requirement for inline error states with explicit user-triggered retry. No request queuing, no local fallback, and no background sync are provided.

---

## 10. Concurrency Model

The exact delivery mechanism is deferred to each architectural implementation plan. Requirements that every implementation must satisfy:

- All operations must be non-blocking; the main thread must not be held waiting on a network response.
- The service must not introduce shared mutable state beyond the genre cache.
- Genre cache writes must be safe under the chosen model:
  - **Actor**: actor isolation provides safety automatically.
  - **Class / struct**: a serial `DispatchQueue` or equivalent mutex must guard the cache property.
- `HTTPClient` is consumed as injected; thread-safety guarantees of the concrete `HTTPClient` instance are governed by the Networking framework plan and the implementation variant.

---

## 11. Error Handling

`TMDBClient` is the sole point where `NetworkError` is mapped to `TMDBError`. Callers only ever see `TMDBError`.

| `NetworkError` source | `TMDBError` case | Recoverability |
|---|---|---|
| `.noConnectivity` | `.offline` | Recoverable — user restores connectivity and retries |
| `.serverError(any)`, `.transportError`, `.decodingError` | `.networkFailure` | Recoverable for transient failures; feature layer shows retry affordance |
| `.invalidURL` | `.invalidRequest` | Not recoverable at runtime — `assertionFailure` in debug; must not occur in production |

```swift
enum TMDBError: Error {
    case offline
    case networkFailure
    case invalidRequest
}
```

TMDB error response bodies (`status_message`, `status_code`) are not decoded. `.networkFailure` is sufficient for MVP. No `NetworkError` value is exposed beyond the service boundary.

---

## 12. iOS-Specific Concerns

- **No Keychain usage**: the API key is carried internally by the injected `HTTPClient` (via `NetworkConfiguration`); `TMDBClient` never reads the key and never touches Keychain.
- **No background execution**: all requests run in the foreground `URLSession` provided by the Networking framework. No `BGTaskScheduler` registration.
- **No APNs, CloudKit, or iCloud sync**.
- **No runtime permission gates**: outbound HTTPS to TMDB requires no entitlement on iOS 17.
- **App Transport Security**: all TMDB and TMDB image URLs use HTTPS; no ATS exception keys are required.

---

## 13. Initialization & Configuration

`TMDBClient` is initialized with a single dependency: an `HTTPClient` instance.

```swift
init(httpClient: HTTPClient)
```

`HTTPClient` carries `NetworkConfiguration` (base URL, API key) internally. `TMDBClient` does not reference `NetworkConfiguration` directly and does not read the API key. The Networking framework plan describes how `HTTPClient` appends the API key to each request.

The composition root constructs `TMDBClient` once and injects it into each feature module via the DI mechanism of the architectural variant (environment value, initializer injection, factory closure, or equivalent). One instance is shared for the lifetime of the app process.

---

## 14. Platform & OS Constraints

- **Minimum deployment target**: iOS 17. All APIs used (`URLSession` via `HTTPClient`, `Codable`, Swift concurrency) are available across the full supported range.
- **Swift version**: Swift 5.9+; structured concurrency and `async`/`await` are available.
- **No entitlements required**: outbound HTTPS needs no special capability.
- **No background session**: foreground `URLSession` only; aligns with PRD's non-blocking UI requirement without requiring background delivery.

---

## 15. Deferred / Out of Scope for MVP

| Item | Rationale |
|---|---|
| Concurrency delivery mechanism (async throws vs. Combine vs. callbacks) | Depends on architectural pattern; defined per-implementation plan |
| TMDB error response body decoding (`status_message`) | Not required by PRD for MVP |
| Image caching / persistence | Not required by PRD; deferred per Networking framework plan |
| Automatic retry with back-off | PRD specifies manual UI-triggered retry only |
| Pagination beyond first page | Explicitly out of scope in PRD |
| Additional `PosterSize` cases beyond `.thumbnail` / `.full` | No current display requirement |

---

## 16. Open Questions / Unresolved Decisions

None. All planning questions have been resolved and decisions are recorded in the planning summary.
