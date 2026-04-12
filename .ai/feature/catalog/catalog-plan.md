# Catalog Feature Plan for Movie Tracker

## 1. Overview

The Catalog feature fulfils the user goal of **discovering trending movies for the week**. It is the default tab the user lands on at cold launch and provides a scrollable list of first-page trending movies sourced from TMDB (`/trending/movie/week`). From this list the user can tap any movie to open its full detail screen.

The feature is a single-screen vertical slice: `CatalogListView`. It owns its own navigation stack, handles all loading/error/empty states inline, and delegates everything else — movie detail, watchlist, review — to the downstream `MovieDetail` feature.

---

## 2. Feature Scope & Responsibility Boundary

### In Scope

- `CatalogListView`: the sole screen owned by this feature; the root destination of the Catalog tab.
- Fetching trending movies by calling `TMDBClientProtocol.fetchTrending()` (first page only).
- Displaying a vertically scrollable list of `MovieCardView` instances.
- Inline loading, error, and (empty-as-error) states.
- Navigating to `MovieDetailView` by pushing a `movieId: Int` onto the Catalog tab's `NavigationStack`.
- Owning the `NavigationPath` (or architectural equivalent) for the Catalog tab stack.
- Extracting the display release year from `Movie.releaseDate` (ISO-8601 string → year) in the presentation layer.
- Formatting `Movie.voteAverage` to one decimal place in the presentation layer.

### Explicitly Out of Scope

| Concern | Owner |
|---|---|
| Sort and filter controls | Not applicable; PRD explicitly excludes them from Catalog (US-026) |
| `MovieCardView` layout and rendering | Shared UI package (consumed as a black box) |
| Poster image loading and display-level caching | Shared UI package / each implementation's image loading component |
| `MovieDetailView` | MovieDetail feature |
| Watchlist and review state | Watchlist / Review features |
| Tab icon and label (SF Symbol name) | DesignSystem / implementation plan |
| `TMDBClientProtocol` injection wiring | Each architectural implementation plan |
| Pull-to-refresh | Out of scope for MVP |
| Accessibility labels and VoiceOver | Deferred for MVP |
| Analytics events | Not defined in PRD |
| Deep links | Out of scope per scaffolding plan |

**Boundary justification**: The feature owns exactly the presentation logic for the trending list and its inline states. Navigation into Movie Detail crosses a feature boundary; the Catalog feature forwards only the `movieId` and takes no further responsibility for that screen's content. Sort/filter are PRD-excluded. All reusable card and error/empty views are shared UI infrastructure, not owned by this feature.

---

## 3. Service Dependencies

| Service | Protocol | Operations Used |
|---|---|---|
| `TMDBClient` | `TMDBClientProtocol` | `fetchTrending() async throws -> [Movie]` |

No persistence service is consumed. No `WatchlistRepository` or `ReviewRepository` dependency exists in this feature.

`TMDBClient` is injected by the composition root via the DI mechanism of each architectural variant (environment value, initializer injection, factory closure, or equivalent). One instance is shared for the lifetime of the app process.

---

## 4. Screen Inventory

| Screen | Purpose | Relationship |
|---|---|---|
| `CatalogListView` | Root trending list; shows all phases (loading, loaded, failed) | Root tab destination |

This feature has exactly one screen. `MovieDetailView` is pushed from here but is owned by the MovieDetail feature.

---

## 5. Presentation Logic

### `CatalogListView`

#### Screen State

Screen state is modelled as a `Phase` enum nested inside the screen's state container:

| Phase | Render |
|---|---|
| `.idle` | Empty content area; no spinner, no list. Transitions to `.loading` immediately on first `.onAppear`. |
| `.loading` | Centered `ProgressView`; card list area replaced by static gray placeholder rows. |
| `.loaded([Movie])` | Vertically scrollable `List` of `MovieCardView` rows. |
| `.failed(TMDBError)` | `ErrorStateView` with a generic error message and a retry button. |

The `.idle` phase exists only briefly at cold launch. It is distinct from `.failed` so the re-fetch guard can differentiate an uninitialized screen from one that has already received an error response.

#### User Actions

| Action | Trigger | Side Effect | State Transition |
|---|---|---|---|
| `onAppear` | View appears in the SwiftUI lifecycle | Dispatch `fetchTrending()` if `Phase` is `.idle` or `.failed`; no-op if `.loading` or `.loaded` | `.idle` / `.failed` → `.loading` |
| Retry tapped | Retry button inside `ErrorStateView` | Dispatch `fetchTrending()` | `.failed` → `.loading` |
| Movie card tapped | Tap gesture on `MovieCardView` | Append `movieId: Int` to `NavigationPath` | No `Phase` change |
| Fetch succeeded (non-empty) | `fetchTrending()` returns a non-empty `[Movie]` | Populate list with result | `.loading` → `.loaded([Movie])` |
| Fetch succeeded (empty) | `fetchTrending()` returns `[]` | Treat as error; surface `ErrorStateView` with generic text | `.loading` → `.failed(TMDBError)` |
| Fetch failed | `fetchTrending()` throws `TMDBError` | Surface `ErrorStateView` | `.loading` → `.failed(TMDBError)` |

