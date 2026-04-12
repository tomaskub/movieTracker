# Search Feature — Planning Session Summary

## Decisions

1. Pre-search idle state is rendered using the shared `EmptyStateView` component.
2. Search is triggered explicitly — by pressing Return on the keyboard or tapping a dedicated button placed next to the search field. No on-the-fly searching.
3. When the search field is cleared after results are displayed, results remain visible until the next explicit search is triggered.
4. `/genre/movie/list` is fetched lazily — only when the filter sheet is first opened.
5. Genre fetch failure is surfaced as an inline error with a retry button inside the filter sheet. Tapping retry shows a loading state within the sheet.
6. Filter changes are applied when the sheet is dismissed without cancellation (drag-to-dismiss = cancel = changes discarded). No intermediate re-filter or re-fetch occurs while the sheet is open.
7. Filtering is applied client-side on the first-page `[Movie]` results returned by `/search/movie`. No filter parameters are sent to TMDB.
8. The filter trigger button is disabled before any search results have been loaded.
9. The filter button uses DesignSystem icons: `filter` (inactive) and `filter-active` (when at least one filter is applied).
10. Sort is exposed as a separate `.sheet` (`SearchSortSheetView`).
11. Sort sheet follows the same dismiss behaviour as the filter sheet: drag-to-dismiss discards pending sort changes; the previously applied sort is preserved.
12. Retry actions are independent: search retry re-issues the last query; genre retry re-fetches only genres. Each has its own affordance in its respective area.
13. Three distinct empty/feedback states are required for the results area: idle (no search yet), no TMDB results, and results-eliminated-by-filters.
14. Only the TMDB `movieId: Int` is passed when pushing `MovieDetailView`.
15. `.thumbnail` `PosterSize` is used for search result cards.
16. Tab-switch state is preserved for the session: query text, results, active filters, and sort are all retained. In-flight requests are allowed to complete.
17. VoiceOver accessibility is explicitly out of scope for this feature.
18. Minimum rating control is a `Stepper` with whole-number steps (1–10). It is gated behind a toggle/checkbox; the stepper is only visible when the toggle is enabled. "No filter" = toggle off.
19. Release year range uses two separate text fields (From / To). Empty fields mean no filter applied. Valid range is 1900 to the current year. Keyboard type is `.numberPad`. Validation fires as soon as possible (on change), not on dismiss.
20. Out-of-range year values (e.g., < 1900 or > current year) are rejected with a red border and inline error message.
21. If "from" year > "to" year, an inline error with red border is surfaced on both fields.
22. Filter sheet drag-to-dismiss = cancel = discard pending filter changes (same pattern as sort sheet).
23. SwiftUI Previews use inline static mock data per state. No `MockTMDBClient` is needed; views do not access the client directly in any architecture.

## Matched Recommendations

1. **Client-side filtering confirmed** — filters and sort are applied on the locally held `[Movie]` array from the first TMDB page. Sort is applied after filtering. No additional network requests are triggered by filter or sort changes.
2. **Explicit submit instead of debounce** — aligns with decision 2; no debounce timer is needed.
3. **Separate genre fetch lifecycle** — genre failure is isolated; it never blocks the search results area. Two independent loading/error states exist on the screen.
4. **Single enum state machine for search results area** — recommended states: `.idle`, `.loading(query:)`, `.results([Movie], filtered: [Movie])`, `.empty(reason:)` (with `.noMatches` and `.filtersEliminated` reasons), `.error(TMDBError, query: String)`.
5. **`SearchFilterState` struct with derived `isActive`** — holds `selectedGenreIds: Set<Int>`, `minimumRatingEnabled: Bool`, `minimumRating: Int` (1–10, only meaningful when enabled), `fromYear: String`, `toYear: String`. `isActive` computed from any non-default value.
6. **Sort applied after client-side filter** — pipeline: fetch → filter → sort → display.
7. **Eager genre pre-fetch — REJECTED** — replaced by lazy fetch on filter sheet first open (decision 4).
8. **Filter sheet uses local draft state; applied on confirm dismiss** — the sheet maintains an in-progress copy of `SearchFilterState`; it is committed to the feature's session state only when dismissed without cancellation.
9. **Sort client-side with no re-fetch** — changing sort order reorders the current filtered `[Movie]` array instantly with no network call.
10. **Pass full `Movie` struct to `MovieDetailView` — REJECTED** — only `movieId: Int` is passed (decision 14).
11. **Three distinct empty states** — idle prompt (`EmptyStateView`), no TMDB results (`EmptyStateView`, no retry), filters eliminated results (`EmptyStateView` with a clear-filters shortcut).
12. **`.thumbnail` PosterSize** — confirmed for search result cards.
13. **Filter trigger disabled before first search** — confirmed (decision 8).
14. **`MockTMDBClient` — REJECTED** — previews use inline static data per state; no shared mock client (decision 23).
15. **Scroll dismisses keyboard** — `.scrollDismissesKeyboard(.immediately)` applied to the results list so scrolling hides the keyboard.

