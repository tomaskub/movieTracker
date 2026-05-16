# Watchlist Feature Implementation Plan

## Presentation Architecture

VIPER with `@Observable` Presenter. Five roles for `WatchlistFeature`:

| Role | Concrete type | Responsibility |
|---|---|---|
| View | `WatchlistListView`, `WatchlistSortSheetView` | Passive SwiftUI views; read `@Observable` Presenter state, forward user events to Presenter |
| Interactor | `WatchlistInteractor` / `WatchlistInteractorProtocol` | Calls `WatchlistRepository.fetchAll`; delegates poster image loading |
| Presenter | `WatchlistListPresenter` (`@Observable`) | Transforms Interactor output into `WatchlistViewState` and per-entry `MovieCardView.ImageState`; owns sort state and sheet presentation flag |
| Entity | `WatchlistEntry` (domain, from `DomainModels`) | Plain value type; fields used directly as view-ready display data |
| Router | `WatchlistRouter` (`@Observable`) | Owns `NavigationPath`; assembles V-I-P-E-R graph; sole entry point for the Watchlist tab |

Key platform types used:
- `@Observable` (iOS 17) on `WatchlistListPresenter` and `WatchlistRouter`
- Synchronous `throws`-based calls to `WatchlistRepository` (no `async`/`Task` required for data fetching)
- `Task<Void, Never>` for per-entry poster image loading with cancellation
- `NavigationStack(path:)` bound to `router.navigationPath`

---

## Screen Inventory

### Screen: WatchlistListView

- **View file:** `Sources/WatchlistFeature/View/WatchlistListView.swift`
- **Presenter file:** `Sources/WatchlistFeature/Presenter/WatchlistListPresenter.swift`
- **View state enum file:** `Sources/WatchlistFeature/Presenter/WatchlistViewState.swift`
- **Interactor files:** `Sources/WatchlistFeature/Interactor/WatchlistInteractorProtocol.swift`, `Sources/WatchlistFeature/Interactor/WatchlistInteractor.swift`
- **Router file:** `Sources/WatchlistFeature/Router/WatchlistRouter.swift`
- **Navigation:** Root destination of the Watchlist tab's `NavigationStack`; never pushed or replaced
- **Scaffolding stub to replace:** The `TabView`'s Watchlist tab entry in `MovieTrackerApp.body`

### Screen: WatchlistSortSheetView

- **View file:** `Sources/WatchlistFeature/View/WatchlistSortSheetView.swift`
- **State management:** Local `@State var draftSortOrder: WatchlistSortOrder` inside the view (no dedicated Presenter — sheet-lifetime state is purely UI-local with no service calls)
- **Navigation:** `.sheet` presented from `WatchlistListView` via `presenter.isSortSheetPresented`
- **Scaffolding stub to replace:** None; new file

---

## Implementation Tasks

### Task 1 — `WatchlistViewState` enum

**File:** `Sources/WatchlistFeature/Presenter/WatchlistViewState.swift`

```swift
enum WatchlistViewState {
    case loading
    case loaded([WatchlistEntry])
    case empty
    case error(String)
}
```

All four cases must be handled by every View `switch` and every unit test. `.loading` is the initial value on every `onAppear`. `.empty` is non-error in tone — reached only when the data layer succeeds and returns zero records. `.error` surfaces only on `WatchlistRepositoryError.fetchFailed`; the associated message must not mention network failures or SwiftData internals.

---

### Task 2 — `WatchlistInteractorProtocol` + `WatchlistInteractor`

**Files:** `Sources/WatchlistFeature/Interactor/WatchlistInteractorProtocol.swift`, `Sources/WatchlistFeature/Interactor/WatchlistInteractor.swift`

- **Protocol:**
  ```swift
  protocol WatchlistInteractorProtocol: AnyObject {
      func fetchAll(sortOrder: WatchlistSortOrder?) throws -> [WatchlistEntry]
      func fetchPosterData(posterPath: String) async throws -> Data
  }
  ```

- **`WatchlistInteractor`** (final class):
  - Stored properties:
    - `private let repository: any WatchlistRepository`
    - `private let tmdbClient: any TMDBClientProtocol`
  - `fetchAll(sortOrder:)`: delegates to `repository.fetchAll(sortOrder: sortOrder)`; maps `WatchlistRepositoryError` to a user-readable `String` before re-throwing as a `WatchlistFeatureError` (a feature-local error type with a `message: String` payload)
  - `fetchPosterData(posterPath:)`: delegates to `tmdbClient.fetchPosterData(posterPath: posterPath, size: .thumbnail)`

