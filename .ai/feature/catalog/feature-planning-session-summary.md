# Catalog Feature — Planning Session Summary

## Decisions

1. Screen state is modelled as a nested `Phase` enum inside a `State` struct: `.idle`, `.loading`, `.loaded([Movie])`, `.failed(TMDBError)`. Using `Phase` (not a top-level enum) keeps TCA idiomatic and reduces friction across all three architectural variants.
2. Loading indicator: centered `ProgressView` in the list content area.
3. Retry action immediately transitions `Phase` to `.loading` before dispatching the network request.
4. No pull-to-refresh. Only an explicit retry button (via `ErrorStateView`) is provided.
5. Poster images load at `.thumbnail` (`w185`) size. While loading or when `posterPath` is `nil`, all card fields (poster area and text fields) show a static gray fill placeholder — no shimmer animation.
6. Navigation to Movie Detail passes only `movieId: Int`; the full `Movie` struct is not forwarded.
7. `MovieCardView` is consumed as a black box from the shared UI package. The Catalog feature does not define its layout.
8. Release year extraction from `Movie.releaseDate` (ISO-8601 string → year integer/string) is performed in the presentation layer, not in the domain type.
9. `voteAverage` is displayed as a number with one decimal place (e.g. `7.4`).
10. An empty `[Movie]` response from the trending endpoint is treated as an error and surfaces `ErrorStateView` with the same generic error text as a network failure.
11. Trending fetch is triggered in `.onAppear`. Re-fetch is guarded: dispatch only when `Phase` is `.idle` or `.failed`; skip if already `.loading` or `.loaded`.
12. `TMDBClient` injection mechanism is deferred to each architectural implementation plan.
13. Accessibility labels are out of scope for MVP.
14. The Catalog feature owns its own `NavigationPath` (or equivalent per variant). In VIPER, the Router exposes an observable/binding to the View; the specific seam is defined in the VIPER implementation plan.
15. Card placeholder: static gray fill for all card fields before data loads (poster area and text fields). No shimmer. When `posterPath` is `nil`, the poster area remains a static gray fill permanently.
16. Empty-array error uses the same generic `ErrorStateView` text as a network failure. Retry re-issues the same request; a repeated empty response is acceptable for MVP.
17. Re-fetch guard: skip re-fetch when `Phase` is `.loaded`; re-fetch only when `.idle` or `.failed`.
18. Navigation title: large title "Trending".
19. Tab icon and label are deferred to the implementation plan / DesignSystem definition.

---

## Matched Recommendations

1. **Flat (nested) enum for screen state** — confirmed as `Phase` nested inside a `State` struct to stay idiomatic across MVVM, TCA, and VIPER.
2. **`.thumbnail` for poster size** — confirmed; `.full` is reserved for Movie Detail.
3. **Nil `posterPath` → static gray fill immediately** — confirmed; shimmer was explicitly rejected; gray fill applies to all card fields before load.
4. **Release year in presentation layer** — confirmed; domain `Movie` struct remains free of formatting logic.
5. **Retry transitions to `.loading` immediately** — confirmed; gives instant visual feedback.
6. **Pass only `movieId: Int` to Movie Detail** — confirmed; Movie Detail is responsible for its own data fetch.
7. **Trigger fetch on `.onAppear`, guard against re-fetch when `.loaded`** — confirmed.
8. **No pull-to-refresh for MVP** — confirmed; `ErrorStateView` retry satisfies PRD requirement US-004.
9. **Empty-array → error state with generic text** — confirmed; distinct messaging deferred to post-MVP.
10. **VoiceOver label format owned by `MovieCardView`** — accessibility is out of scope for MVP entirely; point is moot.

---

## Feature Planning Summary

### a. Confirmed Scope and Responsibility Boundary

**In scope:**
- `CatalogListView`: single screen; root tab destination for the Catalog tab.
- Load trending movies from `TMDBClient.fetchTrending()` (first page only).
- Display a vertically scrollable list of `MovieCardView` instances.
- Show loading, error, and (defensive) empty-as-error states.
- Navigate to `MovieDetailView` by passing `movieId: Int` onto the Catalog tab's `NavigationStack`.
- Own the `NavigationPath` (or equivalent) for the Catalog tab stack.

