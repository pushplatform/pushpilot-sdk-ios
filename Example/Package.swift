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
        .package(path: "..")
    ],
    targets: [
        .executableTarget(
            name: "PushPlatformExample",
            dependencies: [
                .product(name: "PushPlatformSDK", package: "push-platform-sdk-ios")
            ],
            path: "PushPlatformExample"
        )
    ]
)
