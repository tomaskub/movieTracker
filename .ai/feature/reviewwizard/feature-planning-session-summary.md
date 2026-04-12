# ReviewWizard Feature — Planning Session Summary

<conversation_summary>

<decisions>

1. `ReviewWizardView` is a single container screen; step transitions are handled via conditional rendering of per-step child views. No `NavigationStack` is used inside the `.fullScreenCover`.
2. Step navigation is sequential. A back button on steps 2–4 returns the user to the prior step. Step 1 has an explicit Cancel button in the toolbar; swipe-to-dismiss is disabled (`.interactiveDismissDisabled(true)`). There is no jump navigation between steps at any point in the flow.
3. On back-navigation from any step, that step's draft field resets to the **baseline value** — the value from the original `ReviewRepository.fetch` result (or the default empty value for create mode) — not to whatever was last confirmed via Next.
4. Star rating (step 1): row of tappable star icons rendering integers 1–5. **0 stars is a valid selection**; the wizard starts with 0 stars on create. Edit mode pre-populates with the existing review's `rating`. The Next button on step 1 is always enabled.
5. Tag selection (step 2): multi-select, **no minimum, no maximum**. All 11 predefined tags are always visible; selected and unselected chips are visually distinct. Edit mode pre-selects the existing review's tags. The Next button on step 2 is always enabled.
6. Notes (step 3): free-text, **optional** — empty string is valid and does not block Next. `notes` field is always a `String` (never nil). Character limit: **500 characters**, enforced via `.onChange` with a live counter displayed below the `TextEditor` (e.g. "243 / 500"). Keyboard is presented automatically via `@FocusState` on step appear.
7. Step 4 summary: read-only display of rating, tags, and notes. Back button returns to step 3 only. Two primary actions: **Confirm** (save) and **Discard** (dismiss wizard). No jump navigation, no per-section edit affordance.
8. All wizard dismissals — Cancel on step 1, Discard on step 4, and back through to step 1 then Cancel — are **silent with no confirmation dialog**.
9. Step 4 confirm failure: if `ReviewRepository.create` or `ReviewRepository.update` throws, an **inline alert** is shown while remaining on step 4. The user's draft is preserved and the Confirm action can be retried.
10. Wizard inputs are `movieId: Int` and `mode: WizardMode` (`.create` or `.edit`) only. `MovieDetailView` **never passes a `Review` struct** to the wizard.
11. On wizard `onAppear`, the wizard calls `ReviewRepository.fetch(movieId:)` to establish the baseline. For create mode a `nil` result is expected; for edit mode a non-nil `Review` is expected. If edit mode receives `nil` from the fetch, the wizard **falls back to create mode** silently.
12. If `ReviewRepository.fetch` throws on appear, a **full-screen error state** is shown within the `.fullScreenCover` with a Retry action and a Dismiss (Cancel) affordance. No step content is shown until the fetch succeeds.
13. A **segmented progress bar** (e.g. four segments or dots labeled "Step N of 4") is displayed at the top of the wizard on every step.
14. Notes field (step 3) uses a `TextEditor` inside a `ScrollView` with `.scrollDismissesKeyboard(.interactively)`. `@FocusState` is activated on step appear so the keyboard is presented automatically.
15. Accessibility / VoiceOver: **out of scope for MVP**.
16. Haptic feedback: **out of scope for MVP**.
17. `MovieDetailView` re-fetches review state via `ReviewRepository.fetch(movieId:)` in the `.fullScreenCover` `onDismiss` callback. The wizard does not pass a result back to Movie Detail. Ownership of this pattern is recorded in the MovieDetail feature plan.
18. The wizard holds **two state layers**: an immutable `baseline` (set once from the fetch result on appear) and a mutable `WizardDraft` (updated as the user progresses). On back-navigation, the leaving step's field is reset to the corresponding `baseline` field. Step 4 reads directly from `WizardDraft`; no separate "result" struct is needed.
19. The repository operation called on step 4 Confirm is determined by the **resolved mode** after the fetch: `.create` → `ReviewRepository.create(movieId:rating:tags:notes:)`; `.edit` → `ReviewRepository.update(movieId:rating:tags:notes:)`.

