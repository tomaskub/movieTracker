# ReviewWizard Feature Implementation Plan

## Presentation Architecture

VIPER with `@Observable` Presenter. Five roles for `ReviewFeature`:

| Role | Concrete type | Responsibility |
|---|---|---|
| View | `ReviewWizardView` | Passive SwiftUI view; reads `ReviewWizardPresenter` state; owns `@FocusState` for step 3 keyboard; forwards user events to Presenter |
| Interactor | `ReviewWizardInteractor` / `ReviewWizardInteractorProtocol` | Calls `ReviewRepository` (fetch, create, update); all calls synchronous `throws` |
| Presenter | `ReviewWizardPresenter` (`@Observable`) | Owns all wizard state; drives step transitions and fetch/save state machine; delegates dismissal to Router |
| Entity | `FetchState`, `SaveState`, `WizardStep`, `WizardMode`, `WizardBaseline`, `WizardDraft` | Concrete state and data types consumed by View and Presenter |
| Router | `ReviewWizardRouter` | Holds injected `dismiss: () -> Void` closure; assembles the full V-I-P-E-R graph via `makeView()`; provides the public entry point for `MovieDetailRouter` |

Key platform types:
- `@Observable` (iOS 17) on `ReviewWizardPresenter`
- All `ReviewRepository` calls are synchronous `throws` — no `Task` wrapping required at any layer
- `@FocusState` owned by `ReviewWizardView` (SwiftUI property wrapper; cannot live in an `@Observable` class)
- `.interactiveDismissDisabled(true)` on `ReviewWizardView` at all steps and states

---

## Screen Inventory

### Screen: ReviewWizardView

- **View file:** `Sources/ReviewFeature/View/ReviewWizardView.swift`
- **Presenter file:** `Sources/ReviewFeature/Presenter/ReviewWizardPresenter.swift`
- **State types file:** `Sources/ReviewFeature/Entity/ReviewWizardStates.swift`
- **Interactor files:** `Sources/ReviewFeature/Interactor/ReviewWizardInteractorProtocol.swift`, `Sources/ReviewFeature/Interactor/ReviewWizardInteractor.swift`
- **Router file:** `Sources/ReviewFeature/Router/ReviewWizardRouter.swift`
- **Navigation:** `.fullScreenCover` from `MovieDetailView`; controlled by `MovieDetailRouter.wizardPresentation`; no `NavigationStack` inside the cover; all step transitions are internal state mutations
- **Scaffolding stub to replace:** the `Text("Review Wizard")` placeholder currently returned by `MovieDetailRouter.makeWizardView(movieId:mode:)` in `Sources/MovieDetailFeature/Router/MovieDetailRouter.swift`

---

## Implementation Tasks

### Task 1 — Entity State Types

**File:** `Sources/ReviewFeature/Entity/ReviewWizardStates.swift`

Define all concrete state and data types for the wizard:

```swift
enum FetchState: Equatable {
    case loading
    case loaded
    case error(message: String)
}

enum SaveState: Equatable {
    case idle
    case saving
    case error(message: String)
}

enum WizardStep {
    case step1, step2, step3, step4
}

enum WizardMode {
    case create, edit
}

struct WizardBaseline: Equatable {
    var rating: Int
    var tags: [ReviewTag]
    var notes: String

    static let empty = WizardBaseline(rating: 0, tags: [], notes: "")
}

struct WizardDraft: Equatable {
    var rating: Int
    var tags: [ReviewTag]
    var notes: String
}
```

- All types are `internal` to the `ReviewFeature` module.
- `WizardBaseline.empty` is the default used in create mode; `WizardDraft` is always initialized from `WizardBaseline` after a successful fetch.

---

### Task 2 — `ReviewWizardInteractorProtocol` + `ReviewWizardInteractor`

**Files:** `Sources/ReviewFeature/Interactor/ReviewWizardInteractorProtocol.swift`, `Sources/ReviewFeature/Interactor/ReviewWizardInteractor.swift`

