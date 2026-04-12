# PersistenceKit — Framework Planning Summary

## Decisions

1. `EntityStore<T: PersistableEntity>` is the primary public abstraction — generic, parameterised over entity type, exposes `insert`, `delete`, `update`, and `fetch`.
2. `PersistableEntity` is a protocol boundary owned by `PersistenceKit` — `Identifiable`, `Equatable`, `Sendable`. No persistence knowledge.
3. `EntityQuery<T>` is the fetch abstraction owned by `PersistenceKit`, built from Foundation types (`Predicate<T>`, `SortDescriptor<T>`, `fetchLimit: Int?`). Maps to `FetchDescriptor` internally. Never exposed to callers as `FetchDescriptor`.
4. Auto-save only — no `save()` method on any public surface. The concrete implementation calls `context.save()` internally after each mutation.
5. `@Model` classes are fully internal to `PersistenceKit` — never exposed across the module boundary.
6. Repository is a service-layer entity. `PersistenceKit` does not define or own repository protocols or named query methods.
7. `PersistenceKit` owns internal DTO types (`WatchlistEntryEntity`, `ReviewEntity`) with `Entity` suffix. These are `internal` — the service layer never holds them directly.
8. An internal `SwiftDataMappable` protocol handles bidirectional mapping between the internal `@Model` classes and the internal entity DTOs. Invisible to all callers.
9. Single `PersistenceError` enum owned by `PersistenceKit` with cases: `.insertFailed(Error)`, `.fetchFailed(Error)`, `.deleteFailed(Error)`, `.saveFailed(Error)`, `.updateFailed(Error)`, `.notFound`, `.duplicateEntry`.
10. `@MainActor`-isolated concrete types. No background `ModelContext`. Protocol methods are `async`.
11. `ModelContainerProvider` exposes a `StoreType` parameter. In-memory containers are constructed without applying `SchemaMigrationPlan`.
12. `PersistenceKit` owns all `VersionedSchema` declarations and the `SchemaMigrationPlan`. No schema knowledge outside the framework.
13. `PersistenceKit` is a separate Swift Package target.
14. Injection mechanism (ownership of `ModelContainer`, `PersistenceStack` shape) deferred to implementation.
15. No reactive surface (no `AsyncStream`, no Combine publishers) exposed by the framework.
16. A separate `DomainModels` Swift Package target owns all domain types (`WatchlistEntry`, `Review`, `Movie`, `Genre`, `CastMember`, `MovieDetail`, `ReviewTag`). No dependency on `PersistenceKit` or any infrastructure target.
17. Service-layer repositories consume `EntityStore<T>` and map between entity DTOs and `DomainModels` types using dedicated mapper types owned by the service layer.
18. Mapper types in the service layer handle DTO ↔ Domain conversion in both directions. Conversion is always the repository's responsibility.

## Matched Recommendations

1. `EntityStore<T>` as primary abstraction — confirmed; covers both `WatchlistEntry` and `Review` CRUD uniformly.
2. `PersistableEntity` marker protocol with `Identifiable`, `Equatable`, `Sendable` — confirmed; no SwiftData import required for conformance.
3. `EntityQuery<T>` using Foundation `Predicate<T>` and `SortDescriptor<T>` — confirmed; these are iOS 17 Foundation types, not SwiftData-specific, and map cleanly to `FetchDescriptor` internally and would map to `NSFetchRequest` for a Core Data swap.
4. Internal `SwiftDataMappable` protocol for `@Model` ↔ entity DTO mapping — confirmed; invisible to all callers, keeps the swap seam clean.
5. Single `PersistenceError` with `.duplicateEntry` — confirmed; covers `@Attribute(.unique)` violation on `movieId` as a distinct, handleable case.
6. Skip `SchemaMigrationPlan` for in-memory test containers — confirmed; ephemeral stores always match current schema.
7. Single unified `EntityStore<T>` protocol (not split into `ReadableStore`/`WritableStore`) — confirmed for MVP.
8. `DomainModels` as target name — confirmed; zero external dependencies, imported by service, feature, and test layers.
9. Inline mapping deferred to dedicated mapper types — confirmed; service layer owns mappers, one per entity.
10. No reactive surface from `PersistenceKit` — confirmed; `@Model`'s implicit `Observable` is sufficient for architecture-specific observation patterns.

## Summary

### a. Confirmed Responsibility and Boundaries

**In scope:**
- Wrapping SwiftData behind a generic, swappable persistence abstraction
- Owning `@Model` classes (`WatchlistEntryModel`, `ReviewModel`) as internal implementation details
- Defining `PersistableEntity`, `EntityStore<T>`, and `EntityQuery<T>` as the public protocol surface
- Owning internal entity DTOs (`WatchlistEntryEntity`, `ReviewEntity`) and their `SwiftDataMappable` conformances
- Owning `PersistenceError`, `ModelContainerProvider`, `VersionedSchema`, and `SchemaMigrationPlan`
- Auto-saving after every mutation

**Explicitly out of scope (service layer):**
- Repository protocols and named query methods (e.g. `fetchAllWatchlistEntries()`, `fetchReview(forMovieId:)`)
- Domain type definitions — these live in the independent `DomainModels` target
- DTO ↔ Domain mapping — owned by service-layer mapper types
- `ModelContainer` ownership and injection strategy — decided at implementation
- Reactive observation surface

### b. Protocol and Interface Design

**Public surface of `PersistenceKit`:**

