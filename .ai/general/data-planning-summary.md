# Data Planning Session Summary

## Decisions

1. `WatchlistEntry` stores `movieId: Int`, `title: String`, `releaseYear: Int`, `voteAverage: Double`, `posterPath: String?`, and `dateAdded: Date`. Actual poster image bytes are re-fetched from network; only the path string is persisted.
2. `Review` stores `movieId: Int`, `rating: Int` (1–5), `tags: [String]`, `notes: String` (empty allowed, non-optional), `createdAt: Date`, `updatedAt: Date`.
3. `movieId` is typed as `Int` on both models, consistent with TMDB's integer id.
4. `@Attribute(.unique)` is applied to `movieId` on both `WatchlistEntry` and `Review` for store-level uniqueness enforcement.
5. Uniqueness is also guarded at the service/repo layer before insert, surfacing typed domain errors.
6. No SwiftData `@Relationship` between `WatchlistEntry` and `Review`; they are independently keyed by `movieId`.
7. `Review.tags` stored as `[String]` raw values. Tag validation (off-list prevention) is a UI/wizard concern only.
8. `Review.rating` range (1–5) is validated at the service layer; service throws a typed domain error on violation.
9. All SwiftData errors are caught and re-thrown as typed domain errors at the repo layer, decoupling callers from SwiftData internals.
10. `Movie`, `Genre`, and `CastMember` are in-memory only — plain `Codable` structs; no SwiftData `@Model` counterpart.
11. Exactly two `@Model` classes: `WatchlistEntry` and `Review`.
12. A `ModelContainer` factory/provider is used, accepting a store type parameter (`.persistent` vs `.inMemory`) for production vs. test environments.
13. All SwiftData operations run on `@MainActor` only; no background `ModelContext`.
14. Watchlist sort (by `dateAdded`, `title`, `voteAverage`) is performed in-memory after a full fetch.
15. `Review` is fetched by predicate on `movieId`; no composite indexes needed.
16. `VersionedSchema` scaffolding is set up from the start to support schema evolution during exploratory development.
17. In-memory `ModelContainer` is recreated per XCTest case (setUp/tearDown) for full test isolation.
18. Filter and sort preferences (Search and Watchlist tabs) are in-memory only; they are not persisted and reset on cold launch.

## Matched Recommendations

1. **Snapshot display fields on `WatchlistEntry`** — confirmed: `title`, `releaseYear`, `voteAverage`, `posterPath` stored locally; image bytes re-fetched from network. Matched to decision 1.
2. **Two `@Model` classes only** — `WatchlistEntry` and `Review`; all API types are plain `Codable` structs held in memory. Matched to decisions 10–11.
3. **`@Attribute(.unique)` on `movieId`** plus service-layer guard — both layers enforce uniqueness; service throws typed domain errors. Matched to decisions 4–5.
4. **`Review.tags` as `[String]`** — raw string storage; tag validation is a UI/wizard concern. Matched to decision 7.
5. **Injectable `ModelContainer` factory** — swappable between `.persistent` and `.inMemory`; keeps the plan reusable across MVVM, VIPER, and TCA variants. Matched to decision 12.
6. **No `@Relationship` between `WatchlistEntry` and `Review`** — independently keyed by `movieId`; no cascade-delete. Matched to decision 6.
7. **`updatedAt` (and `createdAt`) on `Review`** — both timestamps retained for display metadata. Matched to decision 2.
8. **In-memory sort for Watchlist** — full fetch then sort; dataset is small and bounded. Matched to decision 14.
9. **`@MainActor` only** — single main context; no background context needed for this data volume. Matched to decision 13.
10. **Typed domain errors at repo layer** — SwiftData errors wrapped into domain-specific types, decoupling all three architecture variants from persistence internals. Matched to decision 9.
11. **`notes: String` non-optional** — empty string allowed, avoids nil-handling branches across variants. Matched to decision 2.
12. **Per-test-case in-memory container** — recreated in setUp/tearDown for test-order independence. Matched to decision 17.
13. **`VersionedSchema` scaffolding from day one** — appropriate given exploratory/WIP nature of the project. Matched to decision 16.

## Summary

### a. Key Domain Entities and Attributes

**`WatchlistEntry` (`@Model`)**
- `movieId: Int` — `@Attribute(.unique)`, TMDB integer id
- `title: String`
- `releaseYear: Int`
- `voteAverage: Double`
- `posterPath: String?`
- `dateAdded: Date`

**`Review` (`@Model`)**
- `movieId: Int` — `@Attribute(.unique)`, TMDB integer id
- `rating: Int` — valid range 1–5, enforced at service layer
- `tags: [String]` — raw values from the predefined tag list
- `notes: String` — empty string allowed
- `createdAt: Date`
- `updatedAt: Date`

