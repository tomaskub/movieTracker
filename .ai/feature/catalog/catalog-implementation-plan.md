# Catalog Feature Implementation Plan

## Presentation Architecture

VIPER with `@Observable` Presenter. Five roles for `CatalogFeature`:

| Role | Concrete type | Responsibility |
|---|---|---|
| View | `CatalogView` | Passive SwiftUI view; reads `CatalogPresenter`, forwards user events to Presenter |
| Interactor | `CatalogInteractor` / `CatalogInteractorProtocol` | Calls `TMDBClientProtocol`; returns domain types to Presenter |
| Presenter | `CatalogPresenter` (`@Observable`) | Transforms Interactor output into `CatalogPhase` and per-movie `ImageState`; owns in-flight task management |
| Entity | `CatalogMovieRow` (view-ready) + `Movie` (domain, from `DomainModels`) | View-ready display value type; holds pre-computed `year` and raw `voteAverage` |
| Router | `CatalogRouter` (`@Observable`) | Owns `NavigationPath`; assembles V-I-P-E-R graph; sole entry point for the Catalog tab |

Key platform types used:
- `@Observable` (iOS 17) on `CatalogPresenter` and `CatalogRouter`
- `Task<Void, Never>` for in-flight fetch and per-movie poster tasks with cancellation
- `NavigationStack(path:)` bound to `router.navigationPath`

---

## Screen Inventory

### Screen: CatalogView

- **View file:** `Sources/CatalogFeature/View/CatalogView.swift`
- **Presenter file:** `Sources/CatalogFeature/Presenter/CatalogPresenter.swift`
- **Phase enum file:** `Sources/CatalogFeature/Presenter/CatalogPhase.swift`
- **Interactor files:** `Sources/CatalogFeature/Interactor/CatalogInteractorProtocol.swift`, `Sources/CatalogFeature/Interactor/CatalogInteractor.swift`
- **Router file:** `Sources/CatalogFeature/Router/CatalogRouter.swift`
- **Display model file:** `Sources/CatalogFeature/Entity/CatalogMovieRow.swift`
- **Navigation:** Root destination of the Catalog tab; `NavigationStack` owned by this screen's `CatalogRouter`
- **Scaffolding stub to replace:** `MovieTrackerApp.body` → `WindowGroup { CatalogRouter(tmdbClient: tmdbClient).makeRootView() }`

---

## Implementation Tasks

### Task 1 — `CatalogMovieRow` display model

**File:** `Sources/CatalogFeature/Entity/CatalogMovieRow.swift`

- **Properties:**
  - `id: Int`
  - `title: String`
  - `year: Int` — extracted from `Movie.releaseDate` (ISO-8601 `"yyyy-MM-dd"`) using `Calendar`; falls back to `0` if parsing fails
  - `voteAverage: Double` — raw value from `Movie.voteAverage`; `MovieCardView` formats it internally
  - `posterPath: String?`

- **Factory init:** `init(movie: Movie)` — performs the ISO-8601 `releaseDate → year` extraction inline using a file-private `DateFormatter` with `"yyyy"` format

- **No `imageState` stored here** — poster states are tracked separately in the Presenter's `imageStates: [Int: MovieCardView.ImageState]` dictionary to allow independent mutations without replacing the entire row

---

### Task 2 — `CatalogInteractorProtocol` + `CatalogInteractor`

**Files:** `Sources/CatalogFeature/Interactor/CatalogInteractorProtocol.swift`, `Sources/CatalogFeature/Interactor/CatalogInteractor.swift`

- **Protocol:**
  ```swift
  protocol CatalogInteractorProtocol: AnyObject {
      func fetchTrending() async throws(TMDBError) -> [Movie]
      func fetchPosterData(posterPath: String) async throws(TMDBError) -> Data
  }
  ```

- **`CatalogInteractor`** (final class):
  - Stored property: `private let tmdbClient: any TMDBClientProtocol`
  - `fetchTrending()`: delegates to `tmdbClient.fetchTrending()`
  - `fetchPosterData(posterPath:)`: delegates to `tmdbClient.fetchPosterData(posterPath:size:.thumbnail)`

- **Injected service abstraction:** `any TMDBClientProtocol` — passed via `init(tmdbClient:)`; never instantiated internally

---

### Task 3 — `CatalogPhase` enum

**File:** `Sources/CatalogFeature/Presenter/CatalogPhase.swift`

```swift
enum CatalogPhase {
    case idle
    case loading
    case loaded([CatalogMovieRow])
    case failed(TMDBError)
}
```

All four cases must be handled by every View `switch` and every unit test. `.idle` is the initial value; it is distinct from `.failed` so the re-fetch guard can differentiate an uninitialised screen from one that has already received an error.

---

### Task 4 — `CatalogPresenter`

**File:** `Sources/CatalogFeature/Presenter/CatalogPresenter.swift`

