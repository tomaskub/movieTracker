# MovieDetail Feature Implementation Plan

## Presentation Architecture

VIPER with `@Observable` Presenter and Router. Five roles for `MovieDetailFeature`:

| Role | Concrete type | Responsibility |
|---|---|---|
| View | `MovieDetailView` | Passive SwiftUI view; observes `MovieDetailPresenter` and `MovieDetailRouter`; forwards all user events to Presenter |
| Interactor | `MovieDetailInteractor` / `MovieDetailInteractorProtocol` | Calls `TMDBClientProtocol` (async), `WatchlistRepository` (sync), and `ReviewRepository` (sync); returns domain types to Presenter |
| Presenter | `MovieDetailPresenter` (`@Observable`) | Owns all four sub-states; transforms Interactor output into view-ready state; drives `.confirmationDialog`; delegates navigation events to Router |
| Entity | `DetailState`, `CastState`, `WatchlistState`, `ReviewState`, `WizardPresentation` (view-ready enums) | Concrete state types consumed directly by the View |
| Router | `MovieDetailRouter` (`@Observable`) | Owns `wizardPresentation: WizardPresentation?`; assembles the MovieDetail V-I-P-E-R graph via `makeView(movieId:)`; builds the ReviewWizard VIPER module via `makeWizardView(movieId:mode:)` |

Key platform types used:
- `@Observable` (iOS 17) on `MovieDetailPresenter` and `MovieDetailRouter`
- `Task<Void, Never>` for in-flight `fetchMovie`, `fetchCredits`, watchlist mutation, and review delete tasks with cancellation
- `async let` for parallel `fetchMovie(id:)` + `fetchCredits(id:)` dispatch on screen appear
- Typed throws (`throws(TMDBError)`, `throws(WatchlistRepositoryError)`, `throws(ReviewRepositoryError)`) at the Interactor protocol boundary

---

## Screen Inventory

### Screen: MovieDetailView

- **View file:** `Sources/MovieDetailFeature/View/MovieDetailView.swift`
- **Presenter file:** `Sources/MovieDetailFeature/Presenter/MovieDetailPresenter.swift`
- **State enums file:** `Sources/MovieDetailFeature/Entity/MovieDetailStates.swift`
- **Interactor files:** `Sources/MovieDetailFeature/Interactor/MovieDetailInteractorProtocol.swift`, `Sources/MovieDetailFeature/Interactor/MovieDetailInteractor.swift`
- **Router file:** `Sources/MovieDetailFeature/Router/MovieDetailRouter.swift`
- **Navigation:** pushed onto the active tab's `NavigationStack` by the parent tab router (Catalog, Search, or Watchlist); receives `movieId: Int` as sole input
- **Scaffolding stub to replace:** `.navigationDestination(for: Int.self)` in `CatalogView`, `SearchListView`, and `WatchlistListView` — each currently renders `Text("Movie Detail \(movieId)")`

---

## Implementation Tasks

### Task 1 — State Enums and `WizardPresentation`

**File:** `Sources/MovieDetailFeature/Entity/MovieDetailStates.swift`

Define five types that represent every discrete rendering state in `MovieDetailView`:

```swift
enum DetailState {
    case loading
    case loaded(MovieDetail)
    case error(TMDBError)
}

enum CastState {
    case loading
    case loaded([CastMember])
    case unavailable
}

enum WatchlistState {
    case loading
    case onWatchlist
    case notOnWatchlist
    case mutating
    case error(String)
}

enum ReviewState {
    case loading
    case hasReview(Review)
    case noReview
    case error(String)
}

enum WizardPresentation: Identifiable {
    case create
    case edit

    var id: String {
        switch self {
        case .create: "create"
        case .edit: "edit"
        }
    }
}
```

- All five types are `internal` to the module.
- `WizardPresentation` conforms to `Identifiable` for use with `.fullScreenCover(item:)`.
- No other state is needed at the entity layer; all transient booleans (`showDeleteConfirmation`) live in the Presenter.

---

### Task 2 — `MovieDetailInteractorProtocol` + `MovieDetailInteractor`

**Files:** `Sources/MovieDetailFeature/Interactor/MovieDetailInteractorProtocol.swift`, `Sources/MovieDetailFeature/Interactor/MovieDetailInteractor.swift`

**Protocol:**

