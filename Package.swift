// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NetworkLogger",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "NetworkLogger", targets: ["NetworkLogger"]),
        .library(name: "NetworkLoggerDependencies", targets: ["NetworkLoggerDependencies"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-perception", from: "1.3.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.8.0"),
    ],
    targets: [
        .target(
            name: "NetworkLogger",
            dependencies: [
                .product(name: "Perception", package: "swift-perception"),
                .product(name: "Sharing", package: "swift-sharing"),
            ]
        ),
        .target(
            name: "NetworkLoggerDependencies",
            dependencies: [
                "NetworkLogger",
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "NetworkLoggerTests",
            dependencies: ["NetworkLogger"]
        ),
        .testTarget(
            name: "NetworkLoggerDependenciesTests",
            dependencies: [
                "NetworkLoggerDependencies",
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