#### Side Effects per Action

- **`onAppear` / Retry**: single async call to `TMDBClientProtocol.fetchTrending()`. Result is applied to `Phase` on the main actor. Any in-flight task from a previous dispatch must be cancelled before a new task is started (prevents stale results from a superseded retry from overwriting a newer state).
- **Movie card tapped**: append `movieId` to the `NavigationPath`. No service call.

#### Local Business Rules

- Re-fetch guard: do not dispatch `fetchTrending()` when `Phase` is `.loaded` or `.loading`.
- An empty `[Movie]` result is mapped to `.failed` with the same generic `TMDBError` as a network failure. No distinct "no trending movies" message for MVP.
- Release year is derived from `Movie.releaseDate` (ISO-8601 string → `String` year component) in the presentation layer. The `Movie` domain type is not mutated.
- `voteAverage` is formatted to one decimal place (e.g. `7.4`) in the presentation layer.
- A fetch result that arrives after the `Phase` has already moved on (e.g. a prior in-flight task resolving after a retry was issued) must be discarded. The concrete cancellation mechanism is implementation-specific.

---

## 6. Navigation & Routing

- **Entry point**: `CatalogListView` is the root destination of the Catalog tab. It is the selected tab on cold launch.
- **Owned navigation stack**: the Catalog feature owns its `NavigationPath` (TCA `StackState`, VIPER Router-observable path, or equivalent). This state is local to the feature and session-scoped; it is empty on cold launch and resets on process restart.
- **Internal navigation graph**: single push level — `CatalogListView` → `MovieDetailView(movieId:)`.
- **Navigation trigger**: user taps a `MovieCardView`; the `movieId: Int` of the tapped movie is appended to the path.
- **Back navigation**: standard `NavigationStack` pop (swipe or back button). No additional side effects on return. `Phase` is unaffected by returning from Movie Detail; the loaded list is preserved.
- **Deep links**: not in scope.
- **VIPER note**: the Router owns path mutations; it must expose the path as an observable or binding to the View. The exact seam is defined in the VIPER implementation plan.

---

## 7. State Management

| State | Scope | Lifetime | Initialization | Cleanup |
|---|---|---|---|---|
| `Phase` | Local to `CatalogListView` and its presentation unit | Session; resets to `.idle` on cold launch | `.idle` on init | N/A — no explicit teardown required |
| `NavigationPath` (or equivalent) | Local to Catalog feature | Session; resets to empty on cold launch | Empty on init | Implicit on process exit |

- No state is shared with Search, Watchlist, or MovieDetail features.
- No cross-screen state exists within this feature; it has exactly one screen.
- Concurrent updates: if a retry is issued while a previous fetch task is still in flight, the previous task must be cancelled before the new one starts. The result of any task that resolves after a cancellation is discarded and does not update `Phase`.
- No global or session-scoped state is introduced or consumed by this feature.

---

## 8. User Interactions & Form Validation

No form input fields exist on this screen. The only interactive elements are:

- **Movie card tap** — no validation; always appends `movieId` to the navigation path.
- **Retry button** — no validation; always re-dispatches `fetchTrending()` if `Phase` is `.failed`.

No confirmation dialogs. No destructive actions. No keyboard interaction.

---

## 9. Loading, Empty, and Error States

| State | `CatalogListView` Treatment |
|---|---|
| Initial loading (`.idle` → `.loading`) | Centered `ProgressView`; card list area replaced by static gray placeholder rows |
| Retry loading (`.failed` → `.loading`) | Error view replaced immediately by the same centered `ProgressView` and placeholder rows |
| Loaded (non-empty) | Scrollable `List` of `MovieCardView` rows |
| Loaded (empty `[]`) | Mapped to `.failed`; same `ErrorStateView` as network failure |
| Failed | `ErrorStateView` with generic error message and retry button |

**No optimistic updates.** **No stale-data-alongside-error display.**

**Card-level placeholder**: while the poster image URL resolves, the poster area and all text fields in `MovieCardView` show a static gray fill. If `posterPath` is `nil`, the poster area permanently shows a static gray fill (no image will arrive). No shimmer animation is used.

**Retry behavior**: tapping retry immediately transitions `Phase` to `.loading` for instant visual feedback, then dispatches a new `fetchTrending()` call.

---

## 10. SwiftUI Previews Strategy

Each `Phase` variant requires a dedicated preview backed by a `MockTMDBClient` that conforms to `TMDBClientProtocol`:

| Preview | `MockTMDBClient` behavior | Fixture data required |
|---|---|---|
| `.loaded` | `fetchTrending()` returns a fixed `[Movie]` array immediately | 3–5 `Movie` fixtures: varying `title`, `releaseDate` (ISO-8601), `voteAverage`, both `nil` and non-nil `posterPath` |
| `.failed` | `fetchTrending()` throws `TMDBError.networkFailure` | None beyond the error value |
| `.loading` | `fetchTrending()` suspends indefinitely (never returns or throws) | None |
| `.idle` | No fetch has been triggered yet | None |

