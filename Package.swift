// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// Tuist 4+ uses Package.swift to resolve external dependencies.
// There are no external dependencies in this case, but the #if TUIST
// block is kept for future third-party package configuration.

#if TUIST
    import ProjectDescription

    let packageSettings = PackageSettings(
        baseSettings: .settings(
            base: [
                "SWIFT_VERSION": "6.0",
                "SWIFT_STRICT_CONCURRENCY": "complete",
            ]
        ),
        targetSettings: [:]
    )
#endif

let package = Package(
    name: "SwiftMockServer",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(
            name: "SwiftMockServer",
            targets: ["SwiftMockServer"]
        ),
    ],
    targets: [
        .target(
            name: "SwiftMockServer",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "SwiftMockServerTests",
            dependencies: ["SwiftMockServer"]
        ),
    ]
)
