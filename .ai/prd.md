
Here is the full PRD. Ask mode prevents creating or writing files, so this was not saved to `.ai/prd.md`. Switch to Agent mode if you want that file written automatically; otherwise paste the markdown below into `.ai/prd.md`.
# Product Requirements Document (PRD) - Movie Tracker

## 1. Product overview

Movie Tracker is an iOS 17+ client for browsing movies via The Movie Database (TMDB) REST API, maintaining a personal watchlist and a one-review-per-movie log stored locally with SwiftData. The same product scope is implemented three times (MVVM, VIPER, TCA) as a controlled sample for a comparative study; this PRD defines functional and user-facing behavior only. Implementation choices (patterns, module layout, testing harness) are left to each variant, subject to shared behavioral requirements.

Primary capabilities:

- Browse a single-page trending catalog from TMDB.
- Search the TMDB movie catalogue with optional filters (genre, minimum rating, release year range) and sort results.
- View rich movie detail including synopsis, genres, release date, TMDB rating, and up to three cast members.
- Add and remove movies from a local watchlist from Movie Detail, with duplicate adds prevented in normal use and surfaced as an error if state diverges.
- Create, view, edit, and delete a single review per movie via a four-step wizard; review data is local only.

Top-level navigation is a three-tab bar: Catalog, Search, and Watchlist. Movie Detail is reached by selecting a movie from any of these contexts.

Non-functional constraints called out in product decisions:

- Network requests must not block the main UI (loading and results must be represented asynchronously).
- TMDB API key is supplied at build time from an environment-backed configuration shared across implementations; it is not an end-user credential.
- Catalog and search use TMDB; watchlist and reviews do not require network for listing, though images may still load from TMDB URLs where applicable.
- Pagination is intentionally limited to the first page of each TMDB response (no infinite scroll).
- Filter and sort preferences exist only in memory for the running process; killing the app resets them.
- All UI must follow DesignSystem, using predefined fonts, colors, images and other resources.

Unresolved items tracked elsewhere: the behavioral test scenario list lives in a separate test specification produced after this PRD.

## 2. User problem

People who watch films want a lightweight way to discover what is popular, look up titles, remember what they intend to watch, and record a simple personal opinion (rating, tags, notes) tied to a specific movie. Third-party catalog data (TMDB) avoids maintaining a proprietary movie database, while local persistence keeps watchlist and reviews private and available offline for those features.

Without this app, users juggle browser tabs, notes apps, or streaming UIs that do not unify discovery, intent (watchlist), and reflection (reviews) in one focused flow. Movie Tracker reduces context switching by combining TMDB-backed discovery with local watchlist and review state, with clear error handling when the network or API fails.

## 3. Functional requirements

### 3.1 Platform and data

- Minimum OS: iOS 17.
- Local persistence: SwiftData for watchlist entries and reviews.
- TMDB base URL: `https://api.themoviedb.org/3` with version 3 endpoints below.

### 3.2 TMDB integration

| Endpoint | Use |
|----------|-----|
| GET `/trending/movie/week` | Catalog feed |
| GET `/movie/{movie_id}` | Movie Detail primary payload |
| GET `/movie/{movie_id}/credits` | Cast; use top three billed cast members for display |
| GET `/search/movie?query={query}` | Title search (first page only) |
| GET `/genre/movie/list` | Genre names/ids for filter UI |

- API key authentication uses TMDB’s standard query or header mechanism as documented by TMDB; the key value is injected at build time from environment configuration and must not appear in end-user-visible UI.
- Failed HTTP responses or transport errors for any screen that depends on network data must surface an empty or non-blocking state with an inline error explanation and an explicit retry affordance, without deadlocking the interface.

### 3.3 Catalog tab

- Load trending movies from `/trending/movie/week` (first page only).
- Present a vertically scrollable list of movie cards. Each card shows: poster (when available), title, release year, TMDB `vote_average` as overall rating.
- Do not offer sort controls; preserve TMDB trending order.
- On load failure: show empty state, inline error message, and retry control.

### 3.4 Search tab

