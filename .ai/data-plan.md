# Data Model Plan for Movie Tracker

## 1. Overview

Movie Tracker requires two on-disk persistence models (`WatchlistEntry`, `Review`) backed by SwiftData, and three in-memory-only domain types (`Movie`, `Genre`, `CastMember`) decoded from the TMDB REST API. A composed in-memory type (`MovieDetail`) aggregates the detail-screen payload, with cast retrieval state expressed via the `CastState` enum. A `ReviewTag` enum provides type-safe access to the fixed predefined tag vocabulary in the UI and wizard layers, while `Review.tags` is stored as `[String]` in the SwiftData model.

All SwiftData operations run on `@MainActor`. No background `ModelContext` is used. A `ModelContainer` factory accepts a store type parameter to switch between on-disk (production) and in-memory (tests) configurations. The same data layer is shared across the MVVM, VIPER, and TCA branches.

---

## 2. Domain Entities

### 2.1 `Movie`

| Property | Type | Notes |
|---|---|---|
| `id` | `Int` | TMDB integer id |
| `title` | `String` | |
| `overview` | `String` | |
| `releaseDate` | `String` | ISO-8601 date string as returned by TMDB |
| `genreIds` | `[Int]` | List ids for list-card display; full genre names resolved separately in detail |
| `posterPath` | `String?` | Relative path; full URL assembled at presentation layer |
| `voteAverage` | `Double` | TMDB `vote_average` |

- **Swift type**: `struct`
- **Protocol conformances**: `Codable`, `Equatable`, `Hashable`, `Identifiable` (`id: Int`), `Sendable`
- **Role**: Decoded from `/trending/movie/week` and `/search/movie` responses; used for list-card display in Catalog, Search, and Watchlist tabs. Never written to SwiftData.

---

### 2.2 `Genre`

| Property | Type | Notes |
|---|---|---|
| `id` | `Int` | TMDB genre id |
| `name` | `String` | Display label |

- **Swift type**: `struct`
- **Protocol conformances**: `Codable`, `Equatable`, `Hashable`, `Identifiable` (`id: Int`), `Sendable`
- **Role**: Decoded from `/genre/movie/list`; held in memory for the session to populate the Search filter sheet. Never persisted.

---

### 2.3 `CastMember`

| Property | Type | Notes |
|---|---|---|
| `name` | `String` | Performer name |
| `character` | `String` | Role/character name |

- **Swift type**: `struct`
- **Protocol conformances**: `Codable`, `Equatable`, `Sendable`
- **Role**: Decoded from `/movie/{id}/credits`. Never persisted. Surfaced via `CastState.loaded` on `MovieDetail`; the consumer is responsible for slicing to the desired display count.

---

### 2.4 `CastState`

| Case | Associated value | Notes |
|---|---|---|
| `.notRetrieved` | — | Credits have not been fetched yet, or the fetch failed |
| `.loaded` | `[CastMember]` | Full cast list as returned by the credits endpoint; consumer is responsible for slicing to the desired display count |

- **Swift type**: `enum`
- **Protocol conformances**: `Equatable`, `Sendable`
- **Role**: Makes the retrieval state of cast data explicit at the type level on `MovieDetail`. Replaces the prior `[CastMember]` convention where an empty array was overloaded to mean both "no cast members" and "credits not yet fetched or failed".

---

### 2.5 `MovieDetail`

| Property | Type | Notes |
|---|---|---|
| `movie` | `Movie` | Base movie fields from `/movie/{id}` |
| `genres` | `[Genre]` | Full genre objects returned in the detail endpoint |
| `cast` | `CastState` | `.notRetrieved` until credits are fetched; `.loaded([CastMember])` on success |

- **Swift type**: `struct`
- **Protocol conformances**: `Equatable`, `Sendable`
- **Role**: Composed in memory from the `/movie/{id}` response (which returns full genre objects) and the optional `/movie/{id}/credits` response. Used exclusively in the Movie Detail screen. Not decoded directly from a single JSON payload; assembled by the service layer. `cast` starts as `.notRetrieved` and is updated to `.loaded` by the caller once the credits request resolves.

---

### 2.6 `ReviewTag`

