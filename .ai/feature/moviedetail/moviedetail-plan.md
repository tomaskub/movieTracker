# MovieDetail Feature Plan for Movie Tracker

## 1. Overview

The MovieDetail feature allows a user to inspect the full record of any TMDB movie — synopsis, genres, release date, rating, and cast — and take the two core personal-data actions tied to that movie: toggling watchlist membership and managing a single review. It is the convergence point for all three tabs (Catalog, Search, Watchlist) and the sole entry point for the four-step review wizard.

**User goal**: "I want to read everything about a specific movie and decide whether to save it or log how I feel about it."

---

## 2. Feature Scope & Responsibility Boundary

### In Scope

- `MovieDetailView`: the single screen owned by this feature, pushed onto the active tab's `NavigationStack`.
- Fetching primary movie detail from `GET /movie/{id}` via `TMDBClient`.
- Fetching credits from `GET /movie/{id}/credits` via `TMDBClient`.
- Rendering poster, title, overview, genres, release date, TMDB rating, and up to three cast members.
- Watchlist CTA: state-aware "Add to Watchlist" / "Remove from Watchlist" backed by `WatchlistRepository`.
- Review CTA section: "Log a Review" when no review exists; read-only summary (star rating, tags, notes) with "Edit Review" and "Delete Review" when a review exists; backed by `ReviewRepository`.
- Confirmation dialog before review deletion.
- Presenting `ReviewWizardView` as a `.fullScreenCover` for create and edit flows.
- All loading, error, and unavailable sub-states for each independent section.

### Explicitly Out of Scope

| Concern | Owner |
|---|---|
| Review wizard implementation | Review feature; wizard fetches its own data |
| Composing `MovieDetail` from `/movie/{id}` + credits endpoint | `TMDBClient`; feature receives `MovieDetail` with `cast: .notRetrieved` |
| Slicing cast to top three for display | Feature presentation layer (performed here before rendering) |
| Poster URL assembly from relative path | Presentation layer |
| Offline/no-connectivity banner | Out of scope for MVP |
| Deep linking into `MovieDetailView` | Out of scope for MVP |
| Haptic feedback on watchlist mutations | Out of scope for MVP |
| Share sheet | Not in PRD |
| Tab-switch state persistence | Out of scope for MVP |
| Sorting, filtering | Not applicable to this screen |
| Poster image caching | `AsyncImage` opportunistic display-level caching only |

**Boundary justification**: The feature owns presentation logic for its single screen and composes services into user-facing actions. All infrastructure concerns (network transport, persistence writes, wizard internals) live in dedicated service and feature layers. Cast slicing (top three) is a display decision — the raw list is delivered by `TMDBClient` via `CastState.loaded([CastMember])`; the feature applies the slice at render time.

---

## 3. Service Dependencies

| Service | Protocol | Operations consumed |
|---|---|---|
| `TMDBClient` | `TMDBClientProtocol` | `fetchMovie(id:) async throws -> MovieDetail`; `fetchCredits(id:) async throws -> [CastMember]` |
| `WatchlistRepository` | `WatchlistRepository` | `contains(movieId:) throws -> Bool`; `add(movie:) throws`; `remove(movieId:) throws` |
| `ReviewRepository` | `ReviewRepository` | `fetch(movieId:) throws -> Review?`; `delete(movieId:) throws` |

`ReviewWizardView` (the Review feature) consumes `ReviewRepository` independently for `create` and `update` operations. `MovieDetailView` does not coordinate those calls — it only re-fetches `ReviewRepository.fetch(movieId:)` after the wizard cover is dismissed.

---

## 4. Screen Inventory

| Screen | Purpose | Relationship |
|---|---|---|
| `MovieDetailView` | Full movie detail with watchlist and review actions | Pushed onto the active tab's `NavigationStack` |
| `ReviewWizardView` | Four-step review create/edit flow | Presented as `.fullScreenCover` from `MovieDetailView`; owned by the Review feature |

`MovieDetailView` is the only screen owned by this feature. It presents `ReviewWizardView` but does not implement it.

---

## 5. Presentation Logic

### Screen State Shape

Four independent sub-states govern what is rendered:

```
detailState:    .loading | .loaded(MovieDetail) | .error(TMDBError)
castState:      .loading | .loaded([CastMember]) | .unavailable
watchlistState: .loading | .onWatchlist | .notOnWatchlist | .mutating | .error(String)
reviewState:    .loading | .hasReview(Review) | .noReview | .error(String)
```

