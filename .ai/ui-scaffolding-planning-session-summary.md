# UI Scaffolding Planning Session — Movie Tracker

## Decisions

1. Root navigation uses `TabView` with `.tabItem` labels. DesignSystem provides SF Symbol tab icons. Three tabs: Catalog, Search, Watchlist — in that order.
2. Catalog tab is always selected on cold launch. No tab selection persistence.
3. Movie Detail is pushed onto each tab's own `NavigationStack` (not presented modally).
4. Each tab owns an independent `NavigationStack`.
   - **MVVM**: ViewModel holds `@Published var path: NavigationPath` per tab.
   - **VIPER**: Router is `ObservableObject` with `@Published var path: NavigationPath`; the View binds to it.
   - **TCA**: `NavigationPath` is replaced with `StackState<DestinationFeature>` per tab inside a reducer; driven by `NavigationStackStore` in the view.
5. Review wizard is presented as `.fullScreenCover` from Movie Detail.
   - **MVVM**: ViewModel exposes a `@Published` boolean/optional flag.
   - **VIPER**: Router exposes a `@Published` presentation flag observed by the View.
   - **TCA**: Uses `@Presents` / `ifLet` scope on the parent feature reducer.
6. Search filter sheet uses `.sheet` with automatic sizing and drag-to-dismiss (dismiss = cancel/discard).
   - Same pattern adaptations per architecture as decision 5.
7. No action on tab re-selection.
8. Navigation state resets on cold launch. No `NavigationPath` or `StackState` serialization.
9. Review deletion uses `.confirmationDialog`.
10. Error states and empty states are shared reusable components in a separate shared package (not DesignSystem).
11. Deep linking is out of scope.
12. iPad is out of scope. iPhone-only.
13. App launches directly into the tab bar — no splash, onboarding, or auth gate.
14. A separate shared UI package (distinct from DesignSystem) provides: `MovieCardView`, `ErrorStateView`, `EmptyStateView`, and a loading state component. DesignSystem is strictly a token/resource package.
15. Sort control is a `.sheet` (consistent between Search and Watchlist, mirroring the filter sheet pattern).
    - Same architecture adaptation pattern as decisions 5 and 6.

## Matched Recommendations

1. Each tab owns an independent `NavigationStack` — accepted.
2. Movie Detail uses typed push navigation within each tab's stack — accepted, with TCA using `StackState` instead of raw `NavigationPath`.
3. `.fullScreenCover` for the review wizard — accepted.
4. `.sheet` for the search filter panel with drag-to-dismiss acting as cancel — accepted.
5. No onboarding or auth gate — direct tab bar launch — accepted.
6. Shared `ErrorStateView` and `EmptyStateView` components — accepted, housed in a separate shared package, not DesignSystem.
7. Catalog tab as the default selected tab on cold launch — accepted.
8. No navigation state restoration — accepted.
9. `.confirmationDialog` for review deletion — accepted.
10. Sort control as a separate `.sheet` — replaces the original toolbar `Menu` recommendation per user decision.
11. Cast section degrades inline via `CastState` — does not block the detail screen — accepted.
12. Filter active state shown via tinted icon/badge on the Search toolbar — accepted.
13. iPhone-only, no iPad adaptation — accepted.
14. No deep link infrastructure for MVP — accepted.

## Summary

### Root Navigation Structure

The app root is a `TabView` with three tabs — **Catalog**, **Search**, **Watchlist** — in that order. Tabs use `.tabItem` labels with SF Symbol icons provided by the DesignSystem package. Catalog is always the selected tab on cold launch with no persistence of the selected tab index. There is no onboarding flow, splash screen, or authentication gate; the app launches directly into the tab bar.

### Navigation Container Per Tab

Each tab owns an independent `NavigationStack`. This ensures back-navigation state is preserved per tab when the user switches between them. Architecture-specific wiring:

