# Movie Tracker

[![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-blue)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org)
[![Architecture](https://img.shields.io/badge/architecture-VIPER-purple)](https://github.com/tomaszkubiak/workspace/movie_tracker)
[![License](https://img.shields.io/badge/license-MIT-green)](#license)

## Table of Contents

- [Project Description](#project-description)
- [Tech Stack](#tech-stack)
- [Getting Started Locally](#getting-started-locally)
- [Available Scripts](#available-scripts)
- [Project Scope](#project-scope)
- [Project Status](#project-status)
- [License](#license)

---

## Project Description

Movie Tracker is an iOS 17+ application for discovering movies, maintaining a personal watchlist, and logging reviews. It integrates with [The Movie Database (TMDB)](https://www.themoviedb.org/) REST API for catalogue data and persists watchlist entries and reviews locally using SwiftData.

The product is implemented three times — **MVVM**, **VIPER**, and **TCA** — as a controlled sample for a comparative architectural study. All three variants expose identical user-visible features and navigation. This repository contains the **VIPER** implementation.

Key capabilities:

- **Catalog** — Browse a weekly trending movie feed from TMDB.
- **Search** — Find movies by title with combinable filters (genre, minimum rating, release year range) and sortable results.
- **Movie Detail** — View synopsis, genres, release date, TMDB rating, and top three cast members.
- **Watchlist** — Add and remove movies; list persists offline via SwiftData.
- **Reviews** — Create, edit, and delete a single review per movie through a four-step guided wizard (rating, tags, notes, confirmation).

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Architecture | VIPER (View · Interactor · Presenter · Entity · Router) |
| Persistence | SwiftData |
| Networking | URLSession |
| Remote API | The Movie Database (TMDB) v3 |
| Package manager | Swift Package Manager (SPM) |
| Testing | XCTest (unit & UI) |
| Toolchain | Xcode 26.2 · Swift 5.9 |
| Deployment target | iPhone only · iOS 17+ |

---

## Getting Started Locally

### Prerequisites

- Xcode 26.2 or later
- An iOS 17+ simulator or physical iPhone
- A [TMDB API key](https://developer.themoviedb.org/docs/getting-started) (free registration required)

### Setup

1. **Clone the repository**

   ```bash
   git clone https://github.com/<your-org>/movie_tracker.git
   cd movie_tracker
   git checkout impl/viper
   ```

2. **Configure the TMDB API key**

   The API key is injected at build time from an environment-backed configuration file. Create a `.env` or configuration file at the project root as expected by the build setup (see the project's build configuration for the exact variable name), and set your key:

   ```
   TMDB_API_KEY=your_api_key_here
   ```

   > The key must never be committed to source control or displayed in any end-user screen.

3. **Open the project in Xcode**

   ```bash
   open MovieTracker.xcodeproj
   ```

4. **Select a scheme and destination**

   In Xcode, choose the `MovieTracker` scheme and an iPhone simulator running iOS 17 or later.

5. **Build and run**

   Press `⌘R` or choose **Product → Run**.

---

## Available Scripts

All commands use the `xcodebuild` CLI. Replace `<simulator-id>` with a valid simulator UDID (find one with `xcrun simctl list devices`).

| Task | Command |
|---|---|
| Build | `xcodebuild build -project MovieTracker.xcodeproj -scheme MovieTracker -destination 'platform=iOS Simulator,name=iPhone 16'` |
| Run unit tests | `xcodebuild test -project MovieTracker.xcodeproj -scheme MovieTrackerTests -destination 'platform=iOS Simulator,name=iPhone 16'` |
| Run UI tests | `xcodebuild test -project MovieTracker.xcodeproj -scheme MovieTrackerUITests -destination 'platform=iOS Simulator,name=iPhone 16'` |

---

## Project Scope

### In scope

- All screens and behaviors defined in the PRD: Catalog, Search (with filters and sort), Watchlist (with sort), Movie Detail, and the four-step Review wizard.
- First-page-only TMDB results for catalog and search (no infinite scroll or pagination).
- Local-only watchlist and reviews — no user accounts, cloud sync, or social features.
- Graceful degradation when the credits endpoint fails on Movie Detail.
- Functional parity with the MVVM and TCA implementations; minor visual differences are acceptable.

### Out of scope

- User authentication, profiles, or server-side storage.
- Pagination beyond the first TMDB page.
- Sorting or filtering on the Catalog tab (trending order only).
- A dedicated "My Reviews" management screen.
- Reviewed badges on list tiles.
- Persisting filter or sort preferences across app restarts.
- Partial saves of the review wizard mid-flow.
- Multiple reviews per movie.
- Pixel-identical UI across the three architectural variants.
- Code quality metrics and LLM workflow evaluation (study outcomes, not product requirements).

---

## Project Status

Active development — VIPER implementation in progress (`impl/viper` branch).

The behavioral test scenario list is defined in a separate test specification produced after the PRD. Automated or manual test coverage for all three implementations is planned as a follow-on deliverable.

---

## License

This project is licensed under the [MIT License](LICENSE).
