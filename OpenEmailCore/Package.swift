// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenEmailCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "OpenEmailCore",
            targets: ["OpenEmailCore"]),
    ],
    dependencies: [
        // local dependencies
        .package(path: "../Utils"),
        .package(path: "../OpenEmailModel"),
        .package(path: "../OpenEmailPersistence"),
        .package(path: "../Logging"),
        // remote dependencies
        .package(url: "https://github.com/jedisct1/swift-sodium", branch: "master"),
        .package(url: "https://github.com/hyperoslo/Cache.git", from: "6.0.0"),
    ],
    targets: [
        .target(
            name: "OpenEmailCore",
            dependencies: [
                .product(name: "Sodium", package: "swift-sodium"),
                .product(name: "Cache", package: "cache"),
                .product(name: "Utils", package: "Utils"),
                .product(name: "Logging", package: "Logging"),
                .product(name: "OpenEmailModel", package: "OpenEmailModel"),
                .product(name: "OpenEmailPersistence", package: "OpenEmailPersistence")
            ]),
        .testTarget(
            name: "OpenEmailCoreTests",
            dependencies: ["OpenEmailCore"]),
    ]
)
