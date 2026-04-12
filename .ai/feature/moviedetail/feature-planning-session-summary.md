# MovieDetail Feature — Planning Session Summary

<conversation_summary>

<decisions>

1. Entry data: only `movieId: Int` is passed to `MovieDetailView`; the screen starts in a full loading state and waits for the `/movie/{id}` API response before rendering any content.
2. Optional fields with missing values: show UI placeholders (e.g., empty overview, no poster) rather than treating missing fields as an error.
3. Cast section failure: a "Cast unavailable" inline message is shown with an explicit retry button; failure is non-fatal and does not affect the rest of the screen.
4. Offline indicator on Movie Detail: out of scope for MVP.
5. Watchlist CTA when `Movie` is unavailable: CTA is disabled when the primary detail load is in-progress or has failed; it is only enabled once `MovieDetail` is successfully loaded.
6. Local state (watchlist membership, review): fetched after the primary detail load completes, not eagerly on entry. This simplifies the state machine for MVP.
7. Review deletion: the feature owns the confirmation dialog. The delete is expected to be async depending on the architectural variant; the review state transitions only after the deletion is confirmed successful.
8. Loading strategy: show a loader for all in-progress states; no skeleton or partial content.
9. Watchlist CTA during mutation: replaced with a spinner while add/remove is in-progress.
10. Review delete state transition: the review section transitions from summary to "Log a Review" only after the deletion completes successfully.
11. Screen state decomposition accepted as four independent sub-states: `detailState`, `castState`, `watchlistState`, `reviewState`.
12. Watchlist and review CTAs are disabled until `detailState` is `.loaded`.
13. Wizard dismissal: use the `.fullScreenCover` `onDismiss` callback to re-fetch review state from `ReviewRepository`.
14. No caching: `/movie/{id}` and `/movie/{id}/credits` are always re-fetched on every navigation push to `MovieDetailView`.
15. Tab-switch state persistence: not required. The screen is instantiated fresh per navigation push; persisting state across tab switches is treated as an unlikely edge case and is out of scope.
16. MovieDetail owns wizard presentation. In VIPER: the Router is an `@ObservableObject` that holds `@Published var wizardPresentation: WizardPresentation?`; the View observes the Router directly for this state; user actions are still routed through the Presenter.
17. Wizard pre-population (edit mode): the wizard fetches its own existing `Review` using `movieId`; `MovieDetailView` does not pass the `Review` struct to the wizard.
18. Watchlist add failure (`.alreadyOnWatchlist`): inline error text displayed under the watchlist CTA.
19. Watchlist remove failure (`.notFound`): inline error text displayed under the watchlist CTA.
20. Review delete failure: inline error shown after the confirmation dialog is dismissed.
21. Delete confirmation dialog: title "Are you sure you want to delete the review?"; destructive "Delete" button and non-destructive "Cancel" button.
22. Cast unavailable state: "Cast unavailable" inline text with a retry button; the section header remains visible.
23. Primary detail failure: the entire screen content area is replaced by `ErrorStateView` with a retry action; back navigation remains available via the navigation bar.
24. Previews: multiple previews created per distinct screen state; architecture-specific approach (pre-populated ViewModel / initial state / Presenter); views do not interact with the service layer directly.
25. Haptic feedback: out of scope for MVP.
26. Poster image placeholder: gray rounded rectangle with a camera icon from DesignSystem; no error shown to the user on image-load failure.
27. Navigation bar: large title displaying the movie title, back button only; no share sheet, no toolbar items.
28. VIPER router pattern: Router is an `@ObservableObject` that owns `@Published var wizardPresentation: WizardPresentation?`; the composition root injects all wizard dependencies; the Presenter calls Router methods in response to user actions.
29. Section visibility rule: cast section and watchlist/review CTAs are rendered only after `detailState` reaches `.loaded`; they are not shown during loading or in error state.
30. Cast retry: tapping retry in the cast section re-issues `fetchCredits(id:)` only; the primary detail is not re-fetched.
31. Watchlist CTA spinner: showing a spinner during watchlist mutations is a recommended UX pattern; the implementation is variant-specific (a TCA `Effect` wrapping a synchronous call may introduce an async hop; MVVM/VIPER calling on `@MainActor` may transition synchronously).

</decisions>

<matched_recommendations>

