# ReviewRepository Service Plan for Movie Tracker

## 1. Overview

`ReviewRepository` is the sole service-layer owner of the full review lifecycle for Movie Tracker. It encapsulates create, fetch, update, delete, and existence-check operations for the one-review-per-movie constraint. All review data is local-only; there is no network dependency. The service exposes a synchronous `throws` protocol to the feature layer using only domain types — no SwiftData or `PersistenceKit` type crosses the boundary.

The concrete implementation (`DefaultReviewRepository`) consumes a narrow `ReviewStoring` protocol defined within the service module. `PersistenceKit` is invisible to callers and test targets above this layer.

---

## 2. Domain Capability & Responsibility Boundary

**Domain capability**: Full review lifecycle management with one-review-per-movie enforcement.

### In Scope

| Responsibility | Detail |
|---|---|
| Create a new review | Wizard step 4 confirm — create path; validates rating, stamps timestamps, inserts |
| Overwrite an existing review | Wizard step 4 confirm — edit path; validates rating, stamps `updatedAt`, updates |
| Fetch the single review for a `movieId` | Returns `nil` if no review exists |
| Delete a review unconditionally | No pre-delete existence check; store-level failures propagate |
| Existence check | `contains(movieId:)` convenience; avoids forcing callers to nil-check `fetch` |
| One-review-per-movie invariant | Enforced by `@Attribute(.unique)` on `movieId`; `PersistenceError.duplicateEntry` mapped to `.alreadyExists` |
| Rating validation | Range 1–5 checked before any store interaction on both `create` and `update` |
| `[ReviewTag]` ↔ `[String]` conversion | Performed inline at the concrete-repo boundary |
| `PersistenceError` → `ReviewRepositoryError` mapping | All store errors translated; no persistence type escapes |

### Explicitly Out of Scope

| Concern | Owning Layer |
|---|---|
| Confirmation dialog before deletion | Feature layer (Movie Detail) |
| Wizard step-by-step in-progress state | Wizard feature layer; repository is only called on final confirm |
| Reactive observation / change streams | Architecture-specific feature layer |
| Poster URL construction or any network access | Not applicable |
| Coordinated watchlist + review deletion | Service-layer caller if ever needed |
| `ReviewTag` display labels / ordering | Feature/UI layer |

**Boundary justification**: The repository is called only at the point of a completed user action (wizard final confirm, delete confirm). In-flight wizard state is transient UI state owned by the presenting feature, not a persistence concern. Reactive observation is architecture-specific and must not be prescribed at the protocol level to keep the contract compatible with MVVM, VIPER, and TCA variants.

---

## 3. Framework Dependencies

`ReviewRepository` consumes a single framework via a narrow protocol defined within the service module itself.

| Framework | Protocol consumed | What is required |
|---|---|---|
| `PersistenceKit` | `ReviewStoring` (service-module protocol) | `insert`, `update`, `fetch` (by `movieId`), `delete` over `ReviewEntity` DTOs; `PersistenceError` error surface |

`ReviewStoring` is defined in the service module so that `PersistenceKit` is absent from the `ReviewRepository` protocol and all test targets:

```swift
protocol ReviewStoring {
    func insert(_ entity: ReviewEntity) throws
    func update(_ entity: ReviewEntity) throws
    func fetch(movieId: Int) throws -> ReviewEntity?
    func delete(movieId: Int) throws
}
```

`ReviewEntity` is a DTO type defined inside `PersistenceKit`. The `ReviewRepository` protocol carries no import of `PersistenceKit`. Test targets inject a fake `ReviewStoring` conformer with no `PersistenceKit` dependency.

The Networking framework has no role in this service; reviews are fully offline.

---

## 4. Business Rules

| Rule | Description | Error thrown |
|---|---|---|
| Rating validation | On both `create` and `update`, `rating` must be in the range 1–5 inclusive. Checked before any store interaction. | `ReviewRepositoryError.invalidRating` |
| Duplicate guard on create | No pre-fetch guard. The concrete repo attempts insert and catches `PersistenceError.duplicateEntry` from `@Attribute(.unique)` on `movieId`. | `ReviewRepositoryError.alreadyExists` |
| Tag conversion | `[ReviewTag]` received from callers is mapped to `[String]` raw values before `ReviewStoring`. `[String]` from fetched `ReviewEntity` is mapped back via `compactMap` before returning. | — |
| `createdAt` on create | Both `createdAt` and `updatedAt` are stamped with `Date()` at insert time. | — |
| `updatedAt` on update | `updatedAt` is stamped with `Date()` before writing the entity to the store. | — |
| Unconditional delete | `delete(movieId:)` issues the store delete without a prior existence check. | `ReviewRepositoryError.deleteFailed(Error)` |

---

## 5. Public Interface

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

- Synchronous `throws` throughout — `PersistenceKit` is synchronous and `@MainActor`-confined; `async` adds no value and would force unnecessary `Task` bridging in VIPER Interactors.
- `create` and `update` are distinct, preserving semantic error taxonomy (`.alreadyExists` on `create`, `.notFound` on `update`).
- `fetch` returns an optional domain value type. Callers never see SwiftData lifecycle or `@Model` reference semantics.
- `contains` is a convenience that avoids requiring feature-layer callers to nil-check a `fetch` result for presence checks, consistent with `WatchlistRepository`.
- No reactive stream on the protocol. Each architecture variant provides its own observation mechanism.

---

## 6. State Ownership

**Stateless.** `DefaultReviewRepository` holds only its injected `ReviewStoring` dependency. There is no in-memory cache of review records, no session-scoped state, and no observable property. All persistent state lives in the SwiftData store via `PersistenceKit`. Every operation reads from or writes to the store directly.

