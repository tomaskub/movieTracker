# Technical stack — VIPER

## UI
SwiftUI

## Persistence
SwiftData

## Testing
XCTest (unit and UI tests as applicable)

## Toolchain & deployment
- Xcode 26.2  
- Swift 5.9  
- Deployment: iPhone only  

## Networking
- URLSession  
- No authentication layer (TMDB usage per project configuration)  
- No dedicated HTTP caching layer  
- Remote API: The Movie Database (TMDB) only  

## Dependencies
Swift Package Manager (SPM) for any packages; VIPER is implemented with native Swift modules (no dedicated VIPER framework required).

## Architecture
VIPER: View (SwiftUI), Interactor (business logic and use cases), Presenter (view logic), Entity (domain models), Router (navigation). Data services and SwiftData access live behind protocols consumed by the Interactor.

## Build & delivery
_To be documented._

## Observability
Not included in this project scope.

## Security & privacy
Not applicable for this sample application.

## Internationalization
_To be documented._

## Other
App extensions, widgets, universal links, and performance budgets: not applicable for this sample.
