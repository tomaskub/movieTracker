# Search Feature Plan for Movie Tracker

## 1. Overview

The Search feature allows the user to find movies by text query against the TMDB catalogue, narrow results using combinable in-memory filters (genre, minimum rating, release year range), and reorder results by release date, title, or TMDB rating. All filtering and sorting is client-side against the first TMDB page. The feature is the root of the Search tab and navigates into the shared `MovieDetailView`.

---

## 2. Feature Scope & Responsibility Boundary

### In Scope

- `SearchListView` — search field, search trigger, results list, filter badge indicator, filter sheet trigger, sort sheet trigger.
- `SearchFilterSheetView` — genre multi-select, minimum rating toggle + stepper, from/to year text fields, clear-all, inline genre error/retry.
- `SearchSortSheetView` — sort option selection (release date / title / vote average).
- Client-side filter pipeline applied to the locally held `[Movie]` from the first TMDB page.
- Client-side sort pipeline applied after filtering.
- Three distinct empty/feedback states for the results area: idle prompt, no TMDB matches, and filters-eliminated.
- Lazy genre fetch triggered on first filter sheet open.
- Navigation to `MovieDetailView` (push, passing `movieId: Int` only).

### Explicitly Out of Scope

| Concern | Owner |
|---|---|
| `MovieDetailView` and all screens below it | MovieDetail feature |
| `MovieCardView` reusable card component | Shared UI package |
| `EmptyStateView`, `ErrorStateView` | Shared UI package |
| Poster image loading and caching | Display layer / platform image views |
| TMDB API key handling and network transport | Networking framework + build configuration |
| Filter and sort persistence across launches | Explicitly excluded by PRD |
| VoiceOver accessibility | Deferred — explicitly out of scope for MVP |

### Boundary Justification

The feature owns the full search-and-filter user journey from query entry to result selection. Client-side filtering is justified because the PRD limits results to the first TMDB page and explicitly does not permit additional network requests per filter or sort change. Genre loading is scoped to the filter sheet because the PRD specifies lazy fetch and the Catalog and Watchlist tabs do not use genres. `MovieDetailView` is a separate feature; this feature passes only `movieId: Int` across the boundary.

---

## 3. Service Dependencies

| Service | Protocol | Operations |
|---|---|---|
| `TMDBClient` | `TMDBClientProtocol` | `fetchSearch(query: String) async throws -> [Movie]` |
| `TMDBClient` | `TMDBClientProtocol` | `fetchGenres(force: Bool) async throws -> [Genre]` |

No persistence service is consumed. `WatchlistRepository` and `ReviewRepository` are not accessed by this feature.

The `TMDBClientProtocol` is the sole external dependency. The feature layer never references `HTTPClient`, `NetworkError`, or any Networking framework type directly. `TMDBError` is the error type the feature handles from service calls.

---

## 4. Screen Inventory

| Screen | Presentation Style | Purpose |
|---|---|---|
| `SearchListView` | Root of Search tab's `NavigationStack` | Search field, results list, filter badge, filter/sort triggers, navigation to movie detail |
| `SearchFilterSheetView` | `.sheet` from `SearchListView` | Genre multi-select, minimum rating toggle + stepper, year range fields, clear-all |
| `SearchSortSheetView` | `.sheet` from `SearchListView` | Sort option selection |

`SearchFilterSheetView` and `SearchSortSheetView` are independent sheets; only one can be presented at a time. Both are dismissed via a confirm path (applying the draft) or via drag-to-dismiss (discarding the draft).

---

## 5. Presentation Logic

### 5.1 `SearchListView`

**Screen state:**

| State field | Type | Description |
|---|---|---|
| `query` | `String` | Current text field content; not necessarily the last submitted query |
| `lastSubmittedQuery` | `String?` | The query that produced the current results |
| `searchState` | `SearchState` | Enum driving the results area rendering |
| `activeFilters` | `SearchFilterState` | Currently applied filter snapshot |
| `activeSort` | `SearchSortOption` | Currently applied sort; default `.releaseDate` |
| `isFilterActive` | `Bool` (derived) | `true` when any `activeFilters` field is non-default |

**`SearchState` cases:**

