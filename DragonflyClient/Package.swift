// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DragonflyClient",
    platforms: [
        .macOS(.v10_14),
        .iOS(.v12),
        .tvOS(.v12)
    ],
    products: [
        .library(
            name: "DragonflyClient",
            targets: ["DragonflyClient"]),
    ],
    dependencies: [
        .package(path: "../DragonflyCore")
    ],
    targets: [
        .target(
            name: "DragonflyClient",
            dependencies: ["DragonflyCore"]),
        .testTarget(
            name: "DragonflyClientTests",
            dependencies: ["DragonflyClient"]),
    ]
)
