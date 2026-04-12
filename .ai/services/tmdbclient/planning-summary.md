# TMDBClient Service — Planning Summary

## Decisions

1. `TMDBClient` owns all five TMDB endpoint operations: trending, search, movie detail, credits, and genres.
2. `TMDBClient` exposes `fetchPosterData` overloaded on `movie: Movie` and `posterPath: String`, both accepting a `PosterSize` enum. The client owns base URL prepending and size segment resolution. `PosterSize` has `.thumbnail` (→ `w185`) and `.full` (→ `w500`).
3. `fetchMovie(id:)` and `fetchCredits(id:)` are exposed as two separate operations. The feature layer is responsible for composing them into a final `MovieDetail`.
4. `TMDBError` enum with three cases: `.networkFailure`, `.offline`, `.invalidRequest`. `.invalidRequest` triggers an `assertionFailure`/crash in debug builds and is treated as a non-recoverable programming error.
5. Decode directly into domain structs using `CodingKeys` — no intermediate DTOs for list/search endpoints.
6. Private response envelope types (`GenreListResponse`, `CreditsResponse`, `MovieDetailResponse`) live inside the service as implementation details. None are visible to callers.
7. Credits slicing (top three for display) is the consumer's responsibility. `fetchCredits(id:)` returns the full `[CastMember]` list.
8. Concurrency model (async/await, Combine, completion handlers) is left to each architectural implementation plan.
9. Genre list is cached in memory for the session. The cache defends against failed fetches (nil/empty guard — a failed fetch does not permanently poison the cache). `fetchGenres(force:)` accepts a `force: Bool` parameter to bypass the cache and re-fetch.
10. Image base URL and size segment mapping are baked into the client. `PosterSize.thumbnail` maps to `w185`; `PosterSize.full` maps to `w500`.
11. A single `TMDBClientProtocol` is exposed to the feature layer.
12. `/movie/{id}` response is decoded via a private `MovieDetailResponse` DTO, then mapped to `MovieDetail` with `cast: .notRetrieved`. No DTO for list or search responses.
13. Operations are asynchronous but the delivery mechanism (async throws, `Result`, Combine publisher) is left to each architectural implementation plan.
14. Image fetch is a standalone operation: `fetchPosterData(movie: Movie, size: PosterSize)` and `fetchPosterData(posterPath: String, size: PosterSize)`.
15. `MovieDetail.cast` is typed as `CastState` (`.notRetrieved` / `.loaded([CastMember])`). Data plan updated accordingly.

---

## Matched Recommendations

1. **Single `fetchMovieDetail` vs. two operations** — user chose two separate operations; non-fatal cast degradation logic moves to the feature layer.
2. **`TMDBError` domain enum** — confirmed; maps `NetworkError` internally. `.invalidRequest` crashes in debug (assertionFailure) rather than surfacing to UI.
3. **Decode directly into domain structs** — confirmed for list/search endpoints; `CodingKeys` handles snake_case mapping.
4. **Private envelope types** — confirmed; `GenreListResponse`, `CreditsResponse`, `MovieDetailResponse` are service-internal.
5. **`fetchPosterData(posterPath: String, size: PosterSize)`** — recommended and adopted as one of two overloads; makes the operation composable with both `Movie.posterPath` and `WatchlistEntry.posterPath`.
6. **`CastState` enum** — recommended and adopted; replaces `[CastMember]` on `MovieDetail.cast`; data plan updated.
7. **Genre cache: defend against failed fetch** — confirmed; nil/empty guard prevents a transient failure from locking callers out for the session.
8. **Single protocol** — confirmed.
9. **Do not expose image fetch on the service** — overruled; user explicitly added `fetchPosterData` to the client's responsibility.
10. **`MovieDetail` with `cast: .notRetrieved` as initial state** — confirmed; `fetchMovie` returns `MovieDetail` without cast populated; feature layer merges credits result.

---

## Summary