</decisions>

<matched_recommendations>

1. **Accepted** — Single-container conditional rendering for step management; no `NavigationStack` inside the `.fullScreenCover`.
2. **Accepted** — All in-progress wizard state held in a single `WizardDraft` value type (`rating: Int`, `tags: [ReviewTag]`, `notes: String`) alongside an immutable `WizardBaseline`. On back-navigation each step's field resets to baseline; step 4 reads from the live draft.
3. **Accepted with revision** — Per-step Next button validation is declared in principle; in practice all steps accept 0/empty values so the Next button is always enabled given the agreed validation rules (0 stars valid, tags optional, notes optional).
4. **Accepted** — Discard is silent at all steps including step 4.
5. **Accepted** — Step 4 confirm failure surfaces as an inline alert; wizard remains on step 4 with draft preserved and Confirm retryable.
6. **Rejected** — Wizard does not receive `Review` data from `MovieDetailView`. Wizard fetches its own baseline from `ReviewRepository.fetch(movieId:)` on appear (decision 10–11).
7. **Accepted** — `MovieDetailView` re-fetches review state via `onDismiss` callback; wizard passes no result back (decision 17).
8. **Accepted** — Tags rendered as a wrapping grid of tappable chip/pill buttons; selected vs. unselected state visually distinct using DesignSystem tokens.
9. **Accepted** — `TextEditor` inside `ScrollView` with `.scrollDismissesKeyboard(.interactively)` for step 3. `@FocusState` triggered on appear. 500-character limit enforced via `.onChange` with live counter.
10. **Accepted (accessibility out of scope)** — Star rating rendered as five individual tappable `Button` views. Accessibility annotations deferred to implementation per decision 15.
11. **Accepted** — Segmented progress bar at the top of each step (decision 13).
12. **Rejected** — No haptic feedback (decision 16).
13. **Accepted** — Two SwiftUI Preview variants per step: (a) create mode with default/empty values, (b) edit mode with a fully populated `Review`. Plus one preview for the fetch-failure error state.
14. **Accepted** — `ReviewRepository` is called exactly once, on step 4 Confirm. No intermediate writes occur during step navigation.

</matched_recommendations>

<ios_feature_planning_summary>

## a. Feature Scope & Responsibility Boundary

**In scope:**
- `ReviewWizardView`: single `.fullScreenCover` container managing four sequential steps via conditional rendering.
- Fetching the existing `Review` baseline from `ReviewRepository` on wizard appear.
- Step 1: star rating selection (0–5, integer).
- Step 2: multi-select tag picker from the fixed 11-tag predefined list.
- Step 3: free-text notes with 500-character limit and live counter.
- Step 4: read-only summary of all choices; Confirm and Discard actions.
- On Confirm: calling `ReviewRepository.create` or `ReviewRepository.update` based on resolved mode.
- On any discard/cancel: silent dismissal with no data written to the repository.
- Full-screen error state for fetch failure on appear, with Retry and Dismiss affordances.
- Segmented progress bar on every step.

**Explicitly delegated or out of scope:**
- `MovieDetailView` owns wizard presentation (`.fullScreenCover` binding) and review state re-fetch on dismiss.
- `ReviewRepository` owns one-review-per-movie enforcement, rating validation, and `[ReviewTag]` ↔ `[String]` mapping.
- `ReviewTag` display ordering and label strings: UI layer concern.
- Accessibility / VoiceOver: out of scope for MVP.
- Haptic feedback: out of scope for MVP.
- Deep linking into wizard steps: out of scope.
- Partial saves or draft persistence across app restarts: explicitly out of scope per PRD.

---

## b. Service Dependencies

