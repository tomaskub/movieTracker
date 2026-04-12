# Framework and Service Layer Plan for Movie Tracker

## 1. Framework Layers

### Networking
- **Responsibility:** Generic HTTP transport that dispatches URLSession requests with async/await, decodes JSON responses into `Decodable` types, and normalises transport and HTTP errors into a typed error domain.
- **Rationale:** URL request construction, response decoding, and error normalisation are repeated across every TMDB call. Wrapping URLSession behind a generic interface prevents any service or feature from depending directly on URLSession internals and keeps the concern testable in isolation via protocol substitution.
- **Platform APIs / SDKs:** `URLSession`, `JSONDecoder`, `URLRequest`, `HTTPURLResponse`.
- **Consumers:** `TMDBClient` (primary consumer); all other services with future network needs.
- **Directory:** `.ai/framework/networking/`

### Persistence
- **Responsibility:** SwiftData container lifecycle management — constructs and vends the shared `ModelContainer` for `WatchlistEntry` and `Review` with configurable store type (on-disk for production, in-memory for tests).
- **Rationale:** `ModelContainerProvider` is pure infrastructure: it wraps SwiftData's container initialisation, versioned schema registration, and migration plan attachment with no knowledge of which domain types are stored or what business rules govern them. Multiple repository services share the same container instance.
- **Platform APIs / SDKs:** `SwiftData` (`ModelContainer`, `ModelContext`, `VersionedSchema`, `SchemaMigrationPlan`).
- **Consumers:** `WatchlistRepository`, `ReviewRepository`.
- **Directory:** `.ai/framework/persistence/`

### DesignSystem
- **Responsibility:** Provides the complete set of shared UI design tokens — fonts, colors, icons, spacing, padding, shadows, and corner radii — as a Swift package consumed by all three architectural implementations.
- **Rationale:** Already exists as a shared package per the tech stack. Codifying it here ensures it is planned and documented in dependency order before any feature UI work begins. It contains no business logic and no domain entity knowledge.
- **Platform APIs / SDKs:** SwiftUI, Swift Package Manager.
- **Consumers:** All feature layers across MVVM, VIPER, and TCA implementations.
- **Directory:** `.ai/framework/design-system/`

---

## 2. Service Layers

### TMDBClient
- **Responsibility:** Owns all TMDB API interactions — constructs authenticated requests for each endpoint, dispatches them via the Networking framework, and maps decoded payloads to the typed domain entities `Movie`, `Genre`, `CastMember`, and `MovieDetail`.
- **Rationale:** TMDB-specific request construction (base URL assembly, API key injection, endpoint paths, query parameter encoding) and response-to-domain mapping are shared across Catalog, Search, and Movie Detail features. Composing `MovieDetail` from a parallel `/movie/{id}` + `/movie/{id}/credits` dispatch is domain business logic that must not leak into feature-layer view models, presenters, or reducers. A service boundary also makes TMDB interactions fully testable via a protocol mock.
- **Frameworks consumed:** `Networking`.
- **Domain entities:** `Movie`, `Genre`, `CastMember`, `MovieDetail`.
- **Directory:** `.ai/service/tmdb-client/`

### WatchlistRepository
- **Responsibility:** Owns all SwiftData CRUD operations for `WatchlistEntry` — insert with duplicate guard, full-set fetch, and delete by `movieId` — exposing a SwiftData-free protocol interface with typed domain errors.
- **Rationale:** Watchlist operations are shared across Movie Detail (add/remove CTA, membership check) and the Watchlist tab (list and sort source). Centralising `ModelContext` interactions here keeps all three architectural branches free of SwiftData imports and makes persistence logic independently testable with an in-memory container.
- **Frameworks consumed:** `Persistence`.
- **Domain entities:** `WatchlistEntry`.
- **Directory:** `.ai/service/watchlist-repository/`

### ReviewRepository
- **Responsibility:** Owns all SwiftData CRUD operations for `Review` — create, fetch by `movieId`, overwrite (edit), and delete — enforcing the one-review-per-movie invariant and performing `[String]`↔`[ReviewTag]` conversion at the persistence boundary.
- **Rationale:** Review operations are shared across Movie Detail (summary display, delete with confirmation, edit/create CTA state) and the Review Wizard (save on step-4 confirm, pre-population for edit mode). Centralising uniqueness enforcement and the tag-conversion logic here keeps all three architectural branches decoupled from SwiftData and makes the boundary testable in isolation.
- **Frameworks consumed:** `Persistence`.
- **Domain entities:** `Review`, `ReviewTag`.
- **Directory:** `.ai/service/review-repository/`

---

## 3. Recommended Planning Sequence

1. **DesignSystem** (framework) — no dependencies; required before any UI feature work begins. Already exists as a package; verify scope and document the plan.
2. **Networking** (framework) — no dependencies; required before `TMDBClient`.
3. **Persistence** (framework) — no dependencies; required before `WatchlistRepository` and `ReviewRepository`.
4. **TMDBClient** (service) — depends on `Networking`.
5. **WatchlistRepository** (service) — depends on `Persistence`.
6. **ReviewRepository** (service) — depends on `Persistence`.