```swift
protocol MovieDetailInteractorProtocol: AnyObject {
    // Async — TMDB network calls
    func fetchMovie(id: Int) async throws(TMDBError) -> MovieDetail
    func fetchCredits(id: Int) async throws(TMDBError) -> [CastMember]

    // Sync — WatchlistRepository (MainActor-confined)
    func checkWatchlistStatus(movieId: Int) throws(WatchlistRepositoryError) -> Bool
    func addToWatchlist(movie: Movie) throws(WatchlistRepositoryError)
    func removeFromWatchlist(movieId: Int) throws(WatchlistRepositoryError)

    // Sync — ReviewRepository (MainActor-confined)
    func fetchReview(movieId: Int) throws(ReviewRepositoryError) -> Review?
    func deleteReview(movieId: Int) throws(ReviewRepositoryError)
}
```

**`MovieDetailInteractor`** (`final class`):

- Stored properties:
  - `private let tmdbClient: any TMDBClientProtocol`
  - `private let watchlistRepository: any WatchlistRepository`
  - `private let reviewRepository: any ReviewRepository`

- `init(tmdbClient: any TMDBClientProtocol, watchlistRepository: any WatchlistRepository, reviewRepository: any ReviewRepository)`

- Each method delegates to the corresponding service call with no transformation. `fetchMovie` and `fetchCredits` pass through `TMDBError` directly. Watchlist and review methods pass through their respective typed error.

- The concrete class is `@MainActor`-isolated to match `WatchlistRepository` and `ReviewRepository` concrete confinement. `@MainActor` is not expressed on the protocol.

---

### Task 3 — `MovieDetailPresenter`

**File:** `Sources/MovieDetailFeature/Presenter/MovieDetailPresenter.swift`

**Declaration:** `@Observable @MainActor final class MovieDetailPresenter`

**Stored properties (observable):**

| Property | Type | Initial value |
|---|---|---|
| `detailState` | `DetailState` | `.loading` |
| `castState` | `CastState` | `.loading` |
| `watchlistState` | `WatchlistState` | `.loading` |
| `reviewState` | `ReviewState` | `.loading` |
| `showDeleteConfirmation` | `Bool` | `false` |

**Stored properties (private, non-observable):**

| Property | Type |
|---|---|
| `private let interactor` | `any MovieDetailInteractorProtocol` |
| `private let movieId` | `Int` |
| `weak var router` | `(any MovieDetailRouterProtocol)?` |
| `private var fetchMovieTask` | `Task<Void, Never>?` |
| `private var fetchCreditsTask` | `Task<Void, Never>?` |
| `private var watchlistTask` | `Task<Void, Never>?` |
| `private var reviewDeleteTask` | `Task<Void, Never>?` |

**`init(movieId: Int, interactor: any MovieDetailInteractorProtocol)`**

**Action handlers and state machine:**

| Method | Guard | Side Effects | State Transitions |
|---|---|---|---|
| `handleAppear()` | No-op if any in-flight task is active | Cancels and resets all tasks; calls `startPrimaryFetch()` and `startCreditsFetch()` | `detailState → .loading`, `castState → .loading`, `watchlistState → .loading`, `reviewState → .loading` |
| `handleRetryDetail()` | None | Cancels `fetchMovieTask`; calls `startPrimaryFetch()` | `detailState → .loading`, `watchlistState → .loading`, `reviewState → .loading` |
| `handleRetryCast()` | None | Cancels `fetchCreditsTask`; calls `startCreditsFetch()` | `castState → .loading` |
| `handleToggleWatchlist()` | Guard `detailState == .loaded`; guard `watchlistState != .mutating` | Reads current state; calls `interactor.addToWatchlist` or `interactor.removeFromWatchlist` synchronously inside a `Task` | `watchlistState → .mutating` → `.onWatchlist` / `.notOnWatchlist` on success, `.error(message)` on failure |
| `handleLogReview()` | None | Calls `router?.presentWizard(mode: .create)` | No state change |
| `handleEditReview()` | None | Calls `router?.presentWizard(mode: .edit)` | No state change |
| `handleDeleteReviewTapped()` | None | — | `showDeleteConfirmation → true` |
| `handleDeleteReviewConfirmed()` | None | Calls `interactor.deleteReview(movieId:)` inside `reviewDeleteTask` | `showDeleteConfirmation → false`; `reviewState → .loading` → `.noReview` on success, `.error(message)` on failure |
| `handleDeleteReviewCancelled()` | None | — | `showDeleteConfirmation → false` |
| `handleWizardDismissed()` | None | Calls `interactor.fetchReview(movieId:)` synchronously; updates `reviewState` | `reviewState → .loading` → `.hasReview(review)` or `.noReview` on success, `.error(message)` on failure |

