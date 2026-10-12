// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "PushPlatformExample",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .executable(
            name: "PushPlatformExample",
            targets: ["PushPlatformExample"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pushplatform/pushpilot-sdk-ios.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "PushPlatformExample",
            dependencies: [
                .product(name: "PushPlatformSDK", package: "pushpilot-sdk-ios")
            ],
            path: "PushPlatformExample"
        )
    ]
)