| Case | Raw value (`String`) |
|---|---|
| `mustSee` | `"Must-see"` |
| `rewatchWorthy` | `"Rewatch-worthy"` |
| `underrated` | `"Underrated"` |
| `overrated` | `"Overrated"` |
| `comfortWatch` | `"Comfort watch"` |
| `dark` | `"Dark"` |
| `funny` | `"Funny"` |
| `emotional` | `"Emotional"` |
| `slowBurn` | `"Slow burn"` |
| `greatSoundtrack` | `"Great soundtrack"` |
| `thoughtProvoking` | `"Thought-provoking"` |

- **Swift type**: `enum` with `String` raw value
- **Protocol conformances**: `CaseIterable`, `Codable`, `Equatable`, `Hashable`, `Sendable`
- **Role**: Provides type-safe access to the fixed predefined tag vocabulary in the wizard UI and tag-selection step. `Review.tags` is stored as `[String]` (raw values) in SwiftData; conversion between `ReviewTag` and `String` is performed at the service/repo boundary.

---

### 2.7 `WatchlistEntry`

| Property | Type | Notes |
|---|---|---|
| `movieId` | `Int` | TMDB integer id |
| `title` | `String` | Snapshot at time of add |
| `releaseYear` | `Int` | Derived from `releaseDate` before insert |
| `voteAverage` | `Double` | Snapshot at time of add |
| `posterPath` | `String?` | Relative path; image re-fetched from network |
| `dateAdded` | `Date` | Set at insert time |

- **Swift type**: `struct`
- **Protocol conformances**: `Equatable`, `Hashable`, `Identifiable` (`id: Int` mapping to `movieId`), `Sendable`
- **Role**: Domain type in the `DomainModels` target. Vended to callers by the service layer after mapping from `WatchlistEntryEntity`. Snapshot fields enable list-card display without a network call. Never directly annotated with `@Model`; the internal `WatchlistEntryModel` inside `PersistenceKit` is the SwiftData representation.

---

### 2.8 `Review`

| Property | Type | Notes |
|---|---|---|
| `movieId` | `Int` | TMDB integer id |
| `rating` | `Int` | Range 1–5; validated at service layer |
| `tags` | `[ReviewTag]` | Typed tag values; stored as `[String]` raw values inside `PersistenceKit` only |
| `notes` | `String` | Empty string allowed; non-optional |
| `createdAt` | `Date` | Set at initial insert |
| `updatedAt` | `Date` | Updated on every edit |

- **Swift type**: `struct`
- **Protocol conformances**: `Equatable`, `Hashable`, `Identifiable` (`id: Int` mapping to `movieId`), `Sendable`
- **Role**: Domain type in the `DomainModels` target. Vended to callers by the service layer after mapping from `ReviewEntity`. At most one per `movieId`, enforced at the store level via `@Attribute(.unique)` on `ReviewModel.movieId` and at the service layer. Surfaced read-only on Movie Detail; created and edited via the four-step wizard. Never directly annotated with `@Model`; the internal `ReviewModel` inside `PersistenceKit` is the SwiftData representation.
- **`tags` persistence boundary**: `ReviewTag` ↔ `String` conversion is performed exclusively inside `PersistenceKit`. `ReviewModel` stores tags as `[String]` raw values. The domain type and all callers above the persistence layer work only with `[ReviewTag]`.

---

## 3. Persistence Models

All persistence internals are strictly contained within `PersistenceKit`. Three layers exist inside the module: internal `@Model` classes, internal entity DTOs, and an internal mapping protocol. Nothing in this section crosses the `PersistenceKit` module boundary.

### 3.1 Internal `@Model` classes

#### `WatchlistEntryModel` (internal)

- **SwiftData annotation**: `@Model`
- **Unique constraint**: `@Attribute(.unique)` on `movieId`
- **Store**: on-disk SQLite (production), in-memory (tests)
- **Visibility**: strictly internal to `PersistenceKit`; never vended to service-layer or UI callers

#### `ReviewModel` (internal)

- **SwiftData annotation**: `@Model`
- **Unique constraint**: `@Attribute(.unique)` on `movieId`
- **Store**: on-disk SQLite (production), in-memory (tests)
- **Visibility**: strictly internal to `PersistenceKit`; never vended to service-layer or UI callers

### 3.2 Internal entity DTOs

#### `WatchlistEntryEntity` (public)

- **Conforms to**: `PersistableEntity` (`Identifiable`, `Equatable`)
- **Role**: Public bridge type between `PersistenceKit` and the service layer. Parameterises `EntityStore<T>` for watchlist operations inside `PersistenceKit`. Received and operated on by `DefaultWatchlistRepository`, which maps it to/from the `WatchlistEntry` domain type.
- **Visibility**: public; accessible to service-layer callers. The underlying `WatchlistEntryModel` (`@Model`) remains strictly internal to `PersistenceKit`.