```
.idle
.loading(query: String)
.results(all: [Movie], filtered: [Movie])
.empty(reason: EmptyReason)   // .noMatches | .filtersEliminated
.error(TMDBError, query: String)
```

**`SearchFilterState` shape:**

```
selectedGenreIds: Set<Int>
minimumRatingEnabled: Bool
minimumRating: Int            // 1–10; only meaningful when enabled; default 5 on first toggle-on
fromYear: String              // empty = no constraint
toYear: String                // empty = no constraint
```

**`SearchSortOption` cases:** `.releaseDate` (newest first), `.title` (alphabetical ascending), `.voteAverage` (descending).

**User actions and side effects:**

| Action | Side Effect | State Transition |
|---|---|---|
| Type in search field | Updates `query` | No `searchState` change |
| Tap search button / press Return | Cancels any pending search task; calls `fetchSearch(query:)` | → `.loading(query:)` |
| `fetchSearch` succeeds | Applies `activeFilters` + `activeSort`; derives `filtered` | → `.results(all:filtered:)` or `.empty(.noMatches)` |
| `fetchSearch` fails | — | → `.error(TMDBError, query:)` |
| Tap retry (error state) | Re-calls `fetchSearch` with `lastSubmittedQuery` | → `.loading(query:)` |
| Clear search field | Updates `query` to `""` | `searchState` unchanged |
| Tap filter icon | Presents `SearchFilterSheetView` | No `searchState` change |
| Filter sheet dismissed (confirmed) | Commits draft to `activeFilters`; recomputes `filtered` from current `all` | `.results` re-derived |
| Filter sheet dismissed (drag-to-dismiss) | Draft discarded | `activeFilters` unchanged |
| Tap sort icon | Presents `SearchSortSheetView` | No `searchState` change |
| Sort sheet dismissed (confirmed) | Updates `activeSort`; recomputes `filtered` | `.results` re-derived |
| Sort sheet dismissed (drag-to-dismiss) | Draft discarded | `activeSort` unchanged |
| Tap movie card | Pushes `MovieDetailView(movieId:)` | Navigation push |

**Local business rules:**

- The search button and Return key are disabled when `query.trimmingCharacters(in: .whitespaces).isEmpty`.
- The filter trigger button is disabled while `searchState` is `.idle` or `.loading`. The DesignSystem `filter` icon is shown when inactive; the `filter-active` icon (with tint/badge) when `isFilterActive` is `true`.
- `filtered` is always derived as: `all` → apply `activeFilters` → apply `activeSort`.
- When `filtered.isEmpty` and `all.isNotEmpty`, `searchState` transitions to `.empty(.filtersEliminated)`.
- When TMDB returns an empty array, `searchState` transitions to `.empty(.noMatches)`.
- Each new search submission cancels any in-flight search task before dispatching the new one.

---

### 5.2 `SearchFilterSheetView`

**Local draft state (not committed until confirm dismiss):**

| State field | Type | Description |
|---|---|---|
| `draftFilters` | `SearchFilterState` | Copy of `activeFilters` at sheet open time |
| `genres` | `GenreLoadState` | `.loading` / `.loaded([Genre])` / `.error(TMDBError)` |
| `fromYearError` | `String?` | Inline error message for From Year field |
| `toYearError` | `String?` | Inline error message for To Year field |
| `yearRangeError` | `String?` | Cross-field error when `fromYear > toYear` |

**User actions and side effects:**

| Action | Side Effect |
|---|---|
| Sheet appears | Calls `fetchGenres(force: false)` on first open; shows loading state in genre section |
| Genre fetch succeeds | `genres` → `.loaded([Genre])` |
| Genre fetch fails | `genres` → `.error(TMDBError)`; shows inline error + retry |
| Tap genre retry | Calls `fetchGenres(force: true)`; `genres` → `.loading` |
| Toggle genre item | Updates `draftFilters.selectedGenreIds` |
| Toggle minimum rating on | `draftFilters.minimumRatingEnabled = true`; stepper appears at default value (5) |
| Toggle minimum rating off | `draftFilters.minimumRatingEnabled = false`; stepper hidden |
| Stepper +/− | Updates `draftFilters.minimumRating` (clamped 1–10) |
| Type in From Year | Updates `draftFilters.fromYear`; validates on change |
| Type in To Year | Updates `draftFilters.toYear`; validates on change |
| Tap "Clear All Filters" | Resets `draftFilters` to all-empty defaults; clears all validation errors |
| Confirm dismiss | Commits `draftFilters` to `activeFilters` in parent |
| Drag-to-dismiss | Discards `draftFilters`; `activeFilters` unchanged |