- Initial state (no query yet): show a clear prompt such as “Search for a movie” (exact copy may vary slightly across implementations).
- Accept a search query and fetch results with `/search/movie` (first page only).
- Results use the same card layout as the Catalog tab.
- Provide a filter control that opens a modal or sheet with:
  - Genre selection (using ids/names from `/genre/movie/list`).
  - Minimum rating threshold (aligned with TMDB `vote_average` scale used in UI).
  - Release year range (start/end or equivalent).
- Filters are combinable. When one or more filters are active, the filter trigger shows a tinted icon or badge.
- Sheet includes “Clear All Filters” to reset filter selections to none.
- Filter selections persist in memory until the user terminates the app process; cold launch clears filters.
- Sort (Search results only): three options — by release date (newest first default), alphabetical by title, by TMDB `vote_average`. Sort preference is in-memory only and resets to default on cold launch.
- On search or supporting genre fetch failure: empty state, inline error, retry as appropriate to the failing operation.

### 3.5 Watchlist tab

- List all watchlist entries from SwiftData using the same card layout as Catalog/Search (poster, title, year, TMDB rating as stored or re-fetched per implementation, consistent with project decisions).
- Sort: date added (default newest first), alphabetical by title, by TMDB overall rating. Sort is in-memory only; resets on cold launch.
- Empty watchlist: show an appropriate empty state (no error unless data layer failure).

### 3.6 Movie Detail

- Reachable from Catalog, Search, and Watchlist by tapping a card.
- Primary content from `/movie/{id}`: large poster, title, overview, genres, release date, TMDB rating.
- Cast: separate request to `/movie/{id}/credits`; display up to three cast members (e.g., name and role per design). If this request fails, show the rest of the detail and omit or mark the cast section as unavailable without failing the whole screen.
- Watchlist call-to-action is state-aware: “Add to Watchlist” when not on the list, “Remove from Watchlist” when present.
- Review calls-to-action:
  - If no review exists: show “Log a Review” and no review summary block.
  - If a review exists: show read-only summary (star rating, selected tags, notes) and actions “Edit Review” and “Delete Review”.
- Deleting a review requires a confirmation dialog before permanent removal from SwiftData.
- Do not show a “reviewed” badge on Catalog, Search, or Watchlist list cards.

### 3.7 Review wizard (create and edit)

- Four linear steps:

| Step | Content |
|------|---------|
| 1 | Star rating, integer 1–5 |
| 2 | Tag selection from a fixed predefined list (see 3.8) |
| 3 | Free-text notes |
| 4 | Summary of choices and confirm to save |

- Create: launched from “Log a Review”. Save on final confirmation writes one `Review` in SwiftData for that movie id.
- Edit: launched from “Edit Review”; fields are prepopulated. Save overwrites the single existing review for that movie.
- Navigating away or dismissing the wizard at any step before successful completion discards in-progress work. For edit, discarding restores the user’s view to the previously saved review unchanged.
- At most one review per movie; attempting to violate this at the data layer should be impossible through normal UI; duplicate watchlist adds are prevented at UI level with error if duplication still occurs.

### 3.8 Predefined review tags (Step 2)

The following fixed tags are available for selection (implementations may present as multi-select unless constrained by a future amendment): Must-see, Rewatch-worthy, Underrated, Overrated, Comfort watch, Dark, Funny, Emotional, Slow burn, Great soundtrack, Thought-provoking.

### 3.9 Domain model (logical)

- Movie (from API/cache): id, title, overview, release date, genre ids, poster path, vote average, and fields needed for display.
- Genre: id, name.
- WatchlistEntry: movie id, date added (for sort by date added).
- Review: movie id, rating 1–5, tags (subset of predefined list), notes text, creation or last-updated metadata as needed for display.

### 3.10 Navigation

- Root: tab bar with Catalog, Search, Watchlist.
- Movie Detail is pushed or presented modally per platform convention; back navigation returns to the originating list or tab state without requiring duplicate network loads beyond normal caching behavior.

## 4. Product boundaries

In scope:

- Behaviors and screens described in section 3.
- First-page-only TMDB results for catalog and search.
- Local-only watchlist and reviews; no user accounts, cloud sync, or social features.
- Graceful degradation when the credits endpoint fails on Movie Detail.
- Study-relevant parity: three apps with the same user-visible features; small visual differences between implementations are acceptable.

