// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DragonflyCore",
    products: [
        .library(
            name: "DragonflyCore",
            targets: ["DragonflyCore"]),
    ],
    targets: [
        .target(
            name: "DragonflyCore",
            dependencies: []),
        .testTarget(
            name: "DragonflyCoreTests",
            dependencies: ["DragonflyCore"]),
    ]
)
