# Watchlist Feature Plan for Movie Tracker

## 1. Overview

The Watchlist feature fulfils the user goal of **viewing and navigating all movies the user intends to watch**. It presents the user's saved movies as a sortable list, allows re-ordering by three criteria, and provides navigation into Movie Detail for any entry — where watchlist mutations (add/remove) actually occur. The feature reads from local SwiftData via `WatchlistRepository` and has no network dependency of its own beyond opportunistic poster image loading in the shared `MovieCardView`.

This feature maps to PRD §3.5 (Watchlist tab), US-012, US-013, US-014, and US-039.

---

## 2. Feature Scope & Responsibility Boundary

### In Scope

| Screen / Surface | Purpose |
|---|---|
| `WatchlistListView` | Scrollable list of `WatchlistEntry` records with loading, empty, and error states; sort trigger in the navigation bar |
| `WatchlistSortSheetView` | Draft sort selection sheet with Apply, Cancel, and Clear; presented as `.sheet` from `WatchlistListView` |
| Navigation push → `MovieDetailView` | Tapping any `MovieCardView` row pushes Movie Detail onto the Watchlist tab's `NavigationStack` with only `movieId: Int` passed |

### Out of Scope / Delegated

| Concern | Owner |
|---|---|
| Adding or removing watchlist entries | MovieDetail feature (only surface for mutation) |
| Swipe-to-delete on list rows | Deferred post-MVP |
| Poster URL construction from `posterPath` | Shared `MovieCardView` via `TMDBClient.fetchPosterData` |
| Reactive observation streams | Post-MVP; `onAppear` re-fetch is the MVP strategy |
| Review indicators on list cards | Explicitly excluded — PRD US-038 |
| Tab badge for watchlist entry count | Explicitly excluded |
| `ReviewRepository` interaction | Not consumed by this feature |

**Boundary justification**: All watchlist mutations originate from `MovieDetailView`, which is a separate feature. The Watchlist feature is purely a read + navigate + sort surface. Keeping mutations in Movie Detail avoids split ownership of watchlist CTA state. The `onAppear` re-fetch strategy means the list always reflects current SwiftData state when the user returns from Movie Detail, without requiring a reactive pipeline at MVP.

---

## 3. Service Dependencies

| Service Protocol | Operations Consumed | Purpose |
|---|---|---|
| `WatchlistRepository` | `fetchAll(sortOrder: WatchlistSortOrder?) throws -> [WatchlistEntry]` | Load all watchlist entries, optionally sorted, from local SwiftData |

No other service protocol is consumed. `ReviewRepository` and `TMDBClientProtocol` are not direct dependencies of this feature. Network access is not required for listing — all `WatchlistEntry` fields are snapshots captured at add time. Poster images are loaded asynchronously by the shared `MovieCardView` component using the `posterPath` field.

### `WatchlistSortOrder` values

| Case | Sort behaviour |
|---|---|
| `.dateAdded` | Newest first (default) |
| `.title` | Alphabetical ascending |
| `.voteAverage` | TMDB rating descending |

---

## 4. Screen Inventory

| Screen | Purpose | Presentation style | Parent |
|---|---|---|---|
| `WatchlistListView` | Primary list screen; owns loading, empty, error, and populated states; hosts navigation bar sort button | Root of Watchlist tab's `NavigationStack` | TabView (Tab 3) |
| `WatchlistSortSheetView` | Draft sort order selection; Apply commits, Cancel discards, Clear resets draft to `.dateAdded` | `.sheet` from `WatchlistListView` | `WatchlistListView` |

`MovieDetailView` is pushed from `WatchlistListView` but is owned by the MovieDetail feature. `WatchlistListView` is only responsible for triggering the navigation with `movieId: Int`.

---

## 5. Presentation Logic

### 5.1 `WatchlistListView`

#### Screen State

```
WatchlistViewState:
  .loading
  .loaded([WatchlistEntry])
  .empty
  .error(String)

Supporting state:
  sortOrder: WatchlistSortOrder          // ephemeral; initialized to .dateAdded; never persisted
  isSortSheetPresented: Bool             // transient; drives sheet presentation
```

#### User Actions & Side Effects

| Action | Side Effect |
|---|---|
| Screen appears (`onAppear`) | Transition to `.loading`; call `fetchAll(sortOrder: currentSortOrder)`; transition to `.loaded`, `.empty`, or `.error` |
| Tap sort button (navigation bar) | Set `isSortSheetPresented = true`; present `WatchlistSortSheetView` with current `sortOrder` as initial draft |
| Apply sort (from sheet) | Dismiss sheet; update `sortOrder` to committed value; call `fetchAll(sortOrder: newSortOrder)`; update view state |
| Cancel sort (from sheet) | Dismiss sheet; no state change — `sortOrder` remains unchanged |
| Tap retry button (error state) | Call `fetchAll(sortOrder: currentSortOrder)`; transition to `.loading` then `.loaded`/`.empty`/`.error` |
| Tap `MovieCardView` row | Push `MovieDetailView` onto Watchlist tab's `NavigationStack` with `movieId: Int` |

