# UI Scaffolding Plan for Movie Tracker

## 1. Overview

The navigation skeleton is a three-tab `TabView` (Catalog, Search, Watchlist) where each tab owns an independent `NavigationStack`. Movie Detail is the single shared destination pushed onto whichever tab's stack initiated the navigation. The review wizard is presented as a `.fullScreenCover` from Movie Detail. Filter and sort controls use `.sheet`. There is no authentication gate, onboarding flow, or splash screen — the app launches directly into the tab bar with Catalog selected. No navigation state is persisted across launches. The app is iPhone-only with no iPad adaptation.

---

## 2. Screen Inventory

| Screen | Owning Feature | Presentation Style | Purpose | Key Data Entities |
|---|---|---|---|---|
| `CatalogListView` | Catalog | Root tab destination | Scrollable list of trending movies (first-page `/trending/movie/week`) with inline error/empty/loading state | `Movie` |
| `SearchListView` | Search | Root tab destination | Search query input, results list, filter badge indicator, filter and sort triggers | `Movie`, `Genre` |
| `WatchlistListView` | Watchlist | Root tab destination | Local watchlist entries list, sort trigger, empty state when no entries | `WatchlistEntry` |
| `MovieDetailView` | MovieDetail | Pushed onto tab's `NavigationStack` | Full movie detail: poster, synopsis, genres, release date, rating, cast, watchlist CTA, review summary or "Log a Review" CTA | `MovieDetail`, `WatchlistEntry`, `Review` |
| `ReviewWizardView` | Review | `.fullScreenCover` from `MovieDetailView` | Four-step guided review create/edit flow; internal step progression managed within the cover | `Review`, `ReviewTag` |
| `SearchFilterSheetView` | Search | `.sheet` from `SearchListView` | Genre multi-select, minimum rating, release year range, clear-all; drag-to-dismiss acts as cancel | `Genre` |
| `SearchSortSheetView` | Search | `.sheet` from `SearchListView` | Sort selection for search results (release date / title / rating); drag-to-dismiss acts as cancel | — |
| `WatchlistSortSheetView` | Watchlist | `.sheet` from `WatchlistListView` | Sort selection for watchlist (date added / title / rating); drag-to-dismiss acts as cancel | — |

---

## 3. Root Navigation Structure

The root container is a `TabView` with three tabs in order: **Catalog**, **Search**, **Watchlist**. Tab items use `.tabItem` labels with SF Symbol icons provided by the DesignSystem package. Catalog is always the selected tab on cold launch; the selected tab index is not persisted.

Each tab owns an independent `NavigationStack`. This means back-navigation state is preserved per tab when the user switches between tabs during a session.

```
TabView
├── [Tab 1] Catalog
│   └── NavigationStack
│       └── CatalogListView                      ← root
│           └── MovieDetailView                  ← pushed
│               └── ReviewWizardView             ← .fullScreenCover
│
├── [Tab 2] Search
│   └── NavigationStack
│       └── SearchListView                       ← root
│           ├── SearchFilterSheetView            ← .sheet
│           ├── SearchSortSheetView              ← .sheet
│           └── MovieDetailView                  ← pushed
│               └── ReviewWizardView             ← .fullScreenCover
│
└── [Tab 3] Watchlist
    └── NavigationStack
        └── WatchlistListView                    ← root
            ├── WatchlistSortSheetView           ← .sheet
            └── MovieDetailView                  ← pushed
                └── ReviewWizardView             ← .fullScreenCover
```

No tab re-selection behavior is implemented — tapping the already-active tab does nothing.

---

## 4. Authentication & Onboarding Gate

Not applicable. There is no auth gate, splash screen, or onboarding wrapper. The navigation graph starts directly at the `TabView` on every cold launch.

---

## 5. Feature Entry Points

| Feature | Entry Point Screen | Presentation Style & Trigger | Prerequisite State |
|---|---|---|---|
| Catalog | `CatalogListView` | Root tab destination; selected on cold launch | None |
| Search | `SearchListView` | Root tab destination; user taps Search tab | None |
| Watchlist | `WatchlistListView` | Root tab destination; user taps Watchlist tab | None |
| MovieDetail | `MovieDetailView` | Push onto active tab's `NavigationStack`; user taps any movie card | A `Movie` or `WatchlistEntry` with a TMDB movie id |
| Review (create) | `ReviewWizardView` (step 1) | `.fullScreenCover` from `MovieDetailView`; user taps "Log a Review" | `MovieDetailView` open; no existing `Review` for that `movieId` |
| Review (edit) | `ReviewWizardView` (step 1, prepopulated) | `.fullScreenCover` from `MovieDetailView`; user taps "Edit Review" | `MovieDetailView` open; an existing `Review` for that `movieId` |