- **Injected service abstractions:** `any WatchlistRepository` and `any TMDBClientProtocol` — both passed via `init(repository:tmdbClient:)`

---

### Task 3 — `WatchlistListPresenter`

**File:** `Sources/WatchlistFeature/Presenter/WatchlistListPresenter.swift`

- **Declaration:** `@Observable final class WatchlistListPresenter`

- **Stored properties (observable):**
  - `var viewState: WatchlistViewState = .loading`
  - `var sortOrder: WatchlistSortOrder = .dateAdded`
  - `var isSortSheetPresented: Bool = false`
  - `var imageStates: [Int: MovieCardView.ImageState] = [:]`

- **Stored properties (private, non-observable):**
  - `private let interactor: any WatchlistInteractorProtocol`
  - `weak var router: (any WatchlistRouterProtocol)?`
  - `private var posterTasks: [Int: Task<Void, Never>] = [:]`

- **`init(interactor: any WatchlistInteractorProtocol)`**

- **Action handlers:**

  | Method | Guard | Side effects | State transitions |
  |---|---|---|---|
  | `handleAppear()` | None | Calls `performFetch()` | Always: → `.loading` → `.loaded` / `.empty` / `.error` |
  | `handleSortButtonTap()` | None | Sets `isSortSheetPresented = true` | No `viewState` change |
  | `handleSortApplied(newSortOrder:)` | None | Sets `isSortSheetPresented = false`; updates `sortOrder`; calls `performFetch()` | → `.loading` → `.loaded` / `.empty` / `.error` |
  | `handleSortCancelled()` | None | Sets `isSortSheetPresented = false` | No `viewState` change; `sortOrder` unchanged |
  | `handleRetry()` | None | Calls `performFetch()` | `.error` → `.loading` → `.loaded` / `.empty` / `.error` |
  | `handleMovieTap(movieId:)` | None | Calls `router?.navigate(to: movieId)` | No `viewState` change |

- **Private `performFetch()` method:**
  1. Cancel all `posterTasks`; clear `imageStates`
  2. Set `viewState = .loading`
  3. Call `interactor.fetchAll(sortOrder: sortOrder)` synchronously — `WatchlistRepository` is `@MainActor`-synchronous; no `Task` wrapper needed
  4. On empty array result: set `viewState = .empty`
  5. On non-empty result: set `viewState = .loaded(entries)`; call `startPosterLoads(entries:)`
  6. On thrown error: extract user-readable message from `WatchlistFeatureError`; set `viewState = .error(message)`

- **Private `startPosterLoads(entries:)` method:**
  - For each entry where `posterPath != nil`:
    - Set `imageStates[entry.movieId] = .placeholder`
    - Spawn a `Task<Void, Never>` stored in `posterTasks[entry.movieId]`
    - On success: decode `Data` → `UIImage` → `Image`; set `imageStates[entry.movieId] = .image(image)`
    - On failure or `Task.isCancelled`: leave `.placeholder`

- **`deinit`:** cancels all `posterTasks`

- **Concurrency contract:** the entire class is `@MainActor`-isolated; `performFetch()` is synchronous; poster load tasks are `Task<Void, Never>` bodies that `await` inside and resolve back to `@MainActor` for state mutation

---

### Task 4 — `WatchlistListView`

**File:** `Sources/WatchlistFeature/View/WatchlistListView.swift`

- **Declaration:** `struct WatchlistListView: View`

- **Stored properties:**
  - `private let presenter: WatchlistListPresenter`
  - `private let router: WatchlistRouter`

- **`init(presenter: WatchlistListPresenter, router: WatchlistRouter)`**

- **`body`:** `NavigationStack(path: $router.navigationPath)` containing the phase-rendered content, with `.navigationTitle("Watchlist")` / `.navigationBarTitleDisplayMode(.large)` and `.onAppear { presenter.handleAppear() }`

- **Navigation bar:**
  ```swift
  .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: presenter.handleSortButtonTap) {
              Image(systemName: "line.3.horizontal.decrease.circle")
          }
      }
  }
  ```

- **View state rendering** (switch on `presenter.viewState`):

  | State | Rendered content |
  |---|---|
  | `.loading` | `LoadingView()` centered in a full-height `VStack` |
  | `.loaded(entries)` | `List(entries, id: \.movieId)` where each row is a `MovieCardView` wrapped in a `Button` |
  | `.empty` | `EmptyStateView` centered; copy: "No saved movies yet. Add movies from Catalog or Search." |
  | `.error(message)` | `ErrorStateView(message: message, onRetry: presenter.handleRetry)` centered |

