# PersistenceKit Framework Plan for Movie Tracker

## 1. Overview

`PersistenceKit` is a generic, protocol-driven persistence framework that wraps SwiftData behind a fully abstracted interface. It sits directly above the SwiftData SDK and below the service layer in the dependency stack. No layer above the framework imports SwiftData — all persistence knowledge is contained within this module boundary.

The framework provides three capabilities to any caller:

1. A generic CRUD abstraction (`EntityStore<T>`) parameterised over an entity DTO type.
2. A composable fetch descriptor (`EntityQuery<T>`) built from Foundation-native types that does not leak SwiftData internals.
3. A `ModelContainerProvider` factory that produces a `ModelContainer` configured for either on-disk production use or in-memory test isolation.

All SwiftData `@Model` classes, schema declarations (`VersionedSchema`, `SchemaMigrationPlan`), and internal entity DTO types are strictly internal to the module. The full persistence backend can be replaced by re-implementing only the internals of `PersistenceKit`; every layer above is untouched by such a swap.

The framework targets iOS 17 exclusively (SwiftData requirement). All `EntityStore<T>` methods are synchronous `throws` — SwiftData's `ModelContext` API is itself synchronous, and all operations are confined to `@MainActor`, making async/await unnecessary overhead at this layer. This keeps the persistence contract compatible with completion-handler-based architectures such as VIPER without forcing `Task` bridging at every Interactor call site. It is delivered as a separate Swift Package target named `PersistenceKit`.

---

## 2. Responsibility & Boundary

### In scope

- Defining `PersistableEntity`, `EntityStore<T>`, and `EntityQuery<T>` as the public protocol and type surface.
- Owning the internal `@Model` classes (`WatchlistEntryModel`, `ReviewModel`) as concrete SwiftData representations.
- Owning internal entity DTOs (`WatchlistEntryEntity`, `ReviewEntity`) that cross the in-module boundary between `@Model` objects and `EntityStore` callers.
- Owning the internal `SwiftDataMappable` protocol for bidirectional `@Model` ↔ entity DTO conversion.
- Owning the concrete `SwiftDataEntityStore<T>` implementation, including `FetchDescriptor` construction and `ModelContext.save()` after every mutation.
- Owning `PersistenceError` as the single error type surfaced to callers.
- Owning `ModelContainerProvider` (factory) and all `VersionedSchema` and `SchemaMigrationPlan` declarations.
- Auto-saving after every mutation; no caller-visible `save()` method.

### Out of scope

| Concern | Owning layer |
|---|---|
| Repository protocols and named query methods (e.g. `fetchAllWatchlistEntries()`) | Service layer |
| Domain type definitions (`WatchlistEntry`, `Review`, `Movie`, etc.) | `DomainModels` Swift Package target |
| DTO ↔ Domain type mapping | Service-layer mapper types |
| `ModelContainer` ownership and injection wiring | Composition root of each architecture variant (MVVM / VIPER / TCA) |
| Reactive observation surfaces (`AsyncStream`, Combine publishers) | Architecture-specific feature/presentation layer |

The responsibility boundary is drawn to ensure that `PersistenceKit` has no dependency on `DomainModels` and that `DomainModels` has no dependency on `PersistenceKit`. The service layer is the only layer that imports both and performs the translation between them.

---

## 3. Public API Surface

### 3.1 `PersistableEntity`

- **Kind**: protocol
- **Purpose**: Marker constraint used by `EntityStore<T>` and `EntityQuery<T>`. Implemented by internal entity DTO types. Callers never construct conforming types directly — they only parameterise generics with them via the service layer. No SwiftData import is required to declare conformance.
- **Key requirements**: `Identifiable`, `Equatable`

```swift
public protocol PersistableEntity: Identifiable, Equatable {}
```

---

### 3.2 `EntityQuery<T>`