No hardware or system dependencies require substitution. `MockTMDBClient` is the only test seam needed for Previews.

Static `Movie` fixture data should be defined in a dedicated `MovieFixtures` enum (or equivalent) shared across the feature's Preview and unit-test targets to avoid duplication.

---

## 11. iOS-Specific UI Concerns

- **Keyboard avoidance**: not applicable — no text input fields on this screen.
- **Haptic feedback**: none specified for MVP.
- **Deep links**: out of scope.
- **Share sheet / widget / Live Activity**: not applicable to this feature.
- **App lifecycle (foreground/background)**: the trending fetch is triggered by `.onAppear`. When the app is backgrounded and foregrounded while the Catalog tab is the root visible screen, `.onAppear` does not re-fire for a `NavigationStack` root in SwiftUI — no additional re-fetch guard beyond the `.loaded` check is required. If an implementation triggers `.onAppear` again on foreground (e.g., due to tab re-selection or lifecycle differences between architectural variants), the existing `.loaded` guard prevents a redundant fetch.
- **Navigation title**: large title "Trending" displayed in the navigation bar.
- **Tab bar**: Catalog is the default selected tab on cold launch; the selected tab index is not persisted.

---

## 12. Accessibility

Deferred entirely for MVP. No VoiceOver labels, Dynamic Type overrides, or Reduce Motion alternatives are specified for this feature at this time.

VoiceOver labels for `MovieCardView` rows are owned by the shared UI package's `MovieCardView` component, not by this feature.

---

## 13. Analytics & Tracked Events

No analytics events are defined for this feature. The PRD does not specify analytics requirements.

---

## 14. Testing Strategy

### Presentation Logic Unit Tests (per variant)

| Scenario | Expected Outcome |
|---|---|
| `fetchTrending()` returns non-empty `[Movie]` | `Phase` transitions `.idle` → `.loading` → `.loaded([Movie])` |
| `fetchTrending()` returns empty `[]` | `Phase` transitions `.loading` → `.failed` |
| `fetchTrending()` throws `TMDBError` | `Phase` transitions `.loading` → `.failed` |
| Retry action in `.failed` state | `Phase` transitions immediately to `.loading`; `fetchTrending()` is re-dispatched |
| `.onAppear` when `Phase` is `.loaded` | No fetch is dispatched; `Phase` unchanged |
| `.onAppear` when `Phase` is `.loading` | No fetch is dispatched; `Phase` unchanged |
| Movie card tap | `movieId` is appended to `NavigationPath`; `Phase` unchanged |

### Service Interaction Verification

- `fetchTrending()` is called exactly once on first `.onAppear` when `Phase` is `.idle`.
- `fetchTrending()` is called again on retry when `Phase` is `.failed`.
- `fetchTrending()` is not called when `Phase` is `.loaded` or `.loading`.

### UI / Integration Tests

| Scenario | Verification |
|---|---|
| Happy path | Catalog tab shows a populated list of movie cards after a successful trending fetch |
| Error path | `ErrorStateView` is visible after a failed fetch; tapping retry re-issues the request |

Mock implementation: `MockTMDBClient` (conforms to `TMDBClientProtocol`) with configurable return values for `fetchTrending()`.

---

## 15. Platform & OS Constraints

- **Minimum deployment target**: iOS 17. All APIs used — `NavigationStack`, `TabView`, SwiftUI async task management, `ProgressView`, Swift concurrency — are available across the full supported range without back-deployment shims.
- **Swift version**: Swift 5.9+; structured concurrency (`async`/`await`, `Task`, `withTaskCancellationHandler` or equivalent) is available.
- **No additional entitlements**: outbound HTTPS to TMDB requires no special capability. ATS is satisfied by default for `https://api.themoviedb.org`.
- **No runtime permission prompts**: this feature makes no requests that trigger permission dialogs.
- **Privacy manifest**: no privacy-sensitive system APIs are accessed by this feature. The app-level `PrivacyInfo.xcprivacy` entry for network access covers TMDB calls.

---

## 16. Deferred / Out of Scope for MVP

| Item | Rationale |
|---|---|
| Pull-to-refresh | Not required by PRD; explicit retry button satisfies US-004 |
| Accessibility labels and VoiceOver support | Explicitly deferred for MVP |
| Distinct empty-array error message vs. network error message | Generic `ErrorStateView` text is acceptable for MVP |
| Tab icon and SF Symbol name | Defined by DesignSystem and the per-variant implementation plan |
| `TMDBClientProtocol` injection wiring | Mechanism varies per architectural variant; defined in each implementation plan |
| VIPER Router navigation seam (exact pattern) | Defined in VIPER implementation plan |
| Poster image display-level caching | Not required by PRD for MVP |
| Haptic feedback | Not specified for MVP |
| Analytics events | Not defined in PRD |

---

## 17. Open Questions / Unresolved Decisions

None. All planning decisions have been resolved and recorded in the feature planning session summary (`catalog-planning-notes.md`). No inputs from other plans conflict with the decisions made here.
