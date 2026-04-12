# Feature List for Movie Tracker

## 1. MVP Features

### Catalog
- **User goal:** Browse a scrollable list of this week's trending movies so I can discover popular titles quickly.
- **Screen inventory:**
  - `CatalogListView` — root tab destination; trending movie card list with loading, error, and empty states
- **Services consumed:** `TMDBClient` (GET `/trending/movie/week`)
- **Domain entities:** `Movie`
- **Entry point:** Root tab destination (Catalog tab); selected on cold launch.
- **Directory:** `.ai/feature/catalog/`

---

### Search
- **User goal:** Find movies by text query, narrow results with genre/rating/year filters, and sort the first-page results.
- **Screen inventory:**
  - `SearchListView` — root tab destination; search input, results cards, filter badge, filter and sort triggers; pre-search prompt and zero-results empty state
  - `SearchFilterSheetView` — `.sheet` from `SearchListView`; genre multi-select, minimum rating, release year range, clear-all
  - `SearchSortSheetView` — `.sheet` from `SearchListView`; sort selection (release date / title / rating)
- **Services consumed:** `TMDBClient` (GET `/search/movie`, GET `/genre/movie/list`)
- **Domain entities:** `Movie`, `Genre`
- **Entry point:** Root tab destination (Search tab); user taps Search tab.
- **Directory:** `.ai/feature/search/`

---

### Watchlist
- **User goal:** View all locally-saved watchlist movies in one place and sort them by date added, title, or rating.
- **Screen inventory:**
  - `WatchlistListView` — root tab destination; watchlist entries card list, sort trigger, empty state
  - `WatchlistSortSheetView` — `.sheet` from `WatchlistListView`; sort selection (date added / title / rating)
- **Services consumed:** `WatchlistRepository`
- **Domain entities:** `WatchlistEntry`
- **Entry point:** Root tab destination (Watchlist tab); user taps Watchlist tab.
- **Directory:** `.ai/feature/watchlist/`

---

### MovieDetail
- **User goal:** Read rich information about a selected movie and act on watchlist membership and review state from a single detail hub.
- **Screen inventory:**
  - `MovieDetailView` — pushed onto the active tab's `NavigationStack`; poster, synopsis, genres, release date, TMDB rating, cast section (degradable), watchlist CTA, review summary or "Log a Review" CTA, delete review with confirmation dialog
- **Services consumed:** `TMDBClient` (GET `/movie/{id}`, GET `/movie/{id}/credits`), `WatchlistRepository` (membership check, add, remove), `ReviewRepository` (fetch review, delete review)
- **Domain entities:** `MovieDetail`, `WatchlistEntry`, `Review`
- **Entry point:** Push onto active tab's `NavigationStack`; user taps any movie card in Catalog, Search, or Watchlist.
- **Directory:** `.ai/feature/movie-detail/`

---

### ReviewWizard
- **User goal:** Log a personal star-rating, tag, and notes review for a movie through a guided four-step wizard, and edit or confirm deletion of an existing review.
- **Screen inventory:**
  - `ReviewWizardView` — `.fullScreenCover` from `MovieDetailView`; four-step wizard (star rating → tag selection → notes → summary/confirm); handles both create (empty) and edit (prepopulated) modes; discard before completion leaves persisted state unchanged
- **Services consumed:** `ReviewRepository` (create, overwrite/edit)
- **Domain entities:** `Review`, `ReviewTag`
- **Entry point:** `.fullScreenCover` from `MovieDetailView`; triggered by "Log a Review" (create) or "Edit Review" (edit).
- **Directory:** `.ai/feature/review-wizard/`

---

## 2. Post-MVP Features

None identified. All PRD-scoped capabilities are covered by the five MVP features above.

---

## 3. Recommended Planning Sequence

All service and framework layers are already planned. Feature planning proceeds in dependency-depth order:

1. **Catalog** — depends on `TMDBClient`; simplest feature with one screen and one endpoint.
2. **Search** — depends on `TMDBClient`; isolated in-memory filter and sort state, no cross-feature dependencies.
3. **Watchlist** — depends on `WatchlistRepository`; fully offline-first; no TMDBClient dependency.
4. **MovieDetail** — depends on `TMDBClient`, `WatchlistRepository`, `ReviewRepository`; widest service footprint; provides the entry point (`MovieDetailView`) from which `ReviewWizard` is launched.
5. **ReviewWizard** — depends on `ReviewRepository`; planned after `MovieDetail` because `MovieDetailView` is the sole entry point.

The app bootstrap contract — SPM target dependency graph, service construction order, and `@main` invariants shared across all three branches — is documented in `.ai/app-bootstrap/planning-summary.md`. Refer to this document before beginning any branch implementation.

---

## 4. PRD Coverage Check

