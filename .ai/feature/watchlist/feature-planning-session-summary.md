# Watchlist Feature — Planning Session Summary

## Decisions

1. `MovieCardView` lives in a shared UI components target; the Watchlist feature consumes it as-is.
2. Live list updates are driven by `onAppear` re-fetch (no reactive streams for MVP). The list re-fetches on every `onAppear`, including when `MovieDetailView` is popped back.
3. `WatchlistSortSheetView` handles sorting only (no filtering).
4. `WatchlistSortOrder` selection state is fully owned by the Watchlist feature layer (ephemeral, resets on cold launch).
5. The Watchlist list updates immediately on pop-back from `MovieDetailView` via the `onAppear` re-fetch.
6. No `ReviewRepository` dependency; no reviewed indicator on Watchlist cards (PRD US-038 confirmed).
7. Poster URL construction is handled by `TMDBClient.fetchPosterData` using an appropriate size enum case; the Watchlist feature does not assemble URLs directly.
8. SwiftData read failure surfaces as `ErrorStateView` with a retry button.
9. Screen state shape: `.loading`, `.loaded([WatchlistEntry])`, `.empty`, `.error(String)`. Loading state is kept for future-proofing.
10. `WatchlistSortSheetView` interaction model:
    - Opens showing currently active sort option highlighted.
    - Draft mode — no changes applied until the user taps **Apply**.
    - **Cancel** / drag-to-dismiss discards the draft; previous sort remains.
    - **Clear** resets the draft selection to `.dateAdded` (the default). Tapping Apply after Clear passes `.dateAdded` to `fetchAll`. Sheet re-opens showing `.dateAdded` highlighted.
11. Sort is applied by re-calling `WatchlistRepository.fetchAll(sortOrder:)` — no in-feature duplicate sorting logic.
12. No persistence for sort order or any other feature state across cold launches.
13. Only `movieId: Int` is passed to `MovieDetailView` when navigating from the Watchlist tab.
14. No swipe-to-delete on Watchlist rows; removal is only from `MovieDetailView`.
15. Loading state is retained for future-proofing.
16. Empty state uses a shared `EmptyStateView` component from the shared UI components target; the Watchlist feature owns only the copy string.
17. SwiftUI Previews: three states — populated (2 entries), empty, error. View renders from screen state only; it does not access the repository directly, so no mock repository is needed for previews.
18. `WatchlistSortSheetView` preview strategy deferred to implementation with the concrete architecture pattern.
19. No haptic feedback (no swipe-to-delete).
20. No tab badge for watchlist entry count.
21. No VoiceOver or accessibility requirements for MVP.
22. **Clear** in the sort sheet resets to `.dateAdded` (Option A); the list always has a predictable order.

---

## Matched Recommendations

- **Rec 5 — Accepted**: No swipe-to-delete for MVP; removal is deferred and only available from `MovieDetailView`.
- **Rec 6 — Accepted**: `WatchlistSortOrder` default (`.dateAdded`) is hardcoded as the initial value in the feature's ephemeral state; no `UserDefaults` or `@AppStorage`.
- **Rec 7 — Accepted**: Empty state copy is owned by the feature layer; the shared `EmptyStateView` component accepts copy as a parameter.
- **Rec 8 — Accepted**: SwiftData read failure surfaces as `ErrorStateView` with a retry affordance using non-network-error language.
- **Rec 1 — Rejected**: `onAppear` re-fetch chosen over reactive observation streams for MVP simplicity.
- **Rec 2 — Rejected**: Loading state is kept despite synchronous SwiftData reads, for future-proofing.
- **Rec 3 — Rejected**: `TMDBClient.fetchPosterData` is the canonical poster URL constructor; no separate utility type is added.
- **Rec 4 — Rejected**: Apply button approach chosen over immediate-on-tap sort (draft sheet model).
- **Rec 9 — Rejected**: View renders from screen state only; no mock repository needed for previews.
- **Rec 10 — Rejected**: VoiceOver and accessibility deferred to post-MVP.

