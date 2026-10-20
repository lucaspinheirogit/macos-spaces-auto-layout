// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FullscreenSpike",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "fullscreen-spike", targets: ["fullscreen-spike"])
    ],
    dependencies: [
        .package(path: "../Packages/WindowEngine")
    ],
    targets: [
        .target(name: "BenchReport", dependencies: ["WindowEngine"]),
        .executableTarget(
            name: "fullscreen-spike",
            dependencies: ["BenchReport", "WindowEngine"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "BenchReportTests", dependencies: ["BenchReport", "WindowEngine"]),
    ]
)