---

## 6. Cross-Feature Navigation Flows

| Source Feature | Source Screen | Destination Feature | Destination Screen | Owning Feature | Presentation Style | Data Passed |
|---|---|---|---|---|---|---|
| Catalog | `CatalogListView` | MovieDetail | `MovieDetailView` | MovieDetail | Push onto Catalog's `NavigationStack` | TMDB `movieId` (Int) |
| Search | `SearchListView` | MovieDetail | `MovieDetailView` | MovieDetail | Push onto Search's `NavigationStack` | TMDB `movieId` (Int) |
| Watchlist | `WatchlistListView` | MovieDetail | `MovieDetailView` | MovieDetail | Push onto Watchlist's `NavigationStack` | TMDB `movieId` (Int) |
| MovieDetail | `MovieDetailView` | Review | `ReviewWizardView` | Review | `.fullScreenCover` | `movieId` (Int); for edit, existing `Review` for prepopulation |

No cross-tab navigation occurs. Each tab maintains its own independent stack. `MovieDetailView` is logically shared but instantiated within each tab's own stack — there is no stack-crossing.

---

## 7. Shared Container Screens

| Screen / Component | Role | Features That Use It |
|---|---|---|
| Root `TabView` | Top-level navigation container; hosts all three tab stacks | Catalog, Search, Watchlist |
| `MovieCardView` (shared UI package) | Reusable list-card component; not a screen, but a shared view used as list row | Catalog, Search, Watchlist |
| `ErrorStateView` (shared UI package) | Inline error message + retry affordance; embedded within list/detail content areas | Catalog, Search, Watchlist, MovieDetail (cast section) |
| `EmptyStateView` (shared UI package) | Inline empty state; embedded within list/content areas | Search (no results / pre-search prompt), Watchlist (no entries) |
| Loading state component (shared UI package) | Inline loading indicator; embedded within async-loading list/detail areas | Catalog, Search, Watchlist, MovieDetail |

The shared UI package is distinct from DesignSystem. DesignSystem is strictly a token/resource package (fonts, colors, SF Symbol references, spacing). No functional UI components live in DesignSystem.

---

## 8. Deep Linking Map

Not in scope. No URL scheme, universal link handling, or external navigation entry points are required for this MVP.

---

## 9. Device Class Adaptation

iPhone-only. No iPad layout adaptation, no `NavigationSplitView`, no sidebar navigation, and no multi-window or Scene-based lifecycle requirements beyond the default single-window SwiftUI app lifecycle.

---

## 10. Navigation State Restoration

None. All `NavigationStack` paths (and TCA `StackState` equivalents) reset to their root list screen on cold launch. The selected tab index resets to Catalog. No stack state, scroll position, sheet presentation state, or filter/sort selection is serialized or restored across launches.

---

## 11. Error, Empty-State & Offline Handling

All error and empty states are handled **inline** within each screen's content area — no dedicated error screens, fullscreen error covers, or global network-status overlays.

| Context | Error Handling | Empty-State Handling |
|---|---|---|
| Catalog list | `ErrorStateView` inline in list area; retry re-issues `/trending/movie/week` | `EmptyStateView` inline (only on network failure; trending list is never empty by product definition) |
| Search list | `ErrorStateView` inline in results area; retry re-issues last search request | `EmptyStateView` inline for zero results (distinct from error) and for pre-search prompt state |
| Search genre fetch (filter sheet) | Inline error or disabled genre control within `SearchFilterSheetView`; retry re-issues `/genre/movie/list` | N/A |
| Watchlist list | `ErrorStateView` inline if SwiftData read fails | `EmptyStateView` inline when watchlist has no entries (no network error tone) |
| MovieDetail primary | `ErrorStateView` inline if `/movie/{id}` fails; retry re-fetches detail | N/A |
| MovieDetail cast section | `CastState.notRetrieved` drives hidden or non-fatal placeholder inline within detail screen; does not block watchlist/review CTAs | N/A |

No global offline/no-connectivity screen or blocking overlay is used. Network failures are always surfaced contextually within the relevant screen or section.

`ErrorStateView` and `EmptyStateView` from the shared UI package are the canonical implementations used across all of the above contexts.

---

## 12. Notification-Driven Navigation Targets

Not in scope. No push notification types are defined in the PRD. No notification-to-screen navigation targets are required.

---

## 13. Open Questions / Deferred Decisions

None. All planning questions were resolved in the UI scaffolding planning session. All decisions are recorded in `.ai/ui-scaffolding-planning-session-summary.md`.
