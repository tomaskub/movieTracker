# PRD — Tab Bar Navigation (Root View)

## 1. Overview

The root view of Movie Tracker is a `TabView` with three persistent tabs: Catalog, Search, and Watchlist. It is the first screen rendered after app launch and remains on screen for the entire session. Each tab hosts its own independent navigation stack. The tab bar is the sole top-level navigation entry point; there is no side menu or other root structure.

Note: link to UI mock images once generated (e.g. `![State](./ui-mock/normal-state.png)`).

---

## 2. UI Mocks

> Reference images placed in `./ui-mock/`. If missing, refer to Section 5 for layout spec.

---

## 3. User Stories

### US-001 — Three-tab root navigation

- **Title:** Access Catalog, Search, and Watchlist from the tab bar
- **Description:** As a user, I want a persistent tab bar so I can switch between browsing trending movies, searching the catalogue, and viewing my watchlist.
- **Acceptance criteria:**
  - Given the app has finished launching, when I view the root UI, then I see exactly three tabs labeled for Catalog, Search, and Watchlist.
  - When I tap each tab, then the corresponding primary screen is shown without requiring a restart.
  - Switching tabs preserves the navigation state of each tab's stack (no stack reset on tab switch).

---

## 4. Functional Requirements

### 4.1 Data loading

| Behavior | Specification |
|---|---|
| Endpoint | None — root view itself performs no network calls |
| Trigger | N/A |
| Pagination | N/A |
| Order | N/A |
| Concurrency | N/A |

### 4.2 States

| State | Condition | UI |
|---|---|---|
| **Normal** | App launched successfully | Three-tab bar rendered; selected tab content shown |

There is no loading, empty, or error state for the root view itself. Each tab's child content manages its own states.

### 4.3 Tab items

| Tab | Label | Icon | DSIcon case |
|---|---|---|---|
| Catalog | "Catalog" | `Image.catalogTab` | `.catalogTab` (`popcorn`) |
| Search | "Search" | `Image.searchTab` | `.searchTab` (`magnifyingglass`) |
| Watchlist | "Watchlist" | `Image.watchlistTab` | `.watchlistTab` (`bookmark`) |

### 4.4 Out of scope for this feature

- Any sort, filter, or content logic — delegated to each child tab feature.
- Deep-link routing into a specific tab or movie detail at launch.
- Badge counts on tab items (e.g. watchlist count).
- Custom tab bar appearance beyond design system tokens.

---

## 5. Screen Layout Specification

### Normal state

```
┌──────────────────────────────────────┐
│                                      │
│                                      │
│         [Active tab content]         │
│                                      │
│                                      │
├──────────────────────────────────────┤
│  🍿 Catalog  🔍 Search  🔖 Watchlist │
│  ─────────                           │ ← selection indicator on active tab
└──────────────────────────────────────┘
```

- Tab bar sits at the bottom of the screen; content fills the area above it.
- The active tab item is tinted with the accent color; inactive items use the secondary label color.

---

## 6. Design System Token Reference

### 6.1 Tab bar

| Element | Token |
|---|---|
| Tab bar background | `.backgroundSecondary` |
| Active tab icon + label | `.foregroundStyle(.accent)` |
| Inactive tab icon + label | `.foregroundStyle(.labelOnDark)` (at reduced opacity per system) |
| Tab icon — Catalog | `Image.catalogTab` |
| Tab icon — Search | `Image.searchTab` |
| Tab icon — Watchlist | `Image.watchlistTab` |

### 6.2 Screen background (each tab's NavigationStack)

| Element | Token |
|---|---|
| Default screen background | `.background(.backgroundPrimary)` |

---

## 7. Component Anatomy

### 7.1 `RootView`

```
RootView()
  // No external inputs; owns tab selection state internally.
```

### 7.2 `RootView` tab enum

```swift
enum RootTab {
    case catalog
    case search
    case watchlist
}
```

Each case maps to a child `NavigationStack` hosted inside the corresponding `TabView` item.

---

## 8. Non-Functional Requirements

| Requirement | Detail |
|---|---|
| Main thread safety | Root view is pure SwiftUI state; no network or background work |
| Accessibility | Each tab item must have an accessibility label matching its visible label ("Catalog", "Search", "Watchlist") |
| Tab state preservation | Switching tabs must not reset a child tab's navigation stack |
| Minimum OS | iOS 17 |

---

## 9. Open Questions

| # | Question | Owner | Status |
|---|---|---|---|
| OQ-1 | Should switching back to the already-selected tab pop the child navigation stack to root (common iOS convention)? | Product / Design | Open |
| OQ-2 | Is a custom `TabView` styling modifier needed, or is the default SwiftUI `tabViewStyle(.automatic)` acceptable? | Design | Open |

---

## 10. Acceptance Checklist

- [ ] App launches and immediately shows a tab bar with exactly three items: Catalog, Search, Watchlist.
- [ ] Each tab label and icon matches the specification in Section 4.3.
- [ ] Tapping each tab displays its corresponding primary screen without an app restart.
- [ ] Active tab item is visually distinguished from inactive items (accent color).
- [ ] Navigation state within a tab (e.g. pushed Movie Detail) is preserved when switching to another tab and returning.
- [ ] No network call is made by the root view itself on launch.
- [ ] All three tab items have correct VoiceOver accessibility labels.
