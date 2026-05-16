# Search Feature Implementation Plan

## Presentation Architecture

VIPER with `@Observable` Presenter. Five roles per screen for the `SearchFeature` SPM target:

| Role | Concrete type(s) | Responsibility |
|---|---|---|
| View | `SearchListView`, `SearchFilterSheetView`, `SearchSortSheetView` | Passive SwiftUI views; read `@Observable` Presenter state, forward user events to Presenter |
| Interactor | `SearchListInteractor` / `SearchListInteractorProtocol`, `SearchFilterSheetInteractor` / `SearchFilterSheetInteractorProtocol` | Service calls only; delegates to `TMDBClientProtocol`; returns domain types to Presenter |
| Presenter | `SearchListPresenter` (`@Observable`), `SearchFilterSheetPresenter` (`@Observable`), `SearchSortSheetPresenter` (`@Observable`) | Transforms Interactor output and user actions into view-ready state; owns in-flight task management and client-side filter/sort pipelines |
| Entity | `SearchState`, `SearchFilterState`, `SearchSortOption`, `GenreLoadState` | Plain Swift value and enum types representing domain state |
| Router | `SearchRouter` (`@Observable`) | Owns the Search tab's `NavigationPath`; assembles the full V-I-P-E-R graph; sole entry point for the Search tab |

Key platform types used:
- `@Observable` (iOS 17) on all three Presenters and `SearchRouter`
- `@MainActor` class-level isolation on all Presenters
- `Task<Void, Never>` for in-flight fetch tasks with cancellation
- `NavigationStack(path:)` bound to `router.navigationPath`
- `.sheet(isPresented:)` owned by `SearchListPresenter` state; not path-driven

---

## Screen Inventory

### Screen: SearchListView

- **View file:** `Sources/SearchFeature/View/SearchListView.swift`
- **Presenter file:** `Sources/SearchFeature/Presenter/SearchListPresenter.swift`
- **Interactor files:** `Sources/SearchFeature/Interactor/SearchListInteractorProtocol.swift`, `Sources/SearchFeature/Interactor/SearchListInteractor.swift`
- **Router file:** `Sources/SearchFeature/Router/SearchRouter.swift`
- **Navigation:** Root destination of the Search tab's `NavigationStack`; `NavigationStack` path owned by `SearchRouter`
- **Scaffolding stub to replace:** `SearchFeature` tab entry in the root `TabView` in `MovieTrackerApp.body`

### Screen: SearchFilterSheetView

- **View file:** `Sources/SearchFeature/View/SearchFilterSheetView.swift`
- **Presenter file:** `Sources/SearchFeature/Presenter/SearchFilterSheetPresenter.swift`
- **Interactor files:** `Sources/SearchFeature/Interactor/SearchFilterSheetInteractorProtocol.swift`, `Sources/SearchFeature/Interactor/SearchFilterSheetInteractor.swift`
- **Navigation:** `.sheet` presented from `SearchListView`; presentation state (`isFilterSheetPresented: Bool`) owned by `SearchListPresenter`
- **Scaffolding stub to replace:** None — new screen assembled by `SearchRouter`

### Screen: SearchSortSheetView

- **View file:** `Sources/SearchFeature/View/SearchSortSheetView.swift`
- **Presenter file:** `Sources/SearchFeature/Presenter/SearchSortSheetPresenter.swift`
- **Navigation:** `.sheet` presented from `SearchListView`; presentation state (`isSortSheetPresented: Bool`) owned by `SearchListPresenter`
- **Scaffolding stub to replace:** None — new screen assembled by `SearchRouter`

---

## Implementation Tasks

### Task 1 — Entity types

**Files:**
- `Sources/SearchFeature/Entity/SearchState.swift`
- `Sources/SearchFeature/Entity/SearchFilterState.swift`
- `Sources/SearchFeature/Entity/SearchSortOption.swift`
- `Sources/SearchFeature/Entity/GenreLoadState.swift`