- **MVVM**: each tab's ViewModel holds a `@Published var path: NavigationPath`; the View binds to it.
- **VIPER**: the tab's Router is `ObservableObject` with a `@Published var path: NavigationPath`; the View observes it. This is the agreed SwiftUI-VIPER router adaptation pattern used consistently across all VIPER flows.
- **TCA**: raw `NavigationPath` is replaced with `StackState<DestinationFeature>` inside a per-tab reducer, driven by `NavigationStackStore` in the view. This preserves TCA's structured, testable navigation.

Navigation state resets on cold launch across all three variants. No stack state is serialized.

### Feature Entry Points and Presentation Styles

| Destination | Trigger | Presentation style |
|---|---|---|
| Movie Detail | Tap any movie card (Catalog, Search, Watchlist) | Push onto tab's `NavigationStack` |
| Review wizard (create / edit) | "Log a Review" / "Edit Review" on Movie Detail | `.fullScreenCover` |
| Search filter panel | Filter button on Search tab | `.sheet` (automatic sizing, drag-to-dismiss = cancel) |
| Sort panel | Sort button on Search or Watchlist tab | `.sheet` (automatic sizing, drag-to-dismiss = cancel) |
| Delete confirmation | "Delete Review" on Movie Detail | `.confirmationDialog` |

No tab re-selection behavior is implemented (tapping the active tab does nothing).

### Authentication and Onboarding

Not applicable. No auth gate, no onboarding wrapper. The navigation graph starts at the `TabView`.

### Cross-Feature Navigation Flows

Movie Detail is reached from three separate tab contexts (Catalog, Search, Watchlist) but is a single shared destination. Each tab's own `NavigationStack` pushes Movie Detail — there is no cross-tab navigation or shared stack. Movie Detail is the hub for all watchlist and review actions; no other cross-feature navigation flows exist.

The review wizard is launched from and returns to Movie Detail regardless of which tab originally opened it.

### Shared and Reusable Components

A dedicated **shared UI package** (separate from DesignSystem) provides:

- `MovieCardView` — used identically in Catalog, Search, and Watchlist list screens
- `ErrorStateView` — inline error message + retry affordance, used on all network-dependent screens
- `EmptyStateView` — used on Watchlist (no entries) and Search (no results / pre-search prompt)
- Loading state component — used across all async-loading screens

DesignSystem is strictly a token/resource package (fonts, colors, SF Symbol references, spacing). It provides no functional UI components.

### Cast Section Degradation

Movie Detail's cast section is driven by `CastState`. When `.notRetrieved` (credits not yet fetched or fetch failed), the cast section is hidden or shows a non-fatal placeholder — it does not block the rest of the detail screen or the watchlist/review CTAs. This is handled inline within Movie Detail, not as a separate screen or overlay.

### Filter and Sort State

Filter preferences (genre, minimum rating, release year range) and sort selection (Search and Watchlist) are in-memory only. Both are session-scoped: they reset to defaults on cold launch. Filter active state is surfaced via a tinted icon or badge on the Search toolbar filter button. Sort and filter controls both use `.sheet` presentation with identical interaction patterns.

### Error, Empty State, and Offline Handling

All error and empty states are handled **inline** within each screen's list or content area — no dedicated error screens or overlay sheets. Retry affordances are co-located with the error message. `ErrorStateView` and `EmptyStateView` from the shared package are used consistently across Catalog, Search, Watchlist, and Movie Detail (cast section). There is no global offline/network monitor screen.

### Deep Linking and Universal Links

Out of scope for this MVP. No URL scheme or universal link handling is required. The navigation graph does not need to support external entry points.

### Device Class Adaptation

iPhone-only. No iPad layout adaptation, no sidebar navigation, no multi-window support.

### Navigation State Restoration

None. All navigation stacks reset to their root list on cold launch. No `NavigationPath`, `StackState`, or scroll position is serialized or restored.

### Notification-Driven Navigation

Out of scope. No push notification types are defined in the PRD; no notification-to-screen navigation targets are required.

## Unresolved Issues

None. All planning questions have been resolved and all decisions are recorded above.