#### `ReviewEntity` (public)

- **Conforms to**: `PersistableEntity` (`Identifiable`, `Equatable`)
- **Role**: Public bridge type between `PersistenceKit` and the service layer. Parameterises `EntityStore<T>` for review operations inside `PersistenceKit`. Received and operated on by `DefaultReviewRepository`, which maps it to/from the `Review` domain type.
- **Visibility**: public; accessible to service-layer callers. The underlying `ReviewModel` (`@Model`) remains strictly internal to `PersistenceKit`.

### 3.3 Internal mapping protocol

#### `SwiftDataMappable` (internal)

- **Kind**: protocol (internal to `PersistenceKit`)
- **Purpose**: Bidirectional conversion between an internal `@Model` class and its corresponding entity DTO. Implemented by `WatchlistEntryModel` and `ReviewModel`.
- **Direction**: `@Model` → entity DTO (on fetch), entity DTO → `@Model` (on insert/update)

---

## 4. Relationships

| Relationship | Entities | Cardinality | Declaration | Cascade / Delete |
|---|---|---|---|---|
| Watchlist ↔ Review | `WatchlistEntry` ↔ `Review` | One-to-one by convention (same `movieId`) | None — no SwiftData `@Relationship`; independently keyed by `movieId` | None; removing a `WatchlistEntry` does not delete the `Review`. Coordinated deletes are a service-layer concern if ever required. |

No other relationships exist. All API-sourced types are in-memory only and have no persistence graph connections.

---

## 5. Domain-to-Persistence Boundary

Two explicit mapping layers exist. No SwiftData type (`@Model`, `ModelContext`, `FetchDescriptor`) crosses the `PersistenceKit` module boundary at any point.

### Layer 1 — PersistenceKit-internal: `SwiftDataMappable`

`SwiftDataMappable` performs bidirectional conversion between the internal `@Model` classes and the internal entity DTOs:

- `WatchlistEntryModel` ↔ `WatchlistEntryEntity`
- `ReviewModel` ↔ `ReviewEntity`

This mapping is invisible to all callers outside `PersistenceKit`. The concrete `SwiftDataEntityStore<T>` uses it internally on every fetch (model → entity) and every insert/update (entity → model).

### Layer 2 — Service layer: `Domain type` ↔ `Entity DTO`

`DefaultWatchlistRepository` and `DefaultReviewRepository` own all mapping between domain types and entity DTOs. No `@Model` class or SwiftData type is involved at this layer.

- `WatchlistEntry` ↔ `WatchlistEntryEntity` — performed inline in `DefaultWatchlistRepository`
- `Review` ↔ `ReviewEntity` — performed inline in `DefaultReviewRepository`

The `[ReviewTag]` ↔ `[String]` conversion for `Review.tags` is part of this layer: `DefaultReviewRepository` maps `[ReviewTag]` → `[String]` before passing a `ReviewEntity` to the store, and maps `[String]` → `[ReviewTag]` when constructing a `Review` from a fetched `ReviewEntity`.

### API-sourced types

`Movie`, `Genre`, `CastMember`, and `MovieDetail` never enter SwiftData. They are decoded, used, and released within the network/service layer. `MovieDetail` is assembled in memory by the service layer and never crosses the persistence boundary.

---

## 6. Persistence Configuration

### Container Setup

A `ModelContainerProvider` (factory type) is responsible for constructing and vending the shared `ModelContainer`. It accepts a `storeType` parameter:

- **Production**: `.persistent` — standard on-disk SQLite in the app's default container directory
- **Tests**: `.inMemory` — ephemeral store; container is recreated in `setUp()` and torn down in `tearDown()` per `XCTestCase` for full test isolation

The `ModelContainer` is constructed with the versioned schema (see §10) and injected into each architecture variant via SwiftUI environment (`.modelContainer(_:)`) or a dependency-injection seam specific to each variant.

### Schema Registration

Both `@Model` classes are registered together in a single `ModelContainer`:

```
ModelContainer(for: WatchlistEntryModel.self, ReviewModel.self, ...)
```

No multi-store or shared group container configuration is required.

---

## 7. Fetch and Query Strategy