**`SearchState`:**
```swift
enum SearchState {
    case idle
    case loading(query: String)
    case results(all: [Movie], filtered: [Movie])
    case empty(reason: EmptyReason)
    case error(TMDBError, query: String)
}

extension SearchState {
    enum EmptyReason {
        case noMatches
        case filtersEliminated
    }
}
```

**`SearchFilterState`:**
```swift
struct SearchFilterState: Equatable {
    var selectedGenreIds: Set<Int> = []
    var minimumRatingEnabled: Bool = false
    var minimumRating: Int = 5
    var fromYear: String = ""
    var toYear: String = ""

    var isDefault: Bool {
        selectedGenreIds.isEmpty &&
        !minimumRatingEnabled &&
        fromYear.isEmpty &&
        toYear.isEmpty
    }
}
```

**`SearchSortOption`:**
```swift
enum SearchSortOption: CaseIterable {
    case releaseDate
    case title
    case voteAverage
}
```

**`GenreLoadState`:**
```swift
enum GenreLoadState {
    case loading
    case loaded([Genre])
    case error(TMDBError)
}
```

---

### Task 2 — `SearchListInteractorProtocol` + `SearchListInteractor`

**Files:** `Sources/SearchFeature/Interactor/SearchListInteractorProtocol.swift`, `Sources/SearchFeature/Interactor/SearchListInteractor.swift`

- **Protocol:**
  ```swift
  protocol SearchListInteractorProtocol: AnyObject {
      func searchMovies(query: String) async throws(TMDBError) -> [Movie]
      func fetchPosterData(posterPath: String) async throws(TMDBError) -> Data
  }
  ```

- **`SearchListInteractor`** (final class):
  - Stored property: `private let tmdbClient: any TMDBClientProtocol`
  - `searchMovies(query:)`: delegates to `tmdbClient.fetchSearch(query:)`
  - `fetchPosterData(posterPath:)`: delegates to `tmdbClient.fetchPosterData(posterPath:size:.thumbnail)`
  - Injected via `init(tmdbClient: any TMDBClientProtocol)`

---

### Task 3 — `SearchFilterSheetInteractorProtocol` + `SearchFilterSheetInteractor`

**Files:** `Sources/SearchFeature/Interactor/SearchFilterSheetInteractorProtocol.swift`, `Sources/SearchFeature/Interactor/SearchFilterSheetInteractor.swift`

- **Protocol:**
  ```swift
  protocol SearchFilterSheetInteractorProtocol: AnyObject {
      func fetchGenres(force: Bool) async throws(TMDBError) -> [Genre]
  }
  ```

- **`SearchFilterSheetInteractor`** (final class):
  - Stored property: `private let tmdbClient: any TMDBClientProtocol`
  - `fetchGenres(force:)`: delegates to `tmdbClient.fetchGenres(force:)`
  - Injected via `init(tmdbClient: any TMDBClientProtocol)`

---

### Task 4 — `SearchListPresenter`

**File:** `Sources/SearchFeature/Presenter/SearchListPresenter.swift`

- **Declaration:** `@MainActor @Observable final class SearchListPresenter`

- **Observable stored properties (view-readable):**
  - `var query: String = ""`
  - `var searchState: SearchState = .idle`
  - `var activeFilters: SearchFilterState = SearchFilterState()`
  - `var activeSort: SearchSortOption = .releaseDate`
  - `var imageStates: [Int: MovieCardView.ImageState] = [:]`
  - `var isFilterSheetPresented: Bool = false`
  - `var isSortSheetPresented: Bool = false`

- **Derived properties:**
  - `var isFilterActive: Bool { !activeFilters.isDefault }`
  - `var canSubmitSearch: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }`

- **Private non-observable properties:**
  - `private let interactor: any SearchListInteractorProtocol`
  - `weak var router: SearchRouterProtocol?`
  - `private var lastSubmittedQuery: String? = nil`
  - `private var allMovies: [Movie] = []`
  - `private var searchTask: Task<Void, Never>? = nil`
  - `private var posterTasks: [Int: Task<Void, Never>] = [:]`

