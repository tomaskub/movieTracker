# SharedUIComponents Framework Plan for Movie Tracker

## 1. Overview

`SharedUIComponents` is a local Swift Package target inside `MovieTrackerPackage` that provides a small set of reusable, stateless SwiftUI leaf components consumed by all three architectural implementations (MVVM, VIPER, TCA). Its responsibility is to enforce visual consistency across the Catalog, Search, Watchlist, and Movie Detail features for the four recurring UI patterns: list card, loading indicator, inline error (with and without retry), and empty state.

The package has a single declared dependency: the `DesignSystem` target within the same `MovieTrackerPackage`. It introduces no third-party SDKs, no async behavior, no business logic, and no architecture-specific wiring. All components are synchronous, value-typed `View` structs.

Key constraints from the tech stack and PRD:
- iOS 17 minimum deployment target; all SwiftUI APIs used are available on that target.
- The same PRD UI card layout is reproduced identically in Catalog, Search, and Watchlist; a single `MovieCardView` eliminates drift.
- All UI must follow `DesignSystem` tokens (fonts, colors, icons, spacing); this package enforces that by importing `DesignSystem` directly rather than accepting tokens as call-site parameters.

---

## 2. Responsibility & Boundary

### In scope

| Component | Responsibility |
|---|---|
| `MovieCardView` | Renders the movie list card: poster image state (placeholder or resolved image), title, release year, and TMDB rating formatted to one decimal place with a star icon. Used by Catalog, Search, and Watchlist list screens. |
| `MovieCardView.ImageState` | Nested enum owned by the card component; expresses whether a poster image has been resolved (`.image(Image)`) or is unavailable/loading (`.placeholder`). Consumers own image resolution; this type is the hand-off contract. |
| `ErrorStateView` | Inline error display with a user-supplied message and a retry affordance. Used wherever a failed network operation should offer recovery (Catalog list, Search list, Movie Detail primary content). |
| `InlineErrorView` | Non-retry inline error display with a user-supplied message. Used in contexts where no retry is offered (Movie Detail cast section after a failed credits request). |
| `EmptyStateView` | Inline empty state with a `title` and an optional `subtitle`. Used for the Search pre-search prompt, zero-results state, and the empty Watchlist. |
| `LoadingView` | Standalone loading indicator (not an overlay modifier). Used by Catalog, Search, Watchlist, and Movie Detail during in-flight async operations. |

### Explicitly out of scope

| Item | Owner |
|---|---|
| Image resolution and network loading | Feature layers (Catalog, Search, Watchlist). `MovieCardView` receives a pre-resolved `ImageState`. |
| Tap and navigation behavior | Callers. `MovieCardView` carries no tap gesture or `onTap` closure; callers wrap it in a `Button` or `NavigationLink`. |
| Accessibility annotations (`accessibilityLabel`, `accessibilityAddTraits`) | Per-feature implementation. |
| Animation and transition styling | Callers or a future design iteration. |
| DesignSystem token definitions | `DesignSystem` target. |
| Any business logic, data fetching, or state management | Service and feature layers. |

---

## 3. Public API Surface

### `MovieCardView`

- **Kind**: `struct` conforming to `View`
- **Purpose**: Reusable list card for the Catalog, Search, and Watchlist screens. Callers are feature-level list views in all three architecture branches.
- **Key interface**:

```swift
struct MovieCardView: View {
    enum ImageState {
        case placeholder
        case image(Image)
    }
    init(title: String, year: Int, rating: Double, imageState: ImageState)
}
```

- **Rating formatting**: `MovieCardView` owns the formatting of the raw `Double` `vote_average` to a one-decimal-place string with a `DesignSystem` star icon. Callers pass the raw value; presentation is the component's concern.
- **Constraints**: Passive — no gesture recognizers, closures, or environment object reads beyond `DesignSystem` styling.

---

### `ErrorStateView`

- **Kind**: `struct` conforming to `View`
- **Purpose**: Inline error display with a retry affordance. Callers are any screen that performs a network operation and must offer recovery.
- **Key interface**:

```swift
struct ErrorStateView: View {
    init(message: String, onRetry: () -> Void)
}
```

- **Constraints**: `onRetry` is a synchronous closure; callers dispatch any async work inside it.

---

### `InlineErrorView`

- **Kind**: `struct` conforming to `View`
- **Purpose**: Non-fatal inline error display without a retry affordance. Caller is Movie Detail's cast section, which must continue to render primary content when credits fail.
- **Key interface**:

```swift
struct InlineErrorView: View {
    init(message: String)
}
```

- **Constraints**: No interaction affordance. Display-only.

---

### `EmptyStateView`

- **Kind**: `struct` conforming to `View`
- **Purpose**: Inline empty state used for pre-search prompts, zero-results, and empty Watchlist. Caller is any list screen that must differentiate the empty-data state from an error state.
- **Key interface**:

```swift
struct EmptyStateView: View {
    init(title: String, subtitle: String? = nil)
}
```

- **Constraints**: No `@ViewBuilder` body. Fixed layout driven by `DesignSystem` typography.

---

### `LoadingView`

- **Kind**: `struct` conforming to `View`
- **Purpose**: Standalone loading indicator. Used inline inside list areas and detail screens; not a `ViewModifier` overlay. Callers are list and detail screens in all three architecture branches.
- **Key interface**:

```swift
struct LoadingView: View
```

- **Constraints**: No parameters. `DesignSystem` determines spinner style and color.

---

## 4. Abstraction Depth