Explicitly out of scope:

- User authentication, profiles, or server-side storage of watchlists or reviews.
- Pagination beyond the first TMDB page, infinite scroll, or background prefetch of additional pages.
- Sorting or filtering on the Catalog tab (trending order only).
- Separate “My reviews” or global review management screen (Movie Detail is the hub).
- Indicators on list tiles for “already reviewed.”
- Persisting filter or sort choice across app restarts (UserDefaults or otherwise).
- Partial saves of the review wizard mid-flow.
- Multiple reviews per movie.
- Pixel-identical UI across the three architectural implementations.
- Defining the shared behavioral automated test scenario list (follow-on test specification document).
- Code quality metrics, LLM workflow evaluation, and concurrency posture (study outcomes, not product requirements for the shipped feature set).

## 5. User stories

### US-001 — Three-tab root navigation

- Title: Access Catalog, Search, and Watchlist from the tab bar
- Description: As a user, I want a persistent tab bar so I can switch between browsing trending movies, searching the catalogue, and viewing my watchlist.
- Acceptance criteria:
  - Given the app has finished launching, when I view the root UI, then I see exactly three tabs labeled for Catalog, Search, and Watchlist.
  - When I tap each tab, then the corresponding primary screen is shown without requiring restart.

### US-002 — Browse trending catalog

- Title: View trending movies on Catalog
- Description: As a user, I want to see a list of trending movies for the week so I can discover titles quickly.
- Acceptance criteria:
  - When I open the Catalog tab, then the app requests `/trending/movie/week` and displays a scrollable list of movies from the first page of the response.
  - While the request is in flight, the UI does not freeze; loading is indicated per implementation.
  - The list order matches TMDB trending order for that response (no user reordering).

### US-003 — Catalog card content

- Title: Recognize movies from catalog cards
- Description: As a user, I want each catalog row to show key metadata so I can choose what to open.
- Acceptance criteria:
  - Each card shows title, release year derived from release date, TMDB `vote_average`, and poster artwork when a poster path exists.

### US-004 — Catalog network failure and retry

- Title: Recover from catalog load errors
- Description: As a user, I want to understand when trending movies cannot load and retry without restarting the app.
- Acceptance criteria:
  - When the trending request fails or returns an error state treated as failure, then the Catalog tab shows an empty results area with an inline error message and a retry control.
  - When I invoke retry, then the app attempts the request again.

### US-005 — Open movie detail from catalog

- Title: Drill into a movie from trending list
- Description: As a user, I want to tap a trending movie to see full detail.
- Acceptance criteria:
  - When I tap a catalog card, then Movie Detail opens for that movie’s id.
  - Movie Detail loads `/movie/{id}` for the selected id.

### US-006 — Movie detail core content

- Title: Read movie synopsis and metadata
- Description: As a user, I want to see rich information about a movie on its detail screen.
- Acceptance criteria:
  - Given a successful `/movie/{id}` response, the screen shows poster, title, overview, genres, human-readable release date, and TMDB rating.

### US-007 — Cast section with top three members

- Title: See principal cast
- Description: As a user, I want to see a short cast list so I know who is in the film.
- Acceptance criteria:
  - Given a successful `/movie/{id}/credits` response, the app displays up to three cast members from the billed cast ordering defined in project decisions (top three).
  - Cast presentation includes at least the performer’s name; role/character may be shown per UI design.

### US-008 — Cast failure does not block detail

- Title: View movie detail when cast fails to load
- Description: As a user, I still want synopsis and rating if cast data is unavailable.
- Acceptance criteria:
  - When `/movie/{id}/credits` fails or errors, then Movie Detail still shows primary `/movie/{id}` content.
  - The cast area is empty or shows a non-fatal error state that does not prevent interaction with watchlist or review actions.

### US-009 — Add movie to watchlist

