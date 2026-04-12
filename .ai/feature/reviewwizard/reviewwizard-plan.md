# ReviewWizard Feature Plan for Movie Tracker

## 1. Overview

The ReviewWizard feature lets a user create or update their single personal review for a movie through a four-step sequential wizard: star rating → tag selection → free-text notes → summary and confirm. The wizard is a modal cover owned by the Movie Detail feature entry point. On successful confirm the review is persisted locally; any earlier dismissal silently discards in-progress work. For edit mode the wizard pre-populates fields from the existing review, and cancellation leaves the stored review unchanged.

---

## 2. Feature Scope & Responsibility Boundary

### In Scope

| Responsibility | Detail |
|---|---|
| `ReviewWizardView` container | Single `.fullScreenCover` managing four sequential steps via conditional rendering; no internal `NavigationStack` |
| Baseline fetch on appear | Calls `ReviewRepository.fetch(movieId:)` once to establish the immutable baseline; drives resolved mode |
| Step 1 — Star rating | Five tappable star icons (0–5 selection); 0 is valid; edit mode pre-populates from baseline |
| Step 2 — Tag selection | Multi-select chip grid from the 11 predefined `ReviewTag` cases; no min/max; edit mode pre-selects from baseline |
| Step 3 — Notes | Optional free-text `TextEditor`; 500-character cap enforced live with a counter; keyboard auto-presented on step appear |
| Step 4 — Summary & confirm | Read-only display of all draft fields; Confirm writes via repository; Discard silently dismisses |
| Segmented progress bar | Four-segment indicator displayed on every step |
| Full-screen fetch-error state | Shown inside the cover when baseline fetch throws; offers Retry and Dismiss |
| Repository call on confirm | `ReviewRepository.create` for resolved-create mode; `ReviewRepository.update` for resolved-edit mode |
| Inline save-failure alert | Shown on step 4 when Confirm throws; draft preserved; Confirm retryable |
| Silent discard on Cancel/Discard | No repository write; no confirmation dialog |

### Explicitly Out of Scope

| Concern | Owner |
|---|---|
| `.fullScreenCover` presentation and dismissal binding | `MovieDetailView` (Movie Detail feature) |
| Re-fetching review state after wizard dismissal | `MovieDetailView` via `onDismiss` callback |
| One-review-per-movie enforcement | `ReviewRepository` service |
| Rating range validation (1–5) | `ReviewRepository` service |
| `[ReviewTag]` ↔ `[String]` persistence mapping | `ReviewRepository` / `PersistenceKit` |
| Delete review confirmation dialog | Movie Detail feature |
| Accessibility / VoiceOver | Deferred to post-MVP |
| Haptic feedback | Deferred to post-MVP |
| Deep linking into wizard steps | Out of scope |
| Partial draft persistence across app restarts | Explicitly out of scope per PRD |

**Boundary justification**: The wizard is a short-lived modal whose only durable output is a completed or abandoned review write. All repository-level invariants (uniqueness, rating range, tag conversion) belong in `ReviewRepository`. `MovieDetailView` owns the cover lifecycle since it already manages both the "Log a Review" / "Edit Review" CTAs and the post-dismiss refresh, keeping the wizard entirely ignorant of the detail screen's state.

**SPM target**: `ReviewFeature` is a separate Swift Package Manager target. It is declared as a direct dependency by `MovieDetailFeature` only. It has no outbound feature dependencies.

---

## 3. Service Dependencies

| Service | Protocol | Operations |
|---|---|---|
| `ReviewRepository` | `ReviewRepository` | `fetch(movieId: Int) throws -> Review?` — called once on wizard appear to establish baseline and resolved mode; `create(movieId:rating:tags:notes:) throws` — called on step 4 Confirm in create mode; `update(movieId:rating:tags:notes:) throws` — called on step 4 Confirm in edit mode |

No other service is consumed. `TMDBClient`, `WatchlistRepository`, `NetworkingKit`, and `PersistenceKit` are not accessed by this feature.

**Specific operations and contracts**:

- `fetch` may return `nil` (no review stored) or a `Review` value; a thrown error drives the full-screen error state.
- `create` and `update` are synchronous `throws` on `@MainActor`; the wizard calls them directly without async bridging.
- The wizard inspects `resolvedMode` (derived from the fetch result) to choose `create` vs. `update`, not the original input `mode` parameter.

---

## 4. Screen Inventory

| Screen / Surface | Purpose | Presentation Relationship |
|---|---|---|
| `ReviewWizardView` (container) | Hosts all four steps, the progress bar, and the fetch-error state via conditional rendering | `.fullScreenCover` from `MovieDetailView`; swipe-to-dismiss disabled |
| Step 1 — Rating | Star-rating selection (0–5) | Rendered inside `ReviewWizardView` when `currentStep == .step1` and `fetchState == .loaded` |
| Step 2 — Tags | Multi-select tag chip grid | Rendered inside `ReviewWizardView` when `currentStep == .step2` |
| Step 3 — Notes | `TextEditor` with character counter | Rendered inside `ReviewWizardView` when `currentStep == .step3` |
| Step 4 — Summary | Read-only draft review; Confirm and Discard actions | Rendered inside `ReviewWizardView` when `currentStep == .step4` |
| Fetch-error state | Full-cover error message with Retry and Dismiss | Rendered inside `ReviewWizardView` when `fetchState == .error` |

The wizard has a single `ReviewWizardView` screen; steps are internal rendering states, not distinct navigation destinations.

---

## 5. Presentation Logic

### `ReviewWizardView`

#### Screen State Shape

```
fetchState:    .loading | .loaded | .error(message: String)
currentStep:   .step1 | .step2 | .step3 | .step4
saveState:     .idle | .saving | .error(message: String)
resolvedMode:  .create | .edit
baseline:      WizardBaseline { rating: Int, tags: [ReviewTag], notes: String }
draft:         WizardDraft    { rating: Int, tags: [ReviewTag], notes: String }
isNotesFocused: Bool  (@FocusState for step 3 keyboard)
```

Step content renders only when `fetchState == .loaded`. `fetchState == .loading` renders a full-screen loading indicator within the cover. `fetchState == .error` renders the full-screen error state.

#### User Actions and Side Effects

| Action | Trigger | Side Effect | State Transition |
|---|---|---|---|
| Wizard appears | `.fullScreenCover` presentation | `ReviewRepository.fetch(movieId:)` | `fetchState → .loading` |
| Fetch succeeds (non-nil) | Fetch returns `Review` | None | `baseline` and `draft` set from review; `resolvedMode = .edit`; `fetchState = .loaded` |
| Fetch succeeds (nil) | Fetch returns `nil` | None | `baseline` and `draft` set to defaults; `resolvedMode = .create`; `fetchState = .loaded` |
| Fetch fails | Fetch throws | None | `fetchState = .error(message)` |
| Retry fetch | Tap Retry in error state | Re-issue `ReviewRepository.fetch(movieId:)` | `fetchState → .loading` |
| Dismiss from error | Tap Cancel/Dismiss in error state | Wizard cover dismissed | No repository write |
| Tap star N on step 1 | User taps star icon | None (synchronous local) | `draft.rating = N` |
| Next from step 1 | Tap Next | None | `currentStep → .step2` |
| Back from step 2 | Tap Back | None | `draft.rating = baseline.rating`; `currentStep → .step1` |
| Toggle tag chip on step 2 | Tap chip | None | `draft.tags` toggled |
| Next from step 2 | Tap Next | None | `currentStep → .step3` |
| Back from step 3 | Tap Back | None | `draft.tags = baseline.tags`; `currentStep → .step2` |
| Edit notes on step 3 | Type in `TextEditor` | None | `draft.notes = newValue` (capped at 500 chars) |
| Next from step 3 | Tap Next | None | `currentStep → .step4` |
| Back from step 4 | Tap Back | None | `draft.notes = baseline.notes`; `currentStep → .step3` |
| Cancel on step 1 | Tap Cancel (toolbar) | Wizard dismissed silently | No repository write |
| Discard on step 4 | Tap Discard | Wizard dismissed silently | No repository write |
| Confirm on step 4 | Tap Confirm | `ReviewRepository.create` or `.update` | `saveState → .saving` → wizard dismissed on success; `saveState = .error(message)` on failure |
| Dismiss save alert | Tap OK in failure alert | Alert dismissed | `saveState = .idle`; wizard stays on step 4 |