- **Kind**: struct
- **Purpose**: Composable fetch descriptor passed to `EntityStore.fetch(_:)`. Encapsulates predicate, sort order, and an optional fetch limit using Foundation-native types only. Never exposes `FetchDescriptor` to callers.
- **Key properties**:
  - `predicate: Predicate<T>?` — optional filter; `nil` fetches all records
  - `sortDescriptors: [SortDescriptor<T>]` — ordered sort criteria; empty means no guaranteed order
  - `fetchLimit: Int?` — optional cap on results; `nil` returns all matching records

```swift
public struct EntityQuery<T: PersistableEntity> {
    public var predicate: Predicate<T>?
    public var sortDescriptors: [SortDescriptor<T>]
    public var fetchLimit: Int?

    public init(
        predicate: Predicate<T>? = nil,
        sortDescriptors: [SortDescriptor<T>] = [],
        fetchLimit: Int? = nil
    )
}
```

---

### 3.3 `EntityStore`

- **Kind**: protocol (primary-associated type `T: PersistableEntity`)
- **Purpose**: Generic CRUD contract consumed by service-layer repositories. All methods are synchronous `throws`. SwiftData's `ModelContext` operations are themselves synchronous and all concrete implementations are `@MainActor`-confined, so `async` would add actor-hop overhead without enabling any real concurrency. The synchronous surface keeps the contract compatible with completion-handler-based callers (e.g. VIPER Interactors) without requiring `Task` bridging. Errors are typed as `PersistenceError`.
- **Key operations**:
  - `insert(_ entity: T) throws` — persists a new entity; throws `.duplicateEntry` if a unique constraint is violated
  - `update(_ entity: T) throws` — overwrites an existing entity matched by identity; throws `.notFound` if no matching record exists
  - `delete(_ entity: T) throws` — removes an entity matched by identity; throws `.notFound` if no matching record exists
  - `fetch(_ query: EntityQuery<T>) throws -> [T]` — returns all entities matching the query

```swift
public protocol EntityStore<T> where T: PersistableEntity {
    associatedtype T
    func insert(_ entity: T) throws
    func update(_ entity: T) throws
    func delete(_ entity: T) throws
    func fetch(_ query: EntityQuery<T>) throws -> [T]
}
```

---

### 3.4 `PersistenceError`

- **Kind**: enum conforming to `Error`
- **Purpose**: Single error type surfaced across the module boundary. Wraps underlying SwiftData errors in typed cases; adds semantic cases that callers can match without inspecting SwiftData internals.

```swift
public enum PersistenceError: Error {
    case insertFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)
    case saveFailed(Error)
    case updateFailed(Error)
    case notFound
    case duplicateEntry
}
```

---

### 3.5 `ModelContainerProvider`

- **Kind**: type (concrete shape — struct with static method vs. final class — deferred to implementation; see §11)
- **Purpose**: Factory that constructs and vends a configured `ModelContainer`. The concrete shape is the only public surface needed by the composition root of each architecture variant.
- **Key behaviour**:
  - Accepts a `StoreType` (`.persistent` / `.inMemory`) parameter.
  - `.persistent` path registers `MovieTrackerSchemaV1` and applies the `SchemaMigrationPlan`.
  - `.inMemory` path registers `MovieTrackerSchemaV1` without applying migration (ephemeral store always matches current schema).

---

## 4. Abstraction Depth

`PersistenceKit` adopts a **rich abstraction**, not a thin platform wrapper. The rationale is threefold:

1. **Multi-architecture study context**: The same persistence layer is shared verbatim across MVVM, VIPER, and TCA branches. A thin wrapper that leaks `FetchDescriptor`, `ModelContext`, or `@Model` types would force every branch to import SwiftData and re-implement isolation. The generic `EntityStore<T>` / `EntityQuery<T>` surface absorbs that complexity once.

2. **Swappability requirement**: The planning decision explicitly targets a swap seam where replacing SwiftData with Core Data or Realm requires only re-implementing `SwiftDataMappable` conformances and `SwiftDataEntityStore`. This is only achievable if no SwiftData type crosses the module boundary.