**Explicitly out of scope / delegated:**
- Sort and filter controls — PRD explicitly excludes them from Catalog.
- `MovieCardView` layout — consumed as a black box from the shared UI package.
- Poster image caching — not provided by `TMDBClient`; display-level caching is a shared UI / implementation concern.
- Accessibility labels — deferred for MVP.
- Tab icon and label — deferred to implementation plan / DesignSystem.
- `TMDBClient` injection wiring — deferred to each architectural implementation plan.
- Pull-to-refresh — out of scope for MVP.

---

### b. Service Dependencies

| Service | Protocol | Operations Used |
|---|---|---|
| `TMDBClient` | `TMDBClientProtocol` | `fetchTrending() async throws -> [Movie]` |

No persistence service is consumed. No `WatchlistRepository` or `ReviewRepository` dependency.

---

### c. Presentation Logic — `CatalogListView`

**Screen state shape (`Phase`):**
- `.idle` — initial state on cold launch; no data, no spinner.
- `.loading` — fetch in flight; centered `ProgressView` shown; card list replaced by gray placeholder cells.
- `.loaded([Movie])` — trending list rendered as `MovieCardView` rows.
- `.failed(TMDBError)` — `ErrorStateView` shown with generic error message and retry button.

**User actions:**
| Action | Trigger | Side Effect | State Transition |
|---|---|---|---|
| `onAppear` | View appears | Dispatch `fetchTrending()` if `Phase` is `.idle` or `.failed`; no-op if `.loading` or `.loaded` | `.idle`/`.failed` → `.loading` |
| Retry tapped | Retry button in `ErrorStateView` | Dispatch `fetchTrending()` | `.failed` → `.loading` |
| Movie card tapped | Tap on `MovieCardView` | Push `movieId: Int` onto `NavigationPath` | No `Phase` change |
| Fetch succeeded | `fetchTrending()` returns `[Movie]` (non-empty) | Update state | `.loading` → `.loaded([Movie])` |
| Fetch succeeded empty | `fetchTrending()` returns `[]` | Treat as error; surface `ErrorStateView` | `.loading` → `.failed(TMDBError)` |
| Fetch failed | `fetchTrending()` throws `TMDBError` | Surface `ErrorStateView` | `.loading` → `.failed(TMDBError)` |

**Local business rules:**
- Do not re-fetch when `Phase` is `.loaded` or `.loading`.
- An empty `[Movie]` result is mapped to a `.failed` phase with the same generic error as a network failure.
- Release year is derived from `Movie.releaseDate` (ISO-8601 string) in the presentation layer; `Movie` is not mutated.
- `voteAverage` is formatted to one decimal place in the presentation layer.

---

### d. State Shape and Ownership

| State | Scope | Lifetime | Initialization |
|---|---|---|---|
| `Phase` | Local to `CatalogListView` / its presentation unit | Session; resets to `.idle` on cold launch | `.idle` on init |
| `NavigationPath` (or equivalent) | Local to Catalog feature | Session; resets to empty on cold launch | Empty on init |

No state is shared with other features. No session-scoped or cross-screen state exists within this feature (it has one screen).

Concurrent service updates: a fetch result that arrives after the feature has already transitioned away from `.loading` (e.g., due to rapid retries) must be discarded or guarded. Task cancellation on disappear or on retry dispatch handles this; exact mechanism is implementation-specific.

---

### e. Navigation and Routing

- **Entry point:** Root tab destination; Catalog tab is selected on cold launch.
- **Owned stack:** `CatalogListView` owns its `NavigationPath` (or TCA `StackState`, or VIPER Router-observable path).
- **Internal graph:** Single-level push — `CatalogListView` → `MovieDetailView(movieId:)`.
- **Navigation trigger:** User taps a `MovieCardView`; `movieId: Int` is appended to the path.
- **Back navigation:** Standard `NavigationStack` pop; no additional side effects on return.
- **Deep links:** Not in scope.
- **VIPER note:** The Router owns the navigation logic; it must expose the path as an observable binding to the View. The specific pattern is defined in the VIPER implementation plan.