#### Local Business Rules

- `fetchAll` returns a non-empty array → transition to `.loaded([WatchlistEntry])`
- `fetchAll` returns an empty array → transition to `.empty`
- `fetchAll` throws → transition to `.error(message)` where `message` is derived from `WatchlistRepositoryError` without exposing SwiftData internals
- Sort order changes are not applied until Apply is tapped; the draft lives entirely inside `WatchlistSortSheetView` — `sortOrder` on the list is not mutated until after Apply

### 5.2 `WatchlistSortSheetView`

#### Screen State (Draft)

```
draftSortOrder: WatchlistSortOrder     // initialized to the caller's current sortOrder on open; sheet lifetime only
```

The currently active sort option is shown as highlighted/selected when the sheet opens.

#### User Actions & Side Effects

| Action | Side Effect |
|---|---|
| Tap a sort option | Update `draftSortOrder`; no effect on parent yet |
| Tap **Apply** | Commit `draftSortOrder` to caller; dismiss sheet |
| Tap **Cancel** or drag-to-dismiss | Discard `draftSortOrder`; parent `sortOrder` unchanged; dismiss sheet |
| Tap **Clear** | Set `draftSortOrder = .dateAdded`; sheet remains open; user must tap Apply to commit |

#### Local Business Rules

- All three sort options are always valid; no validation logic is required
- Drag-to-dismiss has identical semantics to Cancel — the draft is discarded
- Clear does not immediately re-sort the list; it only resets the draft selection within the sheet

---

## 6. Navigation & Routing

### Entry Point

`WatchlistListView` is the root screen of the Watchlist tab's `NavigationStack`, activated when the user taps the Watchlist tab item. It is always present as the stack root; it is never pushed or replaced.

### Internal Navigation Graph

```
WatchlistListView (root)
  ├── WatchlistSortSheetView          .sheet (presented/dismissed by WatchlistListView)
  └── MovieDetailView                 pushed onto Watchlist tab's NavigationStack (MovieDetail feature)
        └── ReviewWizardView          .fullScreenCover (Review feature, not owned here)
```

### Navigation Events

| Event | Navigation action | Data passed |
|---|---|---|
| User taps sort button | Present `WatchlistSortSheetView` as `.sheet` | Current `sortOrder` |
| User taps Apply in sort sheet | Dismiss sheet | New `sortOrder` value (via callback/binding) |
| User taps Cancel or drags to dismiss sheet | Dismiss sheet | None |
| User taps any `MovieCardView` | Push `MovieDetailView` onto Watchlist `NavigationStack` | `movieId: Int` |
| User pops back from `MovieDetailView` | `WatchlistListView.onAppear` fires; re-fetch list | — |

### Pop-Back Behavior

When `MovieDetailView` is popped (user navigates back), `onAppear` on `WatchlistListView` fires automatically. This triggers a `fetchAll` call, ensuring that any watchlist mutation performed in Movie Detail (add or remove) is immediately reflected in the list without additional coordination.

### Deep Links

Not in scope. No external URL scheme or universal link handling is required for this feature.

### Cross-Tab Navigation

None. The Watchlist tab's `NavigationStack` is fully independent. No navigation crosses tab boundaries.

---

## 7. State Management

| State | Owner | Initialization | Lifetime | Cleanup |
|---|---|---|---|---|
| `viewState: WatchlistViewState` | `WatchlistListView` presentation unit | `.loading` on first `onAppear` | Screen lifetime; reset to `.loading` at every `onAppear` before fetch | Implicitly released when screen is deallocated |
| `sortOrder: WatchlistSortOrder` | `WatchlistListView` presentation unit | `.dateAdded` (hardcoded default; no persistence) | In-memory session; resets to `.dateAdded` on cold launch | Never persisted; no cleanup needed |
| `isSortSheetPresented: Bool` | `WatchlistListView` presentation unit | `false` | Transient; set to `true` on sort button tap, `false` on any sheet dismissal | Auto-reset on dismissal |
| `draftSortOrder: WatchlistSortOrder` | `WatchlistSortSheetView` | Initialized to caller's `sortOrder` on sheet open | Sheet lifetime only; discarded on Cancel/dismiss | Released when sheet is dismissed |

### Concurrency

