// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "WindowEngine",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "WindowEngine", targets: ["WindowEngine"])
    ],
    targets: [
        .target(name: "WindowEngine"),
        .testTarget(name: "WindowEngineTests", dependencies: ["WindowEngine"]),
    ]
)
