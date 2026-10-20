// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FullscreenSpike",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "WindowKit", targets: ["WindowKit"]),
        .executable(name: "fullscreen-spike", targets: ["fullscreen-spike"]),
    ],
    targets: [
        .target(name: "WindowKit"),
        .executableTarget(
            name: "fullscreen-spike",
            dependencies: ["WindowKit"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "WindowKitTests", dependencies: ["WindowKit"]),
    ]
)