All `WatchlistRepository` operations are synchronous and `@MainActor`-confined. No concurrent service updates arrive on a background thread. There is no need for cancellation logic, debouncing, or in-flight request tracking. `onAppear` always drives a new fetch; any in-progress fetch from the previous `onAppear` is superseded naturally given the synchronous call model.

### State Sharing

No state is shared between this feature and any other feature. The list reflects the SwiftData store on each `onAppear`. Coordination with Movie Detail is achieved entirely through the `onAppear` re-fetch triggered by pop-back.

---

## 8. User Interactions & Form Validation

This feature contains no text input fields and no form validation.

### Sort Sheet Interaction Model

- Single-select among three options; all options are always valid
- The currently active sort is highlighted on open via `draftSortOrder` initialization
- **Apply**: commits the selected option to the list; triggers `fetchAll` with the new order
- **Cancel** / drag-to-dismiss: discards draft; list sort unchanged
- **Clear**: resets draft to `.dateAdded` within the sheet; user must still tap Apply to commit to the list

### Destructive Actions

No destructive actions are owned by this feature. Watchlist removal is performed from `MovieDetailView`.

### Confirmation Dialogs

None required for this feature.

---

## 9. Loading, Empty, and Error States

| Screen | Loading | Empty | Error | Success |
|---|---|---|---|---|
| `WatchlistListView` | Loading indicator (shared loading component) shown while `fetchAll` is in progress | `EmptyStateView` with feature-owned copy; no network-error tone; communicates "no saved movies yet" without implying a failure | `ErrorStateView` with retry button; copy must not imply a network failure (e.g., "Unable to load your watchlist"); retry re-issues `fetchAll` | Scrollable list of `MovieCardView` rows |

### Details

- **Loading state** is transitioned to at the start of every `onAppear` fetch and every retry, to ensure the indicator reflects in-progress work. Retained for future-proofing even though the underlying SwiftData call is synchronous.
- **Empty state** is non-error in tone. It is reached only when the data layer succeeds and returns zero records. An appropriate call-to-action or prompt (e.g., "Add movies from Catalog or Search") may be included in the copy; exact wording is an implementation decision.
- **Error state** surfaces only on `WatchlistRepositoryError.fetchFailed`. The copy must not frame the failure as a network error since SwiftData persistence is fully offline. A retry affordance re-issues the same `fetchAll` call.
- No optimistic updates — all mutations originate from `MovieDetailView` and are reflected on the next `onAppear`.

---

## 10. SwiftUI Previews Strategy

### `WatchlistListView` — Three Preview Scenarios

| Scenario | Screen state | Description |
|---|---|---|
| Populated | `.loaded([WatchlistEntry, WatchlistEntry])` | Two static `WatchlistEntry` values with distinct titles, years, ratings, and `posterPath` values |
| Empty | `.empty` | No entries; shows `EmptyStateView` |
| Error | `.error("Unable to load your watchlist")` | Shows `ErrorStateView` with retry button |

The view renders exclusively from screen state values passed in at construction time. No repository is accessed during preview rendering. No mock `WatchlistRepository` is required.

### `WatchlistSortSheetView` — Preview Deferred

Preview for `WatchlistSortSheetView` is deferred to implementation time once the concrete architecture pattern (ViewModel, Reducer, Presenter) is confirmed. The sheet's state shape is simple enough (`draftSortOrder: WatchlistSortOrder`) that a one-state preview can be authored inline during implementation.

### Static Fixture Data

Two static `WatchlistEntry` values are sufficient for the populated preview:

```
WatchlistEntry(movieId: 1, title: "Dune: Part Two", releaseYear: 2024, voteAverage: 8.1, posterPath: "/path1.jpg", dateAdded: Date())
WatchlistEntry(movieId: 2, title: "Poor Things", releaseYear: 2023, voteAverage: 7.8, posterPath: nil, dateAdded: Date().addingTimeInterval(-86400))
```

Including one entry with a `nil` `posterPath` validates the placeholder image path in `MovieCardView`.

---

## 11. iOS-Specific UI Concerns

### Keyboard Avoidance

Not applicable — this feature contains no text input fields.

### Haptic Feedback

Not applicable — no mutations occur within this feature. Swipe-to-delete (which would warrant haptic feedback) is deferred post-MVP.

### App Lifecycle

`onAppear` fires on tab activation, pop-back from `MovieDetailView`, and app foreground re-entry when `WatchlistListView` is the visible screen. All three cases trigger a fresh `fetchAll`, which is the intended behavior. No additional `scenePhase` or `UIApplication` lifecycle handling is required.

### Poster Images

Poster images are loaded from TMDB CDN URLs at the `MovieCardView` level. `WatchlistListView` passes the `WatchlistEntry` (which contains `posterPath: String?`) to each `MovieCardView`. The card component calls `TMDBClient.fetchPosterData(posterPath:size:)` using the `.thumbnail` size case. Connectivity is not required for list data — only for images, which degrade gracefully to a placeholder when unavailable.