**Protocol:**

```swift
protocol ReviewWizardInteractorProtocol: AnyObject {
    func fetchReview(movieId: Int) throws(ReviewRepositoryError) -> Review?
    func createReview(movieId: Int, rating: Int, tags: [ReviewTag], notes: String) throws(ReviewRepositoryError)
    func updateReview(movieId: Int, rating: Int, tags: [ReviewTag], notes: String) throws(ReviewRepositoryError)
}
```

**`ReviewWizardInteractor`** (`final class`):

- Stored property: `private let reviewRepository: any ReviewRepository`
- `init(reviewRepository: any ReviewRepository)`
- Each method delegates directly to the corresponding `ReviewRepository` call, passing typed errors through unchanged.
- The concrete class is `@MainActor`-isolated to match `ReviewRepository` concrete confinement. `@MainActor` is not expressed on the protocol.

No `async` on any method. All calls are synchronous `throws`.

---

### Task 3 — `ReviewWizardPresenter`

**File:** `Sources/ReviewFeature/Presenter/ReviewWizardPresenter.swift`

**Declaration:** `@Observable @MainActor final class ReviewWizardPresenter`

**Observable stored properties:**

| Property | Type | Initial value |
|---|---|---|
| `fetchState` | `FetchState` | `.loading` |
| `currentStep` | `WizardStep` | `.step1` |
| `saveState` | `SaveState` | `.idle` |
| `resolvedMode` | `WizardMode` | `.create` |
| `baseline` | `WizardBaseline` | `.empty` |
| `draft` | `WizardDraft` | derived from `baseline` |
| `showSaveErrorAlert` | `Bool` | `false` |

**Private non-observable stored properties:**

| Property | Type |
|---|---|
| `private let interactor` | `any ReviewWizardInteractorProtocol` |
| `private let movieId` | `Int` |
| `private let inputMode` | `WizardMode` |
| `weak var router` | `(any ReviewWizardRouterProtocol)?` |

**`init(movieId: Int, inputMode: WizardMode, interactor: any ReviewWizardInteractorProtocol)`**

**Action handlers and state machine:**

| Method | Guard | Side Effects | State Transitions |
|---|---|---|---|
| `handleAppear()` | None | Calls `performFetch()` | `fetchState → .loading` |
| `handleRetryFetch()` | None | Calls `performFetch()` | `fetchState → .loading` |
| `handleDismissFromError()` | None | Calls `router?.dismiss()` | None |
| `handleStarTapped(_ rating: Int)` | None | None | `draft.rating = rating` |
| `handleNextFromStep1()` | None | None | `currentStep → .step2` |
| `handleBackFromStep2()` | None | None | `draft.rating = baseline.rating`; `currentStep → .step1` |
| `handleTagToggled(_ tag: ReviewTag)` | None | None | toggles `tag` in `draft.tags` |
| `handleNextFromStep2()` | None | None | `currentStep → .step3` |
| `handleBackFromStep3()` | None | None | `draft.tags = baseline.tags`; `currentStep → .step2` |
| `handleNotesChanged(_ text: String)` | None | None | `draft.notes = String(text.prefix(500))` |
| `handleNextFromStep3()` | None | None | `currentStep → .step4` |
| `handleBackFromStep4()` | None | None | `draft.notes = baseline.notes`; `currentStep → .step3` |
| `handleCancel()` | None | Calls `router?.dismiss()` | None |
| `handleDiscard()` | None | Calls `router?.dismiss()` | None |
| `handleConfirm()` | Guard `saveState != .saving` | Calls `performSave()` | `saveState → .saving` |
| `handleSaveAlertDismissed()` | None | None | `saveState → .idle`; `showSaveErrorAlert → false` |

