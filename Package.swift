// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Swizzle",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "Swizzle",
            targets: ["Swizzle"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Swizzle",
            dependencies: [ ]),
        .testTarget(
            name: "SwizzleTests",
            dependencies: ["Swizzle"]),
    ]
)