- **Declaration:** `@Observable final class CatalogPresenter`

- **Stored properties (observable):**
  - `var phase: CatalogPhase = .idle`
  - `var imageStates: [Int: MovieCardView.ImageState] = [:]`

- **Stored properties (private, non-observable):**
  - `private let interactor: any CatalogInteractorProtocol`
  - `weak var router: CatalogRouterProtocol?`
  - `private var fetchTask: Task<Void, Never>?`
  - `private var posterTasks: [Int: Task<Void, Never>] = [:]`

- **`init(interactor: any CatalogInteractorProtocol)`**

- **Action handlers:**

  | Method | Guard | Side effects | State transitions |
  |---|---|---|---|
  | `handleAppear()` | No-op if `phase` is `.loading` or `.loaded` | Cancels `fetchTask`; starts new fetch task | `.idle` / `.failed` → `.loading` |
  | `handleRetry()` | None | Cancels `fetchTask`; starts new fetch task | `.failed` → `.loading` |
  | `handleMovieTap(movieId: Int)` | None | Calls `router?.navigate(to: movieId)` | No `phase` change |

- **Private `startFetch()` method:**
  1. Cancel and nil `fetchTask` (and all `posterTasks`)
  2. Set `phase = .loading`; clear `imageStates`
  3. Assign a new `Task<Void, Never>` to `fetchTask` that:
     - Calls `try await interactor.fetchTrending()`
     - Checks `Task.isCancelled` before any state mutation
     - On empty result: `phase = .failed(.networkFailure)`
     - On non-empty result: builds `[CatalogMovieRow]`, sets `phase = .loaded(rows)`, then calls `startPosterLoads(rows:)`
     - On thrown `TMDBError`: `phase = .failed(error)`
  - All state mutations are on the `@MainActor`; mark `startFetch` `@MainActor` (or annotate the class `@MainActor`)

- **Private `startPosterLoads(rows:)` method:**
  - For each row where `posterPath != nil`:
    - Initialise `imageStates[row.id] = .placeholder`
    - Spawn a `Task` stored in `posterTasks[row.id]`
    - On success: decode `Data` → `UIImage` → `Image`; set `imageStates[row.id] = .image(image)`
    - On failure or cancellation: leave `.placeholder`

- **`deinit`:** cancels `fetchTask` and all `posterTasks`

- **Concurrency contract:** the entire class is `@MainActor`-isolated; service calls are awaited inside `Task` bodies which suspend off the main thread

---

### Task 5 — `CatalogView`

**File:** `Sources/CatalogFeature/View/CatalogView.swift`

- **Declaration:** `struct CatalogView: View`

- **Stored properties:**
  - `private let presenter: CatalogPresenter`
  - `private let router: CatalogRouter`

- **`init(presenter: CatalogPresenter, router: CatalogRouter)`**

- **`body`:** wraps everything in `NavigationStack(path: $router.navigationPath)` with `.navigationTitle("Trending")` / `.navigationBarTitleDisplayMode(.large)` and `.onAppear { presenter.handleAppear() }`

- **Phase rendering** (switch on `presenter.phase`):

  | Phase | Rendered content |
  |---|---|
  | `.idle` | `Color.clear` |
  | `.loading` | `LoadingView()` centered; below it, 5 static placeholder rows: `MovieCardView(title: "", year: 0, rating: 0, imageState: .placeholder)` in a `List` with `.redacted(reason: .placeholder)` |
  | `.loaded(rows)` | `List(rows)` where each row is a `MovieCardView` in a `Button` that calls `presenter.handleMovieTap(movieId: row.id)` |
  | `.failed` | `ErrorStateView(message: "Something went wrong. Please try again.", onRetry: presenter.handleRetry)` centered in a `VStack` |

- **Movie row in loaded list:**
  ```swift
  Button { presenter.handleMovieTap(movieId: row.id) } label: {
      MovieCardView(
          title: row.title,
          year: row.year,
          rating: row.voteAverage,
          imageState: presenter.imageStates[row.id] ?? .placeholder
      )
  }
  .buttonStyle(.plain)
  ```

- **Navigation destination:**
  ```swift
  .navigationDestination(for: Int.self) { movieId in
      Text("Movie Detail \(movieId)") // stub until MovieDetailFeature is implemented
  }
  ```

- **No `@FocusState`, no haptics, no accessibility identifiers** — deferred per feature plan

---

### Task 6 — `CatalogRouterProtocol` + `CatalogRouter`

**File:** `Sources/CatalogFeature/Router/CatalogRouter.swift`

- **`CatalogRouterProtocol`:**
  ```swift
  protocol CatalogRouterProtocol: AnyObject {
      func navigate(to movieId: Int)
  }
  ```

