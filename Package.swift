// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "PushPlatformSDK",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "PushPlatformExtension",
            targets: ["PushPlatformExtension"]
        ),
        .library(
            name: "PushPlatformSDK",
            targets: ["PushPlatformSDK"]
        )
    ],
    dependencies: [
        // Zero external dependencies (pure Swift + Foundation)
    ],
    targets: [
        .target(
            name: "PushPlatformExtension",
            dependencies: [],
            path: "Sources/PushPlatformExtension"
        ),
        .target(
            name: "PushPlatformSDK",
            dependencies: ["PushPlatformExtension"],
            path: "Sources/PushPlatformSDK"
        ),
        .testTarget(
            name: "PushPlatformSDKTests",
            dependencies: ["PushPlatformSDK", "PushPlatformExtension"],
            path: "Tests/PushPlatformSDKTests"
        )
    ]
)