- **`init(interactor: any SearchListInteractorProtocol)`**

- **Intent methods:**

  | Method | Guard | Side effects | State transitions |
  |---|---|---|---|
  | `submitSearch()` | Guard `canSubmitSearch`; no-op otherwise | Cancels `searchTask`; cancels all `posterTasks`; clears `imageStates`; stores submitted query as `lastSubmittedQuery`; starts new fetch task | → `.loading(query:)` |
  | `retrySearch()` | Guard `lastSubmittedQuery != nil` | Cancels `searchTask`; restarts fetch with `lastSubmittedQuery!` | → `.loading(query:)` |
  | `selectMovie(movieId: Int)` | None | Calls `router?.pushMovieDetail(movieId:)` | No state change |
  | `openFilterSheet()` | Guard `searchState` is not `.idle` or `.loading` | Calls `filterSheetPresenter.reset(from: activeFilters)` via the callback injected at construction; sets `isFilterSheetPresented = true` | Sheet presented |
  | `openSortSheet()` | Guard `searchState` is not `.idle` or `.loading` | Calls `sortSheetPresenter.reset(to: activeSort)` via the callback injected at construction; sets `isSortSheetPresented = true` | Sheet presented |
  | `commitFilters(_ newFilters: SearchFilterState)` | None | Stores `activeFilters = newFilters`; calls `recomputeFilteredResults()` | `.results` re-derived |
  | `commitSort(_ newSort: SearchSortOption)` | None | Stores `activeSort = newSort`; calls `recomputeFilteredResults()` | `.results` re-derived |
  | `clearActiveFilters()` | None | Resets `activeFilters` to defaults; calls `recomputeFilteredResults()` | `.results` re-derived |

- **Private `startSearch(query: String)` method:**
  1. Cancel and nil `searchTask` and all `posterTasks`; clear `imageStates`; clear `allMovies`
  2. Set `searchState = .loading(query: query)`
  3. Assign a new `Task<Void, Never>` to `searchTask`:
     - Calls `try await interactor.searchMovies(query: query)`
     - Checks `Task.isCancelled` before any state mutation
     - On empty result: `searchState = .empty(reason: .noMatches)`
     - On non-empty result: stores `allMovies = movies`; calls `recomputeFilteredResults()`; then calls `startPosterLoads(movies:)`
     - On `TMDBError`: `searchState = .error(error, query: query)`

- **Private `recomputeFilteredResults()` method:**
  - Applies `activeFilters` to `allMovies` (genre → min rating → from year → to year)
  - Applies `activeSort`
  - If result is empty and `allMovies` is non-empty: `searchState = .empty(reason: .filtersEliminated)`
  - If result is empty and `allMovies` is empty: no-op (state already `.empty(.noMatches)`)
  - Otherwise: `searchState = .results(all: allMovies, filtered: sorted)`

- **Filter pipeline (applied inside `recomputeFilteredResults`):**
  - Genre filter: `selectedGenreIds.isEmpty` → pass all; else keep movies where `movie.genreIds.contains(any of selectedGenreIds)`
  - Min rating filter: skip when `!minimumRatingEnabled`; keep movies where `Int(movie.voteAverage.rounded()) >= minimumRating`
  - From year: skip when `fromYear.isEmpty`; keep movies where `movie.releaseYear >= Int(fromYear)`
  - To year: skip when `toYear.isEmpty`; keep movies where `movie.releaseYear <= Int(toYear)`
  - Sort: `.releaseDate` → descending by `releaseDate`; `.title` → ascending by `title`; `.voteAverage` → descending by `voteAverage`

- **Private `startPosterLoads(movies:)` method:** Same pattern as `CatalogPresenter.startPosterLoads`; spawns per-movie `Task` stored in `posterTasks`; calls `interactor.fetchPosterData(posterPath:)` for each non-nil `posterPath`; updates `imageStates[id]`

- **`deinit`:** Cancels `searchTask` and all `posterTasks`

- **Concurrency contract:** `@MainActor` class-level isolation; service calls awaited inside detached `Task` bodies