**Private `performFetch()` method:**
1. Set `fetchState = .loading`.
2. Call `interactor.fetchReview(movieId: movieId)` synchronously (wrapped in `do/catch`).
3. On success with non-nil `review`: set `baseline` and `draft` from review values; `resolvedMode = .edit`; `fetchState = .loaded`.
4. On success with `nil`: set `baseline = .empty`; `draft = WizardDraft(rating: 0, tags: [], notes: "")`; `resolvedMode = .create`; `fetchState = .loaded`. Input mode `.edit` with a nil fetch result silently falls back to `.create`.
5. On catch: set `fetchState = .error(message: error.localizedDescription)`.

**Private `performSave()` method:**
1. Set `saveState = .saving`.
2. Based on `resolvedMode`, call the appropriate interactor method inside `do/catch`:
   - `.create` → `interactor.createReview(movieId: movieId, rating: draft.rating, tags: draft.tags, notes: draft.notes)`
   - `.edit` → `interactor.updateReview(movieId: movieId, rating: draft.rating, tags: draft.tags, notes: draft.notes)`
3. On success: call `router?.dismiss()`.
4. On catch: `saveState = .error(message: error.localizedDescription)`; `showSaveErrorAlert = true`.

**Concurrency contract:** `@MainActor`-isolated throughout. All repository calls are synchronous. No `Task` wrapping is required. The `.loading` transient states are set immediately before each synchronous call and resolved synchronously after.

---

### Task 4 — `ReviewWizardRouterProtocol` + `ReviewWizardRouter`

**File:** `Sources/ReviewFeature/Router/ReviewWizardRouter.swift`

**`ReviewWizardRouterProtocol`:**

```swift
protocol ReviewWizardRouterProtocol: AnyObject {
    func dismiss()
}
```

**`ReviewWizardRouter`** (`final class`, conforms to `ReviewWizardRouterProtocol`):

- **Private stored properties:**
  - `private let movieId: Int`
  - `private let inputMode: WizardMode`
  - `private let reviewRepository: any ReviewRepository`
  - `private let dismissAction: () -> Void`

- **`init(movieId: Int, inputMode: WizardMode, reviewRepository: any ReviewRepository, dismiss: @escaping () -> Void)`**

- **`func dismiss()`:** calls `dismissAction()`

- **`public func makeView() -> some View`:** assembles the V-I-P-E-R graph:
  1. `let interactor = ReviewWizardInteractor(reviewRepository: reviewRepository)`
  2. `let presenter = ReviewWizardPresenter(movieId: movieId, inputMode: inputMode, interactor: interactor)`
  3. `presenter.router = self`
  4. `return ReviewWizardView(presenter: presenter)`

`makeView()` is the sole public assembly entry point. `MovieDetailRouter.makeWizardView(movieId:mode:)` constructs a `ReviewWizardRouter` and calls `makeView()`:

```swift
func makeWizardView(movieId: Int, mode: WizardPresentation) -> some View {
    let router = ReviewWizardRouter(
        movieId: movieId,
        inputMode: mode == .create ? .create : .edit,
        reviewRepository: reviewRepository,
        dismiss: { [weak self] in self?.dismissWizard() }
    )
    return router.makeView()
}
```

---

### Task 5 — `ReviewWizardView`

**File:** `Sources/ReviewFeature/View/ReviewWizardView.swift`

**Declaration:** `struct ReviewWizardView: View`

**Stored properties:**
- `private let presenter: ReviewWizardPresenter`
- `@FocusState private var isNotesFocused: Bool`

**`init(presenter: ReviewWizardPresenter)`**

**`body` top-level structure:**

The root is a `ZStack` that switches on `presenter.fetchState`:

| `fetchState` | Rendered content |
|---|---|
| `.loading` | `LoadingView()` centered full-screen inside the cover |
| `.error(let message)` | Full-screen error state: `Text(message)` + `Button("Retry") { presenter.handleRetryFetch() }` + `Button("Cancel") { presenter.handleDismissFromError() }`. Uses `ErrorStateView` from `SharedUIComponents` where its interface supports both retry and cancel actions; otherwise inline. |
| `.loaded` | `VStack` containing `WizardProgressBar(currentStep: presenter.currentStep)` followed by the active step sub-view |