`castState`, `watchlistState`, and `reviewState` are **only rendered** when `detailState == .loaded`. While `detailState` is `.loading` or `.error`, only the full-screen loader or `ErrorStateView` is shown — no sub-state sections are visible.

### User Actions and Side Effects

| Action | Trigger | Side Effect | State Transition |
|---|---|---|---|
| Screen appears | Navigation push | Fire `fetchMovie(id:)` + `fetchCredits(id:)` in parallel | `detailState → .loading`, `castState → .loading` |
| Primary detail loaded | `fetchMovie` success | Call `WatchlistRepository.contains(movieId:)` + `ReviewRepository.fetch(movieId:)` | `detailState → .loaded(MovieDetail)`; `watchlistState` + `reviewState` derived from results |
| Primary detail failed | `fetchMovie` failure | — | `detailState → .error(TMDBError)` |
| Retry primary detail | User taps retry in `ErrorStateView` | Re-issue `fetchMovie(id:)` | `detailState → .loading` |
| Credits loaded | `fetchCredits` success | — | `castState → .loaded([CastMember])` (sliced to top 3 at render time) |
| Credits failed | `fetchCredits` failure | — | `castState → .unavailable` |
| Retry cast | User taps retry in cast section | Re-issue `fetchCredits(id:)` only | `castState → .loading` |
| Add to Watchlist | User taps CTA | `WatchlistRepository.add(movie:)` | `watchlistState → .mutating` → `.onWatchlist` on success or `.error(message)` on failure |
| Remove from Watchlist | User taps CTA | `WatchlistRepository.remove(movieId:)` | `watchlistState → .mutating` → `.notOnWatchlist` on success or `.error(message)` on failure |
| Log a Review | User taps CTA | Present wizard in create mode | `wizardPresentation = .create` |
| Edit Review | User taps CTA | Present wizard in edit mode | `wizardPresentation = .edit` |
| Delete Review | User taps CTA | Show confirmation dialog | `showDeleteConfirmation = true` |
| Confirm delete | User confirms dialog | `ReviewRepository.delete(movieId:)` | `reviewState → .loading` → `.noReview` on success or `.error(message)` on failure |
| Cancel delete | User cancels dialog | — | No state change |
| Wizard dismissed | `.fullScreenCover` `onDismiss` | `ReviewRepository.fetch(movieId:)` | `reviewState` re-derived from fetch result |

### Local Business Rules

- Watchlist and review CTA sections are rendered only when `detailState == .loaded`.
- Watchlist CTA is disabled (not hidden) while `detailState` is `.loading`.
- The `Movie` value for `WatchlistRepository.add(movie:)` is extracted from `MovieDetail.movie`; it is available only after `detailState == .loaded`.
- `WatchlistRepository.contains(movieId:)` and `ReviewRepository.fetch(movieId:)` are called only after the primary detail load succeeds.
- Cast list is sliced to the first three members at the presentation layer, not in the service.
- Inline error messages for watchlist mutations are displayed beneath the CTA and are replaced on the next successful operation.
- Inline error message for review delete failure is displayed after the confirmation dialog is dismissed.

---

## 6. Navigation & Routing

### SPM Target

`MovieDetailFeature` is a separate Swift Package Manager target. It is declared as a direct dependency by `CatalogFeature`, `SearchFeature`, and `WatchlistFeature` individually. It declares `ReviewFeature` as its own direct dependency. `ReviewWizardView` is referenced via its concrete type.

### Entry Point

`MovieDetailView` is pushed onto the active tab's `NavigationStack` when the user taps a movie card in Catalog, Search, or Watchlist. It receives a single input: `movieId: Int`. No other data is passed at the navigation boundary.

### Internal Navigation Graph

```
MovieDetailView
└── ReviewWizardView (.fullScreenCover)
```

`wizardPresentation: WizardPresentation?` drives the `.fullScreenCover` binding:
- `nil` — cover is dismissed
- `.create` — wizard opens at step 1 (empty state)
- `.edit` — wizard opens at step 1 (fields pre-populated; wizard fetches its own `Review` by `movieId`)

On wizard dismissal (via `onDismiss` callback), `ReviewRepository.fetch(movieId:)` is re-issued and `reviewState` is updated accordingly.

### VIPER-Specific Routing

The Router is an `@ObservableObject` with `@Published var wizardPresentation: WizardPresentation?`. The View observes the Router for presentation state; user actions flow through the Presenter, which calls Router methods. The Router builds the wizard VIPER module (Interactor + Presenter + View) from dependencies supplied by the composition root. On wizard dismissal, the View notifies the Presenter, which instructs the Interactor to re-fetch review state.

