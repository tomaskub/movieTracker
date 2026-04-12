# SharedUIComponents Framework Planning Summary

<conversation_summary>
<decisions>

1. **Package identity:** `SharedUIComponents` is implemented as a separate target inside `MovieTrackerPackage` — not a standalone Swift Package. It lives alongside the other targets in the monorepo package.
2. **Image state enum:** Nested type — `MovieCardView.ImageState` — with cases `.placeholder` and `.image(Image)`. Placeholder image is provided by the component itself.
3. **`MovieCardView` data contract:** Flat individual parameters: `title: String`, `year: Int`, `rating: Double`, `imageState: MovieCardView.ImageState`.
4. **`MovieCardView` interaction model:** Passive view. `MovieCardView` owns no tap gesture and carries no `onTap` closure. Callers wrap it in a `Button` or `NavigationLink` appropriate to their architecture.
5. **Error state components:** Two separate components — `ErrorStateView` (with retry affordance) and a separate non-retry variant for contexts such as the Movie Detail cast section where no retry is offered.
6. **`EmptyStateView` interface:** `title: String` and `subtitle: String?` properties. No `@ViewBuilder` body.
7. **Loading indicator:** Simple standalone `LoadingView` struct. No `ViewModifier` overlay variant.
8. **DesignSystem coupling:** `SharedUIComponents` declares `DesignSystem` as an explicit target dependency. Token values are not passed as parameters at call sites.
9. **Poster image loading:** Final per Issue 4. `MovieCardView` accepts only `MovieCardView.ImageState`. No `URL`/`AsyncImage` convenience path is added. Consumers own image resolution entirely.
10. **Testability:** XCTest covers `MovieCardView.ImageState` switching logic and rating formatting. Xcode Previews cover rendering correctness for all visual states. No snapshot testing framework.
11. **Accessibility:** Out of scope for this planning session. Deferred to per-feature implementation.
12. **Rating formatting:** Owned by `MovieCardView`. Formats `vote_average: Double` to one decimal place with a DesignSystem star icon. Callers pass the raw `Double`; the component handles presentation.

</decisions>
<matched_recommendations>

1. **Local target in MovieTrackerPackage** — consistent with how DesignSystem is structured; dependency graph is explicit; works cleanly across all three architectural branches.
2. **Nested `MovieCardView.ImageState`** — tight namespace; signals clearly that the enum is part of `MovieCardView`'s contract.
3. **Flat parameters** — sufficient for a fixed MVP card layout; no indirection overhead of a view-model struct.
4. **Passive view** — lowest coupling; MVVM `NavigationLink`, VIPER tap callbacks, and TCA `Button(action:)` all compose around it naturally.
5. **Two separate error components** — cleaner separation than an optional retry parameter; each component has a single, unambiguous responsibility.
6. **`title` + optional `subtitle`** — covers all three `EmptyStateView` contexts (pre-search prompt, zero results, empty watchlist) without `@ViewBuilder` complexity.
7. **Standalone `LoadingView` struct** — avoids overlay layer conflicts with list-based layouts in Catalog/Search/Watchlist.
8. **Explicit DesignSystem dependency** — every caller already depends on DesignSystem; passing tokens as parameters would produce a verbose API with no real decoupling benefit.
9. **No `AsyncImage` path** — keeps the component's responsibility surface minimal; avoids reintroducing dual code paths and ambiguity about ownership.
10. **XCTest for logic, Previews for rendering** — consistent with the project's existing test stance (XCTest + in-memory containers; no snapshot framework in tech stack).
12. **`MovieCardView` owns rating formatting** — enforces consistent presentation across Catalog, Search, and Watchlist; callers pass raw `Double`.

</matched_recommendations>
<ios_framework_planning_summary>

## a. Confirmed Responsibility and Boundaries

**In scope:**
- `MovieCardView` — reusable list-card component displaying poster image state, title, release year, and TMDB rating. Used by Catalog, Search, and Watchlist list screens.
- `ErrorStateView` — inline error message with a retry affordance. Used by Catalog list, Search list, Watchlist list, and Movie Detail primary content.
- `CastErrorView` (or equivalent non-retry variant) — inline non-fatal error indicator for contexts where no retry is offered (Movie Detail cast section). Two separate components, not a single parameterised one.
- `EmptyStateView` — inline empty state with `title` and optional `subtitle`. Used by Search (pre-search prompt and zero results) and Watchlist (no entries).
- `LoadingView` — simple standalone inline loading indicator. Used by Catalog, Search, Watchlist list areas, and Movie Detail during async loads.