When `fetchState == .loaded`, the active step sub-view switches on `presenter.currentStep`:

| `currentStep` | Sub-view |
|---|---|
| `.step1` | `Step1RatingView` |
| `.step2` | `Step2TagsView` |
| `.step3` | `Step3NotesView(isNotesFocused: $isNotesFocused)` |
| `.step4` | `Step4SummaryView` |

**View modifiers applied to the root `ZStack`:**
```swift
.interactiveDismissDisabled(true)
.background(.backgroundPrimary)
.alert(
    "Could not save review",
    isPresented: $presenter.showSaveErrorAlert,
    presenting: presenter.saveState
) { _ in
    Button("OK") { presenter.handleSaveAlertDismissed() }
} message: { saveState in
    if case .error(let message) = saveState {
        Text(message)
    }
}
```

`.onAppear { presenter.handleAppear() }` is applied to the root view.

**`WizardProgressBar`** (private sub-view, same file or `Sources/ReviewFeature/View/WizardProgressBar.swift`):
- Four equal-width `RoundedRectangle` segments in an `HStack(spacing: .xSmall)`.
- Active segments (index ≤ current step index) use `.accent` fill; inactive use `.backgroundTertiary`.
- Accessibility identifier: `"wizardProgressBar"`.
- `.padding(.horizontal, .screenEdge)` and `.padding(.top, .wizardStep)`.

**Step 1 — `Step1RatingView`** (private sub-view):
- Layout: `VStack(spacing: .medium)` with step title `.font(.heading3)` + `HStack(spacing: .xSmall)` of five star `Button` views + Spacer + Next `Button`.
- Star `Button` for index `n` (1–5): shows `Image.starFilled` (DesignSystem) `.foregroundStyle(.rating)` when `n <= presenter.draft.rating`; shows empty star SF Symbol `.foregroundStyle(.backgroundTertiary)` otherwise. Action: `presenter.handleStarTapped(n)`.
- Next button: `Button("Next") { presenter.handleNextFromStep1() }`. Always enabled. `.font(.buttonLabel)`.
- Toolbar: `.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { presenter.handleCancel() } } }`.
- `.padding(.wizardStep)` on the `VStack`.
- Accessibility identifiers: star buttons `"starButton1"` through `"starButton5"`; Next `"step1NextButton"`; Cancel `"step1CancelButton"`.

**Step 2 — `Step2TagsView`** (private sub-view):
- Layout: `VStack(spacing: .medium)` with step title + tag grid + Spacer + `HStack` with Back and Next buttons.
- Tag grid: `LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: .small)` of 11 chip `Button` views iterating `ReviewTag.allCases` in defined order.
- Selected chip: `.background(.accent)`, `.foregroundStyle(.labelOnDark)`, `.cornerRadius(.full)`, `.padding(.tagInset)`. Unselected: `.background(.backgroundSecondary)`, `.cornerRadius(.full)`, `.padding(.tagInset)`.
- Chip action: `presenter.handleTagToggled(tag)`.
- Back: `Button("Back") { presenter.handleBackFromStep2() }`; Next: `Button("Next") { presenter.handleNextFromStep2() }`. Both always enabled.
- Accessibility identifiers: chips `"tagChip_\(tag.rawValue)"`; Back `"step2BackButton"`; Next `"step2NextButton"`.