**Year validation (fires on change):**

- Non-numeric input is blocked by `.numberPad` keyboard.
- Value < 1900 or > current calendar year: red border + inline error on the affected field.
- Both fields valid and `fromYear > toYear`: cross-field inline error with red border on both fields.
- "Clear All Filters" also clears all year errors.

---

### 5.3 `SearchSortSheetView`

**Local draft state:** `draftSort: SearchSortOption` — copy of `activeSort` at open time.

**Sort options:** `.releaseDate` (newest first, default), `.title` (A–Z), `.voteAverage` (highest first).

**Dismiss (confirmed):** commits `draftSort` to `activeSort` in parent; parent recomputes `filtered`.  
**Drag-to-dismiss:** discards `draftSort`; `activeSort` unchanged.

---

## 6. Navigation & Routing

**Entry point:** `SearchListView` is the root destination of the Search tab's `NavigationStack`. The tab is reached by tapping the Search tab item in the root `TabView`.

**Internal navigation graph:**

```
SearchListView  ──.sheet──►  SearchFilterSheetView
                ──.sheet──►  SearchSortSheetView
                ──push──►    MovieDetailView(movieId: Int)
```

**Navigation triggers:**

| Trigger | Navigation action | Data passed |
|---|---|---|
| Tap filter icon | Present `SearchFilterSheetView` as `.sheet` | `activeFilters` (draft copy created in sheet) |
| Tap sort icon | Present `SearchSortSheetView` as `.sheet` | `activeSort` (draft copy created in sheet) |
| Tap movie card | Push `MovieDetailView` onto Search tab's `NavigationStack` | `movieId: Int` |
| Filter sheet confirm dismiss | Sheet removed; `activeFilters` updated | — |
| Sort sheet confirm dismiss | Sheet removed; `activeSort` updated | — |
| Back from `MovieDetailView` | Pop; `SearchListView` returns to its current state | — |

No deep link entry points. No external navigation triggers. Tab-switching preserves the current `NavigationStack` path within the Search tab for the session.

---

## 7. State Management

### Ownership and Lifetime

| State | Owner | Lifetime | Initial value |
|---|---|---|---|
| `query` | `SearchListView` | Session (tab lifetime) | `""` |
| `lastSubmittedQuery` | `SearchListView` | Session | `nil` |
| `searchState` | `SearchListView` | Session | `.idle` |
| `activeFilters` | `SearchListView` | Session (in-memory only) | All-empty defaults |
| `activeSort` | `SearchListView` | Session (in-memory only) | `.releaseDate` |
| `draftFilters` | `SearchFilterSheetView` | Sheet lifetime | Copied from `activeFilters` at presentation |
| `draftSort` | `SearchSortSheetView` | Sheet lifetime | Copied from `activeSort` at presentation |
| `genres` (`GenreLoadState`) | `SearchFilterSheetView` | Sheet lifetime | `.loading` on first open |

### Initialization and Cleanup

- All `SearchListView` state is initialized at first tab presentation and lives for the duration of the process. Cold launch always starts in the `.idle` state with empty filters and default sort.
- `SearchFilterSheetView` and `SearchSortSheetView` initialize their draft state from the parent's current values each time the sheet is presented. Draft state is discarded on drag-to-dismiss without side effects to the parent.
- Genre fetch state is local to the filter sheet and is reset each time the sheet is presented anew.

### Concurrent Update Safety

- Each new search submission cancels any in-flight `fetchSearch` task (via `Task` cancellation) before creating a new one. Results arriving after cancellation are discarded.
- Genre fetch inside the filter sheet is independent and does not affect `searchState`. A genre fetch failure never transitions `searchState`.
- Tab switches (foreground/background transitions) do not cancel in-flight requests; results are applied to the screen state when the task completes and the view is still live.

---

## 8. User Interactions & Form Validation