**Explicitly out of scope (deferred or owned elsewhere):**
- Image resolution and loading — owned by consumers (Catalog, Search, Watchlist feature layers). `MovieCardView` receives a resolved `MovieCardView.ImageState`; it never calls `TMDBClient` or `AsyncImage`.
- Tap / navigation behavior — owned by callers. `MovieCardView` is a passive `View`.
- Accessibility annotations — deferred to per-feature implementation.
- Business logic of any kind — this package is pure UI composition using DesignSystem tokens.
- DesignSystem tokens themselves — provided by the `DesignSystem` target, not redefined here.

## b. Protocol and Interface Design

No protocols are exposed. All components are concrete `View` structs with value-type inputs. The public API surface is:

```swift
// MovieCardView
struct MovieCardView: View {
    enum ImageState {
        case placeholder
        case image(Image)
    }
    init(title: String, year: Int, rating: Double, imageState: ImageState)
}

// ErrorStateView (with retry)
struct ErrorStateView: View {
    init(message: String, onRetry: () -> Void)
}

// Non-retry error variant (name TBD at implementation — e.g. CastUnavailableView or InlineErrorView)
struct InlineErrorView: View {
    init(message: String)
}

// EmptyStateView
struct EmptyStateView: View {
    init(title: String, subtitle: String? = nil)
}

// LoadingView
struct LoadingView: View
```

No protocol abstraction layer is needed — these are leaf UI components with no async behavior or swappable implementations.

## c. Abstraction Depth

Thin, purposeful composition. Each component wraps a small number of SwiftUI primitives (images, text, buttons, progress views) styled with DesignSystem tokens. No richer abstraction (view models, observable objects, state machines) is introduced inside the package. The `MovieCardView.ImageState` enum is the only domain-aware type; it is owned by the component as a nested type and requires no external dependencies.

## d. Third-Party SDK Isolation

Not applicable. `SharedUIComponents` has no third-party SDK dependencies. Its only declared dependency is the `DesignSystem` target within `MovieTrackerPackage`. No SDK wrapping is required.

## e. Testability Strategy

- **XCTest:** Covers `MovieCardView.ImageState` case switching logic and the `vote_average: Double` → formatted rating `String` conversion. These are the only meaningful stateful or computational behaviors in the package.
- **Xcode Previews:** Cover rendering correctness — all `ImageState` cases, `ErrorStateView` with retry, non-retry error variant, `EmptyStateView` title-only and title+subtitle, and `LoadingView`.
- **No snapshot testing framework** — not present in the tech stack; not introduced by this package.

## f. Concurrency Model

Not applicable. All components are synchronous, stateless `View` structs. No `async` functions, `@MainActor` constraints, actors, or Combine publishers are introduced. Image loading is the consumer's responsibility and happens outside this package.

## g. Error Types and Propagation

Not applicable. `SharedUIComponents` does not perform any fallible operations. `ErrorStateView` and `InlineErrorView` display error strings provided by callers; they do not generate or propagate errors themselves.

## h. Initialization and Configuration

Each component is initialized directly at the call site with its value-type parameters. No shared singleton, environment object, or factory is required. `DesignSystem` tokens are accessed via the standard DesignSystem API (static properties or environment values, as defined in the DesignSystem plan). No bootstrap sequence is needed.

The `SharedUIComponents` target is declared in `MovieTrackerPackage`'s `Package.swift` with a dependency on the `DesignSystem` target. All three architectural branch targets (MVVM, VIPER, TCA) consume `SharedUIComponents` through the same package manifest.

## i. OS Version and Platform Constraints

- **Minimum deployment target:** iOS 17, consistent with the project tech stack.
- All SwiftUI APIs used (`Image`, `ProgressView`, `Text`, `Button`, `VStack`, etc.) are available on iOS 17.
- No conditional API availability gates (`#available`) are anticipated.
- iPhone-only; no iPad adaptive layout required.

## j. Aspects Deferred to a Later Iteration

- **Accessibility** — `accessibilityLabel`, `accessibilityAddTraits`, and `accessibilityElement` configuration are deferred to per-feature implementation. The plan does not prescribe a shared accessibility contract.
- **Animation / transition styling** — not specified; left to callers or a future design iteration.
- **Second card variant or layout modes** — the flat parameter list on `MovieCardView` is intentionally minimal for MVP; a view-model struct or multiple layout variants are deferred if a second card style is ever required.
- **Non-retry error variant naming** — exact type name (`InlineErrorView`, `CastUnavailableView`, etc.) is left to the implementation plan.

</ios_framework_planning_summary>
<unresolved_issues>

- **Non-retry error component name:** The exact public type name for the cast-section error indicator (the variant of `ErrorStateView` without a retry affordance) was not decided. The implementation plan should settle on one name and document it.

</unresolved_issues>
</conversation_summary>