### Exit

Back navigation via the system navigation bar back button pops the screen and returns to the originating list. No programmatic back navigation is triggered by this feature.

### Deep Links

Not in scope for MVP.

---

## 7. State Management

### State Local to `MovieDetailView`

| State | Type | Purpose |
|---|---|---|
| `detailState` | `DetailState` | Primary content loading/loaded/error |
| `castState` | `CastState` | Credits section loading/loaded/unavailable |
| `watchlistState` | `WatchlistState` | Watchlist membership + mutation |
| `reviewState` | `ReviewState` | Review existence + mutation |
| `wizardPresentation` | `WizardPresentation?` | Drives `.fullScreenCover` |
| `showDeleteConfirmation` | `Bool` | Drives `.confirmationDialog` |

### No Shared State

All state is local to the screen instance. No session-scoped or cross-feature state is maintained. The Watchlist and Review features each own their own persistence; `MovieDetailView` reads and reacts to that state through synchronous service calls.

### Initialization on Entry

All states are initialized to their loading variants on screen push. `fetchMovie(id:)` and `fetchCredits(id:)` are fired in parallel immediately on appearance. `watchlistState` and `reviewState` remain `.loading` until `detailState` transitions to `.loaded`.

### Cleanup on Exit

All state is local and discarded when the screen is popped. A fresh instance is created on every navigation push; there is no caching at the feature layer.

### Concurrent Service Updates

`fetchCredits` may resolve before or after `fetchMovie`. The feature applies `castState` updates independently — they do not block or invalidate `detailState`. Wizard dismissal triggers a synchronous `ReviewRepository.fetch`; no concurrent review update is expected during the wizard session.

---

## 8. User Interactions & Form Validation

### No Form Inputs

`MovieDetailView` has no text fields or form controls. All data entry is delegated to `ReviewWizardView`.

### Confirmation Dialogs

Review delete requires an explicit `.confirmationDialog` before the destructive action is issued:

- **Title**: "Are you sure you want to delete the review?"
- **Destructive button**: "Delete"
- **Non-destructive button**: "Cancel"

Tapping "Delete" triggers `ReviewRepository.delete(movieId:)`. Tapping "Cancel" or dismissing the dialog leaves `reviewState` unchanged.

### Inline Error Surfacing

| Error Scenario | Location |
|---|---|
| `WatchlistRepository.add` failure (`.alreadyOnWatchlist`, `.insertFailed`) | Inline text below watchlist CTA |
| `WatchlistRepository.remove` failure (`.notFound`, `.deleteFailed`) | Inline text below watchlist CTA |
| `ReviewRepository.delete` failure (`.deleteFailed`) | Inline text in review section, shown after dialog is dismissed |

---

## 9. Loading, Empty, and Error States

| Section | Loading | Success | Error / Unavailable |
|---|---|---|---|
| Primary detail | Full-screen spinner; no content visible | Full content rendered | Full-screen `ErrorStateView` with inline retry; back navigation remains available |
| Cast section | Section-level loading indicator within detail layout | Up to 3 cast members rendered by name and character | "Cast unavailable" inline text + retry button; section header remains visible; non-fatal |
| Watchlist CTA | CTA disabled while `detailState` is loading | "Add to Watchlist" or "Remove from Watchlist" active CTA | CTA replaced with spinner during mutation; inline error text below CTA on failure |
| Review section | Section-level loading indicator | "Log a Review" CTA when no review; read-only summary + "Edit Review" / "Delete Review" when review exists | Inline error text below review section on delete failure |
| Poster image | Gray rounded rectangle + DesignSystem camera icon | Poster image via `AsyncImage` | Silent fallback to placeholder (no user-visible error) |

**No optimistic updates.** All state transitions occur only after the corresponding service call succeeds. The watchlist CTA is replaced with a spinner during mutations regardless of whether the underlying call is synchronous or async.

---

## 10. SwiftUI Previews Strategy

Multiple distinct previews are created, one per named screen state. Views do not interact with the service layer directly in previews.