```swift
public protocol PersistableEntity: Identifiable, Equatable, Sendable {}

public struct EntityQuery<T: PersistableEntity> {
    public var predicate: Predicate<T>?
    public var sortDescriptors: [SortDescriptor<T>]
    public var fetchLimit: Int?
}

public protocol EntityStore<T: PersistableEntity> {
    func insert(_ entity: T) async throws
    func update(_ entity: T) async throws
    func delete(_ entity: T) async throws
    func fetch(_ query: EntityQuery<T>) async throws -> [T]
}

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

**Internal surface (invisible to callers):**

```swift
internal protocol SwiftDataMappable: PersistableEntity {
    associatedtype ManagedObject: PersistentModel
    init(from managedObject: ManagedObject)
    func toManagedObject() -> ManagedObject
}

// Concrete implementation
@MainActor
internal final class SwiftDataEntityStore<T: SwiftDataMappable>: EntityStore {
    // maps EntityQuery<T> → FetchDescriptor<T.ManagedObject>
    // calls context.save() after every mutation
}
```

`WatchlistEntryEntity` and `ReviewEntity` are `internal` structs conforming to both `PersistableEntity` and `SwiftDataMappable`. The service layer never imports or holds these types — it receives and passes `DomainModels` types exclusively.

### c. Abstraction Depth

Rich abstraction — not a thin wrapper. The goal is full SwiftData isolation: swapping to Core Data or Realm requires only re-implementing `SwiftDataMappable` conformances and `SwiftDataEntityStore`. Every layer above (`DomainModels`, service layer, features) is untouched by a backend swap. This depth is justified by the multi-architecture study context and the explicit decision to keep domain types independent of persistence.

### d. Third-Party SDK Isolation

SwiftData is the only persistence SDK. It is fully isolated behind `EntityStore<T>` and `PersistableEntity`. No other third-party SDKs are involved. The `SwiftDataEntityStore` concrete type and all `@Model` declarations are internal. The `PersistableEntity` constraint on `EntityStore<T>` does not reference any SwiftData type.

### e. Testability Strategy

- `ModelContainerProvider` exposes a `StoreType` parameter. Test targets call `makeContainer(storeType: .inMemory)` directly — no migration plan applied, store always matches current schema.
- Service-layer tests can inject a mock or fake `EntityStore<T>` conformance without involving `PersistenceKit` at all — fully protocol-based.
- `@MainActor` isolation on concrete types is consistent with `XCTest` running on the main thread; no additional test actor bridging required.

### f. Concurrency Model

- All `PersistenceKit` concrete types are `@MainActor`-isolated.
- No background `ModelContext` is used anywhere in the persistence layer.
- `EntityStore` protocol methods are declared `async` to allow callers not already on `@MainActor` to `await` them across actor boundaries.
- No Combine or callback interop — Swift concurrency (`async/await`) exclusively.

### g. Error Types and Propagation

`PersistenceError` is the sole error type surfaced by `PersistenceKit`. It wraps underlying SwiftData errors in typed cases (`.insertFailed(Error)`, `.fetchFailed(Error)`, etc.) and adds semantic cases (`.notFound`, `.duplicateEntry`) that callers can match without inspecting SwiftData internals. The service layer translates `PersistenceError` cases into domain-level errors or user-facing messages. No SwiftData error type crosses the module boundary.

### h. Initialization and Configuration

- `ModelContainerProvider` is a factory that accepts a `StoreType` (`.persistent` / `.inMemory`) and produces a `ModelContainer` configured with `MovieTrackerSchemaV1` (production path also applies `SchemaMigrationPlan`; in-memory path skips migration).
- Whether `ModelContainerProvider` is a `struct` with a static method, a `final class`, or whether it `throws` is deferred to implementation — the correct shape depends on the full composition root pattern of each architecture branch.
- `PersistenceKit` does not use SwiftUI's `.modelContainer(_:)` environment injection. The `ModelContainer` is provided programmatically by the composition root of each architecture variant.

### i. OS Version and Platform Constraints

- iOS 17 minimum — SwiftData, `@Model`, `ModelContainer`, `VersionedSchema`, and `SchemaMigrationPlan` all require iOS 17.
- Foundation `Predicate<T>` and `SortDescriptor<T>` used in `EntityQuery<T>` also require iOS 17 — no version gate needed beyond the deployment target.
- `@Attribute(.unique)` on `movieId` for both `@Model` types is an iOS 17 SwiftData feature — the `.duplicateEntry` error case handles its violation.

### j. Deferred Decisions

- **`ModelContainerProvider` concrete shape** (struct/class, throws vs. fatalError): deferred to implementation. The correct choice depends on the error-handling strategy at the app composition root, which differs across MVVM, VIPER, and TCA branches.
- **`PersistenceStack` vs. direct `ModelContainer` injection into concrete stores**: deferred to implementation. Both are valid — the planning session leaves this as an implementation-time decision.
- **DTO split into sub-targets** (`PersistenceCore` / `PersistenceRepositories`): explicitly rejected for MVP. Revisit if the entity count grows.

## Unresolved Issues

1. `ModelContainerProvider` shape and error handling (struct/class, `throws` vs. `fatalError`) — left for implementation, dependent on composition root pattern per architecture branch.
2. `PersistenceStack` ownership model — whether a shared context-holder type wraps `ModelContainer` and is injected into stores, or stores receive `ModelContainer` directly — left for implementation.