No `FetchDescriptor`, `@Model` field reference, or SwiftData `#Predicate` against a `@Model` type appears outside `PersistenceKit`. The two store protocols use different fetch shapes suited to their access patterns:

| Entity DTO | Storing protocol fetch signature | Sort | Indexes |
|---|---|---|---|
| `WatchlistEntryEntity` | `fetch(predicate: Predicate<WatchlistEntryEntity>?) throws -> [WatchlistEntryEntity]` | In-memory after fetch: `dateAdded` desc (default), `title` asc, `voteAverage` desc | `@Attribute(.unique)` on `WatchlistEntryModel.movieId` serves as implicit index for membership checks |
| `ReviewEntity` | `fetch(movieId: Int) throws -> ReviewEntity?` | N/A — at most one result | `@Attribute(.unique)` on `ReviewModel.movieId` |

**`Predicate<WatchlistEntryEntity>`**: `WatchlistEntryEntity` is a plain struct of Foundation-owned types (`Int`, `String`, `Double`, `Date`). `Predicate<T>` is a Foundation type — no SwiftData import is required to construct or pass a `Predicate<WatchlistEntryEntity>` in the service module. Inside `PersistenceKit`, `SwiftDataWatchlistEntryStore` translates the predicate into a `FetchDescriptor<WatchlistEntryModel>` internally.

**`ReviewStoring.fetch(movieId:)`**: a direct keyed lookup is sufficient; no predicate abstraction is needed given the one-review-per-movie constraint. The `@Attribute(.unique)` index on `ReviewModel.movieId` makes this efficient at the store level.

**`EntityQuery<T>`**: an internal `PersistenceKit` detail used to translate predicates and sort descriptors into `FetchDescriptor<T>`. Never exposed to the service layer.

- **Pagination**: not applicable — datasets are user-bounded personal lists
- **Lazy-loading**: not used; all watchlist records are fetched eagerly on screen appearance

---

## 8. Sync and Offline Strategy

- **Watchlist tab**: fully offline-first. All CRUD operations (add, list, remove) read from and write to local SwiftData with no network dependency. Poster images load from TMDB URLs opportunistically when a network is available.
- **Reviews**: fully offline-first. The full review lifecycle (create, read, edit, delete) operates on local SwiftData only.
- **Catalog, Search, Movie Detail**: online-first. These screens depend on TMDB API responses. Failures surface inline error states with retry affordances; no local cache of API results is maintained.
- **No sync**: CloudKit, iCloud, or any remote sync is explicitly out of scope. No conflict resolution or sync-queue infrastructure is required.
- **Filter/sort preferences**: held in memory only (ephemeral state in the view layer or view model/presenter/store per variant); not persisted and reset to defaults on cold launch.

---

## 9. Data Security

- No end-user credentials or sensitive personal data are stored.
- `WatchlistEntry` and `Review` contain non-sensitive personal preference data (movie watchlist, ratings, text notes); no special classification is required.
- The standard SwiftData SQLite store is used without additional encryption. No `NSPersistentStoreFileProtection` or encrypted store configuration is needed.
- No Keychain usage is required for persistence.
- The TMDB API key is delivered via build-time environment-backed configuration (`.xcconfig` or equivalent). It is never stored in SwiftData, written to disk by the app, or exposed in any UI surface.
- Privacy manifest: no tracking-level data is collected; a standard `PrivacyInfo.xcprivacy` entry covering local file access is sufficient.

---

## 10. Migration Strategy

- **Framework**: SwiftData `VersionedSchema` + `SchemaMigrationPlan`
- **Initial version**: `MovieTrackerSchemaV1` defines `WatchlistEntry` and `Review` with the attributes in §2.6 and §2.7
- **Versioning convention**: `MovieTrackerSchemaV{N}` for each breaking change; `SchemaMigrationPlan` lists `MigrationStage` entries in order
- **Default migration**: lightweight/automatic within a schema version (additive changes — new optional attributes, index additions)
- **Custom migration**: a `MigrationStage.custom` stage is added only when a breaking change requires a data transformation (e.g., changing `tags` storage format, renaming an attribute)
- The `ModelContainerProvider` factory passes the `SchemaMigrationPlan` to the `ModelContainer` initializer so migration runs automatically on first launch after an app update

---

## 11. Open Questions / Deferred Decisions

None. All planning questions have been resolved. All decisions are recorded in the data-planning session summary.