- Title: Save a movie to my watchlist
- Description: As a user, I want to mark movies to watch later from detail.
- Acceptance criteria:
  - Given the movie is not on my watchlist, Movie Detail shows “Add to Watchlist”.
  - When I tap it, then a SwiftData watchlist entry is created for that movie id with a date added, and the CTA updates to “Remove from Watchlist”.
  - The movie appears on the Watchlist tab without requiring a network call for list membership.

### US-010 — Remove movie from watchlist

- Title: Remove a movie from my watchlist
- Description: As a user, I want to clear titles I no longer plan to watch.
- Acceptance criteria:
  - Given the movie is on my watchlist, Movie Detail shows “Remove from Watchlist”.
  - When I tap it, then the entry is removed from SwiftData and the CTA updates to “Add to Watchlist”.
  - The movie no longer appears on the Watchlist tab.

### US-011 — Prevent duplicate watchlist entries

- Title: Avoid duplicate watchlist rows
- Description: As a user, I should not accidentally add the same movie twice under normal use.
- Acceptance criteria:
  - When the movie is already on the watchlist, the UI does not offer “Add to Watchlist”.
  - If an implementation edge case still attempts a duplicate insert, then the user sees an error message and the data store remains consistent (no duplicate rows for the same movie id).

### US-012 — Watchlist tab lists saved movies

- Title: View all watchlisted movies
- Description: As a user, I want one place that lists everything I saved.
- Acceptance criteria:
  - When I open the Watchlist tab, then I see all SwiftData watchlist entries in a scrollable list using the same card layout as Catalog/Search.
  - List content does not depend on network availability for membership (posters may still load from network).

### US-013 — Watchlist empty state

- Title: Understand an empty watchlist
- Description: As a user with no saved movies, I want a clear empty state.
- Acceptance criteria:
  - Given zero watchlist entries, the Watchlist tab shows an empty state message or illustration without a network error tone.

### US-014 — Sort watchlist

- Title: Reorder watchlist view
- Description: As a user, I want to sort my watchlist by date added, title, or rating.
- Acceptance criteria:
  - I can choose among: date added (default newest first), alphabetical by title, and TMDB overall rating.
  - Changing sort reorders the visible list accordingly using data available on each entry.
  - After cold launch, sort resets to the default (newest first).

### US-015 — Search tab initial prompt

- Title: See guidance before searching
- Description: As a user, I want the Search tab to invite me to type a query when I have not searched yet.
- Acceptance criteria:
  - When no search has been submitted in the current session state defined by the implementation, the Search tab shows a prompt such as “Search for a movie” and does not show stale results from a prior session beyond what project decisions allow (cold launch clears session state for filters/sort; search field may start empty).

### US-016 — Execute movie search

- Title: Find movies by title
- Description: As a user, I want to search TMDB by text query.
- Acceptance criteria:
  - When I submit a non-empty query, the app calls `/search/movie` with that query (first page) and displays matching results as cards.
  - While loading, the UI remains responsive.

### US-017 — Search results empty

- Title: Handle no matches
- Description: As a user, I want feedback when search returns zero movies.
- Acceptance criteria:
  - When the API returns an empty result set for a valid query, then I see an empty state that is distinct from a network error (no retry framed as failure unless appropriate).

### US-018 — Search network failure and retry

- Title: Recover from search errors
- Description: As a user, I want to retry when search fails.
- Acceptance criteria:
  - When the search request fails, then I see an inline error with retry in the results area.
  - Retry re-issues the last search request.

### US-019 — Open movie detail from search

- Title: Open detail from search results
- Description: As a user, I want the same detail experience from search as from catalog.
- Acceptance criteria:
  - Tapping a search result opens Movie Detail for that id with the same behaviors as US-006–US-008 and watchlist/review actions.

### US-020 — Open filter sheet

- Title: Narrow search with filters
- Description: As a user, I want a filter sheet to constrain results.
- Acceptance criteria:
  - Tapping the filter control opens a modal or sheet.
  - The sheet exposes genre, minimum rating, and release year range controls that can be combined.

### US-021 — Load genres for filters

- Title: See real genre names in filters
- Description: As a user, I want genre choices that match TMDB.
- Acceptance criteria:
  - The app loads `/genre/movie/list` for filter labels and ids.
  - If genre load fails, the filter UI shows an error path or disabled genre control with recovery consistent with section 3.2 (inline error and retry where practical).