---

### Task 5 — `SearchFilterSheetPresenter`

**File:** `Sources/SearchFeature/Presenter/SearchFilterSheetPresenter.swift`

- **Declaration:** `@MainActor @Observable final class SearchFilterSheetPresenter`

- **Observable stored properties:**
  - `var draftFilters: SearchFilterState = SearchFilterState()`
  - `var genreLoadState: GenreLoadState = .loading`
  - `var fromYearError: String? = nil`
  - `var toYearError: String? = nil`
  - `var yearRangeError: String? = nil`

- **Private non-observable properties:**
  - `private let interactor: any SearchFilterSheetInteractorProtocol`
  - `private let onConfirm: (SearchFilterState) -> Void`
  - `private var genreTask: Task<Void, Never>? = nil`
  - `private let currentYear: Int` — captured once at `init` via `Calendar.current.component(.year, from: Date())`

- **`init(interactor: any SearchFilterSheetInteractorProtocol, onConfirm: @escaping (SearchFilterState) -> Void)`**

- **`func reset(from activeFilters: SearchFilterState)`** — called by `SearchListPresenter.openFilterSheet()` before sheet is presented:
  - Sets `draftFilters = activeFilters`
  - Resets all year error properties to `nil`
  - Sets `genreLoadState = .loading`
  - Cancels and nils `genreTask`; starts `loadGenres(force: false)` only if genres have not been successfully loaded in this session (optimization: preserve cached genres across sheet presentations if already `.loaded`)

- **Intent methods:**

  | Method | Side effects |
  |---|---|
  | `viewAppeared()` | Triggers `loadGenres(force: false)` if `genreLoadState != .loaded` |
  | `retryGenreFetch()` | Cancels `genreTask`; sets `genreLoadState = .loading`; calls `loadGenres(force: true)` |
  | `toggleGenre(id: Int)` | Inserts or removes `id` from `draftFilters.selectedGenreIds` |
  | `toggleMinimumRating()` | Flips `draftFilters.minimumRatingEnabled`; if enabling and `minimumRating < 1`, sets to default `5` |
  | `setMinimumRating(_ value: Int)` | Sets `draftFilters.minimumRating = value.clamped(to: 1...10)` |
  | `updateFromYear(_ text: String)` | Sets `draftFilters.fromYear = text`; calls `validateYears()` |
  | `updateToYear(_ text: String)` | Sets `draftFilters.toYear = text`; calls `validateYears()` |
  | `clearAllFilters()` | Resets `draftFilters` to defaults; clears all year error properties |
  | `confirm()` | Calls `onConfirm(draftFilters)` |

- **Private `loadGenres(force:)` method:**
  - Assigns a new `Task` to `genreTask`
  - Calls `try await interactor.fetchGenres(force:)`
  - On success: `genreLoadState = .loaded(genres)`
  - On `TMDBError`: `genreLoadState = .error(error)`
  - Checks `Task.isCancelled` before mutation

- **Private `validateYears()` method:**
  - Clears all year errors first
  - `fromYear` non-empty and not a valid integer in `1900...currentYear`: `fromYearError = "Enter a year between 1900 and \(currentYear)"`
  - `toYear` non-empty and not a valid integer in `1900...currentYear`: `toYearError = "Enter a year between 1900 and \(currentYear)"`
  - Both fields valid and `fromYear > toYear`: `yearRangeError = "From year must be before or equal to To year"`; `fromYearError = ""`; `toYearError = ""` (both fields get red border treatment)

- **`deinit`:** cancels `genreTask`

---

### Task 6 — `SearchSortSheetPresenter`

**File:** `Sources/SearchFeature/Presenter/SearchSortSheetPresenter.swift`

- **Declaration:** `@MainActor @Observable final class SearchSortSheetPresenter`

- **Observable stored properties:**
  - `var draftSort: SearchSortOption = .releaseDate`

- **Private non-observable properties:**
  - `private let onConfirm: (SearchSortOption) -> Void`