---

## 7. Data Transformation & Mapping

Two mapping boundaries, both handled inline in `DefaultReviewRepository`:

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

Domain inputs → `ReviewEntity` on `create`/`update` is the inverse; `createdAt`/`updatedAt` are stamped with `Date()` at the concrete-repo boundary.

No dedicated mapper type is warranted. The mapping is a one-liner `compactMap` for tags and direct field assignment for all other properties. `DomainModels` has no dependency on `PersistenceKit`; `PersistenceKit` has no dependency on `DomainModels`.

---

## 8. Caching Strategy

**No caching required.** Reviews are fully offline-first. All operations read from and write to the local SwiftData store with no network dependency.

- No TTL, no in-memory snapshot, no stale-data concept.
- No read-through or write-through cache.
- SwiftData's own change propagation via `@Model` implicit `Observable` conformance is available to feature-layer callers who hold a live `@Query` or observe the model directly, but the repository itself is stateless and does not manage that surface.

---

## 9. Offline & Sync Behavior

Reviews are **fully offline-first** by design:

- All CRUD operations function without network access.
- No CloudKit, iCloud, or any remote sync (explicitly out of scope per PRD).
- No write queue or deferred sync mechanism is required or planned.
- No conflict resolution — no remote state exists.
- Poster images on Movie Detail may still load from TMDB URLs opportunistically when the network is available, but this is outside `ReviewRepository`'s concern entirely.

---

## 10. Concurrency Model

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

`@MainActor` is expressed on the concrete type only, not on the `ReviewRepository` protocol, preserving the architecture-agnostic contract. This matches the `WatchlistRepository` pattern exactly.

---

## 11. Error Handling

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
| `.alreadyExists` | `PersistenceError.duplicateEntry` on insert | Recoverable — should not occur in normal UI (US-037); feature layer can surface an inline error |
| `.invalidRating` | Service-layer guard before any store call | Recoverable — wizard validates at UI level; this is a defence-in-depth guard |
| `.fetchFailed(Error)` | `PersistenceError.fetchFailed` | Terminal for the operation; feature layer surfaces error state |
| `.insertFailed(Error)` | `PersistenceError.insertFailed` / `.saveFailed` | Terminal |
| `.updateFailed(Error)` | `PersistenceError.updateFailed` / `.saveFailed` | Terminal |
| `.deleteFailed(Error)` | `PersistenceError.deleteFailed` / `.saveFailed` | Terminal |

No `PersistenceError` or SwiftData type crosses the `ReviewRepository` boundary.

---

## 12. iOS-Specific Concerns

| Concern | Decision |
|---|---|
| Keychain | Not required — no credentials or sensitive tokens are managed by this service |
| BGTaskScheduler | Not required — no background sync or prefetch |
| APNs | Not required |
| Runtime permissions | Not required |
| Sign in with Apple | Not applicable |
| iCloud / CloudKit | Explicitly out of scope per PRD |
| Privacy manifest | Standard local file access entry in `PrivacyInfo.xcprivacy`; no required-reason API usage |

The only iOS-specific constraint is the `@MainActor` confinement inherited from SwiftData's `ModelContext`, which is already captured in the concurrency model.

---

## 13. Initialization & Configuration

Constructor injection. No singletons, service locators, or SwiftUI environment access.

```swift
@MainActor
final class DefaultReviewRepository: ReviewRepository {
    private let store: ReviewStoring

    init(store: ReviewStoring) {
        self.store = store
    }
}
```

**Composition root bootstrap sequence** (identical pattern to `WatchlistRepository`):

1. Construct `ModelContainer` via `ModelContainerProvider`.
2. Construct `SwiftDataReviewStore` (wrapping `EntityStore<ReviewEntity>` from the container).
3. Inject `SwiftDataReviewStore` into `DefaultReviewRepository`.
4. Make the repository available via the DI mechanism for the architecture variant:
   - MVVM: SwiftUI environment value or `@EnvironmentObject`
   - VIPER: manual injection into the Interactor via the coordinator
   - TCA: `DependencyKey` / `DependencyValues` entry

No property wrappers, global state, or lazy initialization. The repository is fully ready after `init`.

---

## 14. Platform & OS Constraints

| Constraint | Impact |
|---|---|
| iOS 17 minimum | SwiftData (`@Model`, `ModelContext`, `@Attribute(.unique)`) require iOS 17. No availability gates needed within this service — the deployment target enforces globally. |
| `@Attribute(.unique)` on `movieId` | The store-level uniqueness guard for one-review-per-movie relies on this iOS 17 SwiftData feature. `.duplicateEntry` is the runtime signal. |
| Synchronous `ModelContext` API | All `EntityStore<T>` methods are synchronous; no async bridging is needed at this layer. |
| No background `ModelContext` | All operations occur on `@MainActor`. No performance concern at this dataset scale (user-bounded personal list). |
| No entitlements required | Standard SQLite on-disk persistence in the app's default container directory needs no special entitlement. |

---

## 15. Deferred / Out of Scope for MVP

| Item | Rationale |
|---|---|
| Reactive observation surface (`AsyncStream<Review?>`, Combine publisher) | Each architecture variant provides its own; protocol intentionally does not prescribe one |
| `createdAt` display on Movie Detail | PRD does not require it; `createdAt` is available on the domain struct if needed later |
| Coordinated watchlist + review deletion | Not required by PRD; would be a service-layer caller concern if the product ever adds cascading delete |
| Sorting or filtering reviews | PRD limits reviews to one per movie; no list query is needed |

---

## 16. Open Questions / Unresolved Decisions

None. All planning questions have been answered and all decisions are recorded in the planning session summary (`planning-summary.md`).
