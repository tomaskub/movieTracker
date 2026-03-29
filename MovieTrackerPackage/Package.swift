// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MovieTrackerPackage",
    platforms: [.iOS(.v17)],
    products: [
        .library(
            name: "DesignSystem",
            targets: ["DesignSystem"]
        ),
        .library(
            name: "Networking",
            targets: ["Networking"]
        ),
        .library(
            name: "TMDBClient",
            targets: ["TMDBClient"]
        )
    ],
    targets: [
        .target(name: "DesignSystem"),
        .target(name: "Networking"),
        .target(
            name: "TMDBClient",
            dependencies: ["Networking"]
        ),
        .testTarget(
            name: "NetworkingTests",
            dependencies: ["Networking"]
        ),
        .testTarget(
            name: "TMDBClientTests",
            dependencies: ["TMDBClient", "Networking"]
        )
    ]
)