- **`init(onConfirm: @escaping (SearchSortOption) -> Void)`**

- **`func reset(to activeSort: SearchSortOption)`** — called by `SearchListPresenter.openSortSheet()` before sheet is presented:
  - Sets `draftSort = activeSort`

- **Intent methods:**
  - `selectSort(_ option: SearchSortOption)`: sets `draftSort = option`
  - `confirm()`: calls `onConfirm(draftSort)`

- No Interactor required — no service calls.

---

### Task 7 — `SearchListView`

**File:** `Sources/SearchFeature/View/SearchListView.swift`

- **Declaration:** `struct SearchListView: View`

- **Stored properties:**
  - `private let presenter: SearchListPresenter`
  - `private let filterSheetPresenter: SearchFilterSheetPresenter`
  - `private let sortSheetPresenter: SearchSortSheetPresenter`
  - `private let router: SearchRouter`
  - `@FocusState private var isSearchFieldFocused: Bool`

- **`body` structure:**
  - `NavigationStack(path: $router.navigationPath)` with `.navigationTitle("Search")` and `.navigationBarTitleDisplayMode(.large)`
  - Toolbar: leading filter icon button (`DesignSystem.Icons.filter` or `DesignSystem.Icons.filterActive` when `presenter.isFilterActive`) + trailing sort icon button; both disabled when `searchState` is `.idle` or `.loading`
  - Search field: `TextField("Search movies...", text: $presenter.query)` with submit action calling `presenter.submitSearch()`; `@FocusState` focus binding; Return key triggers search
  - Search button below or alongside field: disabled when `!presenter.canSubmitSearch`
  - Results area: switches on `presenter.searchState`
  - `.scrollDismissesKeyboard(.immediately)` applied to the results `ScrollView` / `List`
  - `.sheet(isPresented: $presenter.isFilterSheetPresented)` — presents `SearchFilterSheetView(presenter: filterSheetPresenter)`; drag-to-dismiss discards draft (no explicit cancel action needed — sheet is dismissed without calling `confirm()`)
  - `.sheet(isPresented: $presenter.isSortSheetPresented)` — presents `SearchSortSheetView(presenter: sortSheetPresenter)`; same drag-to-dismiss discard semantics

- **Results area rendering** (switch on `presenter.searchState`):

  | State | Rendered content |
  |---|---|
  | `.idle` | `EmptyStateView` with "Search for a movie" prompt |
  | `.loading` | `LoadingView()` centered in results area |
  | `.results(_, let filtered)` where `filtered` non-empty | `List(filtered, id: \.id)` where each row is `MovieCardView` in a `Button` calling `presenter.selectMovie(movieId: movie.id)` with `imageState: presenter.imageStates[movie.id] ?? .placeholder` |
  | `.empty(.noMatches)` | `EmptyStateView` — "No movies found" message |
  | `.empty(.filtersEliminated)` | `EmptyStateView` — "No results match your active filters" + "Clear Filters" `Button` calling `presenter.clearActiveFilters()` |
  | `.error(let error, _)` | `ErrorStateView` with error message + retry `Button` calling `presenter.retrySearch()` |

- **Navigation destination:**
  ```swift
  .navigationDestination(for: Int.self) { movieId in
      MovieDetailView(movieId: movieId)
  }
  ```

- **iOS-specific concerns:**
  - `.scrollDismissesKeyboard(.immediately)` on results scroll container
  - Search field: default keyboard; Return key submits via `.onSubmit`
  - Filter icon: `DesignSystem.Icons.filter` (inactive) vs `DesignSystem.Icons.filterActive` (active); sourced from DesignSystem package
  - No haptic feedback (not required for MVP)
  - No accessibility identifiers (deferred)

---

### Task 8 — `SearchFilterSheetView`

**File:** `Sources/SearchFeature/View/SearchFilterSheetView.swift`

- **Declaration:** `struct SearchFilterSheetView: View`

- **Stored property:** `private let presenter: SearchFilterSheetPresenter`