3. **Service-layer contract clarity**: Repositories in the service layer operate entirely on `DomainModels` types and `PersistenceError`. They never write a predicate against a `@Model` field — they construct `EntityQuery<T>` using Foundation `Predicate<T>`, which is backend-neutral. This separation is more valuable than the simplicity of a thin wrapper for a codebase intentionally studied for architectural trade-offs.

The abstraction level should be revisited only if the entity count grows significantly beyond the current two `@Model` classes, at which point per-entity granularity in the public surface may become worth the additional protocol surface.

---

## 5. Third-Party SDK Isolation

### SwiftData

- **Purpose**: On-disk and in-memory persistence via `@Model`, `ModelContext`, and `ModelContainer`.
- **Wrapper protocol introduced**: Yes — `EntityStore<T>` wraps all mutation and fetch operations; `EntityQuery<T>` wraps predicate and sort construction; `SwiftDataMappable` (internal) wraps `@Model` ↔ entity DTO conversion.
- **Rationale**: Full isolation is required. No SwiftData type (`PersistentModel`, `ModelContext`, `FetchDescriptor`, `@Model`) crosses the module boundary. The `PersistableEntity` constraint makes no reference to SwiftData, allowing callers in any layer to conform to it without importing the framework.
- **SDK-specific configuration managed here**: `ModelContainer` construction, `VersionedSchema` registration, `SchemaMigrationPlan` application, and `@Attribute(.unique)` declarations on `movieId` for both `@Model` classes are all owned and contained within `PersistenceKit`.

No other third-party SDKs are involved in this framework.

---

## 6. Testability

### In-memory store for integration tests

`ModelContainerProvider` exposes `makeContainer(storeType: .inMemory)` for test targets. The resulting `ModelContainer` is ephemeral, always matches the current schema (no migration applied), and is recreated in `setUp()` / torn down in `tearDown()` per `XCTestCase`. Tests that exercise the full `SwiftDataEntityStore<T>` code path use this container directly.

### Protocol-based fake for service-layer unit tests

Service-layer repository tests inject a mock or fake conformance to `EntityStore<T>` directly — no `PersistenceKit` types are imported at all for this use case. This is the preferred testing approach for repositories, since it eliminates any dependency on SwiftData or file system access in the test target.

```swift
// Example fake usable by any service-layer test target
final class InMemoryEntityStore<T: PersistableEntity>: EntityStore {
    var storage: [T] = []

    func insert(_ entity: T) throws { storage.append(entity) }
    func update(_ entity: T) throws { /* replace by id */ }
    func delete(_ entity: T) throws { /* remove by id */ }
    func fetch(_ query: EntityQuery<T>) throws -> [T] { storage }
}
```

### System resource substitution

The only system resource involved is the SQLite file. The in-memory `ModelContainer` eliminates all file-system dependency for tests. There are no sensors, hardware peripherals, clocks, or network resources relevant to this framework.

### `@MainActor` compatibility

The concrete `SwiftDataEntityStore<T>` is `@MainActor`-isolated. XCTest runs test methods on the main thread by default; no `async` test methods, `MainActor.run { }` wrappers, or expectation-based waiting is required to exercise the concrete store — tests call the synchronous `throws` methods directly.

---

## 7. Concurrency Model