## Summary

### a. Feature Scope and Responsibility Boundary

**In scope:**
- `SearchListView` — search field, search trigger, results list, filter badge indicator, filter sheet trigger, sort sheet trigger.
- `SearchFilterSheetView` — genre multi-select, minimum rating toggle + stepper, from/to year text fields, clear-all, inline genre error/retry.
- `SearchSortSheetView` — sort option selection (release date / title / vote average).
- Navigation to `MovieDetailView` (push, passing `movieId: Int`).

**Explicitly out of scope / delegated:**
- `MovieDetailView` and everything below it — owned by the MovieDetail feature.
- `MovieCardView` — shared UI package component, consumed as-is.
- `EmptyStateView`, `ErrorStateView` — shared UI package components, consumed as-is.
- Poster image loading/caching — handled at the card view level.
- TMDB API key handling — Networking framework and build configuration.
- Filter/sort persistence across launches — explicitly not persisted; in-memory only.
- VoiceOver accessibility — deferred.

---

### b. Service Dependencies

| Service | Protocol | Operations Used |
|---|---|---|
| `TMDBClient` | `TMDBClientProtocol` | `fetchSearch(query: String) async throws -> [Movie]` |
| `TMDBClient` | `TMDBClientProtocol` | `fetchGenres(force: Bool) async throws -> [Genre]` |

No persistence service is consumed by the Search feature. No `WatchlistRepository` or `ReviewRepository` is accessed. `TMDBClient` is the only service dependency.

---

### c. Presentation Logic Per Screen

#### `SearchListView`

**Screen state:**
- `query: String` — current text field content (not necessarily the last submitted query)
- `lastSubmittedQuery: String?` — the query that produced the current results
- `searchState: SearchState` — enum:
  - `.idle` — no query has been submitted yet
  - `.loading(query: String)` — search request in flight
  - `.results(all: [Movie], filtered: [Movie])` — results received; `filtered` is the client-side filtered+sorted subset
  - `.empty(reason: EmptyReason)` — `.noMatches` or `.filtersEliminated`
  - `.error(TMDBError, query: String)` — search request failed
- `activeFilters: SearchFilterState` — currently applied filter snapshot
- `activeSort: SearchSortOption` — currently applied sort (default: `.releaseDate`)
- `isFilterActive: Bool` — derived from `activeFilters`

**User actions and side effects:**

| Action | Side Effect | State Transition |
|---|---|---|
| Type in search field | Updates `query`; no search triggered | No state change to `searchState` |
| Tap search button or press Return | Calls `fetchSearch(query:)` | → `.loading(query:)` |
| `fetchSearch` succeeds | Applies active filters + sort to results | → `.results(all:filtered:)` or `.empty(.noMatches)` |
| `fetchSearch` fails | — | → `.error(tmdbError, query:)` |
| Tap retry (error state) | Re-calls `fetchSearch` with `lastSubmittedQuery` | → `.loading(query:)` |
| Tap filter icon | Presents `SearchFilterSheetView` as `.sheet` | No state change; sheet opened |
| Filter sheet dismissed (confirmed) | Applies draft filters to `activeFilters`; recomputes `filtered` | `.results` re-derived with new filter |
| Filter sheet dismissed (cancelled) | Draft discarded | `activeFilters` unchanged |
| Tap sort icon | Presents `SearchSortSheetView` as `.sheet` | No state change; sheet opened |
| Sort sheet dismissed (confirmed) | Updates `activeSort`; recomputes `filtered` | `.results` re-derived with new sort |
| Sort sheet dismissed (cancelled) | Draft discarded | `activeSort` unchanged |
| Tap movie card | Pushes `MovieDetailView(movieId:)` | Navigation push |
| Clear search field | Updates `query` to `""` | `searchState` unchanged (results stay) |

**Local business rules:**
- The search button and Return key are disabled when `query.trimmingCharacters(in: .whitespaces).isEmpty`.
- Filter trigger is disabled when `searchState == .idle` or `.loading`.
- `filtered` is always derived as: `all` → apply `activeFilters` → apply `activeSort`.
- When `filtered.isEmpty` and `all.isNotEmpty`, state is `.empty(.filtersEliminated)`.
- When TMDB returns an empty array, state is `.empty(.noMatches)`.

#### `SearchFilterSheetView`

**Screen state (local draft, not committed until confirm dismiss):**
- `draftFilters: SearchFilterState` — copy of `activeFilters` at sheet open time
- `genres: GenreLoadState` — enum: `.loading`, `.loaded([Genre])`, `.error(TMDBError)`
- `SearchFilterState`:
  - `selectedGenreIds: Set<Int>`
  - `minimumRatingEnabled: Bool`
  - `minimumRating: Int` (1–10, default 5 when toggle is first enabled)
  - `fromYear: String` (empty = no constraint)
  - `toYear: String` (empty = no constraint)
