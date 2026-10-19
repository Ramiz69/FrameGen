// swift-tools-version: 6.2

import PackageDescription

// Matches the app's "approachable concurrency" so nonisolated async code behaves the same in
// FrameGen.app, the framegen command-line tool and the package tests.
let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "FrameGenKit",
    platforms: [
        .macOS("27.0"),
    ],
    products: [
        .library(name: "FrameGenKit", targets: ["FrameGenKit"]),
        .library(name: "FrameGenCLI", targets: ["FrameGenCLI"]),
        .executable(name: "framegen-dev", targets: ["framegen-dev"]),
    ],
    targets: [
        .target(
            name: "FrameGenKit",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "FrameGenCLI",
            dependencies: ["FrameGenKit"],
            swiftSettings: swiftSettings
        ),
        // `swift run framegen-dev …` during development; releases ship the Xcode-built tool inside FrameGen.app.
        .executableTarget(
            name: "framegen-dev",
            dependencies: ["FrameGenCLI"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "FrameGenKitTests",
            dependencies: ["FrameGenKit"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "FrameGenCLITests",
            dependencies: ["FrameGenCLI", "FrameGenKit"],
            swiftSettings: swiftSettings
        ),
    ]
)
