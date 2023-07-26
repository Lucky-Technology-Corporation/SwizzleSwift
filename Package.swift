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
    dependencies: [
        .package(url: "https://github.com/mongodb/mongo-swift-driver", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "SwizzleStorage",
            dependencies: [
                .product(name: "MongoSwift", package: "mongo-swift-driver"),
            ]),
        .testTarget(
            name: "SwizzleStorageTests",
            dependencies: ["SwizzleStorage"]),
    ]
)