**Step 3 — `Step3NotesView`** (private sub-view):
- Receives `Binding<Bool>` parameter `isNotesFocused`.
- Layout: `VStack(spacing: .small)` with step title + `ScrollView(.vertical) { TextEditor(text: notesBinding) }` + character counter text + `HStack` with Back and Next buttons.
- `notesBinding`: two-way binding to `presenter.draft.notes`; the `TextEditor` posts `.onChange(of:)` which calls `presenter.handleNotesChanged(_:)`. Since `TextEditor` requires a `Binding<String>`, use a local computed binding via `Binding(get: { presenter.draft.notes }, set: { presenter.handleNotesChanged($0) })`.
- `TextEditor`: `.focused($isNotesFocused)`. `.scrollDismissesKeyboard(.interactively)` on the enclosing `ScrollView`. `.cornerRadius(.medium)`. `.background(.backgroundSecondary)`.
- `.onAppear { isNotesFocused = true }` on the `Step3NotesView` root.
- Character counter: `Text("\(presenter.draft.notes.count) / 500").font(.dsCaption).foregroundStyle(.secondary)`.
- Back/Next: always enabled. Accessibility identifiers: `TextEditor` — `"notesTextEditor"`; counter — `"notesCharacterCounter"`; Back — `"step3BackButton"`; Next — `"step3NextButton"`.

**Step 4 — `Step4SummaryView`** (private sub-view):
- Layout: `VStack(spacing: .medium)` with title "Review Summary" `.font(.heading3)` + read-only summary sections + Spacer + action buttons.
- Summary sections: star rating display (same five-star row, non-interactive), selected tag chips (read-only), notes text.
- Confirm button: `Button("Confirm") { presenter.handleConfirm() }`. Disabled when `presenter.saveState == .saving`; shows `ProgressView()` inline replacing the button label when saving.
- Discard button: `Button("Discard", role: .destructive) { presenter.handleDiscard() }`. Always enabled.
- Back button: `Button("Back") { presenter.handleBackFromStep4() }` in `.toolbar` or inline depending on layout.
- Accessibility identifiers: Confirm `"step4ConfirmButton"`; Discard `"step4DiscardButton"`; Back `"step4BackButton"`.

---

### Task 6 — Navigation Wiring

**Entry point:** `ReviewWizardRouter.makeView()` is the single assembly entry point. `MovieDetailRouter.makeWizardView(movieId:mode:)` constructs a `ReviewWizardRouter` with a `dismiss` closure that calls `MovieDetailRouter.dismissWizard()`, then returns `router.makeView()`. This replaces the `Text("Review Wizard")` stub in `Sources/MovieDetailFeature/Router/MovieDetailRouter.swift`.

**Dismissal flow:**
1. User action (Cancel on step 1 / Discard on step 4 / Dismiss from fetch error / Confirm success) → Presenter calls `router?.dismiss()` → `ReviewWizardRouter.dismissAction()` → `MovieDetailRouter.dismissWizard()` → `wizardPresentation = nil` → `.fullScreenCover` dismissed → `.onDisappear` fires → `MovieDetailPresenter.handleWizardDismissed()`.

**No internal navigation stack.** Step transitions are driven exclusively by `presenter.currentStep` mutations. No `NavigationLink`, `NavigationStack`, or path mutation occurs inside the wizard.

**Sheets/covers from wizard:** None. The wizard does not present any additional modals.

**Deep links:** Not applicable.

---

### Task 7 — Package Integration

**File:** `MovieTrackerPackage/Package.swift`

New SPM target:

```swift
.target(
    name: "ReviewFeature",
    dependencies: [
        "DomainModels",
        "SharedUIComponents",
        "DesignSystem",
        "ReviewRepository"
    ]
)
```

`MovieDetailFeature` already declares `ReviewFeature` as a dependency (per the MovieDetail implementation plan). No changes required to other feature targets.

---

### Task 8 — SwiftUI Previews

**File:** `Sources/ReviewFeature/View/ReviewWizardView+Previews.swift`

**`MockReviewWizardInteractor`** (preview-only, `#if DEBUG`):

```swift
struct MockReviewWizardInteractor: ReviewWizardInteractorProtocol {
    var fetchResult: Result<Review?, ReviewRepositoryError> = .success(nil)
    var saveError: ReviewRepositoryError? = nil

    func fetchReview(movieId: Int) throws(ReviewRepositoryError) -> Review? {
        try fetchResult.get()
    }
    func createReview(movieId: Int, rating: Int, tags: [ReviewTag], notes: String) throws(ReviewRepositoryError) {
        if let error = saveError { throw error }
    }
    func updateReview(movieId: Int, rating: Int, tags: [ReviewTag], notes: String) throws(ReviewRepositoryError) {
        if let error = saveError { throw error }
    }
}
```

