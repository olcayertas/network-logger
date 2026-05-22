// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NetworkLogger",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "NetworkLogger", targets: ["NetworkLogger"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-perception", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "NetworkLogger",
            dependencies: [
                .product(name: "Perception", package: "swift-perception"),
            ]
        ),
        .testTarget(
            name: "NetworkLoggerTests",
            dependencies: ["NetworkLogger"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