- `fromYearError: String?` — inline error message
- `toYearError: String?` — inline error message
- `yearRangeError: String?` — cross-field error when from > to

**User actions and side effects:**

| Action | Side Effect |
|---|---|
| Sheet appears | Calls `fetchGenres(force: false)` if not yet loaded; shows loading state in genre section |
| Genre fetch succeeds | `genres` → `.loaded([Genre])`; renders multi-select |
| Genre fetch fails | `genres` → `.error(TMDBError)`; renders inline error + retry button |
| Tap genre retry | Calls `fetchGenres(force: true)`; `genres` → `.loading` |
| Toggle minimum rating on | `minimumRatingEnabled = true`; stepper appears at default value |
| Toggle minimum rating off | `minimumRatingEnabled = false`; stepper hidden; rating not applied |
| Stepper +/− | Updates `draftFilters.minimumRating` (clamped 1–10) |
| Type in From Year | Updates `draftFilters.fromYear`; validates on change |
| Type in To Year | Updates `draftFilters.toYear`; validates on change |
| Tap "Clear All Filters" | Resets `draftFilters` to all-empty defaults; clears all errors |
| Dismiss without cancel (confirm) | Commits `draftFilters` to `activeFilters` in parent |
| Drag to dismiss (cancel) | Discards `draftFilters`; `activeFilters` unchanged |

**Year validation on change (fires immediately):**
- Non-numeric input is blocked by `.numberPad` keyboard.
- If value < 1900 or > current year: red border + inline error message.
- If `fromYear` and `toYear` are both valid and `from > to`: cross-field inline error with red border on both fields.

#### `SearchSortSheetView`

**Local draft state:** `draftSort: SearchSortOption` — copy of `activeSort` at open time.

**Sort options:** `.releaseDate` (default, newest first), `.title` (alphabetical), `.voteAverage` (descending).

**Dismiss (confirmed):** commits `draftSort` to `activeSort` in parent. **Drag-to-dismiss (cancel):** discards `draftSort`.

---

### d. State Shape and Ownership

| State | Scope | Lifetime | Initialization |
|---|---|---|---|
| `query` | Local to `SearchListView` | Session (tab lifetime) | Empty string on cold launch |
| `lastSubmittedQuery` | Local to `SearchListView` | Session | `nil` on cold launch |
| `searchState` | Local to `SearchListView` | Session | `.idle` on cold launch |
| `activeFilters` | Local to `SearchListView`, passed to filter sheet | Session (in-memory only, reset on cold launch) | All-empty defaults on cold launch |
| `activeSort` | Local to `SearchListView`, passed to sort sheet | Session (in-memory only, reset on cold launch) | `.releaseDate` on cold launch |
| `draftFilters` | Local to `SearchFilterSheetView` | Sheet lifetime | Copied from `activeFilters` at sheet open |
| `draftSort` | Local to `SearchSortSheetView` | Sheet lifetime | Copied from `activeSort` at sheet open |
| `genres` (GenreLoadState) | Local to `SearchFilterSheetView` | Sheet lifetime (re-fetched on re-open if not cached) | `.loading` on first sheet open |

**Concurrency:** In-flight `fetchSearch` tasks that complete after a newer search is triggered must be discarded. Each new search cancels any pending search task. Genre fetch inside the filter sheet is independent and does not affect `searchState`. Tab switches do not cancel in-flight requests; results are applied when the task completes.

---

### e. Navigation and Routing

**Entry point:** `SearchListView` is the root of the Search tab's `NavigationStack`. Selected via tab bar tap.

**Internal graph:**
- `SearchListView` → `.sheet` → `SearchFilterSheetView`
- `SearchListView` → `.sheet` → `SearchSortSheetView`
- `SearchListView` → push → `MovieDetailView(movieId:)`

**Navigation triggers:**
- Movie card tap → push `MovieDetailView` with `movieId: Int`
- Filter icon tap → present `SearchFilterSheetView`
- Sort icon tap → present `SearchSortSheetView`
- Filter/sort sheet dismiss → sheet removed; results recomputed if confirmed

No deep link entry points. No external navigation triggers. No back-navigation concerns within the Search feature itself (back from `MovieDetailView` is handled by the `NavigationStack`).

---

### f. User Interactions and Form Validation