| Preview Name | `detailState` | `watchlistState` | `reviewState` | `castState` |
|---|---|---|---|---|
| Loading | `.loading` | `.loading` | `.loading` | `.loading` |
| Primary error | `.error(.networkFailure)` | — | — | — |
| Loaded — not on watchlist, no review, cast loading | `.loaded(…)` | `.notOnWatchlist` | `.noReview` | `.loading` |
| Loaded — not on watchlist, no review, cast unavailable | `.loaded(…)` | `.notOnWatchlist` | `.noReview` | `.unavailable` |
| Loaded — not on watchlist, no review, cast loaded | `.loaded(…)` | `.notOnWatchlist` | `.noReview` | `.loaded([…])` |
| Loaded — on watchlist, with review, cast loaded | `.loaded(…)` | `.onWatchlist` | `.hasReview(…)` | `.loaded([…])` |
| Loaded — watchlist mutation in progress | `.loaded(…)` | `.mutating` | `.noReview` | `.loaded([…])` |

**Architecture-specific injection approach:**
- **MVVM**: pre-configured `ViewModel` with stub `detailState` / `watchlistState` / `reviewState` / `castState` values injected directly
- **VIPER**: pre-configured `Presenter` output state delivered to the View via its input interface
- **TCA**: initial `State` struct with stubbed values; no side effects fired

Shared preview fixtures (static `MovieDetail`, `Review`, `WatchlistEntry` values) may live in a `PreviewSupport` group within the feature module. These are never shipped to production.

---

## 11. iOS-Specific UI Concerns

| Concern | Decision |
|---|---|
| Navigation bar style | Large title displaying the movie title; back button only; no toolbar items, no share button |
| Poster image loading | `AsyncImage` (or a shared UI wrapper over `AsyncImage`); gray rounded rectangle + DesignSystem camera icon placeholder; silent fallback on load failure — no error shown to the user |
| `.fullScreenCover` presentation | Tabs are not visible while the wizard cover is presented; no state persistence across tab switches is needed because screen state is local and discarded on pop |
| Keyboard avoidance | Not applicable — no text input on this screen |
| Haptic feedback | Out of scope for MVP |
| Share sheet | Out of scope |
| Deep links | Out of scope |
| App lifecycle (foreground/background) | No special handling required; state is re-derived on each navigation push via `onAppear`; no background refresh |
| `PosterSize` | Use `.full` (`w500`) for the large poster displayed on this screen; URL assembled from `MovieDetail.movie.posterPath` at the presentation layer |
| Parallel fetch | `fetchMovie(id:)` and `fetchCredits(id:)` are fired in parallel using Swift structured concurrency (`async let` or equivalent); primary content renders when `fetchMovie` resolves; cast section updates independently when `fetchCredits` resolves or fails |

---

## 12. Accessibility

| Element | VoiceOver Label / Hint |
|---|---|
| Poster image | Label: "[Movie title] poster"; if placeholder is shown: "No poster available" |
| Watchlist CTA ("Add to Watchlist") | Label: "Add [Movie title] to Watchlist" |
| Watchlist CTA ("Remove from Watchlist") | Label: "Remove [Movie title] from Watchlist" |
| Watchlist spinner | Label: "Updating watchlist" |
| "Log a Review" button | Label: "Log a Review for [Movie title]" |
| "Edit Review" button | Label: "Edit your review of [Movie title]" |
| "Delete Review" button | Label: "Delete your review of [Movie title]" |
| Cast retry button | Label: "Retry loading cast" |
| Primary detail retry button | Label: "Retry loading movie detail" |
| Star rating display (in review summary) | Label: "[N] out of 5 stars" |

**Dynamic Type**: All text elements use DesignSystem typography tokens, which must support Dynamic Type scaling. At the largest accessibility sizes, the layout should reflow (e.g. poster and title stack vertically rather than side-by-side) to avoid truncation.

**Reduce Motion**: Any loading spinner animation that uses continuous rotation should respect `accessibilityReduceMotion`; a static indicator or reduced-motion alternative should be provided where applicable.

---

## 13. Analytics & Tracked Events

No analytics requirements are specified in the PRD for this feature. Analytics tracking is not in scope for MVP.

---

## 14. Testing Strategy

### Presentation Logic Unit Tests

Cover all state machine transitions for each sub-state dimension:

| Scenario | Expected Outcome |
|---|---|
| `fetchMovie` succeeds | `detailState → .loaded`; `watchlistState` + `reviewState` populated from service results |
| `fetchMovie` fails | `detailState → .error`; `watchlistState` and `reviewState` remain `.loading` (not rendered) |
| Retry after `fetchMovie` failure | `detailState → .loading` then resolved again |
| `fetchCredits` succeeds | `castState → .loaded([CastMember])` |
| `fetchCredits` fails | `castState → .unavailable` |
| Cast retry | `castState → .loading` then resolved; `detailState` not re-fetched |
| Add to Watchlist — success | `watchlistState: .notOnWatchlist → .mutating → .onWatchlist` |
| Add to Watchlist — failure | `watchlistState: .mutating → .error(message)` |
| Remove from Watchlist — success | `watchlistState: .onWatchlist → .mutating → .notOnWatchlist` |
| Remove from Watchlist — failure | `watchlistState: .mutating → .error(message)` |
| Watchlist CTA disabled during detail loading | CTA is in disabled state while `detailState == .loading` |
| Delete review — confirm | `ReviewRepository.delete(movieId:)` called; `reviewState → .noReview` on success |
| Delete review — cancel | `ReviewRepository.delete` not called; `reviewState` unchanged |
| Delete review — failure | `reviewState → .error(message)` after confirmation |
| Wizard dismissed | `ReviewRepository.fetch(movieId:)` called; `reviewState` updated |
| `onDismiss` with review created | `reviewState → .hasReview(…)` |
| `onDismiss` with review unchanged | `reviewState` unchanged |

### Service Interaction Tests (Mock Services)

- Verify `fetchMovie(id:)` and `fetchCredits(id:)` are both called on screen appearance.
- Verify `WatchlistRepository.contains(movieId:)` and `ReviewRepository.fetch(movieId:)` are called only after `detailState` reaches `.loaded`.
- Verify `WatchlistRepository.add(movie:)` is called with the `Movie` from `MovieDetail.movie`.
- Verify `WatchlistRepository.remove(movieId:)` is called with the correct `movieId`.
- Verify `ReviewRepository.delete(movieId:)` is called only after the user confirms the dialog.
- Verify cast retry calls `fetchCredits(id:)` only (not `fetchMovie`).

### UI Tests

| Flow | Assertion |
|---|---|
| Primary load → content visible | Detail content (title, overview) appears after mock response |
| Watchlist add → CTA updates | "Add to Watchlist" button transitions to "Remove from Watchlist" |
| Review delete confirmation → review removed | Confirm in dialog → "Log a Review" CTA appears |
| Review delete cancel → review preserved | Cancel in dialog → review summary still visible |
| Cast retry → section updates | Tap retry in cast section → cast members appear |

---

## 15. Platform & OS Constraints

| Constraint | Impact on Feature |
|---|---|
| iOS 17 minimum | `SwiftData` (backing `WatchlistRepository` and `ReviewRepository`) requires iOS 17; `async let` structured concurrency requires Swift 5.5+/iOS 15+; both are satisfied. No availability guards needed within this feature. |
| `@MainActor` confinement of service layer | `WatchlistRepository` and `ReviewRepository` concrete implementations are `@MainActor`-isolated. All presentation logic that calls these services must be invoked from the main actor. Each architecture variant handles this via its own mechanism (MVVM `@MainActor` ViewModel, VIPER Interactor calling on main thread, TCA Reducer). |
| SwiftUI `.fullScreenCover` | Available since iOS 14; no availability gate needed. Tabs are hidden while the cover is presented; this is standard SwiftUI behavior. |
| SwiftUI `.confirmationDialog` | Available since iOS 15; no availability gate needed. |
| `AsyncImage` | Available since iOS 15; no availability gate needed. Display-level caching is provided opportunistically by `URLSession`'s built-in cache; no explicit cache management is required. |
| No entitlements required | No special capabilities (iCloud, Push Notifications, background modes) are needed by this feature. |
| Privacy manifest | Standard local file access entry is sufficient (covered by the app-level `PrivacyInfo.xcprivacy`). No API usage from this feature triggers additional required-reason entries. |

---

## 16. Deferred / Out of Scope for MVP

| Item | Rationale |
|---|---|
| Haptic feedback on watchlist mutations | Explicitly deferred per planning session; not in PRD |
| Offline / no-connectivity banner | Deferred per planning session; not in PRD |
| Deep link entry into `MovieDetailView` | Deferred per planning session; not in PRD |
| Share sheet for movie | Not in PRD |
| Accessibility audit (VoiceOver labels, Dynamic Type, Reduce Motion) | Described in §12 above; implementation-time concern not fully scoped in this planning session |
| Analytics event tracking | Not specified in PRD |
| Poster image caching beyond `AsyncImage` opportunistic cache | Deferred per `TMDBClient` plan; not required by PRD |
| Tab-switch state persistence | Treated as an unlikely edge case; out of scope for MVP |
| TMDB detail response caching | No cache at the feature layer; always re-fetches on push |

---

## 17. Open Questions / Unresolved Decisions

None. All questions raised during the planning session have been answered and all decisions are recorded in `feature-planning-session-summary.md`.