**`Movie` (in-memory only)**
- `id: Int`, `title: String`, `overview: String`, `releaseDate: String`, `genreIds: [Int]`, `posterPath: String?`, `voteAverage: Double`

**`Genre` (in-memory only)**
- `id: Int`, `name: String`

**`CastMember` (in-memory only)**
- `name: String`, `character: String`

### b. Domain Model Representation

- `WatchlistEntry` and `Review` are SwiftData `@Model` reference types (class-based, required by SwiftData).
- `Movie`, `Genre`, and `CastMember` are pure Swift `struct` value types conforming to `Codable` (for JSON decoding) and `Equatable`/`Hashable` as needed for UI diffing and set operations.
- No mapping layer is required between domain and persistence types for the two persisted entities, as their shape matches display needs directly.

### c. Relationships, Cardinality, and Cascade/Delete Rules

- `WatchlistEntry` and `Review` have no declared SwiftData `@Relationship`. They are independently keyed by `movieId` (foreign key by convention, not enforced by the graph).
- One `WatchlistEntry` per `movieId` (enforced by `@Attribute(.unique)` + service guard).
- One `Review` per `movieId` (enforced by `@Attribute(.unique)` + service guard).
- No cascade-delete: removing a watchlist entry does not automatically delete the associated review. Coordinated deletes are the responsibility of the service layer if ever required.

### d. Domain-to-Persistence Boundary

- The persistence boundary is clean: only `WatchlistEntry` and `Review` cross into SwiftData.
- API response types (`Movie`, `Genre`, `CastMember`) never touch the store. They are decoded, used, and discarded in memory.
- No explicit mapping/translation layer is needed; the two `@Model` types are directly usable as display models for the Watchlist tab and Movie Detail review summary.
- The repo layer owns all `ModelContext` interactions and exposes a typed, SwiftData-free interface to callers (service/use-case layer and above).

### e. Persistence Strategy

- **Technology**: SwiftData (iOS 17+).
- **On-disk**: `WatchlistEntry`, `Review`.
- **In-memory only**: all API-sourced types.
- **`ModelContainer` configuration**: a factory/provider accepts a `storeType` parameter. Production uses `.persistent`; XCTest uses `.inMemory`. The factory is shared across all three architecture variants (MVVM, VIPER, TCA), injected via SwiftUI environment or dependency injection seam per variant.
- **Actor model**: all `ModelContext` operations run on `@MainActor`. No background contexts are used.
- **Schema**: `VersionedSchema` scaffolding is established from the start. The initial version defines `WatchlistEntry` and `Review` as described above.

### f. Indexing and Fetch Performance

- `@Attribute(.unique)` on `movieId` for both models serves as an implicit index for predicate-based lookups.
- `Review` is always fetched by a single predicate on `movieId` (one-to-one lookup from Movie Detail). No composite indexes needed.
- Watchlist listing: all `WatchlistEntry` records are fetched in a single query; sorting by `dateAdded`, `title`, or `voteAverage` is performed in-memory. The dataset is bounded by the user's personal list and requires no pagination.

### g. Offline-First vs. Online-First Behavior

- **Watchlist tab**: fully offline. List membership and card display (title, year, rating, poster path) are served from SwiftData with no network dependency. Poster images are loaded from TMDB URLs when network is available but are not cached locally.
- **Catalog, Search, Movie Detail**: online-first. These screens depend on TMDB API responses; failures surface inline error states with retry affordances.
- **Reviews**: fully offline. Create, read, edit, and delete operate entirely on local SwiftData storage.
- No sync, conflict resolution, or CloudKit integration is in scope.

### h. Data Security

- No end-user credentials or sensitive personal data are stored by the app.
- TMDB API key is injected at build time via environment-backed configuration and is never persisted in SwiftData or displayed in UI.
- SwiftData uses the standard on-disk SQLite store with no additional encryption. No Keychain usage is required.
- No data classification concerns for watchlist entries or reviews (non-sensitive personal preference data).

### i. Schema Migration Approach

- `VersionedSchema` scaffolding is defined from day one, reflecting the exploratory and iterative nature of the project.
- The initial schema version (`SchemaV1`) defines `WatchlistEntry` and `Review` with the attributes above.
- Future schema versions add new `VersionedSchema` conformances and `MigrationStage` definitions as needed.
- Lightweight/automatic migration is used by default within a version; custom migration stages are added only when a breaking change requires data transformation.

## Unresolved Issues

None. All questions from both planning rounds have been answered and decisions recorded.
