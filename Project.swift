import ProjectDescription

// MARK: - Settings

/// Base build settings shared across all targets
private let baseSettings: SettingsDictionary = [
    "SWIFT_VERSION": "6.0",
    "SWIFT_STRICT_CONCURRENCY": "complete",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
]

/// Settings for the framework target
private let frameworkSettings: Settings = .settings(
    base: baseSettings.merging([
        "SWIFT_EMIT_LOC_STRINGS": "NO",
    ]),
    configurations: [
        .debug(name: "Debug", settings: [
            "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
            "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "$(inherited) DEBUG",
        ]),
        .release(name: "Release", settings: [
            "SWIFT_OPTIMIZATION_LEVEL": "-Owholemodule",
        ]),
    ]
)

/// Settings for the test target
private let testSettings: Settings = .settings(
    base: baseSettings.merging([
        "SWIFT_EMIT_LOC_STRINGS": "NO",
    ]),
    configurations: [
        .debug(name: "Debug", settings: [:]),
        .release(name: "Release", settings: [:]),
    ]
)

/// Settings for the example app target
private let appSettings: Settings = .settings(
    base: baseSettings.merging([
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
        "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
        "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad":
            "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone":
            "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
    ]),
    configurations: [
        .debug(name: "Debug", settings: [
            "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
            "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "$(inherited) DEBUG",
        ]),
        .release(name: "Release", settings: [
            "SWIFT_OPTIMIZATION_LEVEL": "-Owholemodule",
        ]),
    ]
)

// MARK: - Project

let project = Project(
    name: "SwiftMockServer",
    organizationName: "SwiftMockServer",
    settings: .settings(
        base: baseSettings,
        configurations: [
            .debug(name: "Debug", settings: [:]),
            .release(name: "Release", settings: [:]),
        ]
    ),
    targets: [

        // ──────────────────────────────────────────────
        // MARK: 📦 SwiftMockServer (Framework)
        // ──────────────────────────────────────────────

        .target(
            name: "SwiftMockServer",
            destinations: [.iPhone, .iPad, .mac, .appleTv, .appleWatch, .appleVision],
            product: .framework,
            bundleId: "com.swiftmockserver.SwiftMockServer",
            deploymentTargets: .multiplatform(
                iOS: "16.0",
                macOS: "13.0",
                watchOS: "9.0",
                tvOS: "16.0",
                visionOS: "1.0"
            ),
            infoPlist: .default,
            sources: ["Sources/SwiftMockServer/**"],
            settings: frameworkSettings
        ),

        // ──────────────────────────────────────────────
        // MARK: 🧪 SwiftMockServerTests
        // ──────────────────────────────────────────────

        .target(
            name: "SwiftMockServerTests",
            destinations: [.iPhone, .iPad, .mac, .appleTv],
            product: .unitTests,
            bundleId: "com.swiftmockserver.SwiftMockServerTests",
            deploymentTargets: .multiplatform(
                iOS: "16.0",
                macOS: "13.0",
                tvOS: "16.0"
            ),
            infoPlist: .default,
            sources: ["Tests/SwiftMockServerTests/**"],
            dependencies: [
                .target(name: "SwiftMockServer"),
            ],
            settings: testSettings
        ),

        // ──────────────────────────────────────────────
        // MARK: 📱 SwiftMockServerExample (App)
        // ──────────────────────────────────────────────

        .target(
            name: "SwiftMockServerExample",
            destinations: [.iPhone, .iPad],
            product: .app,
            bundleId: "com.swiftmockserver.Example",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": [:],
            ]),
            sources: ["Sources/SwiftMockServerExample/**"],
            dependencies: [
                .target(name: "SwiftMockServer"),
            ],
            settings: appSettings
        ),
    ],
    schemes: [

        // Scheme for framework development
        .scheme(
            name: "SwiftMockServer",
            shared: true,
            buildAction: .buildAction(targets: ["SwiftMockServer"]),
            testAction: .targets(
                [.testableTarget(target: "SwiftMockServerTests")],
                configuration: "Debug",
                options: .options(coverage: true, codeCoverageTargets: ["SwiftMockServer"])
            )
        ),

        // Scheme for the example app
        .scheme(
            name: "SwiftMockServerExample",
            shared: true,
            buildAction: .buildAction(targets: ["SwiftMockServerExample"]),
            testAction: .targets(
                [.testableTarget(target: "SwiftMockServerTests")],
                configuration: "Debug",
                options: .options(coverage: true, codeCoverageTargets: ["SwiftMockServer"])
            ),
            runAction: .runAction(
                configuration: "Debug",
                executable: "SwiftMockServerExample"
            )
        ),
    ],
    additionalFiles: [
        "README.md",
        "LICENSE",
    ]
)