| Field / control | Validation rule | Timing | Error surface |
|---|---|---|---|
| Search field (submit) | Must not be empty or whitespace-only | On submit attempt | Search button and Return key remain disabled; no inline message required |
| From Year text field | Integer 1900 – current year | On change | Red border + inline error message below field |
| To Year text field | Integer 1900 – current year | On change | Red border + inline error message below field |
| Year cross-field | `fromYear ≤ toYear` when both are valid | On change (either field) | Red border on both fields + inline cross-field error message |
| Minimum rating stepper | Clamped 1–10; stepper enforces range | N/A | None required |
| Minimum rating toggle | On → stepper visible; Off → stepper hidden | Immediate | None |
| Genre multi-select | No validation; any combination is valid | N/A | None |
| "Clear All Filters" | Resets all draft filter fields to defaults and clears all validation errors | On tap | Errors cleared immediately |

No confirmation dialogs exist within the Search feature. There are no destructive actions in Search.

---

## 9. Loading, Empty, and Error States

### `SearchListView` Results Area

| State | Display |
|---|---|
| `.idle` | `EmptyStateView` with "Search for a movie" prompt |
| `.loading` | Shared loading indicator component in results area; search field and filter/sort triggers remain accessible |
| `.results(all:filtered:)` where `filtered` is non-empty | `List` / `ScrollView` of `MovieCardView` rows using `.thumbnail` poster size; `.scrollDismissesKeyboard(.immediately)` applied |
| `.empty(.noMatches)` | `EmptyStateView` — "No movies found for [query]"; no retry affordance |
| `.empty(.filtersEliminated)` | `EmptyStateView` — "No results match your active filters" + inline "Clear Filters" shortcut that resets `activeFilters` to defaults and recomputes `filtered` |
| `.error(TMDBError, query:)` | `ErrorStateView` — inline error message + retry button that re-issues `fetchSearch` with `lastSubmittedQuery` |

No optimistic updates. No skeleton placeholders. Loading state is represented by a single loading indicator; there is no row-level shimmer required.

### `SearchFilterSheetView` Genre Section

| State | Display |
|---|---|
| `.loading` | Shared loading indicator within the genre section |
| `.loaded([Genre])` | Multi-select list of genre names |
| `.error(TMDBError)` | `ErrorStateView` inline in genre section + "Retry" button; rest of the sheet (rating, year, clear-all) remains functional |

Genre failure is fully isolated from the search results area. `searchState` is unaffected by genre fetch outcomes.

---

## 10. SwiftUI Previews Strategy

Previews use inline static mock data. The view layer does not access `TMDBClientProtocol` directly in any architectural variant — the presentation object (ViewModel / Presenter / Store) is the dependency boundary. Each preview instantiates the view with a pre-configured presentation object or static state value representing a specific screen state.

| Screen | Preview states |
|---|---|
| `SearchListView` | One preview per `SearchState` case: `.idle`, `.loading`, `.results` (with multiple cards), `.empty(.noMatches)`, `.empty(.filtersEliminated)`, `.error` |
| `SearchFilterSheetView` | Genre `.loading`, genre `.loaded([Genre])` with some genres selected, genre `.error`; a preview with active rating filter and year range to verify validation error display |
| `SearchSortSheetView` | Single preview showing all three sort options with one selected |

All data is inline static `Movie`, `Genre`, and `SearchFilterState` struct literals. No shared mock client is required. No hardware or system dependencies need substitution.

---

## 11. iOS-Specific UI Concerns

| Concern | Decision |
|---|---|
| Keyboard dismissal on scroll | `.scrollDismissesKeyboard(.immediately)` applied to the results `ScrollView` / `List` |
| Search field keyboard type | Default text keyboard; Return key triggers search submission |
| Year text fields keyboard type | `.numberPad`; no Return key; validation fires on-change |
| Filter badge / icon | DesignSystem `filter` icon when inactive; `filter-active` icon (tinted) when `isFilterActive == true` |
| Haptic feedback | Not specified; not required for MVP |
| Deep links | Not in scope |
| Share sheet | Not in scope |
| Widgets / Live Activities | Not in scope |
| App lifecycle (foreground/background) | In-flight `fetchSearch` and `fetchGenres` tasks are allowed to complete; no special foreground/background handling is needed |
| Tab-switch state preservation | `query`, `searchState`, `activeFilters`, and `activeSort` are all retained across tab switches for the session |

