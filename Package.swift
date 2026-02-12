// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TaskOrchestratorKit",
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
            name: "TaskOrchestratorSwift",
            path: "TaskOrchestratorSwift/Sources/TaskOrchestratorSwift"
        ),
        .executableTarget(
            name: "DemoRunner",
            dependencies: ["TaskOrchestratorSwift"],
            path: "TaskOrchestratorSwift/Sources/DemoRunner",
            swiftSettings: [
                .define("DEMO_RUNNER")
            ]
        )
    ]
)
