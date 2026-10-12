// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "PushPlatformSDK",
    platforms: [
        .iOS(.v13)
    ],
    products: [
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
            name: "PushPlatformSDK",
            dependencies: [],
            path: "Sources/PushPlatformSDK"
        ),
        .testTarget(
            name: "PushPlatformSDKTests",
            dependencies: ["PushPlatformSDK"],
            path: "Tests/PushPlatformSDKTests"
        )
    ]
)
