// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MultipeerKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "MultipeerKit",
            targets: ["MultipeerKit"]),
        .library(
            name: "MultipeerKitDynamic",
            type: .dynamic,
            targets: ["MultipeerKit"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MultipeerKit",
            dependencies: []),
        .testTarget(
            name: "MultipeerKitTests",
            dependencies: ["MultipeerKit"]),
    ]
)
