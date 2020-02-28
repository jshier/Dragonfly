// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DragonflyServer",
    products: [
        .executable(name: "dragonfly", targets: ["dragonfly"]),
    ],
    dependencies: [
         .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
         .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.0.0"),
         .package(url: "https://github.com/apple/swift-argument-parser", from: "0.0.1"),
         .package(path: "../DragonflyCore")
    ],
    targets: [
        .target(
            name: "dragonfly",
            dependencies: ["DragonflyServer", "ArgumentParser"]),
        .target(
            name: "DragonflyServer",
            dependencies: ["NIO", "NIOFoundationCompat", "NIOExtras", "DragonflyCore"]),
        .testTarget(
            name: "DragonflyServerTests",
            dependencies: ["DragonflyServer", "NIOTestUtils"]),
    ]
)
