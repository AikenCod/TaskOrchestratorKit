// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TaskOrchestratorSwift",
    platforms: [
        .iOS(.v13),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "TaskOrchestratorSwift",
            targets: ["TaskOrchestratorSwift"]
        ),
        .executable(
            name: "DemoRunner",
            targets: ["DemoRunner"]
        )
    ],
    targets: [
        .target(
            name: "TaskOrchestratorSwift"
        ),
        .executableTarget(
            name: "DemoRunner",
            dependencies: ["TaskOrchestratorSwift"],
            swiftSettings: [
                .define("DEMO_RUNNER")
            ]
        )
    ]
)