1. **Accepted** — Fire `fetchMovie(id:)` and `fetchCredits(id:)` in parallel (Swift `async let` or equivalent). Primary content renders when `fetchMovie` resolves; cast section updates independently when `fetchCredits` resolves or fails.
2. **Rejected** — Eager local state check before the API response. Replaced by decision 6: local state is fetched only after the primary detail load completes.
3. **Accepted** — Watchlist CTA is disabled until `Movie` is available (primary detail loaded successfully).
4. **Accepted with caveat** — Cast state is modelled separately from primary load state, but cast section and CTAs are only rendered after the primary detail succeeds (decision 29).
5. **Accepted** — Screen state decomposed into four independent sub-states: `detailState`, `castState`, `watchlistState`, `reviewState`.
6. **Rejected** — "No intermediate spinner needed; SwiftData is instantaneous." Replaced by decision 9: CTA is replaced with a spinner during mutations regardless of underlying implementation speed, as synchronous vs. asynchronous behaviour is an implementation detail not guaranteed by the service contract.
7. **Accepted** — Inline non-blocking error text under the CTA for watchlist mutation failures (decisions 18–19).
8. **Accepted** — `ErrorStateView` replaces the full screen content area only for primary detail failure (decision 23).
9. **Accepted** — `MovieDetailView` owns the `.fullScreenCover` binding (or the Router owns the binding state in VIPER) for the wizard presentation (decision 16).
10. **Accepted** — `onDismiss` triggers a `ReviewRepository.fetch(movieId:)` re-check (decision 13).
11. **Accepted** — Always re-fetch; no caching at the feature layer (decision 14).
12. **Accepted** — `.confirmationDialog` for review deletion (decision 21).
13. **Rejected** — Haptic feedback on watchlist mutations; out of scope for MVP (decision 25).
14. **Accepted** — `AsyncImage` (or shared UI wrapper) with a gray rounded rectangle + DesignSystem camera icon placeholder (decision 26).
15. **Accepted** — Preview strategy: multiple previews per state; architecture-specific; views do not touch the service layer (decision 24).

</matched_recommendations>

<ios_feature_planning_summary>

## a. Feature Scope & Responsibility Boundary

**In scope:**
- `MovieDetailView`: the single screen owned by this feature, pushed onto the active tab's `NavigationStack`.
- Fetching primary movie detail from `/movie/{id}` and credits from `/movie/{id}/credits`.
- Rendering poster, title, overview, genres, release date, TMDB rating, and up to three cast members.
- Watchlist CTA: "Add to Watchlist" / "Remove from Watchlist" state-aware button backed by `WatchlistRepository`.
- Review CTA: "Log a Review" when no review exists; read-only review summary with "Edit Review" and "Delete Review" when a review exists; backed by `ReviewRepository`.
- Confirmation dialog before review deletion.
- Presenting `ReviewWizardView` as a `.fullScreenCover` for create and edit flows.
- All loading, error, and unavailable sub-states for each section.

**Explicitly delegated or out of scope:**
- Review wizard implementation (owned by the Review feature; wizard fetches its own data).
- Composing `MovieDetail` from detail + credits (done by `TMDBClient`; feature receives `MovieDetail` with `cast: .notRetrieved`).
- Slicing cast to top three (feature responsibility at the presentation layer).
- Poster URL assembly from relative path (presentation layer).
- Sort preferences (not applicable to this screen).
- Deep linking (out of scope for MVP).
- Offline indicator (out of scope for MVP).
- Haptic feedback (out of scope for MVP).
- Share sheet (out of scope for MVP).
- Tab-switch state persistence (out of scope for MVP).

---

## b. Service Dependencies

| Service | Protocol | Operations consumed |
|---|---|---|
| `TMDBClient` | `TMDBClientProtocol` | `fetchMovie(id:)` → `MovieDetail`; `fetchCredits(id:)` → `[CastMember]` |
| `WatchlistRepository` | `WatchlistRepository` | `contains(movieId:)` → `Bool`; `add(movie:)` throws; `remove(movieId:)` throws |
| `ReviewRepository` | `ReviewRepository` | `fetch(movieId:)` → `Review?`; `delete(movieId:)` throws |

`ReviewWizardView` (the Review feature) consumes `ReviewRepository` independently for create and update operations; `MovieDetailView` does not coordinate those calls.

---

## c. Presentation Logic

### `MovieDetailView`

**Screen state shape (four independent sub-states):**

```
detailState:    .loading | .loaded(MovieDetail) | .error(TMDBError)
castState:      .loading | .loaded([CastMember]) | .unavailable
watchlistState: .loading | .onWatchlist | .notOnWatchlist | .mutating | .error(String)
reviewState:    .loading | .hasReview(Review) | .noReview | .error(String)
```

`castState`, `watchlistState`, and `reviewState` are only rendered when `detailState == .loaded`. While `detailState` is `.loading` or `.error`, only the loader or `ErrorStateView` is shown; no section sub-states are visible.

**User actions and side effects:**