---

### f. User Interactions and Validation

No form input or validation in this feature. The only interactive elements are:
- **Movie card tap** — no validation; always navigates.
- **Retry button** — no validation; always re-dispatches fetch.

No confirmation dialogs. No destructive actions.

---

### g. Transient State Treatment

| State | `CatalogListView` Treatment |
|---|---|
| Loading (initial) | Centered `ProgressView`; card list area replaced by gray placeholder rows |
| Loading (retry) | Same as initial load; error view replaced by `ProgressView` immediately on retry tap |
| Loaded (non-empty) | Scrollable list of `MovieCardView` rows |
| Loaded (empty `[]`) | Mapped to error state — same `ErrorStateView` as network failure |
| Failed | `ErrorStateView` with generic error message and retry button |

No optimistic updates. No stale-data-alongside-error display.

**Card-level placeholder:** While the poster image URL is loading, the poster area and all text fields show a static gray fill. If `posterPath` is `nil`, the poster area permanently shows a static gray fill (no image will ever arrive). No shimmer animation.

---

### h. SwiftUI Previews Strategy

- A `MockTMDBClient` (conforming to `TMDBClientProtocol`) that returns a fixed `[Movie]` array from `fetchTrending()` is sufficient for the `.loaded` preview.
- Additional mock variants return a `TMDBError` (for `.failed` preview) and never resolve (for `.loading` preview).
- Static `Movie` fixture data needed: `id`, `title`, `releaseDate` (ISO-8601), `voteAverage`, `posterPath` (both nil and non-nil variants).
- No hardware or system dependencies requiring substitution.

---

### i. iOS-Specific UI Concerns

- **Keyboard avoidance:** Not applicable — no text input on this screen.
- **Haptic feedback:** None specified for MVP.
- **Deep links:** Out of scope.
- **Share sheet / widget / Live Activity:** Not applicable.
- **App lifecycle:** No foreground/background handling required. The fetch is initiated on `.onAppear`; if the app is backgrounded and foregrounded while on this screen, `onAppear` does not re-fire in a `NavigationStack` root — no additional guard needed beyond the `.loaded` check.

---

### j. Accessibility

Deferred entirely for MVP. No VoiceOver labels, Dynamic Type overrides, or Reduce Motion alternatives are specified.

---

### k. Analytics

Not specified in the PRD. No analytics events are defined for this feature.

---

### l. Testing Strategy

**Presentation logic unit tests (per variant):**
- `fetchTrending()` success → `Phase` transitions from `.idle` → `.loading` → `.loaded([Movie])`.
- `fetchTrending()` success with empty array → `Phase` transitions to `.failed`.
- `fetchTrending()` throws → `Phase` transitions to `.failed`.
- Retry action when in `.failed` → `Phase` transitions to `.loading` immediately, then re-dispatches fetch.
- `.onAppear` when `Phase` is `.loaded` → no fetch dispatched.
- `.onAppear` when `Phase` is `.loading` → no fetch dispatched.

**Service interaction verification:**
- `fetchTrending()` is called exactly once on first `.onAppear`.
- `fetchTrending()` is called again on retry; not called when already `.loaded`.

**UI / integration tests:**
- Happy path: Catalog tab displays list of movie cards after successful load.
- Error path: `ErrorStateView` is visible after a failed load; retry re-issues the request.

---

### m. Deferred Items

| Item | Reason |
|---|---|
| Pull-to-refresh | Not required by PRD; retry button satisfies US-004 |
| Accessibility labels and VoiceOver | Out of scope for MVP |
| Tab icon and SF Symbol name | Deferred to DesignSystem / implementation plan |
| `TMDBClient` injection wiring | Varies per architectural variant; defined in each implementation plan |
| VIPER Router navigation seam (exact pattern) | Defined in VIPER implementation plan |
| Poster image display-level caching | Not required by PRD for MVP |
| Distinct empty-array error message | Generic text acceptable for MVP |
| Haptic feedback | Not specified for MVP |
| Analytics events | Not defined in PRD |

---

### n. Unresolved Issues

None. All planning questions have been answered and all decisions are recorded above.