- **Swift concurrency adoption**: Minimal and deliberate. `EntityStore<T>` protocol methods are synchronous `throws`. SwiftData's `ModelContext` API is itself synchronous; there is no underlying async work to expose. Removing `async` from the protocol eliminates forced `Task` bridging in callers that are not structured-concurrency-based (primarily VIPER Interactors), while imposing no cost on MVVM or TCA callers that call synchronous methods from within their own async contexts.
- **`@MainActor` confinement**: The concrete `SwiftDataEntityStore<T>` is `@MainActor`-isolated. This confinement is an implementation detail of the concrete type only — it is not expressed in the `EntityStore` protocol. Callers are responsible for ensuring they invoke store methods on the main thread. In practice, all three architecture variants (MVVM ViewModels, VIPER Interactors, TCA Reducers) already operate on the main thread for UI-driven operations, making this a non-issue.
- **No background `ModelContext`**: All `ModelContext` mutations and fetches occur on the main thread. For an app of this scope (two small entities, user-bounded personal lists), this has no measurable performance impact.
- **Thread-safe shared state**: The `ModelContainer` is thread-safe by SwiftData's own contract; `ModelContext` is main-thread confined, eliminating the need for any additional locking.
- **No reactive surface**: `PersistenceKit` exposes no publishers, streams, or observation hooks. Architecture-specific observation (`@Query` in SwiftUI, Combine publishers in VIPER, `@Observable` in TCA) is the responsibility of the layers above. The `@Model` implicit `Observable` conformance is available to any layer that chooses to use it directly, but `PersistenceKit` does not vend or manage it.
- **VIPER compatibility**: A VIPER Interactor calls repository methods synchronously and delivers results to its output via completion handler or delegate immediately in the same call stack — no `Task { }` wrapper, no async/await import, no actor-hop. This is the primary motivation for the synchronous protocol surface.

---

## 8. Error Handling

### `PersistenceError`

| Case | Failure domain | Propagation | Recoverability |
|---|---|---|---|
| `.insertFailed(Error)` | `ModelContext.insert` or subsequent `save()` failed for a reason other than uniqueness | `throws` | Terminal from the caller's perspective; the service layer surfaces a user-facing error message |
| `.fetchFailed(Error)` | `ModelContext.fetch(_:)` threw | `throws` | Terminal; service layer surfaces error state with optional retry |
| `.deleteFailed(Error)` | `ModelContext.delete` or `save()` failed | `throws` | Terminal |
| `.saveFailed(Error)` | `context.save()` failed after a mutation | `throws` | Terminal; store state may be inconsistent — service layer should treat as fatal for the operation |
| `.updateFailed(Error)` | `save()` after an in-place mutation failed | `throws` | Terminal |
| `.notFound` | `fetch` returned zero results where exactly one was required (update, delete by entity) | `throws` | Recoverable at the service layer — indicates a logic/state divergence that the service layer can translate into a user-visible warning |
| `.duplicateEntry` | `@Attribute(.unique)` violation on `movieId` | `throws` | Recoverable at the service layer — maps to the "duplicate watchlist add" error case described in US-011; service layer translates to a user-facing error without crashing |

No SwiftData error type (`SwiftDataError`, `NSError` with Core Data domain) crosses the module boundary. The associated `Error` values in wrapping cases are available for logging but are not expected to be inspected by callers.

---

## 9. Initialization & Configuration

### Bootstrap sequence

1. The composition root of the architecture variant (app entry point or dependency container) calls `ModelContainerProvider` to produce a `ModelContainer`.
2. The `ModelContainer` is injected into one or more `SwiftDataEntityStore<T>` instances (one per entity type: `WatchlistEntryEntity`, `ReviewEntity`).
3. Each store is made available to service-layer repositories through the injection mechanism of the architecture variant (environment object, DI container, constructor injection, etc.).

### `ModelContainerProvider` inputs

- `storeType: StoreType` — `.persistent` (production) or `.inMemory` (tests)
- No credentials, API keys, or user-configurable values are required.

### DI-agnostic design

`ModelContainerProvider` does not use SwiftUI's `.modelContainer(_:)` environment modifier, nor does it assume any specific DI container. It is a pure factory: given a store type, it returns a configured `ModelContainer`. How that container is threaded through the app is entirely the composition root's concern. This means the same `PersistenceKit` module works identically in the MVVM (SwiftUI environment), VIPER (manual injection), and TCA (dependency client) branches.

