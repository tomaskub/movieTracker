# App Bootstrap — Planning Summary

## Decisions

1. No standalone navigation framework is created. Navigation ownership is distributed — each feature module owns its `NavigationStack` and navigation path state directly in its root view (or its architectural equivalent).
2. Features are structured as separate SPM targets. The feature dependency graph is enforced at compile time via explicit import declarations.
3. Catalog, Search, and Watchlist each declare `MovieDetailFeature` as a direct individual dependency.
4. `MovieDetailFeature` declares `ReviewFeature` as its dependency.
5. Tab features reference `MovieDetailView` via its concrete type (`MovieDetailView(movieId:)`). No factory or builder protocol abstraction is used.
6. Each tab feature owns its own tab bar appearance — SF Symbol name and label string are defined as constants in the feature's public API. The app target reads these values when assembling the `TabView`.
7. The app target has exactly three responsibilities: service construction, tab root view construction (passing in services), and `TabView` assembly. No other logic belongs in the app target.
8. No shared `AppRootView` is extracted. Each branch assembles its `TabView` independently in its own `@main`.
9. Service bootstrap sequence: construct `ModelContainer` (via `PersistenceKit`'s `ModelContainerProvider`) → derive a single `@MainActor`-bound `ModelContext` → construct `NetworkingKit` HTTP client → construct `TMDBClient` (passing the HTTP client) → construct `WatchlistRepository` and `ReviewRepository` (both receiving the shared `ModelContext`).
10. `ModelContainer` initialization failure is handled with `fatalError` with a descriptive message. This is the accepted posture for the study MVP.
11. Both `WatchlistRepository` and `ReviewRepository` share a single `@MainActor`-bound `ModelContext` derived from the `ModelContainer`. This guarantees cross-feature consistency (e.g. an add in Movie Detail is immediately visible in the Watchlist tab without a sync step).
12. Services are passed individually into each tab root view constructor. No `AppDependencies` bundle type is used.
13. Per-architecture DI wiring (SwiftUI environment injection for MVVM, module factory/router patterns for VIPER, `@Dependency` / `DependencyValues` for TCA) is deferred entirely to each branch's implementation plan. This is explicitly a study comparison data point and each branch has full flexibility here.
14. No shared `AppBootstrap` helper is extracted. Each branch's `@main` is written independently to preserve maximum architectural flexibility as a study variable.
15. Navigation path state lives directly in each feature's root view layer — ViewModel for MVVM, Router for VIPER, reducer `StackState` for TCA. Path state is not lifted to the app target.
16. No tab re-selection behavior. Tapping the already-active tab does nothing.

---

## SPM Target Dependency Graph

```
AppTarget (@main)
├── CatalogFeature ──────────┐
├── SearchFeature  ──────────┼──► MovieDetailFeature ──► ReviewFeature
└── WatchlistFeature ────────┘

TMDBClient ──────────────────────► NetworkingKit
WatchlistRepository ─────────────► PersistenceKit
ReviewRepository ────────────────► PersistenceKit

AppTarget ──► CatalogFeature, SearchFeature, WatchlistFeature
AppTarget ──► TMDBClient, WatchlistRepository, ReviewRepository (bootstrap only)
```

Each tab feature also imports the service modules it needs to receive injected dependencies. The app target is the sole site where all service instances are constructed.

---

## Summary

### a. What Lives in the App Target

The app target is the composition root. It is the only place in the codebase where concrete service instances are created and where feature modules are assembled into the `TabView`. It contains no business logic and no shared UI infrastructure.

**`@main` responsibilities (invariant across all three branches):**

1. Construct `ModelContainerProvider` and call `.makeContainer()`. If this throws, call `fatalError` with a descriptive message.
2. Derive a `@MainActor`-bound `ModelContext` from the container.
3. Construct the `NetworkingKit` HTTP client with `NetworkConfiguration` (API key read from `.xcconfig`-backed build config).
4. Construct `TMDBClient` with the HTTP client.
5. Construct `WatchlistRepository` and `ReviewRepository`, both receiving the shared `ModelContext`.
6. Construct the three tab root views, passing each its required services.
7. Assemble the `TabView` using each feature's public tab item metadata (SF Symbol name and label).

**What varies per branch (explicitly not constrained here):**
- How services are passed into feature root views (environment injection, constructor injection, `@Dependency` registration, or factory parameter)
- The concrete type backing each service protocol at the root construction site
- Any additional branch-local setup required by the architecture (e.g. TCA `Store` construction, VIPER module builder wiring)

### b. Feature Module Public API Contract

Each feature module must expose the following as part of its public API for the app target and sibling features to consume:

| Module | Root view type | Tab metadata | Navigation dependency |
|---|---|---|---|
| `CatalogFeature` | `CatalogListView` (owns `NavigationStack`) | `CatalogTab.symbol`, `CatalogTab.label` | `MovieDetailFeature` |
| `SearchFeature` | `SearchListView` (owns `NavigationStack`) | `SearchTab.symbol`, `SearchTab.label` | `MovieDetailFeature` |
| `WatchlistFeature` | `WatchlistListView` (owns `NavigationStack`) | `WatchlistTab.symbol`, `WatchlistTab.label` | `MovieDetailFeature` |
| `MovieDetailFeature` | `MovieDetailView(movieId: Int)` | — | `ReviewFeature` |
| `ReviewFeature` | `ReviewWizardView` (presented as `.fullScreenCover` by MovieDetail) | — | — |

Tab metadata naming convention (`symbol`, `label`) is illustrative. Each branch may choose its own static constant naming as long as the values are public and accessible to the app target.

### c. Service Construction Order

The construction order is fixed and shared across all three branches:

```
ModelContainerProvider
    └── ModelContainer (fatalError on failure)
            └── @MainActor ModelContext
                    ├── WatchlistRepository(context:)
                    └── ReviewRepository(context:)

NetworkConfiguration (API key from build config)
    └── HTTPClient(configuration:)              ← NetworkingKit
            └── TMDBClient(httpClient:)
```

No circular dependencies exist. All services are constructed once and held for the app process lifetime.

### d. Navigation Ownership

Navigation is feature-owned. No navigation framework or shared navigation coordinator exists.

| Feature | Owns | Navigates to |
|---|---|---|
| `CatalogFeature` | `NavigationStack` + path state for Catalog tab | `MovieDetailFeature` (push) |
| `SearchFeature` | `NavigationStack` + path state for Search tab | `MovieDetailFeature` (push) |
| `WatchlistFeature` | `NavigationStack` + path state for Watchlist tab | `MovieDetailFeature` (push) |
| `MovieDetailFeature` | `.fullScreenCover` presentation state | `ReviewFeature` (fullScreenCover) |
| `ReviewFeature` | Internal step navigation | — |

Path state lives in the feature's root view layer. It is never lifted to the app target. Navigation state resets on cold launch across all branches.

### e. Deferred to Each Branch

| Concern | Reason |
|---|---|
| DI wiring mechanism (environment / constructor / `@Dependency`) | Core study variable; each branch chooses its own approach |
| Concrete backing type for each service protocol | Branch-local implementation detail |
| `@main` beyond the invariant bootstrap sequence | Each branch owns its full `@main` with no shared helper |
| TCA `Store` root construction and `DependencyValues` overrides | TCA-branch-local |
| VIPER module builder/assembler patterns | VIPER-branch-local |
| MVVM `EnvironmentKey` / `EnvironmentValues` extensions | MVVM-branch-local |

---

## Unresolved Issues

None. All planning questions have been resolved and all decisions are recorded above.
