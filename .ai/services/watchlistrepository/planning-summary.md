# WatchlistRepository — Planning Session Summary

## Decisions

1. Protocol name: `WatchlistRepository`
2. `add` accepts a full `Movie` domain struct; `releaseYear` derivation from `Movie.releaseDate` is performed inside the service
3. Explicit `contains(movieId: Int) -> Bool` method exposed on the protocol
4. `fetchAll` accepts an optional `WatchlistSortOrder?` parameter; `nil` means no guaranteed order (sort is applied in-memory inside the service before returning)
5. `remove` takes `movieId: Int` as its argument; the service fetches the matching entity internally before deletion
6. `PersistenceError.duplicateEntry` is translated to a named domain error (`.alreadyOnWatchlist`); never swallowed silently
7. Domain error taxonomy: `.alreadyOnWatchlist`, `.notFound`, `.fetchFailed(Error)`, `.insertFailed(Error)`, `.deleteFailed(Error)`
8. No reactive streams, `AsyncStream`, or Combine publishers exposed at any point in the service
9. `WatchlistRepository` protocol is synchronous `throws`; the concrete implementation is `@MainActor`-annotated
10. The concrete repository depends on a narrow `WatchlistEntryStoring` protocol (not `EntityStore<WatchlistEntryEntity>`), keeping PersistenceKit out of the protocol definition and test targets
11. `WatchlistEntry` is the shared domain struct from `DomainModels`; the SwiftData `@Model` class (`WatchlistEntryModel`) is strictly internal to `PersistenceKit`
12. `posterPath` is stored and returned as a relative path; full URL assembly is the presentation layer's responsibility
13. Sort type is `WatchlistSortOrder` enum, defined inside the service module; cases: `.dateAdded` (newest first), `.title` (alphabetical), `.voteAverage` (descending)
14. `WatchlistEntryStoring` protocol operates entirely on `WatchlistEntry` domain structs — no PersistenceKit types appear in the protocol definition
15. Domain struct ↔ `WatchlistEntryEntity` mapping is inline inside the concrete `WatchlistRepository` (or its concrete store adapter); no dedicated mapper type

## Matched Recommendations

1. Expose four named operations only: `add(movie:)`, `remove(movieId:)`, `fetchAll(sortOrder:)`, `contains(movieId:)` — confirmed by decisions 2, 3, 4, 5
2. Year derivation (`releaseDate` → `releaseYear`) lives inside the repository — confirmed by decision 2
3. Surface `.alreadyOnWatchlist` as a named domain error — confirmed by decision 6
4. Sort applied in-memory inside the service; `nil` means no guaranteed order — confirmed by decisions 4 and 13
5. `remove(movieId:)` fetches the matching entity internally before calling the store's delete — confirmed by decision 5
6. Synchronous `throws` protocol; `@MainActor` concrete implementation — confirmed by decision 9
7. `fetchAll` returns `[WatchlistEntry]` domain structs; no `@Model` class crosses the service boundary — confirmed by decisions 11 and 14
8. No reactive stream at the service layer; observation is delegated to the architecture-specific layer — confirmed by decision 8
9. `@MainActor` on the concrete type only, not the protocol — confirmed by decision 9
10. Poster URL assembly belongs in the presentation layer — confirmed by decision 12
11. Constructor injection for the `WatchlistEntryStoring` dependency — follows from decisions 10 and 14
12. `contains(movieId:)` performs a store fetch rather than maintaining a cached `Set` — consistent with the stateless repository design
13. `WatchlistSortOrder` scoped to the service module; not shared with Search — confirmed by decision 13
14. `WatchlistEntryStoring` operates on domain `WatchlistEntry` structs, keeping PersistenceKit out of the protocol and test targets — confirmed by decision 14
15. Mapping is inline in the concrete implementation; no dedicated mapper type — confirmed by decision 15

## Summary

### a. Domain Capability and Responsibility Boundary

`WatchlistRepository` owns all CRUD operations for the user's personal watchlist. Its single domain capability is: **manage the set of movies a user intends to watch**, backed by local SwiftData persistence.