| Service | Protocol | Operations consumed |
|---|---|---|
| `ReviewRepository` | `ReviewRepository` | `fetch(movieId:)` → `Review?` (on appear); `create(movieId:rating:tags:notes:)` throws (step 4 confirm, create mode); `update(movieId:rating:tags:notes:)` throws (step 4 confirm, edit mode) |

No other service or framework is consumed by this feature. `TMDBClient`, `WatchlistRepository`, and `PersistenceKit` are not accessed directly.

---

## c. Presentation Logic

### `ReviewWizardView`

**Wizard mode resolution:**
- Input `mode: WizardMode` (.create / .edit) from `MovieDetailView`.
- On appear: `ReviewRepository.fetch(movieId:)` is called. Fetch result determines `resolvedMode`:
  - Fetch success, non-nil `Review` → `resolvedMode = .edit`; baseline populated from `Review`.
  - Fetch success, nil → `resolvedMode = .create`; baseline set to defaults (rating: 0, tags: [], notes: "").
  - Fetch failure (throws) → wizard shows full-screen error state; no step is rendered.
  - If input `mode == .edit` but fetch returns nil → fall back to `resolvedMode = .create` silently.

**Screen state shape:**

```
fetchState:   .loading | .loaded | .error(String)
currentStep:  .step1 | .step2 | .step3 | .step4
saveState:    .idle | .saving | .error(String)
resolvedMode: .create | .edit
baseline:     WizardBaseline (rating: Int, tags: [ReviewTag], notes: String)
draft:        WizardDraft (rating: Int, tags: [ReviewTag], notes: String)
```

Step content is only rendered when `fetchState == .loaded`.

**User actions and side effects:**

| Action | Trigger | Side effect | State transition |
|---|---|---|---|
| Wizard appears | `.fullScreenCover` presentation | `ReviewRepository.fetch(movieId:)` | `fetchState → .loading` → `.loaded` or `.error` |
| Retry fetch | User taps Retry in error state | Re-issue `ReviewRepository.fetch(movieId:)` | `fetchState → .loading` |
| Dismiss from error | User taps Cancel/Dismiss in error state | Wizard dismissed | `.fullScreenCover` dismissed |
| Tap star on step 1 | User taps star N | `draft.rating = N` | Immediate visual update |
| Next from step 1 | User taps Next | None | `currentStep → .step2` |
| Back from step 2 | User taps Back | `draft.rating = baseline.rating` | `currentStep → .step1` |
| Toggle tag on step 2 | User taps tag chip | `draft.tags` toggled | Immediate visual update |
| Next from step 2 | User taps Next | None | `currentStep → .step3` |
| Back from step 3 | User taps Back | `draft.tags = baseline.tags` | `currentStep → .step2` |
| Edit notes on step 3 | User types in TextEditor | `draft.notes = newValue` (capped at 500 chars) | Immediate visual update |
| Next from step 3 | User taps Next | None | `currentStep → .step4` |
| Back from step 4 | User taps Back | `draft.notes = baseline.notes` | `currentStep → .step3` |
| Cancel on step 1 | User taps Cancel | Wizard dismissed silently | No repository write |
| Discard on step 4 | User taps Discard | Wizard dismissed silently | No repository write |
| Confirm on step 4 | User taps Confirm | `ReviewRepository.create` or `.update` | `saveState → .saving` → wizard dismissed on success, `saveState → .error(message)` on failure |
| Dismiss save alert | User taps OK in failure alert | Alert dismissed | `saveState → .idle`; wizard remains on step 4; Confirm is retryable |

**Local business rules:**
- Next button is always enabled on all steps (0 stars, 0 tags, and empty notes are all valid).
- The 500-character limit on notes is enforced via `.onChange(of: draft.notes)` by truncating to 500 characters if exceeded.
- On back-navigation, only the field owned by the departing step resets to baseline; other draft fields are unchanged.
- Step 4 reads `draft` directly at render time; no separate accumulated result is maintained.
- Repository call on Confirm is determined by `resolvedMode`, not the original input `mode`.