**Private `startPrimaryFetch()` method:**
1. Cancel and nil `fetchMovieTask`.
2. Set `detailState = .loading`, `watchlistState = .loading`, `reviewState = .loading`.
3. Assign a new `Task<Void, Never>` to `fetchMovieTask` that:
   - Calls `try await interactor.fetchMovie(id: movieId)`.
   - Checks `Task.isCancelled` before any state mutation.
   - On success: sets `detailState = .loaded(movieDetail)`, then immediately and synchronously calls `interactor.checkWatchlistStatus(movieId:)` and `interactor.fetchReview(movieId:)` to derive `watchlistState` and `reviewState`.
   - On `TMDBError`: sets `detailState = .error(error)`.

**Private `startCreditsFetch()` method:**
1. Cancel and nil `fetchCreditsTask`.
2. Set `castState = .loading`.
3. Assign a new `Task<Void, Never>` to `fetchCreditsTask` that:
   - Calls `try await interactor.fetchCredits(id: movieId)`.
   - Checks `Task.isCancelled`.
   - On success: sets `castState = .loaded(castMembers)`. Cast slicing to the first three members is performed at the View render site, not here.
   - On `TMDBError`: sets `castState = .unavailable`.

**`deinit`:** cancels `fetchMovieTask`, `fetchCreditsTask`, `watchlistTask`, `reviewDeleteTask`.

**Concurrency contract:** the entire class is `@MainActor`-isolated; async service calls are awaited inside `Task<Void, Never>` bodies; synchronous repository calls are made directly on the main actor after async tasks complete.

---

### Task 4 — `MovieDetailView`

**File:** `Sources/MovieDetailFeature/View/MovieDetailView.swift`

**Declaration:** `struct MovieDetailView: View`

**Stored properties:**
- `private let presenter: MovieDetailPresenter`
- `private let router: MovieDetailRouter`

**`init(presenter: MovieDetailPresenter, router: MovieDetailRouter)`**

**`body` top-level structure:**

```
ScrollView (when detailState == .loaded)
  PosterSection          — AsyncImage with .full PosterSize; placeholder: gray RoundedRectangle + DesignSystem camera icon
  DetailSection          — title, overview, genres, release date, TMDB rating
  CastSection            — driven by castState
  WatchlistCTASection    — driven by watchlistState
  ReviewSection          — driven by reviewState
```

**`detailState` rendering:**

| State | Rendered content |
|---|---|
| `.loading` | Full-screen `LoadingView()` centered; no other sections visible |
| `.loaded(movieDetail)` | `ScrollView` with all sections |
| `.error(tmdbError)` | Full-screen `ErrorStateView(message:onRetry:)` with `presenter.handleRetryDetail` as retry handler; back navigation remains available |

**`castState` rendering** (only visible when `detailState == .loaded`):

| State | Rendered content |
|---|---|
| `.loading` | Section-level `LoadingView()` inline within cast section |
| `.loaded(castMembers)` | Up to 3 members (`castMembers.prefix(3)`) rendered by name and character |
| `.unavailable` | "Cast unavailable" inline text + retry `Button("Retry loading cast") { presenter.handleRetryCast() }` |

**`watchlistState` rendering** (only visible when `detailState == .loaded`):

| State | Rendered content |
|---|---|
| `.loading` | CTA `Button` disabled |
| `.onWatchlist` | Active `Button("Remove from Watchlist") { presenter.handleToggleWatchlist() }` |
| `.notOnWatchlist` | Active `Button("Add to Watchlist") { presenter.handleToggleWatchlist() }` |
| `.mutating` | `ProgressView()` spinner replacing the CTA |
| `.error(message)` | Active CTA (restored to last known state) + inline `Text(message)` below CTA |

**`reviewState` rendering** (only visible when `detailState == .loaded`):

| State | Rendered content |
|---|---|
| `.loading` | Section-level `LoadingView()` inline |
| `.noReview` | `Button("Log a Review") { presenter.handleLogReview() }` |
| `.hasReview(review)` | Read-only summary (star rating display, tags, notes) + `Button("Edit Review")` + `Button("Delete Review", role: .destructive)` |
| `.error(message)` | Inline `Text(message)` below the review section |

