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

## Architecture

TCA: single-purpose reducers, `Store`/`ViewStore` driving SwiftUI, effects for TMDB and persistence side effects, explicit navigation/state composition for multi-step flows.

## Toolchain & deployment
- Xcode 26.2  

## Testing

- **Framework**: XCTest
- **Persistence isolation**: in-memory `ModelContainer` recreated per test case

## Configuration

- **API key delivery**: build-time environment-backed configuration (`.xcconfig` or equivalent); never stored in SwiftData or exposed in UI

## Design System

- Shared `DesignSystem` package providing fonts, colors, icons, spacing, and other UI tokens used across all three implementations

## Internationalization
Not included in this project scope.

## Observability
Not included in this project scope.

## Security & privacy
Not applicable for this sample application.

## Other
App extensions, widgets, universal links, and performance budgets: not applicable for this sample.