#### Local Business Rules

- The Next button is always enabled on all steps (0 stars, 0 tags, empty notes are all valid inputs).
- The 500-character limit on `draft.notes` is enforced synchronously via `.onChange(of: draft.notes)` by truncating to 500 characters.
- On back-navigation, only the field owned by the departing step resets to `baseline`; all other draft fields retain their current values.
- Step 4 reads `draft` directly at render time; no separate accumulated result struct is maintained.
- The repository operation on Confirm is selected by `resolvedMode`, not the original input `mode` parameter.
- If the input `mode` is `.edit` but the fetch returns `nil`, `resolvedMode` silently falls back to `.create`.

---

## 6. Navigation & Routing

### Entry Point

`ReviewWizardView` is presented as a `.fullScreenCover` by `MovieDetailView`. Inputs received on presentation:

- `movieId: Int` — the TMDB integer id of the movie being reviewed
- `mode: WizardMode` — `.create` (from "Log a Review") or `.edit` (from "Edit Review")

`MovieDetailView` owns the binding that controls cover presentation; the wizard has no knowledge of the detail screen's state.

### Internal Navigation Graph

```
[Fetch loading / error state]
  → Retry → re-fetch
  → Dismiss → cover dismissed (no write)

Step 1 (Rating)
  ← Cancel (toolbar) → cover dismissed (no write)
  → Next → Step 2

Step 2 (Tags)
  ← Back → Step 1  [draft.rating reset to baseline.rating]
  → Next → Step 3

Step 3 (Notes)
  ← Back → Step 2  [draft.tags reset to baseline.tags]
  → Next → Step 4

Step 4 (Summary)
  ← Back → Step 3  [draft.notes reset to baseline.notes]
  → Confirm → repository write → cover dismissed on success; alert on failure
  → Discard → cover dismissed (no write)
```

Step navigation is implemented as mutations to `currentStep`; there is no `NavigationStack` or `NavigationLink` inside the cover.

### Swipe-to-Dismiss

Disabled on all steps and states with `.interactiveDismissDisabled(true)`. The user must use an explicit Cancel, Discard, or Dismiss action to exit the wizard.

### Exit Triggers

| Trigger | Write? | Downstream Effect |
|---|---|---|
| Cancel on step 1 | No | `MovieDetailView.onDismiss` fires; Movie Detail re-fetches review state |
| Discard on step 4 | No | `MovieDetailView.onDismiss` fires |
| Confirm success (step 4) | Yes (create or update) | `MovieDetailView.onDismiss` fires; Movie Detail re-fetches and reflects saved review |
| Dismiss from fetch-error state | No | `MovieDetailView.onDismiss` fires |

### Deep Links

Not in scope.

---

## 7. State Management

### State Layers

**`WizardBaseline`** — immutable value, set once on successful fetch:

| Field | Create default | Edit value |
|---|---|---|
| `rating: Int` | `0` | Fetched review's `rating` |
| `tags: [ReviewTag]` | `[]` | Fetched review's `tags` |
| `notes: String` | `""` | Fetched review's `notes` |

**`WizardDraft`** — mutable value, updated by user actions throughout the session:

- `rating: Int`
- `tags: [ReviewTag]`
- `notes: String`

Both `baseline` and `draft` are initialized from the same fetch result immediately after a successful fetch. They diverge as the user makes choices.

### Additional Local State

| State | Type | Purpose |
|---|---|---|
| `fetchState` | `FetchState` | Loading / loaded / error for baseline fetch |
| `currentStep` | `WizardStep` | Controls which step content renders |
| `saveState` | `SaveState` | Idle / saving / error for step 4 confirm |
| `resolvedMode` | `WizardMode` | `.create` or `.edit` derived after fetch; determines repository operation |
| `isNotesFocused` | `Bool` (`@FocusState`) | Drives keyboard presentation on step 3 appear |