### a. Domain Capability and Responsibility Boundary

`TMDBClient` is the single service that owns all communication with the TMDB REST API v3. Its domain capability is: **provide typed, domain-level access to TMDB movie data**. It translates HTTP responses into domain types and shields all callers from transport, encoding, and API-specific details.

**In scope:**
- Fetch trending movies (`/trending/movie/week`)
- Search movies (`/search/movie`)
- Fetch movie detail (`/movie/{id}`) → returns `MovieDetail` with `cast: .notRetrieved`
- Fetch credits (`/movie/{id}/credits`) → returns full `[CastMember]`
- Fetch genres (`/genre/movie/list`) with in-memory session cache
- Fetch poster image data given a path or `Movie` and a `PosterSize`
- Map `NetworkError` to `TMDBError`
- Construct all `HTTPRequest` values (paths, query items)

**Explicitly out of scope (delegated):**
- Composing `MovieDetail` from `fetchMovie` + `fetchCredits` results — **feature layer**
- Slicing cast to top-three for display — **feature layer**
- Non-fatal cast failure degradation logic — **feature layer**
- Poster URL size decisions (only `.thumbnail`/`.full` enum, not raw size strings) — **feature layer chooses enum case**
- Concurrency delivery mechanism — **each architectural implementation plan**
- `WatchlistEntry` and `Review` persistence — **persistence/repo layer**

---

### b. Framework Dependencies

| Framework | Interface consumed | What the service requires |
|---|---|---|
| Networking | `HTTPClient` protocol | Generic JSON fetch (`HTTPRequest` → `Decodable`); image data fetch (URL → `Data`) |
| Networking | `HTTPRequest` | Path, query items, HTTP method construction |
| Networking | `NetworkError` | Mapped internally to `TMDBError`; never exposed to callers |
| Networking | `NetworkConfiguration` | Base URL and API key injected at construction; client appends key automatically |

No other framework dependencies. The service has no SwiftData or persistence dependency.

---

### c. Business Rules

- **Genre cache guard**: a failed genre fetch does not overwrite a previously successful cache; nil/empty state is maintained so the next call re-attempts.
- **Force refresh**: `fetchGenres(force: Bool)` bypasses the cache when `force: true`; callers use this for explicit retry after a failure.
- **`TMDBError.invalidRequest` is a programming error**: triggers `assertionFailure` in debug builds; must never occur in production. Indicates malformed `HTTPRequest` construction.
- **No mutation rules**: `TMDBClient` is read-only with respect to domain state; it never writes to persistence.

---

### d. State Ownership

| State | Type | Scope | Lifecycle |
|---|---|---|---|
| Genre list cache | `[Genre]?` | In-memory, session-scoped | Populated on first successful `fetchGenres` call; cleared on app termination; re-fetchable via `force: true` |

No other owned state. All other operations are stateless request/response.

---

### e. Public Interface

A single protocol `TMDBClientProtocol` is exposed to the feature layer. Operations:

```swift
func fetchTrending() → async [Movie] or Result / publisher
func fetchSearch(query: String) → async [Movie] or Result / publisher
func fetchMovie(id: Int) → async MovieDetail or Result / publisher
func fetchCredits(id: Int) → async [CastMember] or Result / publisher
func fetchGenres(force: Bool) → async [Genre] or Result / publisher
func fetchPosterData(movie: Movie, size: PosterSize) → async Data or Result / publisher
func fetchPosterData(posterPath: String, size: PosterSize) → async Data or Result / publisher
```

All operations throw/return `TMDBError`. The exact call signature (async throws, `Result<T, TMDBError>`, Combine `AnyPublisher`) is defined per architectural implementation plan. No observable state streams — all operations are request/response only.

---

### f. Data Transformation and Mapping

