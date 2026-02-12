import Foundation
import TaskOrchestratorSwift

private final class TOESwiftLogStore: @unchecked Sendable {
    private var lines: [String] = []
    private let lock = NSLock()

    func append(_ line: String) {
        lock.lock()
        lines.append(line)
        lock.unlock()
    }

    func joined() -> String {
        lock.lock()
        defer { lock.unlock() }
        return lines.joined(separator: "\n")
    }
}

private final class TOESwiftLogObserver: SWOrchestratorObserver {
    private let name: String
    private let append: @Sendable (String) -> Void

    init(name: String, append: @escaping @Sendable (String) -> Void) {
        self.name = name
        self.append = append
    }

    func didStartRun(_ runID: UUID) {
        append("[\(name)] run start: \(runID.uuidString)")
    }

    func willStartTask(_ taskID: String, runID: UUID) {
        append("[\(name)] -> \(taskID)")
    }

    func didSkipTask(_ taskID: String, runID: UUID, reason: String) {
        append("[\(name)] skip \(taskID) (\(reason))")
    }

    func didFinishTask(_ taskID: String, runID: UUID, success: Bool, durationMs: Double, error: Error?) {
        append("[\(name)] <- \(taskID) success=\(success) cost=\(String(format: "%.2f", durationMs))ms error=\(error.map { String(describing: $0) } ?? "none")")
    }

    func didFinishRun(_ runID: UUID, success: Bool) {
        append("[\(name)] run finish: \(runID.uuidString) success=\(success)")
    }
}

@objc(TOESwiftDemoBridge)
public final class TOESwiftDemoBridge: NSObject {
    @objc(runScenario:completion:)
    public static func runScenario(_ scenario: NSString, completion: @escaping (NSString) -> Void) {
        Task {
            let text = await executeScenario(scenario as String)
            await MainActor.run {
                completion(text as NSString)
            }
        }
    }

    private static func executeScenario(_ scenario: String) async -> String {
        let config = SWOrchestratorConfiguration(
            maxConcurrentTasks: 3,
            strictDependencyCheck: true,
            waveTimeoutSeconds: 20,
            taskTimeoutSeconds: 20
        )
        let orchestrator = SWTaskOrchestrator(configuration: config)
        let store = TOESwiftLogStore()
        let append: @Sendable (String) -> Void = { line in
            store.append(line)
        }

        if scenario == "cycle" {
            let observer = TOESwiftLogObserver(name: "swift-cycle", append: append)
            await orchestrator.setObserver(observer)
            for task in cycleTasks() {
                await orchestrator.register(task)
            }
            let result = await orchestrator.run(initialContext: [:])
            store.append(resultText(result))
            return store.joined()
        }

        let observer = TOESwiftLogObserver(name: "swift-normal", append: append)
        await orchestrator.setObserver(observer)
        for task in normalTasks() {
            await orchestrator.register(task)
        }
        let result = await orchestrator.run(initialContext: [:])
        store.append(resultText(result))
        return store.joined()
    }

    private static func normalTasks() -> [SWTaskDefinition] {
        [
            SWTaskDefinition(id: "01_env_prepare", priority: 100) { context in
                context.set("prod", for: "env")
                context.set("https://api.example.com", for: "baseURL")
            },
            SWTaskDefinition(id: "02_fetch_remote_config", priority: 80, dependencies: ["01_env_prepare"], lane: .concurrent) { context in
                try await Task.sleep(nanoseconds: 900_000_000)
                context.set(true, for: "featureA")
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
                struct ProbeError: Error, CustomStringConvertible { var description: String { "optional probe failed (mock)" } }
                throw ProbeError()
            },
            SWTaskDefinition(id: "06_route_main", priority: 40, dependencies: ["03_login", "04_warm_cache"], lane: .mainActor) { context in
                guard (context.value(for: "token", as: String.self) != nil), context.value(for: "cacheWarm", as: Bool.self) == true else {
                    struct RouteError: Error, CustomStringConvertible { var description: String { "route prerequisites missing" } }
                    throw RouteError()
                }
                context.set("home", for: "initialRoute")
            },
            SWTaskDefinition(id: "07_boot_analytics", priority: 30, dependencies: ["06_route_main"]) { context in
                context.set("done", for: "analyticsBoot")
            }
        ]
    }

    private static func cycleTasks() -> [SWTaskDefinition] {
        [
            SWTaskDefinition(id: "cycle_A", dependencies: ["cycle_C"]) { _ in },
            SWTaskDefinition(id: "cycle_B", dependencies: ["cycle_A"], lane: .concurrent) { _ in },
            SWTaskDefinition(id: "cycle_C", dependencies: ["cycle_B"]) { _ in }
        ]
    }

    private static func resultText(_ result: SWOrchestratorRunResult) -> String {
        let route = result.contextSnapshot["initialRoute"] as? String ?? "none"
        let token = result.contextSnapshot["token"] as? String ?? "none"
        return "success: \(result.success)\nfailedTaskID: \(result.failedTaskID ?? "none")\nordered: \(result.orderedTaskIDs.joined(separator: " -> "))\nskipped: \(result.skippedTaskIDs.joined(separator: ", "))\nerrors: \(result.errorsByTaskID)\ncontext(initialRoute/token): \(route) / \(token)"
    }
}