| Field | Validation Rule | Timing | Error Surface |
|---|---|---|---|
| Search field (submit) | Must not be empty or whitespace-only | On submit attempt | Search button remains disabled; no inline error needed |
| From Year text field | Must be integer 1900–current year | On change | Red border + inline error message below field |
| To Year text field | Must be integer 1900–current year | On change | Red border + inline error message below field |
| Year cross-field (from > to) | `fromYear ≤ toYear` when both are valid | On change (either field) | Red border on both fields + inline cross-field error |
| Minimum rating stepper | Clamped 1–10; no free text | N/A (stepper enforces range) | None needed |

**Confirmation dialogs:** None within the Search feature. No destructive actions in Search.

**"Clear All Filters":** Resets all draft filter state to defaults (empty genre set, rating toggle off, empty year fields) and clears all validation errors.

---

### g. Transient State Treatment

#### `SearchListView` results area

| State | Display |
|---|---|
| `.idle` | `EmptyStateView` with "Search for a movie" prompt |
| `.loading` | Loading indicator (shared UI loading component) in results area |
| `.results` (non-empty `filtered`) | `List` / `ScrollView` of `MovieCardView` rows |
| `.empty(.noMatches)` | `EmptyStateView` — "No movies found for [query]" (no retry) |
| `.empty(.filtersEliminated)` | `EmptyStateView` — "No results match your active filters" + inline "Clear Filters" shortcut |
| `.error` | `ErrorStateView` — inline error message + retry button |

#### `SearchFilterSheetView` genre section

| State | Display |
|---|---|
| `.loading` | Loading indicator within genre section |
| `.loaded([Genre])` | Multi-select genre list |
| `.error` | `ErrorStateView` inline in genre section + retry button |

No optimistic updates. All mutations are local (filter/sort state); no SwiftData writes occur in Search.

---

### h. SwiftUI Previews Strategy

Previews use inline static mock data. The view layer does not access `TMDBClientProtocol` directly in any architecture variant; the presentation object (ViewModel / Presenter / Store) is the dependency boundary. Previews instantiate the view with a pre-configured presentation object or static state value representing each specific screen state:

- `SearchListView` previews: one per `SearchState` case (idle, loading, results, empty-no-matches, empty-filters-eliminated, error).
- `SearchFilterSheetView` previews: genre loading, genre loaded, genre error.
- `SearchSortSheetView` preview: single static state (all three sort options visible).

No hardware or system dependencies require substitution. All data is inline static structs.

---

### i. iOS-Specific UI Concerns

| Concern | Decision |
|---|---|
| Keyboard avoidance | `.scrollDismissesKeyboard(.immediately)` on the results `ScrollView`/`List` |
| Search field keyboard | Default text keyboard with Return key triggering search |
| Year text fields keyboard | `.numberPad`; no Return key; validation fires on-change |
| Haptic feedback | None specified; not required for MVP |
| Deep links | Not in scope |
| Share sheet | Not in scope |
| Widgets / Live Activities | Not in scope |
| App lifecycle (foreground/background) | In-flight requests allowed to complete; no special foreground/background handling needed |

---

### j. Accessibility

VoiceOver labels, Dynamic Type support, and Reduce Motion alternatives are explicitly **out of scope** for this feature in the MVP.

---

### k. Analytics and Tracked Events

Not defined in the PRD. No analytics events are specified for the Search feature.

---

### l. Testing Strategy

**Presentation logic units to test:**
- Client-side filter application: given `[Movie]` + `SearchFilterState`, assert correct `filtered` output for each filter type and combination.
- Client-side sort: assert correct ordering for each `SearchSortOption`.
- `isActive` derivation from `SearchFilterState`: active when any filter is non-default; inactive when all cleared.
- Year validation: boundary values (1899, 1900, current year, current year + 1), cross-field (from > to, from == to, from < to).
- State transitions: verify that a new search cancels a pending search; verify that genre failure does not affect `searchState`.

**Service interactions to verify:**
- `fetchSearch(query:)` is called with the correct query on submit.
- `fetchGenres(force: false)` is called on first filter sheet open; `fetchGenres(force: true)` is called on retry.
- No additional `fetchSearch` call is triggered by filter or sort changes.

**UI test coverage:**
- Submit a query → results displayed.
- Submit a query → open filter sheet → apply genre filter → results list updates.
- Submit a query → sort → list order changes.
- Filter sheet: drag-to-dismiss → active filters unchanged.
- Error state → tap retry → loading state shown.

---

### m. Deferred Items

| Item | Reason |
|---|---|
| VoiceOver labels and hints | Explicitly out of scope for MVP |
| Dynamic Type support | Not specified; deferred |
| Reduce Motion alternatives | Not specified; deferred |
| Analytics event tracking | Not defined in PRD |
| Pagination beyond first TMDB page | Explicitly out of scope in PRD |
| Persisting filter/sort preferences across launches | Explicitly out of scope in PRD |
| Image caching for posters | Not required by PRD; handled at display layer |

---

### n. Unresolved Issues

None. All planning questions from both Q&A rounds have been answered. All decisions are recorded above.