- **`body` structure:**
  - `NavigationStack` header with "Filters" title, "Done" toolbar button calling `presenter.confirm()` then dismiss
  - Genre section:
    - Switch on `presenter.genreLoadState`:
      - `.loading` → `LoadingView()`
      - `.loaded(let genres)` → `List` of toggle rows; each row: genre name + checkmark when `presenter.draftFilters.selectedGenreIds.contains(genre.id)`; tap calls `presenter.toggleGenre(id:)`
      - `.error` → inline `ErrorStateView` with "Retry" button calling `presenter.retryGenreFetch()`
  - Rating section:
    - `Toggle` bound to `presenter.draftFilters.minimumRatingEnabled` via intent: calls `presenter.toggleMinimumRating()`
    - `Stepper` — shown only when `presenter.draftFilters.minimumRatingEnabled`; value `presenter.draftFilters.minimumRating` in range `1...10`; calls `presenter.setMinimumRating(_:)`
  - Year section:
    - From Year `TextField` with `.numberPad` keyboard; text bound via `onChange` to `presenter.updateFromYear(_:)`; red border when `presenter.fromYearError != nil` or `presenter.yearRangeError != nil`; inline error text below field
    - To Year `TextField` with `.numberPad` keyboard; text bound via `onChange` to `presenter.updateToYear(_:)`; red border when `presenter.toYearError != nil` or `presenter.yearRangeError != nil`; cross-field error message when `presenter.yearRangeError != nil`
  - "Clear All Filters" `Button` at bottom calling `presenter.clearAllFilters()`
  - `.onAppear { presenter.viewAppeared() }`

- **Drag-to-dismiss:** handled naturally by SwiftUI `.sheet` — no `onConfirm` is called; draft is discarded

---

### Task 9 — `SearchSortSheetView`

**File:** `Sources/SearchFeature/View/SearchSortSheetView.swift`

- **Declaration:** `struct SearchSortSheetView: View`

- **Stored property:** `private let presenter: SearchSortSheetPresenter`

- **`body` structure:**
  - `NavigationStack` header with "Sort By" title, "Done" toolbar button calling `presenter.confirm()` then dismiss
  - `List` of `SearchSortOption.allCases` each rendered as a row with label and checkmark when `presenter.draftSort == option`; tap calls `presenter.selectSort(_:)`

  | Option | Label |
  |---|---|
  | `.releaseDate` | "Release Date (Newest First)" |
  | `.title` | "Title (A–Z)" |
  | `.voteAverage` | "Rating (Highest First)" |

- **Drag-to-dismiss:** draft discarded; no `onConfirm` called

---

### Task 10 — `SearchRouterProtocol` + `SearchRouter`

**Files:** `Sources/SearchFeature/Router/SearchRouterProtocol.swift`, `Sources/SearchFeature/Router/SearchRouter.swift`

- **`SearchRouterProtocol`:**
  ```swift
  protocol SearchRouterProtocol: AnyObject {
      func pushMovieDetail(movieId: Int)
  }
  ```

- **`SearchRouter`** (`@Observable final class`, `SearchRouterProtocol`):
  - `var navigationPath: NavigationPath = NavigationPath()`
  - `private let tmdbClient: any TMDBClientProtocol`
  - `init(tmdbClient: any TMDBClientProtocol)`
  - `func pushMovieDetail(movieId: Int)`: appends `movieId` to `navigationPath`
  - `func makeRootView() -> some View`: assembles the full V-I-P-E-R graph:
    1. `let listInteractor = SearchListInteractor(tmdbClient: tmdbClient)`
    2. `let filterInteractor = SearchFilterSheetInteractor(tmdbClient: tmdbClient)`
    3. `let listPresenter = SearchListPresenter(interactor: listInteractor)`
    4. `let filterSheetPresenter = SearchFilterSheetPresenter(interactor: filterInteractor, onConfirm: { [weak listPresenter] in listPresenter?.commitFilters($0) })`
    5. `let sortSheetPresenter = SearchSortSheetPresenter(onConfirm: { [weak listPresenter] in listPresenter?.commitSort($0) })`
    6. Wire reset callbacks into `listPresenter` (inject via dedicated `init` parameters or setter properties): `listPresenter.onOpenFilterSheet = { [weak filterSheetPresenter] filters in filterSheetPresenter?.reset(from: filters) }` and `listPresenter.onOpenSortSheet = { [weak sortSheetPresenter] sort in sortSheetPresenter?.reset(to: sort) }`
    7. `listPresenter.router = self`
    8. `return SearchListView(presenter: listPresenter, filterSheetPresenter: filterSheetPresenter, sortSheetPresenter: sortSheetPresenter, router: self)`

