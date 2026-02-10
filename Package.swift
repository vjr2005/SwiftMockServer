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

// Replace PLACEHOLDER with the real checksum after running `make xcframework`.
// The binary target is excluded from resolution until the checksum is set,
// so `swift build` and `swift test` keep working during development.
let binaryChecksum = "7a13e0b67766c4133c6ac3c8907e1c44af6d8821802858c32ad7ba88d2403823"

var products: [Product] = [
    .library(
        name: "SwiftMockServer",
        targets: ["SwiftMockServer"]
    ),
]

var targets: [Target] = [
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

if binaryChecksum != "PLACEHOLDER" {
    products.append(
        .library(
            name: "SwiftMockServerBinary",
            targets: ["SwiftMockServerBinary"]
        )
    )
    targets.append(
        .binaryTarget(
            name: "SwiftMockServerBinary",
            url: "https://github.com/vjr2005/SwiftMockServer/releases/download/1.1.0/SwiftMockServer.xcframework.zip",
            checksum: binaryChecksum
        )
    )
}

let package = Package(
    name: "SwiftMockServer",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: products,
    targets: targets
)