### US-022 — Active filter affordance

- Title: Notice when filters apply
- Description: As a user, I want to see that filters are on without opening the sheet.
- Acceptance criteria:
  - When at least one filter is non-default/active, the filter trigger shows a tinted icon or badge per design.
  - When all filters are cleared, the indicator returns to the inactive appearance.

### US-023 — Clear all filters

- Title: Reset filters quickly
- Description: As a user, I want one action to remove every filter.
- Acceptance criteria:
  - The filter sheet exposes “Clear All Filters”.
  - Activating it resets genre, rating threshold, and year range to their non-filtering defaults and updates results accordingly.

### US-024 — Filter persistence for app session

- Title: Keep filters while using the app
- Description: As a user, I expect filters to stay applied as I navigate until I kill the app.
- Acceptance criteria:
  - After setting filters and closing the sheet, filters remain applied to the current search context while the process runs.
  - After user-terminated process and cold launch, filters start cleared.

### US-025 — Sort search results

- Title: Reorder search results
- Description: As a user, I want search results sorted by release date, title, or TMDB rating.
- Acceptance criteria:
  - I can select among release date (default newest first), alphabetical title, and `vote_average`.
  - The list reflects the selection for the loaded first-page result set.
  - After cold launch, sort resets to default.

### US-026 — No sort on catalog

- Title: Catalog follows TMDB order only
- Description: As a user, I should not see sort controls on trending.
- Acceptance criteria:
  - Catalog tab has no sort UI.
  - Order remains as returned by `/trending/movie/week`.

### US-027 — Start review wizard (create)

- Title: Log a new review
- Description: As a user without a review, I want to start a guided review flow.
- Acceptance criteria:
  - Given no review exists for the movie, Movie Detail shows “Log a Review”.
  - Tapping it opens the four-step wizard at step 1.

### US-028 — Wizard step 1 rating

- Title: Choose star rating
- Description: As a user, I want to assign 1–5 stars.
- Acceptance criteria:
  - Step 1 requires a whole-number rating between 1 and 5 inclusive before proceeding (or validation on final submit per implementation, but invalid submissions are blocked).

### US-029 — Wizard step 2 tags

- Title: Choose predefined tags
- Description: As a user, I want to tag my reaction using a fixed list.
- Acceptance criteria:
  - Step 2 only allows selection from the predefined tag list in section 3.8.
  - Selected tags are shown on the step 4 summary.

### US-030 — Wizard step 3 notes

- Title: Add free-text notes
- Description: As a user, I want optional or required notes per design.
- Acceptance criteria:
  - Step 3 provides a free-text notes field; emptiness rules follow implementation unless constrained later, but summary step reflects the final text.

### US-031 — Wizard step 4 confirm save

- Title: Confirm before saving review
- Description: As a user, I want to review my choices before they are stored.
- Acceptance criteria:
  - Step 4 shows rating, tags, and notes summary and a confirm action.
  - On confirm, SwiftData persists exactly one review for the movie id and Movie Detail shows the read-only summary with edit/delete affordances.

### US-032 — Discard wizard on cancel (create)

- Title: Abandon new review safely
- Description: As a user, I want to exit without saving a partial review.
- Acceptance criteria:
  - If I leave the wizard before successful completion on create, then no new review row is created.
  - Movie Detail continues to show “Log a Review”.

### US-033 — View existing review on detail

- Title: See saved review summary
- Description: As a user, I want confirmation of what I logged.
- Acceptance criteria:
  - Given a review exists, Movie Detail shows rating, tags, and notes read-only alongside “Edit Review” and “Delete Review”.
  - “Log a Review” is not shown.

### US-034 — Edit existing review

- Title: Update my review
- Description: As a user, I want to change rating, tags, or notes later.
- Acceptance criteria:
  - Tapping “Edit Review” opens the wizard with all fields prepopulated.
  - Completing step 4 overwrites the prior review for that movie id; count remains one.

### US-035 — Discard wizard on cancel (edit)