Feature planning sessions may begin after steps 1–6 are complete, as all features depend on at least one of the services above.

---

## 4. PRD Coverage Check

| PRD Section / Requirement | Covered By |
|---|---|
| §3.1 — SwiftData persistence for watchlist and reviews | `Persistence` (framework), `WatchlistRepository`, `ReviewRepository` |
| §3.2 — TMDB API key, auth, error handling, non-blocking requests | `Networking` (transport + async/await), `TMDBClient` (key injection, error surface) |
| §3.2 — GET `/trending/movie/week` | `TMDBClient` |
| §3.2 — GET `/movie/{id}` | `TMDBClient` |
| §3.2 — GET `/movie/{id}/credits` | `TMDBClient` |
| §3.2 — GET `/search/movie` | `TMDBClient` |
| §3.2 — GET `/genre/movie/list` | `TMDBClient` |
| §3.3 — Catalog tab (load trending, card data) | `TMDBClient` |
| §3.4 — Search tab (search, genre filter, sort) | `TMDBClient` (network); sort/filter state is feature-layer ephemeral |
| §3.5 — Watchlist tab (list entries, sort) | `WatchlistRepository`; sort is feature-layer ephemeral |
| §3.6 — Movie Detail (primary payload, cast, watchlist CTA) | `TMDBClient`, `WatchlistRepository`, `ReviewRepository` |
| §3.6 — Cast section graceful degradation | `TMDBClient` (non-fatal credits failure exposed via domain result type) |
| §3.7 — Review wizard create/edit/discard/confirm | `ReviewRepository` |
| §3.7 — One review per movie enforcement | `ReviewRepository` |
| §3.8 — Predefined review tag vocabulary | `ReviewTag` enum (data layer, already defined); conversion at `ReviewRepository` boundary |
| §3.9 — Domain model types | Defined in data plan; decoded/owned by `TMDBClient` (API types) and repositories (persisted types) |
| §3.10 — Navigation (tab bar, detail push) | **Feature-layer / UI scaffolding concern** — no service or framework required |
| Non-functional: non-blocking UI | `Networking` (async/await dispatch); all service calls are async |
| Non-functional: DesignSystem tokens in all UI | `DesignSystem` (framework) |
| US-040 — API key not exposed in UI | `TMDBClient` (reads key from build-time config at initialisation; never passes it to presentation layer) |

No uncovered requirements identified.

---

## 5. Feature-Layer Candidates (Flagged Items)

### API Key Configuration
- **Classification:** Trivially thin infrastructure — a single `Bundle.main.infoDictionary` or `ProcessInfo` read with no transformation or reuse across multiple independently testable modules.
- **Decision:** The key is read once inside `TMDBClient`'s initialiser or a static constant scoped to that service module. No standalone `AppConfiguration` framework is warranted; the two-line read does not justify its own planning session.
- **Owning layer:** `TMDBClient` service.

### In-Memory Sort State (Watchlist and Search)
- **Classification:** Ephemeral UI preference, process-scoped, with no persistence and no sharing across features.
- **Decision:** Belongs entirely in the view model / presenter / store of each feature variant. Resetting to defaults on cold launch is a natural consequence of not persisting it.
- **Owning layer:** Catalog, Search, and Watchlist feature layers (per architectural variant).

### In-Memory Filter State (Search)
- **Classification:** Same as sort state — ephemeral, process-scoped, no cross-feature sharing.
- **Decision:** Feature-layer concern in the Search feature.
- **Owning layer:** Search feature layer.

### Navigation Structure (Tab Bar, Detail Push)
- **Classification:** UI scaffolding — tab bar root, NavigationStack/modal presentation — with no business logic.
- **Decision:** Belongs in the UI scaffolding plan and the feature layer of each variant. Not a framework or service concern.
- **Owning layer:** UI scaffolding / feature layers.

---

## 6. Open Questions / Ambiguities

### Q1 — DesignSystem planning scope ✅ Resolved
The `DesignSystem` package already exists and is complete. No full planning session is required — a documentation pass to record its API surface is sufficient.

### Q2 — `TMDBClient` API key injection mechanism ✅ Resolved
The API key is injected into `TMDBClient` via dependency injection. `TMDBClient` receives the key as a constructor parameter; the call site (composition root for each architectural variant) is responsible for reading the value from the build-time `.xcconfig`-backed configuration and passing it in. The service module itself has no dependency on `Bundle` or `ProcessInfo`.

### Q3 — `ModelContext` access pattern in repositories ✅ Resolved
Both `WatchlistRepository` and `ReviewRepository` receive their `ModelContext` via dependency injection (constructor injection). The `Persistence` framework's `ModelContainerProvider` is responsible for constructing the `ModelContainer`; the composition root derives a `ModelContext` from it and injects it into each repository. No repository accesses the SwiftUI environment directly.