### Initialization on Appear

`fetchState` is set to `.loading` and the fetch is issued immediately when the wizard appears. No step content is rendered until the fetch succeeds.

### Cleanup on Dismissal

All wizard state is local to `ReviewWizardView`. When the `.fullScreenCover` is dismissed, all state is released. No wizard-scoped state persists to the session or escapes to `MovieDetailView`.

### Concurrent Updates

No concurrent mutations are possible. The wizard is a `.fullScreenCover` modal that blocks the presenting view. `ReviewRepository` is synchronous and `@MainActor`-confined. No locking or actor-hopping is required.

---

## 8. User Interactions & Form Validation

### Step 1 — Star Rating

- Five individual tappable `Button` views rendered as star icons from the DesignSystem.
- Tapping star N sets `draft.rating = N`. Stars 1–5 are rendered as filled; stars above the current rating as empty.
- Rating 0 (no star selected) is a valid initial and submittable state.
- Edit mode pre-fills from `baseline.rating`; no star highlighted if the existing rating was somehow 0.
- Next button: always enabled.

### Step 2 — Tag Selection

- 11 chip/pill buttons arranged in a wrapping grid, one per `ReviewTag` case in their defined order.
- Tapping a chip toggles its inclusion in `draft.tags`. Selected and unselected states use visually distinct DesignSystem color tokens.
- No minimum selection; no maximum selection; zero tags is valid.
- Edit mode pre-selects tags matching `baseline.tags`.
- Next button: always enabled.

### Step 3 — Notes

- A `TextEditor` inside a `ScrollView` with `.scrollDismissesKeyboard(.interactively)`.
- Keyboard is auto-presented on step appear via `@FocusState` activation.
- 500-character limit enforced via `.onChange(of: draft.notes)` by truncating to 500 characters before assigning.
- Live counter displayed below the editor (e.g., "243 / 500").
- Empty notes is valid. Next button: always enabled.

### Step 4 — Summary & Confirm

- Read-only presentation of `draft.rating`, `draft.tags`, and `draft.notes`. No editing affordance on this step.
- Confirm: calls the repository; `saveState → .saving` (Confirm button may show activity indicator). On failure an `.alert` is shown describing the error; the alert has a single dismiss action returning `saveState → .idle`; wizard stays on step 4 and Confirm is retryable.
- Discard: dismisses silently with no dialog.

### Destructive Action Confirmation

No confirmation dialog for Cancel on step 1 or Discard on step 4. Dismissal at any point before successful Confirm is always silent. (Delete review confirmation is a Movie Detail concern, not a wizard concern.)

---

## 9. Loading, Empty, and Error States

### Baseline Fetch

| State | Design |
|---|---|
| Loading | Full-screen loading indicator centered within the `.fullScreenCover`; no step content rendered |
| Success | Progress bar and first step (step 1) rendered with draft/baseline initialized |
| Error | Full-screen `ErrorStateView` with an error message, a Retry button (re-issues fetch), and a Dismiss/Cancel button (closes the cover without writing) |

### Step 4 Confirm

| State | Design |
|---|---|
| Saving | Confirm button shows an activity indicator; button is disabled during save to prevent double-tap |
| Success | Cover dismissed automatically; no visible transition required |
| Error | Inline `.alert` with error description and single OK dismiss action; wizard stays on step 4 with draft intact; Confirm is re-enabled after dismissing the alert |

### Per-Step Content

All step content states are synchronous. There are no loading, empty, or error states within individual steps (star selection, tag chips, notes field) beyond the character counter for notes. No skeleton views or placeholders are required for step content.

No optimistic update strategy is used. The repository write happens only on step 4 Confirm; no intermediate writes occur during step navigation.

---

## 10. SwiftUI Previews Strategy

### Preview Variants