| Action | Trigger | Side effect | State transition |
|---|---|---|---|
| Screen appears | Navigation push | `fetchMovie(id:)` + `fetchCredits(id:)` fired in parallel | `detailState → .loading`, `castState → .loading` |
| Primary detail loaded | `fetchMovie` success | Check `WatchlistRepository.contains` + `ReviewRepository.fetch` | `detailState → .loaded`, `watchlistState` + `reviewState` populated |
| Primary detail failed | `fetchMovie` failure | None | `detailState → .error` |
| Retry primary detail | User taps retry | Re-issue `fetchMovie(id:)` | `detailState → .loading` |
| Credits loaded | `fetchCredits` success | None | `castState → .loaded([CastMember])` (sliced to top 3 at presentation) |
| Credits failed | `fetchCredits` failure | None | `castState → .unavailable` |
| Retry cast | User taps retry in cast section | Re-issue `fetchCredits(id:)` only | `castState → .loading` |
| Add to Watchlist | User taps CTA | `WatchlistRepository.add(movie:)` | `watchlistState → .mutating` → `.onWatchlist` on success or `.error(message)` on failure |
| Remove from Watchlist | User taps CTA | `WatchlistRepository.remove(movieId:)` | `watchlistState → .mutating` → `.notOnWatchlist` on success or `.error(message)` on failure |
| Log a Review | User taps CTA | Present wizard in create mode | `wizardPresentation = .create` |
| Edit Review | User taps CTA | Present wizard in edit mode | `wizardPresentation = .edit` |
| Delete Review | User taps CTA | Show confirmation dialog | `showDeleteConfirmation = true` |
| Confirm delete | User confirms dialog | `ReviewRepository.delete(movieId:)` | `reviewState → .loading` → `.noReview` on success or `.error(message)` on failure |
| Cancel delete | User cancels dialog | None | No state change |
| Wizard dismissed | `.fullScreenCover` `onDismiss` | `ReviewRepository.fetch(movieId:)` | `reviewState` re-derived from fetch result |

**Local business rules:**
- Watchlist and review CTAs are rendered only when `detailState == .loaded`.
- Watchlist CTA is disabled (not merely hidden) while `detailState` is loading.
- The `Movie` value for `WatchlistRepository.add(movie:)` is extracted from `MovieDetail.movie` — available only after `detailState == .loaded`.
- Cast list is sliced to the first three members at the presentation layer.
- Inline error messages for watchlist and review mutations are displayed beneath the relevant CTA and replace themselves on the next successful operation.

---

## d. State Shape & Ownership

**Local to `MovieDetailView`:**
- `detailState: DetailState`
- `castState: CastState`
- `watchlistState: WatchlistState`
- `reviewState: ReviewState`
- `wizardPresentation: WizardPresentation?` (drives `.fullScreenCover`)
- `showDeleteConfirmation: Bool`

**Initialization on entry:**
- All states initialized to their loading variants on screen push.
- `fetchMovie` + `fetchCredits` fired in parallel immediately.
- `watchlistState` and `reviewState` populated only after `detailState` transitions to `.loaded`.

**Cleanup on exit:**
- All state is local and discarded when the screen is popped; no session-scoped state is maintained.
- A fresh instance is created on every navigation push; no caching at the feature layer.

**Concurrent service updates:**
- `fetchCredits` may resolve before or after `fetchMovie`. The feature applies `castState` updates independently; they do not block or invalidate `detailState`.
- Wizard dismissal triggers a synchronous `ReviewRepository.fetch`; no concurrent review update is expected during the wizard session.

---

## e. Navigation & Routing

**Entry point:** `MovieDetailView` is pushed onto the active tab's `NavigationStack` when the user taps a movie card in Catalog, Search, or Watchlist. It receives `movieId: Int` as its initialization parameter.

**Internal navigation:**
- `ReviewWizardView` is presented as a `.fullScreenCover` from `MovieDetailView`.
- `wizardPresentation: WizardPresentation?` drives the cover: `nil` = dismissed, non-nil = presented with mode (`.create` or `.edit`).
- Wizard dismissal is handled via the `onDismiss` callback; review state is re-fetched synchronously from `ReviewRepository`.

**VIPER-specific routing:**
- The Router is an `@ObservableObject` with `@Published var wizardPresentation: WizardPresentation?`.
- The View observes the Router for presentation state; user actions flow through the Presenter, which calls Router methods.
- The Router builds the wizard VIPER module (Interactor + Presenter + View) using dependencies from the composition root.
- On wizard dismissal, the View notifies the Presenter, which instructs the Interactor to re-fetch review state.

**Exit:** Back navigation via the system navigation bar back button pops the screen and returns to the originating list. No programmatic back navigation is triggered by this feature.

**Deep links:** Not in scope for MVP.

---

## f. User Interactions & Validation

**Confirmation dialogs:**
- Review delete: `.confirmationDialog` with message "Are you sure you want to delete the review?", destructive "Delete" button, and non-destructive "Cancel" button.

