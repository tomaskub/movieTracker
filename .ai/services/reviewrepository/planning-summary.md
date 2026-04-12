# ReviewRepository — Service Planning Session Summary

## Decisions

1. `ReviewRepository` protocol exposes `[ReviewTag]` (not `[String]`). The `[String]` ↔ `[ReviewTag]` conversion is performed at the concrete repository boundary.
2. No pre-insert duplicate guard fetch. The concrete repository relies solely on the store returning `PersistenceError.duplicateEntry`; this is caught and mapped to `.alreadyExists`.
3. A `contains(movieId:) throws -> Bool` method is included on the protocol, consistent with `WatchlistRepository`.
4. Strict separation between domain and persistence throughout. The public `ReviewRepository` protocol and all callers interact only with domain types. SwiftData `@Model` classes never cross the service boundary.
5. A narrow `ReviewStoring` protocol is defined in the service module. `PersistenceKit` is absent from the `ReviewRepository` protocol and all test targets.
6. `ReviewStoring` exposes `ReviewEntity` DTOs (defined inside `PersistenceKit`). The concrete `DefaultReviewRepository` performs all DTO ↔ domain mapping internally.
7. `create` and `update` are distinct operations on the protocol.
8. The protocol returns a `Review` domain value type (struct), not a SwiftData `@Model` class or a `ReviewEntity` DTO.
9. Rating range (1–5) is validated in both `create` and `update`. Out-of-range values throw `.invalidRating`.
10. `delete(movieId:)` performs the deletion unconditionally. No pre-delete guard; any store-level failure propagates as `.deleteFailed`.
11. `ReviewRepositoryError` cases: `.notFound`, `.alreadyExists`, `.invalidRating`, `.fetchFailed(Error)`, `.insertFailed(Error)`, `.updateFailed(Error)`, `.deleteFailed(Error)`.
12. Protocol carries no actor annotation. Concrete `DefaultReviewRepository` is `@MainActor`-isolated. Matches `WatchlistRepository` pattern exactly.

## Matched Recommendations

1. Mirror `WatchlistRepository`'s narrow-protocol pattern — confirmed via decisions 4, 5, 6.
2. Expose `[ReviewTag]` in the public interface; concrete repo performs `compactMap` conversion against `ReviewStoring` — confirmed via decision 1.
3. Separate `create` and `update` operations — confirmed via decision 7.
4. Fully synchronous `throws` protocol — confirmed via decision 12 (same pattern as `WatchlistRepository`).
5. Validate rating in the concrete repository on both `create` and `update` — confirmed via decision 9.
6. Use a `Review` value-type domain struct for the public interface — confirmed via decision 8.
7. `.notFound` retained for `update` and `fetch` semantics; removed from `delete` per decision 10.
8. Keep `ReviewRepository` stateless — confirmed; no caching or session state.
9. Expose `contains(movieId:)` — confirmed via decision 3.
10. Expose `updatedAt` in the returned `Review` domain struct — retained; `createdAt`/`updatedAt` are in the data plan and surfaced on the domain struct.

## Summary

### a. Domain Capability & Responsibility Boundary

**Domain capability**: `ReviewRepository` is the sole owner of the full review lifecycle — create, fetch, update, delete, and existence check — for the one-review-per-movie constraint. It is fully offline and has no network dependency.

**In scope**:
- Create a new `Review` for a `movieId` (wizard step 4 confirm, create path).
- Overwrite an existing `Review` for a `movieId` (wizard step 4 confirm, edit path).
- Fetch the single `Review` for a `movieId`, returning `nil` if none exists.
- Delete the `Review` for a `movieId` unconditionally.
- Check existence of a review for a `movieId` (`contains`).
- Enforce the one-review-per-movie invariant via store-level `@Attribute(.unique)` error mapping.
- Validate rating range (1–5) on create and update.
- Convert `[ReviewTag]` ↔ `[String]` at the service boundary.
- Translate all `PersistenceError` values into typed `ReviewRepositoryError` cases.

**Explicitly out of scope**:

| Concern | Owning layer |
|---|---|
| Confirmation dialog before deletion | Feature layer (Movie Detail) |
| Wizard step-by-step state (partial review in progress) | Wizard feature layer; repository is only called on final confirm |
| Reactive observation / change streams | Architecture-specific feature layer |
| Poster URL construction or any network access | Not applicable |
| Coordinated watchlist + review deletion | Service-layer caller, if ever needed |
| `ReviewTag` display labels / ordering | Feature/UI layer |

---

### b. Framework Dependencies