- **`CatalogRouter`** (`@Observable final class`, `CatalogRouterProtocol`):
  - `var navigationPath: NavigationPath = NavigationPath()`
  - `private let tmdbClient: any TMDBClientProtocol`
  - `init(tmdbClient: any TMDBClientProtocol)`
  - `func navigate(to movieId: Int)`: appends `movieId` to `navigationPath`
  - `func makeRootView() -> some View`: assembles the V-I-P-E-R graph:
    1. `let interactor = CatalogInteractor(tmdbClient: tmdbClient)`
    2. `let presenter = CatalogPresenter(interactor: interactor)`
    3. `presenter.router = self`
    4. `return CatalogView(presenter: presenter, router: self)`

- **Assembly rule:** `makeRootView()` is the only entry point that allocates a `CatalogPresenter` and `CatalogInteractor`. Nothing outside this method constructs these types.

---

### Task 7 — Package and App Integration

**Files:** `MovieTrackerPackage/Package.swift`, `MovieTracker/MovieTrackerApp.swift`

- **New SPM target** in `Package.swift`:
  ```swift
  .target(
      name: "CatalogFeature",
      dependencies: ["DomainModels", "SharedUIComponents", "TMDBClient"]
  )
  ```
  `MovieDetailFeature` is not yet available; the navigation destination uses a stub `Text` view. The dependency will be added once `MovieDetailFeature` exists.

- **App target dependency:** add `"CatalogFeature"` to `MovieTracker`'s linked frameworks in the Xcode project (or via `Package.swift` if the app is also SPM-managed).

- **`MovieTrackerApp.body` update:**
  ```swift
  WindowGroup {
      CatalogRouter(tmdbClient: tmdbClient).makeRootView()
  }
  ```
  The full `TabView` assembly is deferred to the UI scaffolding implementation step; for now `CatalogRouter.makeRootView()` is the sole root view.

---

### Task 8 — SwiftUI Previews

**File:** `Sources/CatalogFeature/View/CatalogView+Previews.swift`

- **`MockCatalogInteractor`** (defined in this file, preview-only):
  - `enum Behavior { case success([Movie]), case failure(TMDBError), case loading }`
  - `fetchTrending()`: returns fixture movies, throws, or suspends indefinitely per `Behavior`
  - `fetchPosterData(posterPath:)`: throws `.networkFailure` (poster loading not exercised in previews)

- **`MovieFixtures`** (internal enum, shared by previews and tests):
  - 3–5 `Movie` values with varying `title`, `releaseDate`, `voteAverage`, and both `nil` and non-nil `posterPath`
  - Defined in `Sources/CatalogFeature/Testing/MovieFixtures.swift` (conditionally compiled with `#if DEBUG`)

- **Four preview variants** (one per `CatalogPhase`):
  - `.loaded`: `MockCatalogInteractor(behavior: .success(MovieFixtures.all))`
  - `.failed`: `MockCatalogInteractor(behavior: .failure(.networkFailure))`
  - `.loading`: `MockCatalogInteractor(behavior: .loading)`
  - `.idle`: Presenter constructed but `handleAppear()` never called

---

### Task 9 — Unit Tests

**File:** `Tests/CatalogFeatureTests/CatalogPresenterTests.swift`

- **`MockCatalogInteractor`** (test double, conforms to `CatalogInteractorProtocol`):
  - Configurable `fetchTrendingResult: Result<[Movie], TMDBError>`
  - `fetchCallCount: Int` to verify call frequency

- **Test cases** (all driven by constructing `CatalogPresenter` with a mock interactor, calling action handlers, and asserting `phase`):

  | Scenario | Action | Expected `phase` |
  |---|---|---|
  | Non-empty fetch success | `handleAppear()` | `.idle` → `.loading` → `.loaded([…])` |
  | Empty fetch result | `handleAppear()` | `.loading` → `.failed(.networkFailure)` |
  | Fetch throws `TMDBError` | `handleAppear()` | `.loading` → `.failed(error)` |
  | Retry in `.failed` | `handleRetry()` | `.failed` → `.loading` |
  | `handleAppear()` when `.loaded` | `handleAppear()` | No fetch dispatched; `fetchCallCount == 1` |
  | `handleAppear()` when `.loading` | `handleAppear()` twice | No second fetch dispatched; `fetchCallCount == 1` |

---

## Open Questions / Deferred Decisions

1. **`MovieDetailView` stub**: `CatalogView`'s `.navigationDestination(for: Int.self)` uses `Text("Movie Detail \(movieId)")` until `MovieDetailFeature` is implemented. The plan notes `CatalogFeature` will add `MovieDetailFeature` as a direct SPM dependency at that point.
2. **Full `TabView` assembly**: `CatalogRouter.makeRootView()` is wired as the sole root for now. The three-tab `TabView` is assembled in the UI scaffolding implementation step.
3. **`@MainActor` isolation strategy**: `CatalogPresenter` is annotated `@MainActor` at the class level. If this introduces friction with the test target's default executor, test cases must be annotated `@MainActor` or wrapped in `await MainActor.run { }`.
