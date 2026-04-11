# Tech Stack — Movie Tracker

## Platform

- **Minimum OS**: iOS 17
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI

## Persistence

- **Framework**: SwiftData (iOS 17 native)
- **Store type**: SQLite on-disk (production), in-memory (tests)
- **Schema versioning**: `VersionedSchema` from initial release

## Networking

- **Transport**: `URLSession` with async/await
- **API**: TMDB REST v3

## Architecture Pattern

Intentionally unspecified at this layer. The same data model, persistence layer, and service contracts are shared across three parallel implementations — MVVM, VIPER, and TCA — each living in its own branch. All architecture-specific wiring (view models, presenters, reducers, stores) is branch-local.

## Testing

- **Framework**: XCTest
- **Persistence isolation**: in-memory `ModelContainer` recreated per test case

## Configuration

- **API key delivery**: build-time environment-backed configuration (`.xcconfig` or equivalent); never stored in SwiftData or exposed in UI

## Design System

- Shared `DesignSystem` package providing fonts, colors, icons, spacing, and other UI tokens used across all three implementations