| Endpoint | Decoding target | Mapping |
|---|---|---|
| `/trending/movie/week` | `[Movie]` directly via `CodingKeys` | None — domain struct is the decode target |
| `/search/movie` | `[Movie]` directly via `CodingKeys` | None |
| `/genre/movie/list` | Private `GenreListResponse` (wraps `genres: [Genre]`) | Extract `genres` array; return `[Genre]` |
| `/movie/{id}` | Private `MovieDetailResponse` DTO | Map to `MovieDetail(movie:genres:cast:.notRetrieved)` |
| `/movie/{id}/credits` | Private `CreditsResponse` (wraps `cast: [CastMember]`) | Extract `cast` array; return `[CastMember]` |
| Image data | Raw `Data` via `HTTPClient` image operation | No transformation; return as-is |

`MovieDetailResponse` is the only DTO requiring an explicit mapping step — the detail endpoint returns full `Genre` objects and additional fields that differ from the list `Movie` shape.

---

### g. Caching and Offline Strategy

- **Genres**: cached in memory after first successful fetch. Failed fetches do not poison the cache. `force: true` bypasses cache and re-fetches regardless of current cache state.
- **All other operations**: no caching. Each call dispatches a live network request.
- **Offline behaviour**: `TMDBClient` does not degrade gracefully by design — it surfaces `.offline` to the feature layer, which owns the retry affordance per PRD. No local fallback, no request queuing.

---

### h. Concurrency Model

Deferred to each architectural implementation plan. Requirements:

- Operations must be non-blocking (main thread must not be held).
- The service must not introduce shared mutable state beyond the genre cache.
- Genre cache write must be safe under the chosen concurrency model (actor isolation, mutex, or MainActor dispatch depending on implementation).
- The `HTTPClient` interface is consumed as injected; thread-safety guarantees of `HTTPClient` are per the Networking framework plan.

---

### i. Error Handling

| `NetworkError` source | `TMDBError` case | Recoverability |
|---|---|---|
| `.noConnectivity` | `.offline` | Recoverable — user restores connectivity and retries |
| `.serverError(any)`, `.transportError`, `.decodingError` | `.networkFailure` | Recoverable for transient failures; feature layer shows retry |
| `.invalidURL` | `.invalidRequest` | Not recoverable — `assertionFailure` in debug; should not reach production |

All `NetworkError` mapping is performed inside the service. Callers only ever see `TMDBError`. TMDB error response bodies (`status_message`, `status_code`) are not decoded; `.networkFailure` is sufficient for MVP.

---

### j. iOS-Specific Decisions

- **No Keychain usage**: API key is injected via `NetworkConfiguration` at construction time from build-time `.xcconfig` config; the service never touches Keychain.
- **No background execution**: all requests run in the foreground `URLSession`; no `BGTaskScheduler` registration.
- **No APNs, CloudKit, or iCloud sync**.
- **No runtime permission gates**: outbound HTTPS requires no entitlement.

---

### k. Initialization and Configuration

`TMDBClient` receives an `HTTPClient` instance via initializer injection at the composition root. No other dependencies. The `HTTPClient` carries `NetworkConfiguration` (base URL, API key) internally — `TMDBClient` does not reference `NetworkConfiguration` directly. The composition root constructs `TMDBClient` once and injects it into each feature module via the DI mechanism of the architectural variant (environment value, factory closure, initializer injection, or equivalent).

---

### l. Deferred Items

| Item | Reason |
|---|---|
| Concurrency delivery mechanism (async throws vs. Combine vs. callbacks) | Depends on architectural pattern; defined per-implementation |
| TMDB error response body decoding (`status_message`) | Not required by PRD for MVP |
| Image caching / persistence | Not required by PRD; deferred per Networking framework plan |
| Automatic retry with back-off | PRD specifies manual UI-triggered retry only |
| Pagination beyond first page | Explicitly out of scope in PRD |
| Additional `PosterSize` cases beyond `.thumbnail` / `.full` | No current display requirement |

---

## Unresolved Issues

None. All planning questions have been resolved.
