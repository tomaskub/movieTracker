# WatchlistRepository Service Plan for Movie Tracker

## 1. Overview

`WatchlistRepository` is the sole owner of all CRUD operations over a user's personal watchlist. It encapsulates the business logic for adding and removing movies, querying membership, and listing watchlist entries with optional in-memory sorting. It exposes a synchronous, `throws`-based protocol to the feature layer and is fully backed by local SwiftData persistence via the `PersistenceKit` framework — no network access of any kind is involved.

The same protocol and concrete implementation are shared across all three architectural variants (MVVM, VIPER, TCA). Architecture-specific observation wiring is explicitly out of scope.

---

## 2. Domain Capability & Responsibility Boundary

**Domain capability**: manage the set of movies a user intends to watch, backed by local persistence.

### In Scope

- Add a `Movie` to the watchlist, including extraction of snapshot fields and year derivation from `Movie.releaseDate`.
- Remove a watchlist entry identified by `movieId`.
- Fetch all watchlist entries with optional in-memory sorting.
- Check membership by `movieId`.
- Enforce the one-entry-per-movie invariant and surface violations as a typed domain error.
- Translate `PersistenceError` values into `WatchlistRepositoryError` cases; no `PersistenceError` or SwiftData type crosses the service boundary.

### Explicitly Out of Scope

| Concern | Owning Layer |
|---|---|
| Sort preference state (which `WatchlistSortOrder` is active) | Watchlist feature layer (ephemeral, resets on cold launch) |
| Poster URL construction from relative path | Presentation layer |
| Reactive observation / change streams | Architecture-specific feature layer (`@Query`, Combine, `AsyncStream`) |
| Review lifecycle (`ReviewRepository`) | `ReviewRepository` service |
| Network access of any kind | Not applicable — watchlist is fully offline |
| Coordinated watchlist + review deletion | Service layer caller, if ever required |

**Boundary justification**: Snapshot fields eliminate network dependency for the Watchlist tab entirely. Sort state is ephemeral per-PRD and belongs with the feature layer that owns the in-memory selection. Observation mechanisms differ per architecture variant; the repository exposes request/response operations only.

---

## 3. Framework Dependencies

| Framework | Protocol consumed | What is required |
|---|---|---|
| `PersistenceKit` | `WatchlistEntryStoring` (narrow service-module protocol) | `insert`, `fetch` (with predicate), `delete` operations over `WatchlistEntryEntity` DTOs; `PersistenceError` error surface |

`WatchlistRepository` protocol has **no import of `PersistenceKit`**. The concrete `DefaultWatchlistRepository` maps `WatchlistEntry` ↔ `WatchlistEntryEntity` before calling `WatchlistEntryStoring`, keeping all domain mapping inside the service layer. `WatchlistEntryEntity` is a public type vended by `PersistenceKit`.

`NetworkingKit` is **not a dependency** — all operations are local.

### `WatchlistEntryStoring` contract

```swift
protocol WatchlistEntryStoring {
    func insert(_ entry: WatchlistEntryEntity) throws
    func fetch(predicate: Predicate<WatchlistEntryEntity>?) throws -> [WatchlistEntryEntity]
    func delete(movieId: Int) throws
}
```

This protocol is defined in the service module. It operates on `WatchlistEntryEntity` DTOs — the public bridge type vended by `PersistenceKit`. `DefaultWatchlistRepository` performs the `WatchlistEntry` ↔ `WatchlistEntryEntity` mapping before and after calling this protocol, so no domain mapping logic leaks into `SwiftDataWatchlistEntryStore` or test doubles.

---

## 4. Business Rules

| Rule | Description | Error thrown |
|---|---|---|
| **Duplicate guard on add** | Before insert, if a `WatchlistEntry` with the same `movieId` already exists in the store, throw `.alreadyOnWatchlist`. This maps from `PersistenceError.duplicateEntry` triggered by `@Attribute(.unique)` on `movieId`. | `WatchlistRepositoryError.alreadyOnWatchlist` |
| **Year derivation** | `releaseYear: Int` is derived from `Movie.releaseDate` (ISO-8601 string) inside `add(movie:)`. The caller never supplies a year. Failed parsing produces `releaseYear = 0` (defensive fallback). | — |
| **Snapshot fields** | `title`, `releaseYear`, `voteAverage`, and `posterPath` are captured from the `Movie` struct at add time. They are not refreshed on subsequent TMDB calls. | — |
| **Remove guard** | If no entry exists for the given `movieId`, throw `.notFound`. This maps from `PersistenceError.notFound`. | `WatchlistRepositoryError.notFound` |
| **In-memory sort** | After a full fetch, the concrete implementation sorts results in memory: `.dateAdded` (newest first), `.title` (alphabetical ascending), `.voteAverage` (descending). A `nil` sort order returns records in store-native order with no sort guarantee. | — |
| **Single entry per movie** | Enforced at both the `@Attribute(.unique)` store level and via the duplicate guard above. Normal UI prevents duplicate adds; the service provides a named error if state diverges. | `WatchlistRepositoryError.alreadyOnWatchlist` |

---