**View modifiers applied to `body`:**
```swift
.navigationTitle(movieTitle)          // title from detailState when loaded; empty string while loading
.navigationBarTitleDisplayMode(.large)
.onAppear { presenter.handleAppear() }
.fullScreenCover(item: $router.wizardPresentation) { mode in
    router.makeWizardView(movieId: presenter.movieId, mode: mode)
        .onDisappear { presenter.handleWizardDismissed() }
}
.confirmationDialog(
    "Are you sure you want to delete the review?",
    isPresented: $presenter.showDeleteConfirmation,
    titleVisibility: .visible
) {
    Button("Delete", role: .destructive) { presenter.handleDeleteReviewConfirmed() }
    Button("Cancel", role: .cancel) { presenter.handleDeleteReviewCancelled() }
}
```

**Poster URL assembly:** `MovieDetail.movie.posterPath` is used with `TMDBClient`'s image URL pattern at the presentation layer; the `PosterSize.full` (`w500`) variant is used. Assembled at render time as a computed URL from the relative path.

**iOS-specific concerns:**
- No `@FocusState` (no text inputs).
- No haptics (out of scope for MVP).
- Dynamic Type: all text uses DesignSystem typography tokens. At the largest accessibility sizes, the poster + title stack should reflow vertically to avoid truncation.
- `accessibilityReduceMotion`: `LoadingView` spinner animation should respect `UIAccessibility.isReduceMotionEnabled`.
- No deep link entry point (out of scope for MVP).

**Accessibility identifiers for UI testing:**

| Element | Accessibility identifier |
|---|---|
| Poster image | `"movieDetailPoster"` |
| Watchlist CTA button | `"watchlistCTAButton"` |
| Watchlist mutating spinner | `"watchlistMutatingSpinner"` |
| "Log a Review" button | `"logReviewButton"` |
| "Edit Review" button | `"editReviewButton"` |
| "Delete Review" button | `"deleteReviewButton"` |
| Cast retry button | `"castRetryButton"` |
| Primary detail retry button | `"detailRetryButton"` |
| Star rating display | `"starRatingDisplay"` |
| Delete confirmation destructive button | `"deleteReviewConfirmButton"` |

**Accessibility labels:**
- Poster image (loaded): `"[Movie title] poster"` / (placeholder): `"No poster available"`
- Watchlist add: `"Add [Movie title] to Watchlist"`
- Watchlist remove: `"Remove [Movie title] from Watchlist"`
- Watchlist spinner: `"Updating watchlist"`
- Log review: `"Log a Review for [Movie title]"`
- Edit review: `"Edit your review of [Movie title]"`
- Delete review: `"Delete your review of [Movie title]"`
- Cast retry: `"Retry loading cast"`
- Detail retry: `"Retry loading movie detail"`
- Star rating: `"[N] out of 5 stars"`

---

### Task 5 — `MovieDetailRouterProtocol` + `MovieDetailRouter`

**File:** `Sources/MovieDetailFeature/Router/MovieDetailRouter.swift`

**`MovieDetailRouterProtocol`:**

```swift
protocol MovieDetailRouterProtocol: AnyObject {
    func presentWizard(mode: WizardPresentation)
    func dismissWizard()
}
```

**`MovieDetailRouter`** (`@Observable final class`, conforms to `MovieDetailRouterProtocol`):

- **Observable stored property:**
  - `var wizardPresentation: WizardPresentation?`

- **Private stored properties:**
  - `private let tmdbClient: any TMDBClientProtocol`
  - `private let watchlistRepository: any WatchlistRepository`
  - `private let reviewRepository: any ReviewRepository`

- **`init(tmdbClient: any TMDBClientProtocol, watchlistRepository: any WatchlistRepository, reviewRepository: any ReviewRepository)`**

- **`func presentWizard(mode: WizardPresentation)`:** sets `wizardPresentation = mode`

- **`func dismissWizard()`:** sets `wizardPresentation = nil`

- **`func makeView(movieId: Int) -> some View`:** assembles the V-I-P-E-R graph:
  1. `let interactor = MovieDetailInteractor(tmdbClient: tmdbClient, watchlistRepository: watchlistRepository, reviewRepository: reviewRepository)`
  2. `let presenter = MovieDetailPresenter(movieId: movieId, interactor: interactor)`
  3. `presenter.router = self`
  4. `return MovieDetailView(presenter: presenter, router: self)`

- **`func makeWizardView(movieId: Int, mode: WizardPresentation) -> some View`:** builds the ReviewWizard VIPER module by calling the public factory entry point from `ReviewFeature` (e.g. `ReviewWizardRouter(movieId: movieId, mode: mode, reviewRepository: reviewRepository).makeView()`). The exact ReviewWizard factory signature is deferred to the ReviewWizard implementation plan.

