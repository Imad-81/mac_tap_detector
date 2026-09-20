// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TapDetector",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "tap-detector",
            targets: ["TapDetector"]
        )
    ],
    targets: [
        .executableTarget(
            name: "TapDetector",
            dependencies: [],
            path: "Sources/TapDetector"
        )
    ]
)