- **Movie row in loaded list:**
  ```swift
  Button { presenter.handleMovieTap(movieId: entry.movieId) } label: {
      MovieCardView(
          title: entry.title,
          year: entry.releaseYear,
          rating: entry.voteAverage,
          imageState: presenter.imageStates[entry.movieId] ?? .placeholder
      )
  }
  .buttonStyle(.plain)
  ```

- **Sort sheet binding:**
  ```swift
  .sheet(isPresented: Binding(
      get: { presenter.isSortSheetPresented },
      set: { if !$0 { presenter.handleSortCancelled() } }
  )) {
      WatchlistSortSheetView(
          currentSortOrder: presenter.sortOrder,
          onApply: { presenter.handleSortApplied(newSortOrder: $0) },
          onCancel: { presenter.handleSortCancelled() }
      )
  }
  ```
  Drag-to-dismiss triggers the `set` closure with `false`, which calls `handleSortCancelled()` — identical semantics to the Cancel button.

- **Navigation destination:**
  ```swift
  .navigationDestination(for: Int.self) { movieId in
      MovieDetailView(movieId: movieId)
  }
  ```

- **No `@FocusState`, no haptics, no accessibility identifiers** — deferred per feature plan

---

### Task 5 — `WatchlistSortSheetView`

**File:** `Sources/WatchlistFeature/View/WatchlistSortSheetView.swift`

- **Declaration:** `struct WatchlistSortSheetView: View`

- **Stored properties:**
  - `let currentSortOrder: WatchlistSortOrder`
  - `let onApply: (WatchlistSortOrder) -> Void`
  - `let onCancel: () -> Void`
  - `@State private var draftSortOrder: WatchlistSortOrder`

- **`init(currentSortOrder:onApply:onCancel:)`:** initialises `_draftSortOrder = State(initialValue: currentSortOrder)`

- **Layout structure:**
  - Sheet title: "Sort by"
  - `List` or `Form` with three rows:
    - "Date Added" (`.dateAdded`) — checkmark when `draftSortOrder == .dateAdded`
    - "Title" (`.title`) — checkmark when `draftSortOrder == .title`
    - "Rating" (`.voteAverage`) — checkmark when `draftSortOrder == .voteAverage`
  - Tapping a row sets `draftSortOrder`; no immediate effect on the parent
  - Button row: **Clear** (sets `draftSortOrder = .dateAdded`; sheet stays open), **Cancel** (calls `onCancel()`), **Apply** (calls `onApply(draftSortOrder)`)

- **State transitions:**
  - **Apply**: commits draft to caller; caller dismisses sheet via `isSortSheetPresented = false`
  - **Cancel** / drag-to-dismiss: discards draft; parent `sortOrder` unchanged; sheet dismissed
  - **Clear**: resets draft to `.dateAdded` within the sheet only; user must tap Apply to commit

- **No service calls, no Presenter** — all behaviour is expressed through the two callbacks and `@State`-local draft

---

### Task 6 — `WatchlistRouterProtocol` + `WatchlistRouter`

**File:** `Sources/WatchlistFeature/Router/WatchlistRouter.swift`

- **`WatchlistRouterProtocol`:**
  ```swift
  protocol WatchlistRouterProtocol: AnyObject {
      func navigate(to movieId: Int)
  }
  ```

- **`WatchlistRouter`** (`@Observable final class`, `WatchlistRouterProtocol`):
  - `var navigationPath: NavigationPath = NavigationPath()`
  - `private let repository: any WatchlistRepository`
  - `private let tmdbClient: any TMDBClientProtocol`
  - `init(repository: any WatchlistRepository, tmdbClient: any TMDBClientProtocol)`
  - `func navigate(to movieId: Int)`: appends `movieId` to `navigationPath`
  - `func makeRootView() -> some View`: assembles the full V-I-P-E-R graph:
    1. `let interactor = WatchlistInteractor(repository: repository, tmdbClient: tmdbClient)`
    2. `let presenter = WatchlistListPresenter(interactor: interactor)`
    3. `presenter.router = self`
    4. `return WatchlistListView(presenter: presenter, router: self)`

- **Assembly rule:** `makeRootView()` is the only entry point that allocates `WatchlistListPresenter` and `WatchlistInteractor`. Nothing outside this method constructs these types.

---

### Task 7 — Package and App Integration

**Files:** `MovieTrackerPackage/Package.swift`, app target `TabView` assembly