**Assembly rule:** `makeView(movieId:)` is the only entry point that allocates `MovieDetailInteractor` and `MovieDetailPresenter`. Nothing outside this method constructs these types.

**Parent router integration:** Each tab router (`CatalogRouter`, `SearchRouter`, `WatchlistRouter`) receives a `MovieDetailRouter` instance injected at construction. In each tab's `.navigationDestination(for: Int.self)`, the stub `Text("Movie Detail \(movieId)")` is replaced with:

```swift
.navigationDestination(for: Int.self) { movieId in
    movieDetailRouter.makeView(movieId: movieId)
}
```

The `MovieDetailRouter` instance is held as a stored property by the parent router. A single shared router instance per tab is sufficient because navigation path ensures only one `MovieDetailView` is active per tab at a time.

---

### Task 6 — Package Integration

**File:** `MovieTrackerPackage/Package.swift`

New SPM target:

```swift
.target(
    name: "MovieDetailFeature",
    dependencies: [
        "DomainModels",
        "SharedUIComponents",
        "DesignSystem",
        "TMDBClient",
        "WatchlistRepository",
        "ReviewRepository",
        "ReviewFeature"
    ]
)
```

**Parent feature targets that must add `MovieDetailFeature` as a dependency:**
- `CatalogFeature`
- `SearchFeature`
- `WatchlistFeature`

Each parent target replaces the `Text("Movie Detail \(movieId)")` stub in its `.navigationDestination` with `movieDetailRouter.makeView(movieId:)`.

---

### Task 7 — SwiftUI Previews

**File:** `Sources/MovieDetailFeature/View/MovieDetailView+Previews.swift`

**`MockMovieDetailInteractor`** (defined in this file, preview-only, `#if DEBUG`):

```swift
struct MockMovieDetailInteractor: MovieDetailInteractorProtocol {
    var movieResult: Result<MovieDetail, TMDBError> = .success(PreviewFixtures.movieDetail)
    var creditsResult: Result<[CastMember], TMDBError> = .success(PreviewFixtures.castMembers)
    var watchlistContains: Bool = false
    var review: Review? = nil
}
```

Each method either returns the configured fixture or throws the configured error. Async methods for TMDB may suspend indefinitely via `try await Task.never()` to simulate the `.loading` state.

**`PreviewFixtures`** (internal enum, `#if DEBUG`):
- Static `MovieDetail` value with a real-looking title, overview, genre list, release date, vote average
- Static `[CastMember]` with 4 members (preview will slice to 3)
- Static `Review` with rating 4, one tag, short notes
- Defined in `Sources/MovieDetailFeature/Testing/PreviewFixtures.swift`

**Preview variants** (one per named sub-state combination from the feature plan §10):

| Preview name | `detailState` | `watchlistState` | `reviewState` | `castState` |
|---|---|---|---|---|
| Loading | `.loading` | `.loading` | `.loading` | `.loading` |
| Primary error | `.error(.networkFailure)` | — | — | — |
| Loaded — not on watchlist, no review, cast loading | `.loaded(…)` | `.notOnWatchlist` | `.noReview` | `.loading` |
| Loaded — not on watchlist, no review, cast unavailable | `.loaded(…)` | `.notOnWatchlist` | `.noReview` | `.unavailable` |
| Loaded — not on watchlist, no review, cast loaded | `.loaded(…)` | `.notOnWatchlist` | `.noReview` | `.loaded([…])` |
| Loaded — on watchlist, with review, cast loaded | `.loaded(…)` | `.onWatchlist` | `.hasReview(…)` | `.loaded([…])` |
| Loaded — watchlist mutating | `.loaded(…)` | `.mutating` | `.noReview` | `.loaded([…])` |

Each preview constructs a `MockMovieDetailInteractor` configured to produce the target state immediately, then builds the Presenter with pre-set state values directly (bypassing `handleAppear()`) to avoid async side effects in previews.

---

### Task 8 — Unit Tests

**File:** `Tests/MovieDetailFeatureTests/MovieDetailPresenterTests.swift`

**`MockMovieDetailInteractor`** (test double, conforms to `MovieDetailInteractorProtocol`):
- Configurable `fetchMovieResult: Result<MovieDetail, TMDBError>`
- Configurable `fetchCreditsResult: Result<[CastMember], TMDBError>`
- Configurable `watchlistContains: Bool`
- Configurable `review: Review?`
- `fetchMovieCallCount: Int`, `fetchCreditsCallCount: Int`, `addToWatchlistCallCount: Int`, etc. for interaction verification