- Title: Cancel edits without losing saved review
- Description: As a user, I want to abandon changes and keep the original review.
- Acceptance criteria:
  - If I exit the wizard before successful completion while editing, then SwiftData review content is unchanged from before the edit session began.
  - Movie Detail still shows the prior summary.

### US-036 — Delete review with confirmation

- Title: Remove my review deliberately
- Description: As a user, I want to delete my review but avoid accidents.
- Acceptance criteria:
  - Tapping “Delete Review” shows a confirmation dialog.
  - If I confirm, the review is removed from SwiftData and Movie Detail shows “Log a Review” with no summary.
  - If I cancel the dialog, the review remains.

### US-037 — Single review per movie

- Title: Enforce one review per title
- Description: As a user, I should never have two reviews for the same movie.
- Acceptance criteria:
  - After saving a review, I cannot start a second independent review for the same movie id; only edit/delete paths are available.
  - Data layer enforces uniqueness of review per movie id.

### US-038 — No reviewed badge on lists

- Title: Uncluttered list tiles
- Description: As a user, list rows should not show reviewed status.
- Acceptance criteria:
  - Catalog, Search, and Watchlist cards never show a reviewed indicator badge or icon.

### US-039 — Open detail from watchlist

- Title: Inspect watchlisted movie
- Description: As a user, I want detail from my saved list.
- Acceptance criteria:
  - Tapping a watchlist card opens Movie Detail and behaves consistently with other entry points, including TMDB refresh for detail fields as implemented.

### US-040 — Secure TMDB API access

- Title: Protect API credentials from end users
- Description: As a stakeholder, TMDB access must follow agreed security practice for a client key.
- Acceptance criteria:
  - The TMDB API key is provided via build-time configuration from an environment file, not typed by the user in the app.
  - The key is not displayed in any end-user-visible screen or share sheet exposed by the app for normal use.
  - All TMDB calls use this configuration so traffic is authorized against TMDB expectations.

### US-041 — Non-blocking network operations

- Title: Keep UI responsive during API calls
- Description: As a user, I want the interface to stay interactive while data loads.
- Acceptance criteria:
  - For Catalog load, Search load, Movie Detail loads, credits load, and genre load, the main thread is not blocked waiting on the network; loading and errors are surfaced asynchronously.

## 6. Success metrics

### 6.1 Product and UX

- Users can complete core flows without ambiguity: browse trending, search with optional filters and sort, add/remove watchlist, create/edit/delete review, and recover from typical network failures using retry.
- Empty and error states are present on every network-dependent list or detail subsection per requirements, with measurable manual test pass on a checklist derived from this PRD.
- Watchlist and review data survive backgrounding and relaunch of the app (same device) for the life of the install, barring OS data purge.

### 6.2 Study parity (three implementations)

- MVVM, VIPER, and TCA versions expose the same user-visible features and navigation described in sections 3–5; intentional differences are limited to non-specified visual polish.
- Each implementation documents adherence to the shared endpoints, single-page TMDB policy, SwiftData persistence, wizard discard rules, and session-only filter/sort behavior.

### 6.3 Engineering quality (delivery)

- No critical defects open against P0 flows (tab navigation, catalog load, search, watchlist CRUD, review CRUD, Movie Detail with degradation) at milestone acceptance.
- A follow-on test specification enumerates behavioral scenarios; all three implementations implement automated or manual coverage for that list (coverage percentage not mandated).

### 6.4 Security and configuration

- API key handling matches US-040; no key material is committed to public artifact stores in plaintext as part of release process (team policy outside this PRD may add scanning gates).

---

PRD checklist (verification):

- Every user story above maps to observable UI or data outcomes and can be tested manually or with UI tests.
- Acceptance criteria use concrete screens, endpoints, or state transitions.
- Stories collectively cover navigation, catalog, search (including filters, sort, errors), watchlist (sort, empty, detail entry), Movie Detail (cast success/failure, CTAs), full wizard lifecycle (create, edit, discard both modes, delete confirm), duplicates, list-card policy, non-blocking UI, and API key handling.
- Authentication: end-user login is not in scope; access control for TMDB is addressed via US-040 (build-injected API key, not exposed in UI).
```