**Thin composition.** Each component wraps a small number of SwiftUI primitives (`Image`, `Text`, `ProgressView`, `Button`, `VStack`, `HStack`, etc.) styled exclusively with `DesignSystem` tokens. No view models, `ObservableObject`, `@State`, or state machines are introduced inside the package.

The sole domain-aware type is `MovieCardView.ImageState`, which exists because consumers need a typed hand-off point for poster resolution. It is owned as a nested type to keep the namespace tight and signal that it is part of the card's contract only.

Rationale for this depth:
- The PRD mandates a consistent card layout across three screens and three architecture branches. A flat-parameter view struct enforces that parity without over-engineering for a fixed MVP layout.
- A view-model struct or protocol layer would add indirection with no decoupling benefit at this layer — the components are leaves with no swappable implementations.
- If a second card variant or layout mode is ever required, the flat parameter list is the natural extension point; a view-model struct can be introduced at that point.

---

## 5. Third-Party SDK Isolation

No third-party SDKs are involved. The only declared dependency is the `DesignSystem` target within `MovieTrackerPackage`. No SDK wrapping is required.

---

## 6. Testability

### XCTest coverage

Two behaviors in this package are stateful or computational and therefore warrant unit tests:

1. **`MovieCardView.ImageState` switching logic** — verify that consumers can round-trip `.placeholder` and `.image(Image)` values and that equality/identity behaves as expected.
2. **Rating formatting** — verify that a raw `Double` `vote_average` (e.g. `7.348`) is formatted to the expected one-decimal-place string (e.g. `"7.3"`) by the card component's internal formatting logic. This logic should be extracted to an internal testable function or property.

### Xcode Previews

Previews cover rendering correctness for all visual states:
- `MovieCardView` with `.placeholder` image state.
- `MovieCardView` with `.image(Image)` image state.
- `ErrorStateView` with a sample message and a no-op retry closure.
- `InlineErrorView` with a sample message.
- `EmptyStateView` with title only.
- `EmptyStateView` with title and subtitle.
- `LoadingView` standalone.

### Test helpers

No fake or in-memory implementations are required — the components have no async behavior or system resource dependencies. No snapshot testing framework is introduced; the tech stack does not include one.

---

## 7. Concurrency Model

Not applicable in a meaningful sense. All components are synchronous, stateless `View` structs with no `async` functions, `@MainActor` constraints, actors, `Task` creation, or Combine publishers. SwiftUI renders them on the main thread by framework contract.

The `onRetry` closure on `ErrorStateView` is synchronous; callers are responsible for dispatching any `async` work (e.g. `Task { await viewModel.reload() }`) inside the closure. This keeps the component's responsibility surface minimal.

---

## 8. Error Handling

Not applicable. `SharedUIComponents` performs no fallible operations. `ErrorStateView` and `InlineErrorView` accept and display error message strings provided by callers; they do not generate, own, or propagate error types. Error domain ownership remains entirely with the service and feature layers.

---

## 9. Initialization & Configuration

Each component is initialized directly at the call site with its value-type parameters. No shared singleton, environment object, factory, or dependency injection seam is required.

`DesignSystem` tokens are accessed via the standard `DesignSystem` API (static properties or SwiftUI environment values, as defined in the DesignSystem plan). No bootstrap sequence is needed before using any component.

**Package manifest:** `SharedUIComponents` is declared as a target in `MovieTrackerPackage/Package.swift` with a single target dependency on `DesignSystem`:

```swift
.target(
    name: "SharedUIComponents",
    dependencies: ["DesignSystem"]
)
```

All three architecture branch targets (MVVM, VIPER, TCA) consume `SharedUIComponents` through the same package manifest. No per-branch configuration is required.

---

## 10. Platform & OS Constraints

- **Minimum deployment target**: iOS 17, consistent with the project tech stack.
- All SwiftUI primitives used (`Image`, `Text`, `ProgressView`, `Button`, `VStack`, `HStack`, `Spacer`) are available on iOS 17. No `#available` guards are anticipated.
- **iPhone-only**: No iPad-adaptive layout or size-class branching is required.
- No entitlements, background execution, privacy manifest entries, or capability configurations are required by this framework. It is a pure UI composition package with no system resource access.

---

## 11. Deferred / Out of Scope for MVP

| Deferred item | Rationale | Trigger to revisit |
|---|---|---|
| Accessibility annotations (`accessibilityLabel`, `accessibilityAddTraits`, `accessibilityElement`) | Deferred to per-feature implementation; accessibility requirements are not specified in the PRD for MVP. | Formal accessibility audit or App Store submission requirement. |
| Animation and transition styling for components | Not specified in PRD; left to callers or a future design iteration. | A DesignSystem update that prescribes motion behavior. |
| Second card variant or layout modes for `MovieCardView` | The flat parameter list is intentionally minimal for a fixed MVP card layout. A view-model struct or multiple layout variants would be warranted only if a second card style is required. | New screen requiring a different card shape. |
| `@ViewBuilder` body slot on `EmptyStateView` | Not needed for the three current empty-state use cases (pre-search prompt, zero results, empty watchlist). | A context requiring custom illustration or action inside the empty state. |

---

## 12. Open Questions / Unresolved Decisions

| Issue | What is unknown | Information needed to resolve |
|---|---|---|
| **`InlineErrorView` public type name** | The exact public type name for the non-retry error variant (candidate names: `InlineErrorView`, `CastUnavailableView`) was not settled during the planning session. | Implementation team decision at the time the type is authored. Should be documented and consistent across all three architecture branches. |