| Framework | Protocol consumed | What is required |
|---|---|---|
| `PersistenceKit` | `ReviewStoring` (narrow service-module protocol) | `insert`, `update`, `fetch` (by predicate on `movieId`), `delete` operations over `ReviewEntity` DTOs; `PersistenceError` error surface |

**`ReviewStoring` contract** (defined in the service module):

```swift
protocol ReviewStoring {
    func insert(_ entity: ReviewEntity) throws
    func update(_ entity: ReviewEntity) throws
    func fetch(movieId: Int) throws -> ReviewEntity?
    func delete(movieId: Int) throws
}
```

- `ReviewEntity` is a DTO defined inside `PersistenceKit`.
- The `ReviewRepository` protocol itself carries **no import of `PersistenceKit`**.
- Test targets for `ReviewRepository` inject a fake `ReviewStoring` conformer with no `PersistenceKit` dependency.

---

### c. Business Rules

| Rule | Description | Error thrown |
|---|---|---|
| **Rating validation** | On both `create` and `update`, `rating` must be in the range 1–5 inclusive. Checked before any store interaction. | `ReviewRepositoryError.invalidRating` |
| **Duplicate guard on create** | No pre-fetch guard; the concrete repo attempts insert and catches `PersistenceError.duplicateEntry` from `@Attribute(.unique)` on `movieId`. | `ReviewRepositoryError.alreadyExists` |
| **Tag conversion** | `[ReviewTag]` received from callers is mapped to `[String]` (raw values) before passing to `ReviewStoring`. `[String]` from fetched `ReviewEntity` is mapped back to `[ReviewTag]` via `compactMap` before returning to callers. | — |
| **`updatedAt` on update** | The concrete `update` implementation stamps `updatedAt` with `Date()` before writing the entity to the store. | — |
| **`createdAt` on create** | The concrete `create` implementation stamps both `createdAt` and `updatedAt` with `Date()` at insert time. | — |
| **Unconditional delete** | `delete(movieId:)` issues the store delete without a prior existence check. Any store-level failure surfaces as `.deleteFailed`. | `ReviewRepositoryError.deleteFailed(Error)` |

---

### d. State Ownership

**Stateless.** The concrete `DefaultReviewRepository` holds only its injected `ReviewStoring` dependency. No in-memory cache of review records, no session-scoped state, no observable property. All persistent state lives in the SwiftData store via `PersistenceKit`. Every operation reads from or writes to the store directly.

---

### e. Public Interface

```swift
protocol ReviewRepository {
    func create(movieId: Int, rating: Int, tags: [ReviewTag], notes: String) throws
    func update(movieId: Int, rating: Int, tags: [ReviewTag], notes: String) throws
    func fetch(movieId: Int) throws -> Review?
    func delete(movieId: Int) throws
    func contains(movieId: Int) throws -> Bool
}
```

**`Review` domain struct** (defined in `DomainModels`):

```swift
struct Review: Equatable, Sendable {
    let movieId: Int
    let rating: Int
    let tags: [ReviewTag]
    let notes: String
    let createdAt: Date
    let updatedAt: Date
}
```

**Rationale**:
- Synchronous `throws` throughout — `PersistenceKit` is synchronous and `@MainActor`-confined; `async` adds no value.
- `create` and `update` are distinct, preserving semantic error taxonomy (`.alreadyExists` on `create`, `.notFound` on `update`).
- `fetch` returns an optional domain value type, not a `@Model` class. Callers never see SwiftData lifecycle.
- `contains` is a convenience that avoids requiring feature-layer callers to nil-check a `fetch` result for presence checks.
- No reactive stream on the protocol. Each architecture variant provides its own observation mechanism.

---

### f. Data Transformation & Mapping

Two mapping boundaries, both handled inline in the concrete `DefaultReviewRepository`:

**`[ReviewTag]` → `[String]`** (on `create` / `update`):
```swift
let rawTags = tags.map(\.rawValue)
```

**`[String]` → `[ReviewTag]`** (on `fetch` / `contains`):
```swift
let tags = entity.tags.compactMap(ReviewTag.init(rawValue:))
```

**`ReviewEntity` → `Review` domain struct** (on `fetch`):

| `ReviewEntity` field | `Review` field | Transformation |
|---|---|---|
| `movieId: Int` | `movieId` | Direct |
| `rating: Int` | `rating` | Direct |
| `tags: [String]` | `tags: [ReviewTag]` | `compactMap(ReviewTag.init(rawValue:))` |
| `notes: String` | `notes` | Direct |
| `createdAt: Date` | `createdAt` | Direct |
| `updatedAt: Date` | `updatedAt` | Direct |