---

## d. State Shape & Ownership

**Two state layers:**

`WizardBaseline` — let constant, set once on successful fetch:
- `rating: Int` (0 for create, fetched review rating for edit)
- `tags: [ReviewTag]` ([] for create, fetched review tags for edit)
- `notes: String` ("" for create, fetched review notes for edit)

`WizardDraft` — mutable value, accumulates user choices:
- `rating: Int`
- `tags: [ReviewTag]`
- `notes: String`

**Additional local state:**
- `fetchState: FetchState`
- `currentStep: WizardStep`
- `saveState: SaveState`
- `resolvedMode: WizardMode`
- `isNotesFocused: Bool` (`@FocusState` for step 3 keyboard)

**Initialization on appear:**
- `fetchState = .loading`; fetch issued immediately.
- On successful fetch: `baseline` and `draft` both initialized from fetch result (or defaults). `resolvedMode` set. `fetchState = .loaded`.

**Cleanup on dismissal:**
- All state is local and discarded when the `.fullScreenCover` is dismissed. No session-scoped state escapes the wizard.

**Concurrent updates:**
- No concurrent mutations are possible; the wizard is a `.fullScreenCover` modal and `ReviewRepository` is `@MainActor` synchronous.

---

## e. Navigation & Routing

**Entry point:** `.fullScreenCover` presented from `MovieDetailView`. Inputs: `movieId: Int`, `mode: WizardMode`.

**Internal navigation graph:**
```
Step 1 (Rating)
  ← Cancel → dismiss wizard (silent)
  → Next → Step 2

Step 2 (Tags)
  ← Back → Step 1 (draft.rating resets to baseline.rating)
  → Next → Step 3

Step 3 (Notes)
  ← Back → Step 2 (draft.tags reset to baseline.tags)
  → Next → Step 4

Step 4 (Summary)
  ← Back → Step 3 (draft.notes reset to baseline.notes)
  → Confirm → repository write → dismiss on success; alert on failure
  → Discard → dismiss wizard (silent)
```

**Exit triggers:**
- Cancel on step 1: silent dismiss, no repository write.
- Discard on step 4: silent dismiss, no repository write.
- Confirm success on step 4: dismiss; `MovieDetailView.onDismiss` triggers `ReviewRepository.fetch(movieId:)` re-check.
- Dismiss from fetch-error state: dismiss; `MovieDetailView.onDismiss` triggers re-check.

**Swipe-to-dismiss:** disabled (`.interactiveDismissDisabled(true)`) on all steps.

**Deep links:** not in scope.

---

## f. User Interactions & Validation

**Step 1 — Star rating:**
- Five tappable star icon buttons (1–5). Tapping sets `draft.rating` to that value. 0 stars (no star tapped) is valid. For edit mode, existing rating is pre-selected from baseline.
- Next is always enabled.

**Step 2 — Tag selection:**
- 11 chip/pill buttons in a wrapping grid layout. Tapping a chip toggles its selection in `draft.tags`. No minimum, no maximum.
- For edit mode, existing tags are pre-selected from baseline.
- Next is always enabled.

**Step 3 — Notes:**
- `TextEditor` inside `ScrollView`. Keyboard auto-presented via `@FocusState` on step appear.
- `.scrollDismissesKeyboard(.interactively)` for natural keyboard hide.
- 500-character limit enforced inline; live counter displayed below the editor (e.g. "243 / 500").
- Empty notes field is valid; Next is always enabled.

**Step 4 — Summary & Confirm:**
- Read-only display of all choices. No editing affordance.
- Confirm calls the repository. If it throws, an inline `.alert` is shown with a dismissal action; wizard stays on step 4 for retry.
- No confirmation dialog for Discard.

---

## g. Transient State Treatment