| Preview | State | Purpose |
|---|---|---|
| Step 1 — create mode | `draft.rating = 0`, no tags, empty notes; `fetchState = .loaded` | Verify default empty-state appearance |
| Step 1 — edit mode | `draft.rating` from fixture `Review`; `fetchState = .loaded` | Verify pre-populated star selection |
| Step 2 — create mode | No tags selected | Verify unselected chip grid layout |
| Step 2 — edit mode | Fixture tags pre-selected | Verify selected chip visual distinction |
| Step 3 — create mode | Empty notes field, counter at "0 / 500" | Verify empty field appearance and keyboard placeholder |
| Step 3 — edit mode | Fixture notes pre-filled, counter reflecting length | Verify populated field |
| Step 4 — create mode (empty notes) | Rating set, some tags, empty notes | Verify summary renders gracefully without notes |
| Step 4 — edit mode | All fields from fixture `Review` | Verify fully populated summary |
| Fetch-error state | `fetchState = .error("Could not load review.")` | Verify error state with Retry and Dismiss affordances |

### Service Substitution

Views do not interact with `ReviewRepository` directly in previews. Each architecture variant populates previews through its own mechanism:

- **MVVM**: pre-configured `ViewModel` with stubbed state values.
- **VIPER**: pre-configured `Presenter` output / view state.
- **TCA**: initial `State` struct with fixture values.

A shared `FakeReviewRepository` (or equivalent stub) may be used where the baseline fetch must be satisfied for the preview to reach `fetchState == .loaded`.

---

## 11. iOS-Specific UI Concerns

| Concern | Decision |
|---|---|
| Swipe-to-dismiss | Disabled on all steps via `.interactiveDismissDisabled(true)` |
| Keyboard avoidance (step 3) | `TextEditor` inside `ScrollView` with `.scrollDismissesKeyboard(.interactively)`; natural swipe-up hides keyboard |
| Keyboard presentation (step 3) | `@FocusState` variable set to `true` in `.onAppear` of step 3 content to auto-present the keyboard |
| Progress indicator | Segmented progress bar (four segments / dots labeled "Step N of 4") at the top of all steps |
| Character counter | Live counter below the `TextEditor` on step 3; limit enforced inline via `.onChange` |
| Star rating UI | Row of five individual `Button` views with star SF Symbol icons from DesignSystem |
| Tag grid UI | Wrapping `FlowLayout` or `LazyVGrid` of chip/pill `Button` views; DesignSystem tokens for selected/unselected colors |
| Haptic feedback | Out of scope for MVP |
| Deep links | Out of scope |
| Share sheet | Not applicable to this feature |
| Widget / Live Activity | Not applicable |
| Context menus / drag-and-drop | Not applicable |
| Runtime permissions | None required |
| App lifecycle (foreground/background) | No special handling; `WizardDraft` is in-memory only and is discarded on dismiss — backgrounding the app does not require saving or restoring draft state |

---

## 12. Accessibility

VoiceOver labels, hints, and Dynamic Type support are out of scope for MVP. Implementation should apply standard SwiftUI accessibility practices at the time of build (`.accessibilityLabel`, `.accessibilityHint`, `.accessibilityValue` for star buttons and tag chips). Reduce Motion alternatives for step transition animations are deferred to post-MVP.

---

## 13. Analytics & Tracked Events

No analytics requirements are specified in the PRD for this feature. No events are tracked for MVP.

---

## 14. Testing Strategy

### Presentation Logic Unit Tests

| Scenario | Assertions |
|---|---|
| Fetch succeeds with non-nil review | `resolvedMode == .edit`; `baseline` and `draft` populated from review; `fetchState == .loaded` |
| Fetch succeeds with nil | `resolvedMode == .create`; `baseline` and `draft` at defaults; `fetchState == .loaded` |
| Fetch throws | `fetchState == .error(message)` |
| Retry after fetch error | Fetch re-issued; `fetchState → .loading` |
| Input mode `.edit` with nil fetch result | `resolvedMode == .create` (silent fallback) |
| Tap star N | `draft.rating == N` |
| Next from step 1 | `currentStep == .step2` |
| Back from step 2 | `draft.rating == baseline.rating`; `currentStep == .step1` |
| Toggle tag chip | Tag toggled in `draft.tags` |
| Next from step 2 | `currentStep == .step3` |
| Back from step 3 | `draft.tags == baseline.tags`; `currentStep == .step2` |
| Notes input at exactly 500 chars | `draft.notes.count == 500` |
| Notes input exceeding 500 chars | `draft.notes.count == 500` (truncated) |
| Next from step 3 | `currentStep == .step4` |
| Back from step 4 | `draft.notes == baseline.notes`; `currentStep == .step3` |
| Confirm in create mode | `ReviewRepository.create` called with `draft` values; cover dismissed on success |
| Confirm in edit mode | `ReviewRepository.update` called with `draft` values; cover dismissed on success |
| Confirm throws | `saveState == .error(message)`; wizard stays on step 4 |
| Dismiss save alert | `saveState == .idle`; wizard on step 4; Confirm re-enabled |
| Cancel on step 1 | Cover dismissed; no repository write |
| Discard on step 4 | Cover dismissed; no repository write |
| Dismiss from fetch-error state | Cover dismissed; no repository write |