- **Assembly rule:** `makeRootView()` is the only entry point that allocates Interactors and Presenters. No type outside this method constructs these objects.

---

### Task 11 — Package and App Integration

**Files:** `MovieTrackerPackage/Package.swift`, `MovieTracker/MovieTrackerApp.swift` (or equivalent app-target bootstrap)

- **New SPM target** in `Package.swift`:
  ```swift
  .target(
      name: "SearchFeature",
      dependencies: ["DomainModels", "SharedUIComponents", "TMDBClient", "MovieDetailFeature"]
  )
  ```

- **`TabView` integration:** Add `SearchRouter(tmdbClient: tmdbClient).makeRootView()` as the second tab in the root `TabView`:
  ```swift
  SearchRouter(tmdbClient: tmdbClient).makeRootView()
      .tabItem { Label("Search", systemImage: DesignSystem.Icons.search) }
      .tag(1)
  ```
  If `MovieDetailFeature` is not yet available, stub `.navigationDestination(for: Int.self)` with `Text("Movie Detail \(movieId)")` in `SearchListView` and omit the `MovieDetailFeature` dependency until it exists.

---

### Task 12 — SwiftUI Previews

**File:** `Sources/SearchFeature/View/SearchViews+Previews.swift`

- **`MockSearchListInteractor`** (preview-only, `#if DEBUG`):
  - `enum Behavior { case success([Movie]), case failure(TMDBError), case loading }`
  - `searchMovies(query:)`: returns fixture movies, throws, or suspends indefinitely per `Behavior`
  - `fetchPosterData(posterPath:)`: throws `.networkFailure`

- **`MockSearchFilterSheetInteractor`** (preview-only):
  - `enum Behavior { case success([Genre]), case failure(TMDBError), case loading }`
  - `fetchGenres(force:)`: returns fixture genres, throws, or suspends

- **`SearchFixtures`** (`#if DEBUG`, `Sources/SearchFeature/Testing/SearchFixtures.swift`):
  - 3–5 `Movie` structs with varied fields
  - 5–8 `Genre` structs

- **Preview variants:**

  | Screen | Previewed states |
  |---|---|
  | `SearchListView` | `.idle`, `.loading`, `.results` (multiple cards), `.empty(.noMatches)`, `.empty(.filtersEliminated)`, `.error` |
  | `SearchFilterSheetView` | Genre `.loading`, genre `.loaded` with several genres selected + active rating filter + year range, genre `.error` |
  | `SearchSortSheetView` | All three sort options; one selected |

---

### Task 13 — Unit Tests

**Files:** `Tests/SearchFeatureTests/`

- **`SearchListPresenterTests.swift`** — tests constructed with `MockSearchListInteractor`:

  | Scenario | Assertion |
  |---|---|
  | Submit search → success (non-empty) | `searchState` transitions `.idle → .loading → .results` |
  | Submit search → success (empty array) | `.loading → .empty(.noMatches)` |
  | Submit search → `TMDBError` thrown | `.loading → .error` |
  | Retry from `.error` state | Re-issues search; `.error → .loading` |
  | New submission cancels in-flight task | Previous task is cancelled; `searchMovies` called once with new query |
  | Cannot submit when query is whitespace-only | `submitSearch()` no-ops; `searchMovies` never called |
  | Filter applied → filtered is empty, all is non-empty | `searchState = .empty(.filtersEliminated)` |
  | Filter applied → filtered is non-empty | `searchState = .results` with correct subset |
  | `clearActiveFilters()` resets and recomputes | `activeFilters.isDefault == true`; `recomputeFilteredResults()` called |
  | Genre failure does not affect `searchState` | `searchState` remains `.results` after `filterSheetPresenter` genre error |
  | Sort `.title` order | `filtered` is alphabetically ascending |
  | Sort `.releaseDate` order | `filtered` is descending by release date |
  | Sort `.voteAverage` order | `filtered` is descending by vote average |