- **New SPM target** in `Package.swift`:
  ```swift
  .target(
      name: "WatchlistFeature",
      dependencies: ["DomainModels", "SharedUIComponents", "WatchlistRepository", "TMDBClient", "MovieDetailFeature"]
  )
  ```

- **`TabView` assembly** (in the UI scaffolding implementation step or `MovieTrackerApp.swift`):
  ```swift
  WatchlistRouter(repository: watchlistRepository, tmdbClient: tmdbClient)
      .makeRootView()
      .tabItem { Label("Watchlist", systemImage: "bookmark") }
      .tag(2)
  ```
  `watchlistRepository` and `tmdbClient` are constructed at the app composition root and passed down; they are not singletons.

---

### Task 8 — SwiftUI Previews

**File:** `Sources/WatchlistFeature/View/WatchlistListView+Previews.swift`

- **`MockWatchlistInteractor`** (preview-only, defined in this file):
  - `enum Behavior { case populated, empty, error }`
  - `fetchAll(sortOrder:)`: returns two fixture entries on `.populated`, throws a message string on `.error`, returns `[]` on `.empty`
  - `fetchPosterData(posterPath:)`: throws (poster loading not exercised in previews)

- **Static fixture data** (shared with unit tests via `#if DEBUG`):
  ```swift
  WatchlistEntry(movieId: 1, title: "Dune: Part Two", releaseYear: 2024, voteAverage: 8.1, posterPath: "/path1.jpg", dateAdded: Date())
  WatchlistEntry(movieId: 2, title: "Poor Things", releaseYear: 2023, voteAverage: 7.8, posterPath: nil, dateAdded: Date().addingTimeInterval(-86400))
  ```
  The second entry with `posterPath: nil` exercises the `.placeholder` path in `MovieCardView`.

- **Three `WatchlistListView` preview variants:**
  - Populated: `MockWatchlistInteractor(behavior: .populated)`
  - Empty: `MockWatchlistInteractor(behavior: .empty)`
  - Error: `MockWatchlistInteractor(behavior: .error)`

- **`WatchlistSortSheetView` preview:** single inline preview with `currentSortOrder: .dateAdded`, no-op callbacks

---

### Task 9 — Unit Tests

**File:** `Tests/WatchlistFeatureTests/WatchlistListPresenterTests.swift`

- **`MockWatchlistInteractor`** (test double, conforms to `WatchlistInteractorProtocol`):
  - Configurable `fetchAllResult: Result<[WatchlistEntry], Error>`
  - `fetchCallCount: Int` and `lastSortOrder: WatchlistSortOrder?` to verify call frequency and arguments
  - `fetchPosterData(posterPath:)`: throws immediately (poster loading not under test here)

- **Test cases** (all driven by constructing `WatchlistListPresenter` with the mock, calling action handlers, and asserting observable state):

  | Scenario | Action | Expected outcome |
  |---|---|---|
  | Non-empty fetch | `handleAppear()` | `viewState == .loaded([…])`; `fetchCallCount == 1` |
  | Empty fetch | `handleAppear()` | `viewState == .empty`; `fetchCallCount == 1` |
  | Fetch throws | `handleAppear()` | `viewState == .error(…)`; message does not contain "SwiftData" or "network" |
  | Sort Apply — state update | `handleSortApplied(newSortOrder: .title)` | `sortOrder == .title`; `fetchCallCount == 1`; `lastSortOrder == .title` |
  | Sort Apply — isSortSheetPresented | `handleSortApplied(newSortOrder: .title)` | `isSortSheetPresented == false` |
  | Sort Cancel — sortOrder unchanged | `handleSortButtonTap()` then `handleSortCancelled()` | `sortOrder == .dateAdded`; `fetchCallCount == 0` (no fetch on cancel) |
  | Sort Cancel — isSortSheetPresented | `handleSortCancelled()` | `isSortSheetPresented == false` |
  | Sort Clear then Apply | `handleSortApplied(newSortOrder: .dateAdded)` | `fetchAll` called with `.dateAdded`; list reflects default sort |
  | Retry from error | `handleRetry()` after fetch throws | `viewState` transitions through `.loading` to new outcome; `fetchCallCount == 2` |
  | Sort button tap | `handleSortButtonTap()` | `isSortSheetPresented == true` |
  | Pop-back re-fetch | `handleAppear()` called twice | `fetchCallCount == 2` — no guard skips the second fetch |

---

## Open Questions / Deferred Decisions

1. **Tab assembly entry point**: `WatchlistRouter.makeRootView()` is the Watchlist tab's contribution to the root `TabView`. The calling site is owned by the UI scaffolding implementation step and is not defined within `WatchlistFeature`.