**In scope:**
- Add a `Movie` to the watchlist (including snapshot field extraction and year derivation)
- Remove a watchlist entry by `movieId`
- Fetch all watchlist entries with optional in-memory sorting
- Check membership by `movieId`
- Enforce the one-entry-per-movie invariant and surface violations as a typed domain error

**Explicitly out of scope (delegated elsewhere):**
- Sort preference state (ephemeral; owned by the Watchlist feature layer)
- Poster URL construction (presentation layer)
- Reactive observation / change streams (architecture-specific feature layer)
- Review lifecycle (owned by `ReviewRepository`)
- Network access of any kind

---

### b. Framework Dependencies

| Framework | Interface consumed | What is required |
|---|---|---|
| `PersistenceKit` | `WatchlistEntryStoring` (narrow service-module protocol wrapping `EntityStore<WatchlistEntryEntity>`) | insert, fetch (with predicate), delete operations for `WatchlistEntry` records; `PersistenceError` error surface |

`WatchlistRepository` does **not** import `PersistenceKit` in its protocol definition. The concrete implementation depends on `WatchlistEntryStoring`, whose production conformer (`SwiftDataWatchlistEntryStore`) wraps `EntityStore<WatchlistEntryEntity>` internally.

---

### c. Business Rules

- **Duplicate guard on add:** Before or during insert, if a `WatchlistEntry` with the same `movieId` already exists, the service throws `WatchlistRepositoryError.alreadyOnWatchlist`. This maps from `PersistenceError.duplicateEntry` (triggered by `@Attribute(.unique)` on `movieId`).
- **Year derivation:** `releaseYear: Int` is derived from `Movie.releaseDate` (ISO-8601 string) inside the service at insert time. The caller is never required to supply a year.
- **Snapshot fields:** `title`, `releaseYear`, `voteAverage`, and `posterPath` are captured from the `Movie` struct at add time. They are not refreshed on subsequent TMDB calls.
- **Remove guard:** If no entry exists for the given `movieId`, the service throws `WatchlistRepositoryError.notFound`.
- **In-memory sort:** Sorting (`.dateAdded` desc, `.title` asc, `.voteAverage` desc) is applied by the service after fetching all records. A `nil` sort order returns records in store-native order.

---

### d. State Ownership

The service is **stateless** beyond the `WatchlistEntryStoring` dependency it holds. All persistent state lives in the SwiftData store. No in-memory cache, no `Set` of watched IDs, no session-scoped collection. Each operation reads from or writes to the store directly.

---

### e. Public Interface Design

```swift
protocol WatchlistRepository {
    func add(movie: Movie) throws
    func remove(movieId: Int) throws
    func fetchAll(sortOrder: WatchlistSortOrder?) throws -> [WatchlistEntry]
    func contains(movieId: Int) throws -> Bool
}

enum WatchlistSortOrder {
    case dateAdded   // newest first
    case title       // alphabetical ascending
    case voteAverage // descending
}
```

**Rationale:** Synchronous `throws` matches `PersistenceKit`'s synchronous `EntityStore<T>` surface and eliminates unnecessary `Task` bridging in callers already on `@MainActor`. No observable state stream is exposed — each architectural variant derives its own observation mechanism (`@Query` in MVVM SwiftUI, Combine in VIPER, `AsyncStream` in TCA) from the protocol's request/response operations.

---

### f. Data Transformation and Mapping

Two mapping boundaries exist:

1. **`Movie` → `WatchlistEntry` (on add):** Inline in the concrete `WatchlistRepository`. Fields map 1:1 except `releaseYear`, which is derived from `Movie.releaseDate` via a date-parsing expression. No dedicated mapper type.

2. **`WatchlistEntry` ↔ `WatchlistEntryEntity` (PersistenceKit boundary):** The `WatchlistEntryStoring` protocol operates on `WatchlistEntry` domain structs. Its concrete production conformer (`SwiftDataWatchlistEntryStore`) holds an `EntityStore<WatchlistEntryEntity>` and performs the field-level mapping inline. This keeps PersistenceKit entirely absent from the `WatchlistRepository` protocol and from test targets.