### Service Interaction Tests (Mock Repository)

- `ReviewRepository.fetch(movieId:)` is called exactly once on appear.
- `ReviewRepository.create` is called (not `update`) when `resolvedMode == .create`.
- `ReviewRepository.update` is called (not `create`) when `resolvedMode == .edit`.
- Neither `create` nor `update` is called on Cancel, Discard, or Dismiss-from-error.
- `create` / `update` receive the exact `draft` values at the time of Confirm.

### UI Test Coverage

| Flow | Scenario |
|---|---|
| Full create flow | Step 1 → tap star 4 → Next → tap two tags → Next → type notes → Next → Confirm; verify wizard dismissed |
| Full edit flow | Open in edit mode; verify pre-populated fields; modify rating → Next → ... → Confirm; verify wizard dismissed |
| Back-navigation field reset | Advance to step 3, go back to step 2; verify `draft.tags` reverted to baseline |
| Cancel on step 1 | Tap Cancel; verify wizard dismissed without writing |
| Discard on step 4 | Advance all steps; tap Discard; verify wizard dismissed without writing |
| Confirm failure | Stub `ReviewRepository.create` to throw; tap Confirm; verify alert shown; tap OK; verify wizard still on step 4 |
| Fetch failure and retry | Stub `ReviewRepository.fetch` to throw; verify full-screen error state; tap Retry; stub to succeed; verify step 1 shown |

---

## 15. Platform & OS Constraints

| Constraint | Impact on Feature |
|---|---|
| iOS 17 minimum deployment target | SwiftData (used by `ReviewRepository` / `PersistenceKit`) requires iOS 17; no API availability checks needed in wizard code — the deployment target enforces globally |
| `@MainActor` confinement of `ReviewRepository` | All repository calls (`fetch`, `create`, `update`) are synchronous on the main actor; wizard presentation logic must remain on `@MainActor` |
| Synchronous `throws` repository protocol | No `async`/`await` or `Task` wrapping is required at the wizard layer; state transitions on confirm are synchronous |
| No entitlements required | Local SwiftData persistence via `ReviewRepository` requires no special entitlement or privacy permission prompt |
| `PrivacyInfo.xcprivacy` | Standard local file access entry covers SwiftData usage; no user-facing permission prompt is triggered by this feature |

---

## 16. Deferred / Out of Scope for MVP

| Item | Rationale |
|---|---|
| VoiceOver labels and hints for star buttons and tag chips | Deferred per planning session decision; standard iOS practices should be applied at implementation time |
| Dynamic Type layout audit | Deferred to implementation; layout should be tested at accessibility text sizes |
| Reduce Motion alternatives for step transitions | Deferred to implementation |
| Haptic feedback on star tap, tag toggle, step transitions, and save success | Explicitly out of scope for MVP per planning session |
| Analytics event tracking | Not specified in PRD |
| Character limit increase above 500 | Agreed at 500; revisit only if user research indicates longer notes are needed |
| Partial draft persistence across app restarts | Explicitly out of scope per PRD section 4 |
| Deep linking into specific wizard steps | Out of scope per PRD section 4 |

---

## 17. Open Questions / Unresolved Decisions

None. All questions raised in the feature planning session have been answered and recorded in `feature-planning-session-summary.md`.
