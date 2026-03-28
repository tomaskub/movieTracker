# Tech Stack — Movie Tracker

## Platform

- **Minimum OS**: iOS 17
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI

## Persistence

- **Framework**: SwiftData (iOS 17 native)
- **Store type**: SQLite on-disk (production), in-memory (tests)
- **Schema versioning**: `VersionedSchema` from initial release

## Networking

- **Transport**: `URLSession` with async/await
- **API**: TMDB REST v3

## Architecture

**Pattern**: VIPER — each feature module is composed of five roles:

| Role | Responsibility |
|---|---|
| **View** | Passive SwiftUI view; reads `@Observable` Presenter state, forwards user events to Presenter |
| **Interactor** | Business logic; called by Presenter, delegates to Services/Repositories |
| **Presenter** | Marked `@Observable`; transforms Interactor output into view-ready state; owns the Interactor |
| **Entity** | Plain Swift value types (`struct`) representing domain data |
| **Router** | Mutates a shared `NavigationPath` to drive `NavigationStack`; assembles the full V-I-P-E-R graph for each module |

**Navigation**: the root container is a `TabView` with three tabs (Catalog, Search, Watchlist). Each tab owns an independent `NavigationStack` with its own `NavigationPath`. Each tab-root Router owns and mutates its tab's path — path state is never lifted to the app target. This preserves per-tab back-navigation state when the user switches tabs. Sheets and full-screen covers (filter/sort sheets, Review wizard) are presented modally from within the relevant stack, not via path mutation.

**Module assembly**: the Router is also the builder — it instantiates the Interactor, Presenter, and View and wires their protocol references before pushing the destination.

**Service / Repository layer**: Interactors depend on protocol-typed service and repository objects (e.g. `MovieRepository`, `TMDBService`) injected at assembly time; concrete implementations are passed in by the Router.

## Toolchain & deployment
- Xcode 26.2  

## Testing

- **Framework**: XCTest
- **Unit testing**: protocol boundaries between VIPER roles allow each layer (Interactor, Presenter) to be tested in isolation with mock collaborators
- **Persistence isolation**: in-memory `ModelContainer` recreated per test case

## Configuration

- **API key delivery**: build-time environment-backed configuration (`.xcconfig` or equivalent); never stored in SwiftData or exposed in UI

## Design System

- Shared `DesignSystem` package providing fonts, colors, icons, spacing, and other UI tokens used across all three implementations

## Internationalization
Not included in this project scope.

## Observability
Not included in this project scope.

## Security & privacy
Not applicable for this sample application.

## Other
App extensions, widgets, universal links, and performance budgets: not applicable for this sample.
