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
        .testTarget(name: "NetworkingTests", dependencies: ["Networking"]),
        .testTarget(name: "PersistenceKitTests", dependencies: ["PersistenceKit"]),
        .testTarget(name: "SharedUIComponentsTests", dependencies: ["SharedUIComponents"]),
        .testTarget(name: "TMDBClientTests", dependencies: ["TMDBClient", "Networking", "DomainModels"]),
        .testTarget(name: "ReviewRepositoryTests", dependencies: ["ReviewRepository"]),
    ]
)