**Inline error surfacing:**
- Watchlist add failure (`.alreadyOnWatchlist`, `.insertFailed`): inline error text displayed below the watchlist CTA.
- Watchlist remove failure (`.notFound`, `.deleteFailed`): inline error text below the CTA.
- Review delete failure (`deleteFailed`): inline error text shown after the confirmation dialog is dismissed.

**No form inputs on this screen** — all data entry is delegated to the wizard.

---

## g. Transient State Treatment

| Section | Loading | Success | Error / Unavailable |
|---|---|---|---|
| Primary detail | Full-screen loader | Full content rendered | Full-screen `ErrorStateView` + retry |
| Cast section | Section loader (within detail layout) | Up to 3 cast members | "Cast unavailable" + retry button (non-fatal; does not affect other sections) |
| Watchlist CTA | CTA disabled (detail loading) | "Add" or "Remove" CTA | CTA replaced with spinner during mutation; inline error text on failure |
| Review section | Section loader | Review summary + Edit/Delete; or "Log a Review" | Inline error text on delete failure |
| Poster image | Gray rounded rectangle + DesignSystem camera icon | Poster image | Silent fallback to placeholder (no error shown) |

**No optimistic updates.** Watchlist and review state transitions only after the corresponding service call succeeds. The watchlist CTA is replaced with a spinner during mutation; the implementation of the async boundary is variant-specific.

---

## h. SwiftUI Previews Strategy

Multiple distinct previews are created, one per named screen state:
- Primary loading
- Primary error
- Loaded — not on watchlist, no review, cast loading
- Loaded — not on watchlist, no review, cast unavailable
- Loaded — not on watchlist, no review, cast loaded
- Loaded — on watchlist, with review, cast loaded
- Loaded — watchlist mutation in progress (CTA spinner)

**Architecture-specific approach:** views do not interact with the service layer directly. Each architectural variant populates the preview using its own mechanism:
- MVVM: pre-configured `ViewModel` with stub data
- VIPER: pre-configured `Presenter` output / view state
- TCA: initial `State` struct with stubbed values

No mock service implementations are injected into the View in previews. Shared preview fixtures (static `MovieDetail`, `Review`, `WatchlistEntry` values) may live in a preview support group within the feature module.

---

## i. iOS-Specific UI Concerns

| Concern | Decision |
|---|---|
| Navigation bar | Large title (movie title), back button only; no toolbar items |
| Poster image loading | `AsyncImage` or shared UI wrapper; gray rounded rectangle + DesignSystem camera icon as placeholder; silent fallback on failure |
| `.fullScreenCover` | Tabs are not visible while the wizard cover is presented; no state persistence needed across tab switches |
| Keyboard avoidance | Not applicable — no text input on this screen |
| Haptic feedback | Out of scope for MVP |
| Share sheet | Out of scope |
| Deep links | Out of scope |
| App lifecycle (foreground/background) | No special handling required; state is re-derived on re-appear via `onAppear` re-checks |

---

## j. Accessibility Requirements

Not explicitly discussed in this planning session. To be addressed at implementation time with standard iOS practices:
- VoiceOver labels for watchlist and review CTAs, cast member cells, and poster image.
- Dynamic Type support for all text elements via DesignSystem typography tokens.
- Reduce Motion alternatives for any loading animations.

---

## k. Analytics & Tracked Events

Not discussed. No analytics requirements are specified in the PRD for this feature.

---

## l. Testing Strategy

Not explicitly scoped in this session. Recommended coverage per standard practice:
- **Presentation logic unit tests**: state transitions for all `detailState`, `castState`, `watchlistState`, `reviewState` permutations; CTA enabled/disabled rules; wizard presentation triggers; `onDismiss` re-fetch behaviour.
- **Service interaction tests**: verify `fetchMovie` + `fetchCredits` are called in parallel on entry; verify `WatchlistRepository.add/remove` and `ReviewRepository.delete` are called with correct `movieId`; verify error mapping to inline error state.
- **UI tests**: primary load → content visible; watchlist add → CTA flips; review delete confirmation → review removed; cast retry → credits re-fetched.

---

## m. Deferred to Later Iterations

| Item | Reason |
|---|---|
| Haptic feedback on watchlist mutations | Out of scope for MVP |
| Offline / no-connectivity banner | Out of scope for MVP |
| Deep link entry into `MovieDetailView` | Out of scope for MVP |
| Share sheet for movie | Not in PRD |
| Accessibility audit (VoiceOver labels, Dynamic Type, Reduce Motion) | Deferred to implementation; not explicitly planned in this session |
| Analytics event tracking | Not specified in PRD |
| Poster image caching | Deferred per TMDBClient plan; `AsyncImage` handles display-level caching opportunistically |

---

## n. Unresolved Issues

None. All questions raised in the planning session have been answered and all decisions are recorded above.

</ios_feature_planning_summary>

<unresolved_issues>
None.
</unresolved_issues>

</conversation_summary>