### Deep Links

Not in scope for this feature.

### Share Sheet

Not in scope for this feature.

### Widget / Live Activity

Not in scope.

### Context Menus / Drag-and-Drop

Not required. Swipe-to-delete is explicitly deferred.

### Runtime Permissions

None required. Local SwiftData persistence needs no user permission grant.

### Tab Badge

Explicitly excluded. No badge showing watchlist entry count is shown on the Watchlist tab item.

---

## 12. Accessibility

Deferred to post-MVP per planning decision.

No VoiceOver labels, hints, or grouping customization beyond SwiftUI defaults are required for the initial implementation. No Dynamic Type layout adaptations beyond what SwiftUI and the shared DesignSystem components provide automatically are required. No Reduce Motion alternatives are needed (no custom animations are defined for this feature).

---

## 13. Analytics & Tracked Events

Not specified in the PRD. No analytics events are defined for this feature.

---

## 14. Testing Strategy

### Presentation Logic Unit Tests

Test the presentation unit (ViewModel, Presenter, or Reducer depending on the architecture variant) with a fake `WatchlistRepository` conformance. All tests run on the main thread; no async machinery is required.

| Scenario | Starting state | Action | Expected outcome |
|---|---|---|---|
| Fetch success — populated | Initial | `onAppear` | Transitions `.loading` → `.loaded([WatchlistEntry])` |
| Fetch success — empty | Initial | `onAppear` | Transitions `.loading` → `.empty` |
| Fetch throws | Initial | `onAppear` | Transitions `.loading` → `.error(message)` |
| Sort apply | `.loaded([…])` | Apply new sort order from sheet | `sortOrder` updated; `fetchAll` called with new order; state updated |
| Sort cancel | `.loaded([…])` | Cancel from sheet | `sortOrder` unchanged; no additional `fetchAll` call |
| Sort clear then apply | Sheet open | Clear → Apply | `fetchAll` called with `.dateAdded`; list reflects default sort |
| Retry from error | `.error(…)` | Tap retry | `fetchAll` re-issued; transitions through `.loading` to new state |

### Service Interaction Tests

- Verify `fetchAll(sortOrder: .dateAdded)` is called on first `onAppear`.
- Verify `fetchAll(sortOrder:)` is called with the selected sort order after Apply.
- Verify `fetchAll` is **not** called after Cancel.
- Verify `fetchAll` is called with `.dateAdded` after Clear + Apply.
- Verify `fetchAll` is called again on the second `onAppear` (pop-back scenario).

### UI Tests

Optional for MVP. The three SwiftUI preview scenarios cover the primary visual states. UI test coverage can be added in a follow-on pass if the shared behavioral test specification requires it.

---

## 15. Platform & OS Constraints

| Constraint | Impact |
|---|---|
| iOS 17 minimum | SwiftData (`@Model`, `ModelContext`, `@Attribute(.unique)`), `Predicate<T>`, and `SortDescriptor<T>` require iOS 17; no availability guards are needed — the deployment target enforces this globally |
| `WatchlistRepository` is `@MainActor`-confined | All `fetchAll` calls must originate from the main thread; all three architecture variants (MVVM ViewModels, VIPER Interactors, TCA Reducers) already operate on the main thread for UI-driven operations |
| No entitlements required | Local SwiftData SQLite persistence in the default app container requires no capability entitlements |
| No background execution | All persistence operations and all feature state transitions occur on the main thread; no `BGTaskScheduler` registration is needed |

---

## 16. Deferred / Out of Scope for MVP

| Item | Rationale |
|---|---|
| Swipe-to-delete on watchlist rows | Not required by PRD; removed from MVP scope in planning session |
| Reactive observation (`@Query`, `AsyncStream`, Combine publisher of `[WatchlistEntry]`) | `onAppear` re-fetch is sufficient for MVP; each architecture variant may add its own observation mechanism post-MVP |
| `WatchlistSortSheetView` SwiftUI Preview | Deferred to implementation once the concrete architecture pattern and view construction approach are confirmed |
| VoiceOver labels, Dynamic Type customisation, Reduce Motion | Post-MVP accessibility pass |
| Analytics events | Not specified in PRD; no events defined |
| Tab badge for watchlist entry count | Explicitly excluded per planning decision |
| Sort preference persistence across cold launches | Intentionally excluded per PRD; resets to `.dateAdded` on every cold launch |

---

## 17. Open Questions / Unresolved Decisions

None. All planning questions have been answered and all recommendations have been matched to explicit decisions in the watchlist feature planning session summary.