**`PreviewFixtures`** (internal enum, `#if DEBUG`):
- **File:** `Sources/ReviewFeature/Testing/PreviewFixtures.swift`
- Static `Review`: `movieId: 550`, `rating: 4`, `tags: [.thoughtProvoking, .classic]`, `notes: "A gripping film."`, `createdAt: .now`, `updatedAt: .now`

Each preview constructs a `ReviewWizardPresenter` and sets its state directly (bypassing `handleAppear()`) to avoid async side effects.

**Preview variants:**

| Preview name | `fetchState` | `currentStep` | `resolvedMode` | Draft content |
|---|---|---|---|---|
| Fetch loading | `.loading` | `.step1` | `.create` | defaults |
| Fetch error | `.error("Could not load review.")` | `.step1` | `.create` | defaults |
| Step 1 — create mode | `.loaded` | `.step1` | `.create` | `rating=0`, `tags=[]`, `notes=""` |
| Step 1 — edit mode | `.loaded` | `.step1` | `.edit` | `rating=4` from fixture |
| Step 2 — create mode | `.loaded` | `.step2` | `.create` | no tags selected |
| Step 2 — edit mode | `.loaded` | `.step2` | `.edit` | fixture tags pre-selected |
| Step 3 — create mode | `.loaded` | `.step3` | `.create` | empty notes, counter "0 / 500" |
| Step 3 — edit mode | `.loaded` | `.step3` | `.edit` | fixture notes pre-filled |
| Step 4 — create (empty notes) | `.loaded` | `.step4` | `.create` | `rating=3`, `tags=[.funny]`, `notes=""` |
| Step 4 — edit mode | `.loaded` | `.step4` | `.edit` | all fields from fixture |

---

### Task 9 — Unit Tests

**File:** `Tests/ReviewFeatureTests/ReviewWizardPresenterTests.swift`

**`MockReviewWizardInteractor`** (test double):
- `var fetchResult: Result<Review?, ReviewRepositoryError>`
- `var createError: ReviewRepositoryError?`
- `var updateError: ReviewRepositoryError?`
- `var fetchCallCount: Int = 0`
- `var createCallCount: Int = 0`
- `var updateCallCount: Int = 0`
- `var lastCreateArgs: (movieId: Int, rating: Int, tags: [ReviewTag], notes: String)?`
- `var lastUpdateArgs: (movieId: Int, rating: Int, tags: [ReviewTag], notes: String)?`

**`MockReviewWizardRouter`** (test double, conforms to `ReviewWizardRouterProtocol`):
- `var dismissCallCount: Int = 0`

**Test scenarios:**

