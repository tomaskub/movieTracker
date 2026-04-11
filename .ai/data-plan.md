# Data Model Plan for Movie Tracker

## 1. Overview

Movie Tracker requires two on-disk persistence models (`WatchlistEntry`, `Review`) backed by SwiftData, and three in-memory-only domain types (`Movie`, `Genre`, `CastMember`) decoded from the TMDB REST API. A composed in-memory type (`MovieDetail`) aggregates the detail-screen payload. A `ReviewTag` enum provides type-safe access to the fixed predefined tag vocabulary in the UI and wizard layers, while `Review.tags` is stored as `[String]` in the SwiftData model.

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
- **Role**: Decoded from `/movie/{id}/credits`; top three by billing order surfaced on Movie Detail. Never persisted. Absence (failed request) is a non-fatal state.

---

### 2.4 `MovieDetail`

| Property | Type | Notes |
|---|---|---|
| `movie` | `Movie` | Base movie fields from `/movie/{id}` |
| `genres` | `[Genre]` | Full genre objects returned in the detail endpoint |
| `cast` | `[CastMember]` | Top three; may be empty if credits request failed |

- **Swift type**: `struct`
- **Protocol conformances**: `Equatable`, `Sendable`
- **Role**: Composed in memory from the `/movie/{id}` response (which returns full genre objects) and the optional `/movie/{id}/credits` response. Used exclusively in the Movie Detail screen. Not decoded directly from a single JSON payload; assembled by the service layer after both requests resolve.

---

### 2.5 `ReviewTag`

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

### 2.6 `WatchlistEntry` (`@Model`)

| Property | Type | Notes |
|---|---|---|
| `movieId` | `Int` | `@Attribute(.unique)`; TMDB integer id |
| `title` | `String` | Snapshot at time of add |
| `releaseYear` | `Int` | Derived from `releaseDate` before insert |
| `voteAverage` | `Double` | Snapshot at time of add |
| `posterPath` | `String?` | Relative path; image re-fetched from network |
| `dateAdded` | `Date` | Set at insert time |

- **Swift type**: `class` (required by SwiftData `@Model`)
- **Protocol conformances**: implicit `Observable` via `@Model`
- **Role**: Persistent record of user intent to watch a movie. Powers the Watchlist tab entirely offline. Snapshot fields enable list-card display without a network call.

---

### 2.7 `Review` (`@Model`)

| Property | Type | Notes |
|---|---|---|
| `movieId` | `Int` | `@Attribute(.unique)`; TMDB integer id |
| `rating` | `Int` | Range 1–5; validated at service layer |
| `tags` | `[String]` | Raw `ReviewTag` string values |
| `notes` | `String` | Empty string allowed; non-optional |
| `createdAt` | `Date` | Set at initial insert |
| `updatedAt` | `Date` | Updated on every edit |

- **Swift type**: `class` (required by SwiftData `@Model`)
- **Protocol conformances**: implicit `Observable` via `@Model`
- **Role**: Persistent log of a user's opinion of a movie. At most one per `movieId`, enforced at both the store level (`@Attribute(.unique)`) and the service layer. Surfaced read-only on Movie Detail; created and edited via the four-step wizard.

---

## 3. Persistence Models

Both SwiftData `@Model` classes are their own persistence representation; no separate DTO or mapped counterpart exists.

### 3.1 `WatchlistEntry`

- **SwiftData annotation**: `@Model`
- **Unique constraint**: `@Attribute(.unique)` on `movieId`
- **Store**: on-disk SQLite (production), in-memory (tests)
- **Differs from domain**: none — the class is used directly as the display model for Watchlist list cards

### 3.2 `Review`

- **SwiftData annotation**: `@Model`
- **Unique constraint**: `@Attribute(.unique)` on `movieId`
- **Store**: on-disk SQLite (production), in-memory (tests)
- **Differs from domain**: `tags` is `[String]` rather than `[ReviewTag]`; conversion is performed at the repo/service boundary

---

## 4. Relationships

| Relationship | Entities | Cardinality | Declaration | Cascade / Delete |
|---|---|---|---|---|
| Watchlist ↔ Review | `WatchlistEntry` ↔ `Review` | One-to-one by convention (same `movieId`) | None — no SwiftData `@Relationship`; independently keyed by `movieId` | None; removing a `WatchlistEntry` does not delete the `Review`. Coordinated deletes are a service-layer concern if ever required. |

No other relationships exist. All API-sourced types are in-memory only and have no persistence graph connections.

---

## 5. Domain-to-Persistence Boundary

**Decision**: No explicit mapping layer.

`WatchlistEntry` and `Review` serve directly as display models for the screens that consume them (Watchlist tab cards, Movie Detail review summary). Their attribute sets match display needs without transformation.

The sole conversion at the boundary is `[String]` ↔ `[ReviewTag]` for `Review.tags`, which is handled inline at the repo layer (a one-line `compactMap`), not a dedicated mapper type.

API-sourced types (`Movie`, `Genre`, `CastMember`) never enter SwiftData. They are decoded, used, and released within the network/service layer. `MovieDetail` is assembled in memory by the service layer and never crosses the persistence boundary.

The **repo layer** owns all `ModelContext` interactions. It exposes a typed, SwiftData-free interface to callers (service/use-case layer and above), wrapping all SwiftData errors into typed domain errors. This decouples the MVVM, VIPER, and TCA branches from SwiftData internals entirely.

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
ModelContainer(for: WatchlistEntry.self, Review.self, ...)
```

No multi-store or shared group container configuration is required.

---

## 7. Fetch and Query Strategy

| Entity | Fetch Pattern | Sort | Indexes |
|---|---|---|---|
| `WatchlistEntry` | Full fetch of all records (no predicate) | In-memory, after fetch: `dateAdded` desc (default), `title` asc, `voteAverage` desc | `@Attribute(.unique)` on `movieId` serves as implicit index for membership checks |
| `Review` | Single-record predicate: `#Predicate { $0.movieId == id }` | N/A — at most one result | `@Attribute(.unique)` on `movieId` |

- **Pagination**: not applicable for local data; datasets are user-bounded personal lists
- **Lazy-loading**: not used; all records are fetched eagerly on screen appearance
- **No `@Query` macro with predicate in SwiftUI views for `Review`**: the repo layer issues `FetchDescriptor`-based fetches, keeping persistence details out of views

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