No external mapper type, no `Codable` transformation, no complex graph traversal — all mapping is trivial field assignment.

---

### g. Caching and Offline / Sync Strategy

**Fully offline-first.** All four operations (`add`, `remove`, `fetchAll`, `contains`) read from and write to the local SwiftData store with no network dependency. Poster images are stored as relative paths; loading from the TMDB CDN is an opportunistic presentation-layer concern and does not affect data availability. No cache TTL, no background sync, no conflict resolution. CloudKit/iCloud sync is explicitly out of scope.

---

### h. Concurrency Model

- `WatchlistRepository` **protocol** carries no actor annotation — it is callable from any context.
- The **concrete implementation** is `@MainActor`-isolated, matching `PersistenceKit`'s `SwiftDataEntityStore<T>` confinement. All store calls occur on the main thread.
- No `async` surface on the protocol; callers (MVVM `@MainActor` ViewModels, VIPER Interactors on main thread, TCA Reducers) call synchronous methods directly. VIPER Interactors require no `Task` wrapper.
- No thread-safe mutation infrastructure needed — single-thread confinement via `@MainActor` is sufficient for this scope.

---

### i. Error Handling

```swift
enum WatchlistRepositoryError: Error {
    case alreadyOnWatchlist          // duplicate movieId insert attempt
    case notFound                    // remove called for non-existent movieId
    case fetchFailed(Error)          // underlying store fetch failure
    case insertFailed(Error)         // underlying store insert failure
    case deleteFailed(Error)         // underlying store delete failure
}
```

| Case | Source | Recoverability |
|---|---|---|
| `.alreadyOnWatchlist` | `PersistenceError.duplicateEntry` | Recoverable — feature layer surfaces a user-visible error message |
| `.notFound` | `PersistenceError.notFound` | Recoverable — indicates state divergence; feature layer can refresh CTA state |
| `.fetchFailed` | `PersistenceError.fetchFailed` | Terminal for the operation; feature layer surfaces an error state |
| `.insertFailed` | `PersistenceError.insertFailed` / `.saveFailed` | Terminal; feature layer surfaces an error state |
| `.deleteFailed` | `PersistenceError.deleteFailed` / `.saveFailed` | Terminal; feature layer surfaces an error state |

No `PersistenceError` or SwiftData type crosses the `WatchlistRepository` boundary.

---

### j. iOS-Specific Decisions

- **Keychain:** Not required — no credentials or tokens involved.
- **BGTaskScheduler:** Not required — no background sync.
- **APNs:** Not required — no push-triggered data refresh.
- **Runtime permissions:** Not required — local SQLite persistence needs no user permission.
- **iCloud / CloudKit:** Explicitly out of scope.
- **Privacy manifest:** Standard local file access entry in `PrivacyInfo.xcprivacy`; no required-reason API usage from this service.

---

### k. Initialization and Configuration

The concrete `WatchlistRepository` receives its `WatchlistEntryStoring` dependency via **constructor injection**. No singletons, service locators, or SwiftUI environment access. The composition root of each architecture variant (MVVM app entry point, VIPER application coordinator, TCA store bootstrap) constructs `SwiftDataWatchlistEntryStore` (wrapping an `EntityStore<WatchlistEntryEntity>` derived from the shared `ModelContainer`) and injects it into the concrete repository. The same constructor pattern works identically across all three branches.

---

### l. Deferred / Out of Scope for MVP

- **Reactive observation surface** (`AsyncStream`, Combine publisher of `[WatchlistEntry]`) — deferred; each architecture variant provides its own observation mechanism.
- **Poster URL assembly** — deferred to the presentation layer; not a repository concern at any future iteration either.
- **Sort preference persistence** — intentionally excluded per PRD; resets on cold launch; owned by the feature layer.

## Unresolved Issues

None. All planning questions have been answered and all recommendations have been matched to explicit user decisions.