Domain inputs → `ReviewEntity` on `create`/`update` is the inverse; `createdAt`/`updatedAt` stamped with `Date()` at the boundary.

No dedicated mapper type. `DomainModels` has no dependency on `PersistenceKit`; `PersistenceKit` has no dependency on `DomainModels`.

---

### g. Caching & Offline/Sync Strategy

**No caching required.** Reviews are fully offline-first. All operations read from and write to the local SwiftData store with no network dependency.

- No TTL, no in-memory snapshot, no stale-data concept.
- No CloudKit / iCloud sync (explicitly out of scope per PRD).
- No write queue or deferred sync.
- No conflict resolution — no remote state exists.

---

### h. Concurrency Model

| Concern | Decision |
|---|---|
| Protocol actor annotation | None — callable from any context |
| Concrete implementation isolation | `@MainActor` — matches `PersistenceKit`'s `SwiftDataEntityStore<T>` confinement |
| `async` on protocol | No — synchronous `throws` throughout |
| VIPER compatibility | Interactors call synchronous methods; no `Task` wrapper required |
| MVVM compatibility | `@MainActor` ViewModels call synchronous methods directly |
| TCA compatibility | Reducer wraps calls in `Effect` if needed; repository itself is synchronous |
| Background `ModelContext` | Not used |
| Thread-safe mutation | Not needed — single-thread `@MainActor` confinement |

`@MainActor` is expressed on the concrete type only, not on the `ReviewRepository` protocol, preserving the architecture-agnostic contract.

---

### i. Error Handling

```swift
enum ReviewRepositoryError: Error {
    case notFound           // fetch/update called for movieId with no review
    case alreadyExists      // create called for movieId that already has a review
    case invalidRating      // rating outside 1–5
    case fetchFailed(Error)
    case insertFailed(Error)
    case updateFailed(Error)
    case deleteFailed(Error)
}
```

| Case | Source | Recoverability |
|---|---|---|
| `.notFound` | `PersistenceError.notFound` on update; `nil` result on fetch | Recoverable — feature layer refreshes Movie Detail CTA state |
| `.alreadyExists` | `PersistenceError.duplicateEntry` on insert | Recoverable — should not occur in normal UI (US-037); feature layer can surface an error |
| `.invalidRating` | Service-layer guard before any store call | Recoverable — wizard validates at UI level; this is a defence-in-depth error |
| `.fetchFailed(Error)` | `PersistenceError.fetchFailed` | Terminal for operation; feature layer surfaces error state |
| `.insertFailed(Error)` | `PersistenceError.insertFailed` / `.saveFailed` | Terminal |
| `.updateFailed(Error)` | `PersistenceError.updateFailed` / `.saveFailed` | Terminal |
| `.deleteFailed(Error)` | `PersistenceError.deleteFailed` / `.saveFailed` | Terminal |

No `PersistenceError` or SwiftData type crosses the `ReviewRepository` boundary.

---

### j. iOS-Specific Concerns

| Concern | Decision |
|---|---|
| Keychain | Not required |
| BGTaskScheduler | Not required |
| APNs | Not required |
| Runtime permissions | Not required |
| Sign in with Apple | Not applicable |
| iCloud / CloudKit | Explicitly out of scope |
| Privacy manifest | Standard local file access entry in `PrivacyInfo.xcprivacy`; no required-reason API usage |

---

### k. Initialization & Configuration

Constructor injection. No singletons, service locators, or SwiftUI environment access.

```swift
final class DefaultReviewRepository: ReviewRepository {
    private let store: ReviewStoring

    init(store: ReviewStoring) {
        self.store = store
    }
}
```

Composition root bootstrap sequence (identical pattern to `WatchlistRepository`):
1. Construct `ModelContainer` via `ModelContainerProvider`.
2. Construct `SwiftDataReviewStore` (wrapping `EntityStore<ReviewEntity>` from the container).
3. Inject `SwiftDataReviewStore` into `DefaultReviewRepository`.
4. Make the repository available via the DI mechanism for the architecture variant (SwiftUI environment, VIPER coordinator, TCA dependency client).

---

### l. Deferred / Out of Scope for MVP

| Item | Rationale |
|---|---|
| Reactive observation surface (`AsyncStream`, Combine publisher of `Review?`) | Each architecture variant provides its own; protocol intentionally does not prescribe one |
| `createdAt` display on Movie Detail | PRD does not require it; `createdAt` is available on the domain struct if needed later |
| Coordinated watchlist + review deletion | Not required by PRD; would be a service-layer caller concern |

## Unresolved Issues

None. All planning questions have been answered and all decisions are recorded above.