## 5. Public Interface

```swift
// Defined in the service module; no PersistenceKit or SwiftData import required
protocol WatchlistRepository {
    func add(movie: Movie) throws
    func remove(movieId: Int) throws
    func fetchAll(sortOrder: WatchlistSortOrder?) throws -> [WatchlistEntry]
    func contains(movieId: Int) throws -> Bool
}

enum WatchlistSortOrder {
    case dateAdded    // newest first (default)
    case title        // alphabetical ascending
    case voteAverage  // descending
}

enum WatchlistRepositoryError: Error {
    case alreadyOnWatchlist          // duplicate movieId insert attempt
    case notFound                    // remove called for non-existent movieId
    case fetchFailed(Error)          // underlying store fetch failure
    case insertFailed(Error)         // underlying store insert failure
    case deleteFailed(Error)         // underlying store delete failure
}
```

**Rationale for synchronous `throws`**: `PersistenceKit`'s `EntityStore<T>` surface is synchronous; all store calls are `@MainActor`-confined. Removing `async` eliminates unnecessary `Task` bridging at every call site, particularly in VIPER Interactors that deliver results to their output via delegate or completion handler in the same call stack.

**No reactive stream on the protocol**: Each architecture variant derives its own observation mechanism — SwiftUI `@Query` in MVVM, a Combine publisher in VIPER, or an `AsyncStream` in TCA — from the request/response operations above. The repository does not prescribe an observation strategy.

---

## 6. State Ownership

The service is **stateless** beyond the `WatchlistEntryStoring` dependency it holds at construction time.

- No in-memory cache of entries.
- No `Set` of watched movie IDs.
- No session-scoped collection.

All persistent state lives in the SwiftData store. Every operation reads from or writes to the store directly. This means `contains(movieId:)` performs a store fetch rather than checking a cached set — consistent with the stateless design and acceptable given the user-bounded dataset size.

`WatchlistSortOrder` selection is **not owned here** — it is ephemeral state in the feature layer and resets to `.dateAdded` on cold launch per PRD.

---

## 7. Data Transformation & Mapping

Two mapping boundaries exist; both are handled inline with no dedicated mapper type.

### Boundary 1 — `Movie` → `WatchlistEntry` (on `add`)

Performed inline in the concrete `WatchlistRepository`:

| Source field | Target field | Transformation |
|---|---|---|
| `movie.id` | `movieId` | Direct |
| `movie.title` | `title` | Direct |
| `movie.releaseDate` | `releaseYear` | Parse ISO-8601 string; extract year component. Defensive fallback to `0` on parse failure. |
| `movie.voteAverage` | `voteAverage` | Direct |
| `movie.posterPath` | `posterPath` | Direct (relative path; URL assembly is the presentation layer's concern) |
| — | `dateAdded` | `Date()` at insert time |

No dedicated mapper type. Complexity is a single date-parsing expression — a one-liner using `Calendar` and `DateFormatter` or ISO8601DateFormatter.

### Boundary 2 — `WatchlistEntry` ↔ `WatchlistEntryEntity` (service layer)

Performed inline in `DefaultWatchlistRepository` before insert and after fetch. No dedicated mapper type.

| `WatchlistEntry` field | `WatchlistEntryEntity` field | Transformation |
|---|---|---|
| `movieId` | `movieId` | Direct |
| `title` | `title` | Direct |
| `releaseYear` | `releaseYear` | Direct |
| `voteAverage` | `voteAverage` | Direct |
| `posterPath` | `posterPath` | Direct |
| `dateAdded` | `dateAdded` | Direct |

`SwiftDataWatchlistEntryStore` is a thin conformer — it passes `WatchlistEntryEntity` values directly to `EntityStore<WatchlistEntryEntity>` with no additional mapping. The `WatchlistEntryModel` ↔ `WatchlistEntryEntity` conversion is owned by `PersistenceKit` via `SwiftDataMappable`.

---

## 8. Caching Strategy

**None required.** The service is fully offline-first and reads directly from the SwiftData store on every operation.

- No TTL.
- No in-memory snapshot of results.
- No stale-data concept — the store is always the source of truth.

`posterPath` is stored as a relative path at add time. The presentation layer assembles the full TMDB CDN URL opportunistically; network availability does not affect data availability for the Watchlist tab.

---

## 9. Offline & Sync Behavior

**Fully offline-first.** All four operations (`add`, `remove`, `fetchAll`, `contains`) are local-only.

- No network dependency for any watchlist operation.
- No write queue or deferred sync.
- No conflict resolution — no remote state to conflict with.
- No background fetch, CloudKit sync, or iCloud integration (explicitly out of scope per PRD).

Poster images load from TMDB CDN URLs at the presentation layer when a network is available; the `posterPath` field is always available regardless of connectivity.

---

## 10. Concurrency Model

| Concern | Decision |
|---|---|
| Protocol actor annotation | None — callable from any context |
| Concrete implementation isolation | `@MainActor` — matches `PersistenceKit`'s `SwiftDataEntityStore<T>` confinement |
| `async` on protocol | No — synchronous `throws` throughout |
| VIPER compatibility | Interactors call synchronous methods directly; no `Task` wrapper required |
| MVVM compatibility | `@MainActor` ViewModels call synchronous methods; no actor-hop overhead |
| TCA compatibility | Reducer calls synchronous methods; `Effect` wrapping is the Reducer's responsibility if needed |
| Background `ModelContext` | Not used — all operations on main thread |
| Thread-safe mutation | Not needed — single-thread `@MainActor` confinement is sufficient |

`@MainActor` is expressed on the concrete type only, not on the `WatchlistRepository` protocol, to preserve the protocol's architecture-agnostic contract.

---

## 11. Error Handling

| Error case | Source | Propagation | Recoverability |
|---|---|---|---|
| `.alreadyOnWatchlist` | `PersistenceError.duplicateEntry` from `@Attribute(.unique)` violation | `throws` | Recoverable — feature layer surfaces a user-visible error message; watchlist state remains consistent |
| `.notFound` | `PersistenceError.notFound` on `remove` | `throws` | Recoverable — indicates UI/state divergence; feature layer can refresh CTA state |
| `.fetchFailed(Error)` | `PersistenceError.fetchFailed` | `throws` | Terminal for the operation; feature layer surfaces an error state |
| `.insertFailed(Error)` | `PersistenceError.insertFailed` / `.saveFailed` | `throws` | Terminal; feature layer surfaces an error state |
| `.deleteFailed(Error)` | `PersistenceError.deleteFailed` / `.saveFailed` | `throws` | Terminal; feature layer surfaces an error state |

No `PersistenceError` or SwiftData type crosses the `WatchlistRepository` boundary. The associated `Error` values in wrapping cases are available for logging but are not expected to be inspected by feature-layer callers.

---

## 12. iOS-Specific Concerns

| Concern | Decision |
|---|---|
| **Keychain** | Not required — no credentials or tokens involved |
| **BGTaskScheduler** | Not required — no background sync |
| **APNs** | Not required — no push-triggered data refresh |
| **Runtime permissions** | Not required — local SQLite persistence needs no user permission grant |
| **Sign in with Apple** | Not applicable |
| **iCloud / CloudKit** | Explicitly out of scope per PRD |
| **Privacy manifest** | Standard local file access entry in `PrivacyInfo.xcprivacy`; no required-reason API usage from this service |

---

## 13. Initialization & Configuration

The concrete `WatchlistRepository` receives its `WatchlistEntryStoring` dependency via **constructor injection**. No singletons, service locators, or SwiftUI environment access.

```swift
final class DefaultWatchlistRepository: WatchlistRepository {
    private let store: WatchlistEntryStoring

    init(store: WatchlistEntryStoring) {
        self.store = store
    }
}
```

The composition root of each architecture variant:
1. Constructs a `ModelContainer` via `ModelContainerProvider`.
2. Constructs `SwiftDataWatchlistEntryStore` (wrapping `EntityStore<WatchlistEntryEntity>` from the container).
3. Injects `SwiftDataWatchlistEntryStore` into `DefaultWatchlistRepository`.
4. Makes the repository available via the DI mechanism specific to each variant (SwiftUI environment, VIPER application coordinator, TCA dependency client).

The same constructor pattern works identically across all three branches. No variant-specific bootstrapping logic is required in the service module.

---

## 14. Platform & OS Constraints

| Constraint | Impact |
|---|---|
| **iOS 17 minimum** | SwiftData `@Model`, `@Attribute(.unique)`, `ModelContext`, and `ModelContainer` all require iOS 17. No availability guards are needed — the deployment target enforces this globally. |
| **`Predicate<T>` and `SortDescriptor<T>`** | Both require iOS 17. Used internally by `WatchlistEntryStoring` conformers; no availability gate needed. |
| **`@Attribute(.unique)` on `movieId`** | iOS 17 SwiftData feature. The `.duplicateEntry` error case is the runtime signal for its violation; no fallback for earlier OS versions is needed. |
| **No entitlements required** | Standard SQLite on-disk persistence in the app's default container directory requires no special entitlements. |
| **No background execution** | All operations occur on the main thread; no background task registration or `BGTaskScheduler` usage is needed. |

---

## 15. Deferred / Out of Scope for MVP

| Item | Rationale |
|---|---|
| **Reactive observation surface** (`AsyncStream`, Combine publisher of `[WatchlistEntry]`) | Each architecture variant provides its own observation mechanism; the protocol intentionally does not prescribe one. Deferred indefinitely — not a repository concern. |
| **Poster URL assembly** | Presentation layer responsibility. Not a repository concern at any future iteration. |
| **Sort preference persistence** | Intentionally excluded per PRD. Resets on cold launch. Owned by the feature layer. |
| **Coordinated watchlist + review deletion** | Not required by PRD. Would be a service-layer caller concern if added, not a `WatchlistRepository` change. |
| **CloudKit / iCloud sync** | Explicitly out of scope per PRD. |

---

## 16. Open Questions / Unresolved Decisions

None. All planning questions have been answered and all recommendations have been matched to explicit decisions in the planning session summary.