---

## 12. Accessibility

VoiceOver labels and hints, Dynamic Type layout adaptations, and Reduce Motion alternatives are **explicitly out of scope for MVP** for the Search feature. All three areas are deferred to a later iteration.

---

## 13. Analytics & Tracked Events

No analytics events are defined in the PRD for the Search feature. No events are emitted.

---

## 14. Testing Strategy

### Presentation Logic Unit Tests

| Unit | Test scenarios |
|---|---|
| Client-side filter pipeline | Given `[Movie]` + `SearchFilterState`, assert correct `filtered` output for: genre filter (single, multiple, no match), minimum rating enabled/disabled and threshold, year `fromYear` constraint, year `toYear` constraint, combined filters, filter with empty result |
| Client-side sort | Assert correct ordering for `.releaseDate` (newest first), `.title` (A–Z), `.voteAverage` (highest first); verify sort is applied after filter |
| `isActive` derivation | Active when any filter field is non-default; inactive when all fields are cleared |
| Year validation | Boundary values: 1899 (rejected), 1900 (accepted), current year (accepted), current year + 1 (rejected); cross-field: `from > to` (error on both), `from == to` (valid), `from < to` (valid); clearing fields removes errors |
| State transitions | New search submission cancels in-flight task; genre failure does not affect `searchState`; filters-eliminated state is produced when `filtered.isEmpty` and `all.isNotEmpty`; `.noMatches` when TMDB returns empty array |

### Service Interaction Tests (using mock `TMDBClientProtocol`)

| Scenario |
|---|
| `fetchSearch(query:)` is called with the exact submitted query on each explicit search trigger |
| `fetchGenres(force: false)` is called when the filter sheet first opens |
| `fetchGenres(force: true)` is called when the user taps the genre retry button |
| No `fetchSearch` call is triggered by filter or sort changes |
| A new search submission cancels the previous in-flight search and issues the new query |

### UI Test Coverage

| Flow |
|---|
| Submit a query → results list is displayed |
| Submit a query → open filter sheet → apply genre filter → dismiss → results list reflects filter |
| Submit a query → open sort sheet → change sort → dismiss → list order changes |
| Filter sheet drag-to-dismiss → active filters are unchanged |
| Submit a query → error state is displayed → tap retry → loading state is shown |

---

## 15. Platform & OS Constraints

- **Minimum deployment target**: iOS 17. All APIs used (`URLSession` with async/await, `SwiftUI`, `Stepper`, `.scrollDismissesKeyboard`, `.sheet`) are available across the full supported range.
- **Swift version**: Swift 5.9+; structured concurrency (`async`/`await`, `Task`, `Task.cancel()`) is available.
- **No special entitlements required**: outbound HTTPS to TMDB needs no capability.
- **No background execution**: all requests run in the foreground `URLSession` provided by the Networking framework.
- **Privacy manifest**: no tracking-level data is collected; no additional `PrivacyInfo.xcprivacy` entries beyond local file access are required for this feature.
- **DesignSystem dependency**: filter icon variants (`filter`, `filter-active`) and all typography/spacing tokens must be sourced from the shared DesignSystem package.

---

## 16. Deferred / Out of Scope for MVP

| Item | Rationale |
|---|---|
| VoiceOver labels and hints | Explicitly out of scope for MVP per planning session decision |
| Dynamic Type layout adaptations | Not specified; deferred |
| Reduce Motion alternatives | Not specified; deferred |
| Analytics event tracking | Not defined in PRD |
| Pagination beyond first TMDB page | Explicitly excluded by PRD |
| Persisting filter and sort preferences across launches | Explicitly excluded by PRD |
| Poster image caching | Not required by PRD; handled at display layer |
| Sending filter parameters to TMDB API | PRD scopes to first page only; client-side filtering is the specified approach |
| Debounce / live search | Explicit submit model chosen in planning; no debounce required |

---

## 17. Open Questions / Unresolved Decisions

None. All planning questions from both Q&A rounds have been resolved. All decisions are recorded in `.ai/feature/search/feature-planning-session-summary.md`.
