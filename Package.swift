// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "SwizzleStorage",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "SwizzleStorage",
            targets: ["SwizzleStorage"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SwizzleStorage",
            dependencies: [ ]),
        .testTarget(
            name: "SwizzleStorageTests",
            dependencies: ["SwizzleStorage"]),
    ]
)
