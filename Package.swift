// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OneShot",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "OneShot",
            targets: ["OneShot"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "1.14.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0")
    ],
    targets: [
        .executableTarget(
            name: "OneShot",
            dependencies: [
                "KeyboardShortcuts",
                .product(name: "Crypto", package: "swift-crypto")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "OneShotTests",
            dependencies: ["OneShot"],
            path: "Tests"
        )
    ]
)