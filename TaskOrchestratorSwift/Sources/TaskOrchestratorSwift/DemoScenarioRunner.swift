import Foundation

public enum SWDemoScenarioRunner {
    public typealias Logger = @Sendable (String) -> Void

    public static func runAll(log: @escaping Logger = { print($0) }) async {
        log("=== Scenario 1: normal flow ===")

        let config = SWOrchestratorConfiguration(
            maxConcurrentTasks: 3,
            strictDependencyCheck: true,
            waveTimeoutSeconds: 20,
            taskTimeoutSeconds: 20
        )

        let orchestrator = SWTaskOrchestrator(configuration: config)
        let normalObserver = LoggingObserver(name: "normal", log: log)
        await orchestrator.setObserver(normalObserver)

        for task in normalTasks() {
            await orchestrator.register(task)
        }

        let first = await orchestrator.run(initialContext: [:])
        printResult(first, log: log)

        log("\n=== Scenario 2: rerun for idempotent skip ===")
        let second = await orchestrator.run(initialContext: [:])
        printResult(second, log: log)

        log("\n=== Scenario 3: cycle dependency ===")
        let cycleOrchestrator = SWTaskOrchestrator(configuration: config)
        let cycleObserver = LoggingObserver(name: "cycle", log: log)
        await cycleOrchestrator.setObserver(cycleObserver)

        for task in cycleTasks() {
            await cycleOrchestrator.register(task)
        }

        let cycle = await cycleOrchestrator.run(initialContext: [:])
        printResult(cycle, log: log)
    }

    public static func normalTasks() -> [SWTaskDefinition] {
        [
            SWTaskDefinition(id: "01_env_prepare", priority: 100) { context in
                context.set("prod", for: "env")
                context.set("https://api.example.com", for: "baseURL")
            },
            SWTaskDefinition(id: "02_fetch_remote_config", priority: 80, dependencies: ["01_env_prepare"], lane: .concurrent) { context in
                try await Task.sleep(nanoseconds: 900_000_000)
                context.set(true, for: "featureA")
                context.set(15, for: "requestTimeout")
            },
            SWTaskDefinition(id: "03_login", priority: 70, dependencies: ["02_fetch_remote_config"], lane: .concurrent) { context in
                try await Task.sleep(nanoseconds: 600_000_000)
                context.set("token_demo_123", for: "token")
            },
            SWTaskDefinition(id: "04_warm_cache", priority: 60, dependencies: ["02_fetch_remote_config"], lane: .concurrent) { context in
                try await Task.sleep(nanoseconds: 1_200_000_000)
                context.set(true, for: "cacheWarm")
            },
            SWTaskDefinition(id: "05_optional_probe", priority: 50, dependencies: ["02_fetch_remote_config"], lane: .concurrent, continueOnFailure: true) { _ in
                try await Task.sleep(nanoseconds: 300_000_000)
                struct ProbeError: Error, CustomStringConvertible {
                    var description: String { "optional probe failed (mock)" }
                }
                throw ProbeError()
            },
            SWTaskDefinition(id: "06_route_main", priority: 40, dependencies: ["03_login", "04_warm_cache"], lane: .mainActor) { context in
                let token: String? = context.value(for: "token")
                let cacheWarm: Bool? = context.value(for: "cacheWarm")
                guard token != nil, cacheWarm == true else {
                    struct RouteError: Error, CustomStringConvertible {
                        var description: String { "route prerequisites missing" }
                    }
                    throw RouteError()
                }
                context.set("home", for: "initialRoute")
            },
            SWTaskDefinition(id: "07_boot_analytics", priority: 30, dependencies: ["06_route_main"]) { context in
                context.set("done", for: "analyticsBoot")
            }
        ]
    }

    public static func cycleTasks() -> [SWTaskDefinition] {
        [
            SWTaskDefinition(id: "cycle_A", dependencies: ["cycle_C"]) { _ in },
            SWTaskDefinition(id: "cycle_B", dependencies: ["cycle_A"], lane: .concurrent) { _ in },
            SWTaskDefinition(id: "cycle_C", dependencies: ["cycle_B"]) { _ in }
        ]
    }

    public static func printResult(_ result: SWOrchestratorRunResult, log: Logger = { print($0) }) {
        log("success: \(result.success)")
        log("failedTaskID: \(result.failedTaskID ?? "none")")
        log("ordered: \(result.orderedTaskIDs.joined(separator: " -> "))")
        log("skipped: \(result.skippedTaskIDs.joined(separator: ", "))")
        log("errors: \(result.errorsByTaskID)")

        let snapshot = result.contextSnapshot
        let route = snapshot["initialRoute"] as? String ?? "none"
        let token = snapshot["token"] as? String ?? "none"
        log("context(initialRoute/token): \(route) / \(token)")
    }
}

private final class LoggingObserver: SWOrchestratorObserver {
    private let name: String
    private let log: SWDemoScenarioRunner.Logger

    init(name: String, log: @escaping SWDemoScenarioRunner.Logger) {
        self.name = name
        self.log = log
    }

    func didStartRun(_ runID: UUID) {
        log("[\(name)] run start: \(runID.uuidString)")
    }

    func willStartTask(_ taskID: String, runID: UUID) {
        log("[\(name)] -> \(taskID)")
    }

    func didSkipTask(_ taskID: String, runID: UUID, reason: String) {
        log("[\(name)] skip \(taskID) (\(reason))")
    }

    func didFinishTask(_ taskID: String, runID: UUID, success: Bool, durationMs: Double, error: Error?) {
        log("[\(name)] <- \(taskID) success=\(success) cost=\(String(format: "%.2f", durationMs))ms error=\(error.map { String(describing: $0) } ?? "none")")
    }

    func didFinishRun(_ runID: UUID, success: Bool) {
        log("[\(name)] run finish: \(runID.uuidString) success=\(success)")
    }
}
