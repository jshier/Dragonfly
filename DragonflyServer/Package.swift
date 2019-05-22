// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DragonflyServer",
    dependencies: [
         .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
         .package(path: "../DragonflyCore")
    ],
    targets: [
        .target(
            name: "DragonflyServer",
            dependencies: ["NIO", "DragonflyCore"]),
        .testTarget(
            name: "DragonflyServerTests",
            dependencies: ["DragonflyServer"]),
    ]
)