| Context | Loading | Success | Error |
|---|---|---|---|
| Fetch on appear | Full-screen loader within `.fullScreenCover` | Step 1 rendered with baseline applied | Full-screen `ErrorStateView` with Retry and Dismiss affordances |
| Step 4 Confirm | (No full-screen loader; Confirm button may show activity indicator) | Wizard dismissed | Inline `.alert` on step 4; Confirm retryable |
| Star tap / tag toggle / notes edit | Not applicable (synchronous local state) | Immediate visual update | Not applicable |

No optimistic updates. No intermediate state persisted. All step transitions are immediate and synchronous.

---

## h. SwiftUI Previews Strategy

Two preview variants per step (eight previews minimum):
- **Create mode**: default empty state (rating 0, no tags, empty notes, empty summary).
- **Edit mode**: fully populated state (pre-existing rating, tags, and notes from a fixture `Review`).

Additional previews:
- Fetch failure / full-screen error state.
- Step 4 with notes field empty (create mode) to verify summary renders gracefully.

**Architecture-specific approach:** views do not interact with the service layer directly in previews. Each variant populates previews via its own mechanism:
- MVVM: pre-configured `ViewModel` with stubbed state.
- VIPER: pre-configured `Presenter` output / view state.
- TCA: initial `State` struct with fixture values.

A shared `FakeReviewRepository` or static fixture may be used where the fetch call must be satisfied for preview rendering.

---

## i. iOS-Specific UI Concerns

| Concern | Decision |
|---|---|
| Swipe-to-dismiss | Disabled (`.interactiveDismissDisabled(true)`) on all steps |
| Keyboard avoidance (step 3) | `ScrollView` + `.scrollDismissesKeyboard(.interactively)`; `@FocusState` activates keyboard on step appear |
| Progress indicator | Segmented progress bar at the top of each step (4 segments) |
| Character counter | Live counter below `TextEditor` on step 3; limit enforced via `.onChange` |
| Star rating UI | Row of five tappable `Button` views with star icons from DesignSystem |
| Tag grid UI | Wrapping layout of chip/pill buttons; DesignSystem tokens for selected/unselected colors |
| Haptic feedback | Out of scope for MVP |
| Deep links | Out of scope |
| App lifecycle (foreground/background) | No special handling required; draft state is in-memory only and is discarded on dismiss |

---

## j. Accessibility Requirements

Out of scope for MVP. To be addressed at implementation time with standard iOS practices.

---

## k. Analytics & Tracked Events

Not discussed. No analytics requirements are specified in the PRD for this feature.

---

## l. Testing Strategy

Not explicitly scoped in this session. Recommended coverage per standard practice:
- **Presentation logic unit tests**: fetch success/failure on appear; mode resolution including nil-fetch fallback to create; step state transitions (Next, Back, field reset to baseline on back); draft accumulation; Confirm success → dismiss; Confirm failure → saveState error; silent discard paths.
- **Service interaction tests**: verify `ReviewRepository.fetch` called on appear; verify `create` vs `update` called based on resolved mode; verify no repository call on discard; verify 500-character limit enforced before `create`/`update`.
- **UI tests**: full create flow (step 1 → 4 → confirm); full edit flow (pre-populated fields → modify → confirm); back-navigation field reset; cancel/discard silent dismiss.

---

## m. Deferred to Later Iterations

| Item | Reason |
|---|---|
| Haptic feedback on step transitions and save | Out of scope for MVP |
| VoiceOver labels for star rating control and tag chips | Out of scope for MVP |
| Dynamic Type support audit | Deferred to implementation |
| Reduce Motion alternatives for step transitions | Deferred to implementation |
| Analytics event tracking | Not specified in PRD |
| Character limit above 500 | Agreed at 500; revisit only if user research suggests longer notes are needed |
| Partial draft persistence across app restarts | Explicitly out of scope per PRD |

---

## n. Unresolved Issues

None. All questions raised in the planning session have been answered and all decisions are recorded above.

</ios_feature_planning_summary>

<unresolved_issues>
None.
</unresolved_issues>

</conversation_summary>
