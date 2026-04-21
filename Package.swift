// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "A2UI",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .visionOS(.v1),
    ],
    products: [
        // The library you import in your own Swift apps.
        .library(name: "A2UI", targets: ["A2UI"]),

        // A runnable sample that shows each component rendering with static
        // data. No WebSocket / no server required. Useful to verify the
        // library works in your environment:  `swift run A2UIKitchenSink`.
        .executable(name: "A2UIKitchenSink", targets: ["A2UIKitchenSink"]),
    ],
    targets: [
        .target(
            name: "A2UI",
            path: "Sources/A2UI"
        ),
        .executableTarget(
            name: "A2UIKitchenSink",
            dependencies: ["A2UI"],
            path: "Sources/A2UIKitchenSink"
        ),
        .testTarget(
            name: "A2UITests",
            dependencies: ["A2UI"],
            path: "Tests/A2UITests"
        ),
    ]
)