| Scenario | Action | Expected outcome |
|---|---|---|
| Fetch succeeds with non-nil review | `handleAppear()` | `resolvedMode == .edit`; `baseline` and `draft` populated from review; `fetchState == .loaded` |
| Fetch succeeds with nil | `handleAppear()` | `resolvedMode == .create`; `baseline == .empty`; `fetchState == .loaded` |
| Fetch throws | `handleAppear()` | `fetchState == .error(message)` |
| Retry after fetch error | `handleRetryFetch()` | `fetchCallCount == 2`; `fetchState` resolved |
| Input mode `.edit` with nil fetch result | `handleAppear()` with `inputMode: .edit`, `fetchResult: .success(nil)` | `resolvedMode == .create` |
| Tap star N | `handleStarTapped(3)` | `draft.rating == 3` |
| Next from step 1 | `handleNextFromStep1()` | `currentStep == .step2` |
| Back from step 2 resets rating | Set `draft.rating = 5`; `handleBackFromStep2()` | `draft.rating == baseline.rating`; `currentStep == .step1` |
| Toggle tag chip — add | `handleTagToggled(.funny)` | `draft.tags.contains(.funny)` |
| Toggle tag chip — remove | `handleTagToggled(.funny)` twice | `draft.tags` does not contain `.funny` |
| Next from step 2 | `handleNextFromStep2()` | `currentStep == .step3` |
| Back from step 3 resets tags | Set `draft.tags = [.classic]`; `handleBackFromStep3()` | `draft.tags == baseline.tags`; `currentStep == .step2` |
| Notes at exactly 500 chars | `handleNotesChanged(String(repeating: "a", count: 500))` | `draft.notes.count == 500` |
| Notes exceeding 500 chars | `handleNotesChanged(String(repeating: "a", count: 501))` | `draft.notes.count == 500` |
| Next from step 3 | `handleNextFromStep3()` | `currentStep == .step4` |
| Back from step 4 resets notes | Set `draft.notes = "edited"`; `handleBackFromStep4()` | `draft.notes == baseline.notes`; `currentStep == .step3` |
| Confirm in create mode | `handleConfirm()` with `resolvedMode == .create` | `createCallCount == 1`; `updateCallCount == 0`; `dismissCallCount == 1` |
| Confirm in edit mode | `handleConfirm()` with `resolvedMode == .edit` | `updateCallCount == 1`; `createCallCount == 0`; `dismissCallCount == 1` |
| Confirm passes correct draft values | `handleConfirm()` with known draft | `lastCreateArgs` matches `draft.rating`, `draft.tags`, `draft.notes` at confirm time |
| Confirm throws | `handleConfirm()` with `createError` set | `saveState == .error(message)`; `showSaveErrorAlert == true`; `dismissCallCount == 0` |
| Dismiss save alert | `handleSaveAlertDismissed()` | `saveState == .idle`; `showSaveErrorAlert == false` |
| Confirm guard — already saving | Call `handleConfirm()` while `saveState == .saving` | `createCallCount == 1` (second call is no-op) |
| Cancel on step 1 | `handleCancel()` | `dismissCallCount == 1`; `createCallCount == 0`; `updateCallCount == 0` |
| Discard on step 4 | `handleDiscard()` | `dismissCallCount == 1`; no repo write |
| Dismiss from fetch error | `handleDismissFromError()` | `dismissCallCount == 1`; no repo write |

**Service interaction assertions:**
- `fetchReview(movieId:)` called exactly once on `handleAppear()`.
- `fetchReview` called again on `handleRetryFetch()` (`fetchCallCount == 2`).
- `createReview` called when `resolvedMode == .create`; `updateReview` not called.
- `updateReview` called when `resolvedMode == .edit`; `createReview` not called.
- Neither `createReview` nor `updateReview` called on `handleCancel()`, `handleDiscard()`, or `handleDismissFromError()`.

---

## Open Questions / Deferred Decisions

1. **`FlowLayout` for tag chips:** The feature plan specifies a "wrapping `FlowLayout` or `LazyVGrid`" for the tag grid. If `SharedUIComponents` does not provide a `FlowLayout`, use `LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))])`. Confirmed at implementation time.

2. **`WizardMode` / `WizardPresentation` type mapping:** `WizardPresentation` (in `MovieDetailFeature`) and `WizardMode` (in `ReviewFeature`) are semantically identical `.create`/`.edit` enums. `MovieDetailRouter.makeWizardView(movieId:mode:)` converts between them at the boundary. Whether a shared type in `DomainModels` is warranted is deferred to the implementation step.

3. **Step transition animation:** The feature plan defers Reduce Motion alternatives. The implementor should apply `.transition(.opacity)` or `.transition(.asymmetric(insertion:.move(edge:.trailing), removal:.move(edge:.leading)))` for step changes, and defer motion-sensitive alternatives to post-MVP.

4. **`@MainActor` in test target:** `ReviewWizardPresenter` is `@MainActor`-isolated. All test cases interacting with the Presenter must be annotated `@MainActor` or wrapped in `await MainActor.run { }`.