- **`SearchFilterSheetPresenterTests.swift`**:

  | Scenario | Assertion |
  |---|---|
  | `viewAppeared()` triggers genre fetch | `fetchGenres(force: false)` called once |
  | Genre fetch success | `genreLoadState = .loaded` |
  | Genre fetch failure | `genreLoadState = .error` |
  | Retry genre | `fetchGenres(force: true)` called |
  | Year `fromYear` < 1900 | `fromYearError != nil` |
  | Year `fromYear` > current year | `fromYearError != nil` |
  | Year `fromYear` valid boundary (1900) | `fromYearError == nil` |
  | Year `fromYear > toYear` | `yearRangeError != nil` |
  | Year `fromYear == toYear` | `yearRangeError == nil` |
  | `clearAllFilters()` | `draftFilters == SearchFilterState()`; all error properties `nil` |
  | `confirm()` | `onConfirm` called with current `draftFilters` |

---

### Task 14 — Navigation Wiring

- **Entry point:** `SearchRouter.makeRootView()` produces `SearchListView` wrapped in `NavigationStack(path: $router.navigationPath)`; this view is assigned as tab 2 in the root `TabView`
- **Internal push destinations:** `MovieDetailView(movieId:)` registered via `.navigationDestination(for: Int.self)` inside `SearchListView.body`; `SearchRouter.pushMovieDetail(movieId:)` appends `movieId: Int` to `router.navigationPath`
- **Filter sheet:** presented via `.sheet(isPresented: $presenter.isFilterSheetPresented)` in `SearchListView`; `SearchFilterSheetView` is assembled in `SearchRouter.makeRootView()` and passed to `SearchListView`
- **Sort sheet:** presented via `.sheet(isPresented: $presenter.isSortSheetPresented)` in `SearchListView`; same lifetime as filter sheet presenter
- **Confirm dismiss:** filter/sort `confirm()` → callback → `SearchListPresenter.commitFilters/commitSort` → `recomputeFilteredResults()`; followed by programmatic dismiss via `@Environment(\.dismiss)`
- **Drag-to-dismiss:** SwiftUI sets `isPresented = false` without any `confirm()` call being made; draft state is discarded

---

## Open Questions / Deferred Decisions

1. **`reset` callback wiring pattern:** Task 10 describes injecting `onOpenFilterSheet` and `onOpenSortSheet` closures into `SearchListPresenter`. An alternative is to pass `filterSheetPresenter` and `sortSheetPresenter` directly into `SearchListPresenter` at construction. The closure approach keeps Presenter dependencies minimal; the direct injection approach is simpler to test. Resolve at implementation time.

2. **Genre cache preservation across sheet presentations:** Task 5 notes an optimization: if `genreLoadState` is already `.loaded` when `reset(from:)` is called, skip the re-fetch. This is desirable UX but adds a branch to the genre fetch guard. Confirm with the team whether genres should always re-fetch on each sheet presentation or be preserved for the session.

3. **`@MainActor` isolation in unit tests:** All Presenters are `@MainActor`-isolated. Test cases must be annotated `@MainActor` or wrapped in `await MainActor.run { }`. Decide on a per-project convention and apply consistently across all feature test targets.

4. **`MovieDetailFeature` stub:** If `MovieDetailFeature` is not yet available when `SearchFeature` is implemented, the `.navigationDestination(for: Int.self)` should use a `Text` stub. The `MovieDetailFeature` SPM dependency is added once that feature exists; no other changes to `SearchFeature` are required at that point.