### Lazy / deferred initialization

None. The `ModelContainer` is created eagerly at app launch. SwiftData's own initializer is synchronous; no deferred init is needed or appropriate given the small schema size.

---

## 10. Platform & OS Constraints

| Constraint | Impact |
|---|---|
| **iOS 17 minimum** | SwiftData (`@Model`, `ModelContext`, `ModelContainer`), `VersionedSchema`, `SchemaMigrationPlan`, and `@Attribute(.unique)` all require iOS 17. No availability gates are needed within the module — the deployment target enforces this globally. |
| **Foundation `Predicate<T>` and `SortDescriptor<T>`** | Both require iOS 17. Used in `EntityQuery<T>` as the caller-facing query surface. No version gate is needed beyond the deployment target. |
| **`@Attribute(.unique)` on `movieId`** | iOS 17 SwiftData feature. The `.duplicateEntry` error case is the runtime signal for its violation. No fallback is needed for earlier OS versions given the iOS 17 minimum. |
| **No entitlements required** | Standard SQLite on-disk persistence in the app's default container directory requires no special entitlements (no iCloud, no shared app group, no HealthKit access, etc.). |
| **No background execution** | All persistence operations occur on the main thread. No background task registration, background fetch entitlement, or `BGTaskScheduler` usage is needed. |
| **No privacy manifest entries specific to persistence** | `WatchlistEntry` and `Review` contain non-sensitive personal preference data. A standard `PrivacyInfo.xcprivacy` entry covering local file access is sufficient; no required-reason API usage from `PersistenceKit` triggers additional declarations. |

---

## 11. Deferred / Out of Scope for MVP

### `ModelContainerProvider` concrete shape (struct vs. final class; `throws` vs. `fatalError`)

**Deferred to implementation.** The correct error-handling strategy at the `ModelContainer` initialisation point depends on the composition root pattern of each architecture branch. A `fatalError` on container construction failure is common in SwiftUI entry points; a `throws` variant is more appropriate when a DI container or coordinator owns composition. Both are valid — the planning session intentionally leaves this as an implementation-time decision.

**Trigger to revisit**: when the composition root pattern for each branch (MVVM, VIPER, TCA) is established.

### `PersistenceStack` wrapper type

**Deferred to implementation.** Whether a shared `PersistenceStack` type holds the `ModelContainer` and vends `ModelContext` instances to concrete stores, or whether stores receive `ModelContainer` directly, is an internal implementation detail. Both approaches satisfy the public API surface.

**Trigger to revisit**: when the first concrete `SwiftDataEntityStore<T>` implementation is written and the context ownership model becomes concrete.

### Sub-target split (`PersistenceCore` / `PersistenceRepositories`)

**Explicitly rejected for MVP.** With only two `@Model` entities, the overhead of additional targets outweighs the benefit. Revisit if the entity count exceeds five or if compile-time isolation of schema types from generic infrastructure becomes desirable.

---

## 12. Open Questions / Unresolved Decisions

### 1. `ModelContainerProvider` shape and error handling

**Unknown**: Should `ModelContainerProvider` be a `struct` with a static factory method, a `final class`, or a namespace enum? Should it `throw` on container construction failure or call `fatalError`?

**Information needed**: The composition root pattern chosen for each architecture variant. The MVVM SwiftUI entry point, the VIPER application coordinator, and the TCA `Store` bootstrap sequence each imply a different preferred error surface at startup.

### 2. `PersistenceStack` ownership model

**Unknown**: Should a shared `PersistenceStack` type own the `ModelContainer` and derive `ModelContext` for each store, or should each `SwiftDataEntityStore<T>` receive the `ModelContainer` directly and create its own context?

**Information needed**: The injection topology of each architecture branch. If a single `ModelContext` is shared across all stores (simpler, avoids context divergence), a `PersistenceStack` wrapper is the natural home. If stores are independently injected, direct `ModelContainer` injection is sufficient.
