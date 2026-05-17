// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MovieTrackerPackage",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "DomainModels", targets: ["DomainModels"]),
        .library(name: "PersistenceKit", targets: ["PersistenceKit"]),
        .library(name: "SharedUIComponents", targets: ["SharedUIComponents"]),
        .library(name: "TMDBClient", targets: ["TMDBClient"]),
        .library(name: "ReviewRepository", targets: ["ReviewRepository"]),
        .library(name: "WatchlistRepository", targets: ["WatchlistRepository"]),
        .library(name: "CatalogFeature", targets: ["CatalogFeature"]),
    ],
    targets: [
        .target(name: "DesignSystem"),
        .target(name: "Networking"),
        .target(name: "DomainModels"),
        .target(
            name: "PersistenceKit",
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .target(
            name: "SharedUIComponents",
            dependencies: ["DesignSystem"]
        ),
        .target(
            name: "TMDBClient",
            dependencies: ["Networking", "DomainModels"]
        ),
        .target(
            name: "ReviewRepository",
            dependencies: ["DomainModels", "PersistenceKit"]
        ),
        .target(
            name: "WatchlistRepository",
            dependencies: ["DomainModels", "PersistenceKit"]
        ),
        .target(
            name: "CatalogFeature",
            dependencies: ["DomainModels", "SharedUIComponents", "TMDBClient"]
        ),
        .testTarget(name: "CatalogFeatureTests", dependencies: ["CatalogFeature", "DomainModels", "TMDBClient"]),
        .testTarget(name: "NetworkingTests", dependencies: ["Networking"]),
        .testTarget(name: "PersistenceKitTests", dependencies: ["PersistenceKit"]),
        .testTarget(name: "SharedUIComponentsTests", dependencies: ["SharedUIComponents"]),
        .testTarget(name: "TMDBClientTests", dependencies: ["TMDBClient", "Networking", "DomainModels"]),
        .testTarget(name: "ReviewRepositoryTests", dependencies: ["ReviewRepository"]),
        .testTarget(name: "WatchlistRepositoryTests", dependencies: ["WatchlistRepository"]),
    ]
)