| PRD Requirement | Feature Owner |
|---|---|
| §3.3 — Catalog tab: trending list, card display, load failure + retry | Catalog |
| §3.4 — Search tab: query input, results, filter sheet (genre/rating/year), filter badge, clear-all, sort, empty/error states | Search |
| §3.5 — Watchlist tab: list entries, sort, empty state | Watchlist |
| §3.6 — Movie Detail: poster, overview, genres, release date, rating, cast (with graceful degradation), watchlist CTA, review summary/delete CTA | MovieDetail |
| §3.7 — Review wizard: four-step flow, create, edit (prepopulated), discard rules, one-per-movie enforcement | ReviewWizard |
| §3.8 — Predefined review tag vocabulary (UI selection) | ReviewWizard |
| §3.9 — Domain model types | Covered by data model plan; consumed by features above |
| §3.10 — Tab bar root navigation, NavigationStack per tab | UI scaffolding (not a feature) |
| US-001 — Three-tab root navigation | UI scaffolding |
| US-002–US-004 — Browse trending, card content, catalog error/retry | Catalog |
| US-005 — Open detail from catalog | Catalog (source) → MovieDetail (destination) |
| US-006–US-008 — Detail content, cast, cast failure degradation | MovieDetail |
| US-009–US-011 — Add/remove watchlist, duplicate prevention | MovieDetail (CTA) + WatchlistRepository (enforcement) |
| US-012–US-014 — Watchlist tab list, empty state, sort | Watchlist |
| US-015–US-018 — Search prompt, execute search, empty results, error/retry | Search |
| US-019 — Open detail from search | Search (source) → MovieDetail (destination) |
| US-020–US-025 — Filter sheet, genre load, active filter badge, clear-all, session persistence, sort search results | Search |
| US-026 — No sort on catalog | Catalog |
| US-027–US-032 — Review wizard: create, step 1–4, discard on cancel | ReviewWizard |
| US-033 — View existing review on detail | MovieDetail |
| US-034 — Edit existing review | MovieDetail (entry) + ReviewWizard (wizard) |
| US-035 — Discard wizard on cancel (edit) | ReviewWizard |
| US-036 — Delete review with confirmation | MovieDetail |
| US-037 — Single review per movie enforcement (UI level) | MovieDetail (no duplicate CTA shown); ReviewRepository (data enforcement) |
| US-038 — No reviewed badge on list cards | Catalog, Search, Watchlist (shared `MovieCardView` has no badge) |
| US-039 — Open detail from watchlist | Watchlist (source) → MovieDetail (destination) |
| US-040 — Secure TMDB API key | TMDBClient service (not a feature concern) |
| US-041 — Non-blocking network operations | Networking framework + async service calls (not a feature concern) |

No UNCOVERED requirements.

---

## 5. Screen Assignment

| Screen | Owning Feature | Notes |
|---|---|---|
| `CatalogListView` | Catalog | Root tab destination |
| `SearchListView` | Search | Root tab destination |
| `SearchFilterSheetView` | Search | `.sheet` from `SearchListView` |
| `SearchSortSheetView` | Search | `.sheet` from `SearchListView` |
| `WatchlistListView` | Watchlist | Root tab destination |
| `WatchlistSortSheetView` | Watchlist | `.sheet` from `WatchlistListView` |
| `MovieDetailView` | MovieDetail | Pushed onto active tab's `NavigationStack` from all three tabs |
| `ReviewWizardView` | ReviewWizard | `.fullScreenCover` from `MovieDetailView` |

All 8 screens have unambiguous single-feature ownership. No screen is shared across feature boundaries at the ownership level. `MovieDetailView` is logically reached from three tabs but is instantiated within each tab's own `NavigationStack` — it belongs to MovieDetail, not to Catalog, Search, or Watchlist.

**SPM target dependency graph:**
```
CatalogFeature  ──► MovieDetailFeature ──► ReviewFeature
SearchFeature   ──►        │
WatchlistFeature ──►       │
                           └── (ReviewFeature has no further feature dependencies)
```
Each tab feature declares `MovieDetailFeature` as an explicit SPM target dependency. `MovieDetailFeature` declares `ReviewFeature`. Tab features reference `MovieDetailView` via its concrete type (`MovieDetailView(movieId:)`); `MovieDetailFeature` references `ReviewWizardView` via its concrete type.

---

## 6. Service Gap Analysis

No gaps identified. All domain capabilities required by the five features are covered by the existing service and framework plans:

| Capability Required | Feature | Covered By |
|---|---|---|
| Fetch trending movies | Catalog | `TMDBClient` |
| Search movies by text | Search | `TMDBClient` |
| Fetch genre list | Search | `TMDBClient` |
| Fetch movie detail | MovieDetail | `TMDBClient` |
| Fetch cast / credits | MovieDetail | `TMDBClient` |
| Watchlist add / remove / membership check | MovieDetail | `WatchlistRepository` |
| Watchlist fetch all entries | Watchlist | `WatchlistRepository` |
| Review fetch by movieId | MovieDetail | `ReviewRepository` |
| Review delete | MovieDetail | `ReviewRepository` |
| Review create / overwrite | ReviewWizard | `ReviewRepository` |
| ReviewTag vocabulary | ReviewWizard | `ReviewTag` enum (data model) + `ReviewRepository` (tag conversion boundary) |

---

## 7. Open Questions / Ambiguities

None. All feature boundaries are unambiguous given the PRD, data model plan, layer plan, and UI scaffolding plan. Key decisions already resolved upstream:

- **Watchlist add/remove lives in MovieDetail, not Watchlist.** The Watchlist tab is a read-only list with a sort control; it does not own mutation.
- **Review display, delete, and entry-point CTAs live in MovieDetail.** ReviewWizard owns only the wizard screens. The two features communicate through `ReviewRepository` and a data handoff at `.fullScreenCover` presentation (movieId + optional existing Review).
- **Sort and filter state are ephemeral, feature-layer concerns.** No service or persistence layer change is needed; they reset on cold launch by construction.
- **`MovieDetailView` is instantiated per-tab, not shared.** Each tab's `NavigationStack` creates its own instance; there is no cross-stack navigation.