---

## Summary

### a. Feature Scope & Responsibility Boundary

**In scope:**
- `WatchlistListView` — scrollable list of local watchlist entries with sort, loading, empty, and error states.
- `WatchlistSortSheetView` — draft sort selection sheet with Apply, Cancel, and Clear actions.
- Navigation from `WatchlistListView` → `MovieDetailView` (push onto Watchlist tab's `NavigationStack`).

**Explicitly out of scope / delegated:**
- Removal of watchlist entries — only possible from `MovieDetailView` (MovieDetail feature boundary).
- Poster URL construction — delegated to `TMDBClient.fetchPosterData` with size enum.
- Swipe-to-delete on list rows — deferred post-MVP.
- Reactive observation streams — deferred post-MVP; `onAppear` re-fetch is sufficient.
- Review indicator badges on list cards — explicitly excluded (PRD US-038).

---

### b. Service Dependencies

| Service | Protocol | Operations used |
|---|---|---|
| `WatchlistRepository` | `WatchlistRepository` | `fetchAll(sortOrder: WatchlistSortOrder?) throws -> [WatchlistEntry]` |

No other service dependency. `ReviewRepository` is not consumed. Network access is not required for listing.

---

### c. Presentation Logic Per Screen

#### `WatchlistListView`

**Screen state:**
```swift
enum WatchlistViewState {
    case loading
    case loaded([WatchlistEntry])
    case empty
    case error(String)
}
```
Plus `sortOrder: WatchlistSortOrder` (default `.dateAdded`) and `isSortSheetPresented: Bool`.

**User actions and side effects:**

| Action | Side Effect |
|---|---|
| Screen appears (`onAppear`) | Call `fetchAll(sortOrder: currentSortOrder)`; transition to `.loading → .loaded / .empty / .error` |
| Tap sort button | Set `isSortSheetPresented = true`; present `WatchlistSortSheetView` |
| Apply sort (from sheet) | Dismiss sheet; update `sortOrder`; call `fetchAll(sortOrder: selectedOrder)`; update list state |
| Cancel sort (from sheet) | Dismiss sheet; no state change |
| Tap retry (error state) | Call `fetchAll(sortOrder: currentSortOrder)`; transition to `.loading → …` |
| Tap movie card | Push `MovieDetailView` with `movieId: Int` |

**Local state transition rules:**
- `fetchAll` success with non-empty result → `.loaded([WatchlistEntry])`
- `fetchAll` success with empty result → `.empty`
- `fetchAll` throws → `.error(message)`
- Sort changes are only committed to `sortOrder` after Apply is tapped; the draft lives inside the sheet.

#### `WatchlistSortSheetView`

**Screen state (draft):**
- `draftSortOrder: WatchlistSortOrder` — initialized to the currently active `sortOrder` when the sheet opens.
- Currently active sort option is highlighted on open.

**Actions:**
- **Apply**: commits `draftSortOrder` to the parent; sheet dismisses.
- **Cancel** / drag-to-dismiss: discards draft; parent `sortOrder` unchanged.
- **Clear**: sets `draftSortOrder = .dateAdded`; sheet remains open; user must tap Apply to commit.

---

### d. State Shape & Ownership

| State | Owner | Lifetime |
|---|---|---|
| `viewState: WatchlistViewState` | `WatchlistListView` presentation unit | Screen lifetime; set to `.loading` at each `onAppear` before fetch |
| `sortOrder: WatchlistSortOrder` | `WatchlistListView` presentation unit | In-memory session; initialized to `.dateAdded` on cold launch; never persisted |
| `draftSortOrder: WatchlistSortOrder` | `WatchlistSortSheetView` | Sheet lifetime; discarded on Cancel/dismiss |
| `isSortSheetPresented: Bool` | `WatchlistListView` presentation unit | Transient |

No state is shared across features. All operations are synchronous, main-thread, and triggered by user action or `onAppear` — no concurrent service update handling required.

---

### e. Navigation & Routing

- **Entry point**: `WatchlistListView` is the root of the Watchlist tab's `NavigationStack`; activated by tapping the Watchlist tab.
- **MovieDetail entry**: tapping any `MovieCardView` row pushes `MovieDetailView` with `movieId: Int` onto the Watchlist tab's `NavigationStack`.
- **Pop-back behavior**: `onAppear` on `WatchlistListView` fires when `MovieDetailView` is popped, re-fetching the list to reflect any add/remove that occurred in detail.
- **Sort sheet**: presented as `.sheet` from `WatchlistListView`; internal to this feature.
- No deep link entry points. No cross-tab navigation. No full-screen covers owned by this feature.

---

### f. User Interactions & Validation

No form fields or text input. No validation rules. No confirmation dialogs owned by this feature.

Sort sheet:
- Single-select from three options (`.dateAdded`, `.title`, `.voteAverage`).
- All options always valid; no validation needed.
- Clear resets draft to `.dateAdded`; Apply commits; Cancel discards.

---

### g. Transient State Treatment

| Screen | Loading | Empty | Error | Success |
|---|---|---|---|---|
| `WatchlistListView` | Loading indicator while `fetchAll` is in progress | `EmptyStateView` with feature-owned copy (no network-error tone) | `ErrorStateView` with retry button; copy must not imply a network failure | Scrollable list of `MovieCardView` rows |

- No optimistic updates — all mutations originate from `MovieDetailView` and are reflected on the next `onAppear`.
- `.loading` state is retained for future-proofing.

---

### h. SwiftUI Previews Strategy

Three preview scenarios for `WatchlistListView`:
1. **Populated** — screen state set to `.loaded` with 2 static `WatchlistEntry` values.
2. **Empty** — screen state set to `.empty`.
3. **Error** — screen state set to `.error("Unable to load your watchlist")`.

View renders from screen state only. No repository access in the view layer; no mock repository needed.

`WatchlistSortSheetView` preview deferred to implementation once the concrete architecture pattern is confirmed.

---

### i. iOS-Specific UI Concerns

- **Keyboard avoidance**: not applicable — no text input.
- **Haptic feedback**: not applicable — no mutations in this feature.
- **Deep links**: not in scope.
- **Share sheet**: not in scope.
- **Widget / Live Activity**: not in scope.
- **App lifecycle**: `onAppear` covers re-entry from background and pop-back naturally; no additional lifecycle handling needed.
- **Poster images**: loaded from TMDB CDN URLs via `TMDBClient.fetchPosterData` with the appropriate size enum case.

---

### j. Accessibility

Deferred to post-MVP. No VoiceOver labels, Dynamic Type customization, or Reduce Motion handling required for the initial implementation.

---

### k. Analytics & Tracked Events

Not specified in the PRD. No analytics events defined for this feature.

---

### l. Testing Strategy

- **Presentation logic unit tests**: verify state transitions for `fetchAll` success (populated), `fetchAll` success (empty), `fetchAll` throws, sort change via Apply, Cancel (no state change), Clear + Apply (`.dateAdded` applied). Inject a fake `WatchlistRepository` conformance.
- **Service interaction tests**: verify that `fetchAll(sortOrder:)` is called on `onAppear` and on Apply with the correct `sortOrder` argument.
- **UI tests**: optional; the three SwiftUI preview states cover the primary visual outcomes.

---

### m. Deferred Items

| Item | Reason |
|---|---|
| Swipe-to-delete on Watchlist rows | Not in PRD; deferred post-MVP |
| Reactive observation (AsyncStream, Combine, @Query) | `onAppear` re-fetch sufficient for MVP |
| `WatchlistSortSheetView` SwiftUI Preview | Deferred to implementation once architecture pattern is confirmed |
| VoiceOver / accessibility | Post-MVP |
| Analytics | Not specified in PRD |
| Tab badge for watchlist entry count | Explicitly excluded |

---

### n. Unresolved Issues

None. All planning questions have been answered and all recommendations matched to explicit decisions.