**Test scenarios (Presenter state machine):**

| Scenario | Action | Expected outcome |
|---|---|---|
| `fetchMovie` succeeds | `handleAppear()` | `detailState → .loaded`; `watchlistState` + `reviewState` derived |
| `fetchMovie` fails | `handleAppear()` | `detailState → .error`; `watchlistState` + `reviewState` remain `.loading` |
| Retry after `fetchMovie` failure | `handleRetryDetail()` | `detailState → .loading` then resolved |
| `fetchCredits` succeeds | `handleAppear()` | `castState → .loaded([CastMember])` |
| `fetchCredits` fails | `handleAppear()` | `castState → .unavailable` |
| Cast retry | `handleRetryCast()` | `castState → .loading` then resolved; `fetchMovieCallCount` unchanged |
| Add to watchlist — success | `handleToggleWatchlist()` from `.notOnWatchlist` | `watchlistState: .notOnWatchlist → .mutating → .onWatchlist` |
| Add to watchlist — failure | `handleToggleWatchlist()` from `.notOnWatchlist` | `watchlistState: .mutating → .error(message)` |
| Remove from watchlist — success | `handleToggleWatchlist()` from `.onWatchlist` | `watchlistState: .onWatchlist → .mutating → .notOnWatchlist` |
| Remove from watchlist — failure | `handleToggleWatchlist()` from `.onWatchlist` | `watchlistState: .mutating → .error(message)` |
| Toggle guard — `.mutating` | `handleToggleWatchlist()` during mutation | No additional mutation task dispatched |
| Delete review — confirm | `handleDeleteReviewTapped()` + `handleDeleteReviewConfirmed()` | `ReviewRepository.delete` called; `reviewState → .noReview` |
| Delete review — cancel | `handleDeleteReviewTapped()` + `handleDeleteReviewCancelled()` | `ReviewRepository.delete` not called; `reviewState` unchanged |
| Delete review — failure | `handleDeleteReviewConfirmed()` with failure | `reviewState → .error(message)` |
| Wizard dismissed — review created | `handleWizardDismissed()` with review present | `reviewState → .hasReview(…)` |
| Wizard dismissed — review unchanged | `handleWizardDismissed()` with no review | `reviewState → .noReview` |

**Service interaction tests:**
- Verify `fetchMovie(id:)` and `fetchCredits(id:)` are both called on `handleAppear()`.
- Verify `checkWatchlistStatus` and `fetchReview` are only called after `fetchMovie` succeeds.
- Verify `addToWatchlist(movie:)` is called with the `Movie` from `MovieDetail.movie`.
- Verify `removeFromWatchlist(movieId:)` is called with the correct `movieId`.
- Verify `deleteReview(movieId:)` is only called after `handleDeleteReviewConfirmed()`, not after `handleDeleteReviewCancelled()`.
- Verify `handleRetryCast()` calls `fetchCredits(id:)` only — `fetchMovieCallCount` is not incremented.

---

## Open Questions / Deferred Decisions

1. **ReviewWizard factory entry point:** `MovieDetailRouter.makeWizardView(movieId:mode:)` calls a public assembly method on the ReviewWizard VIPER module. The exact method signature and type name (`ReviewWizardRouter`, `ReviewWizardAssembler`, etc.) depend on the ReviewWizard implementation plan, which has not yet been produced. A stub `Text("Review Wizard")` should be used in `makeWizardView` until the ReviewWizard implementation plan is completed.

2. **`@MainActor` isolation in test target:** `MovieDetailPresenter` is `@MainActor`-isolated. All test cases that interact with the Presenter must be annotated `@MainActor` or wrapped in `await MainActor.run { }`. The test target must be configured accordingly.

3. **Parent router dependency injection:** `MovieDetailRouter` is injected into each tab router as a stored property. The exact injection site (composition root, app-level coordinator, or `AppRouter`) is determined by the UI scaffolding implementation step, which pre-dates this feature.

4. **Poster URL assembly helper:** The View needs to construct a full TMDB CDN URL from `MovieDetail.movie.posterPath` and `PosterSize.full`. Whether this is an extension on `String`, a free function, or a method on a shared utility type is left to the implementor; it must not reach into `TMDBClient` directly from the View.
