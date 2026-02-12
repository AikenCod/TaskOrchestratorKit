import Foundation

private struct GraphEntry {
    let task: SWTaskDefinition
    let registerIndex: Int
    var indegree: Int
    var dependents: [String]
}

private struct TaskExecutionOutcome {
    let taskID: String
    let recorded: Bool
    let success: Bool
    let skipped: Bool
    let resultingContext: [String: any Sendable]?
    let error: Error?
    let continueOnFailure: Bool
}

private final class ResultGate: @unchecked Sendable {
    private let lock = NSLock()
    private var open = true

    func close() {
        lock.lock()
        open = false
        lock.unlock()
    }

    func isOpen() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return open
    }
}

public actor SWTaskOrchestrator {
    public var configuration: SWOrchestratorConfiguration
    public var stateStore: any SWTaskStateStore
    private weak var observer: (any SWOrchestratorObserver)?

    private var registeredTasks: [SWTaskDefinition] = []

    public init(
        configuration: SWOrchestratorConfiguration = .init(),
        stateStore: any SWTaskStateStore = SWInMemoryTaskStateStore()
    ) {
        self.configuration = configuration
        self.stateStore = stateStore
    }

    public func register(_ task: SWTaskDefinition) {
        guard !task.id.isEmpty else { return }
        registeredTasks.append(task)
    }

    public func clearTasks() {
        registeredTasks.removeAll()
    }

    public func setObserver(_ observer: (any SWOrchestratorObserver)?) {
        self.observer = observer
    }

    public func run(initialContext: [String: any Sendable] = [:]) async -> SWOrchestratorRunResult {
        var result = SWOrchestratorRunResult()
        observer?.didStartRun(result.runID)

        let tasks = registeredTasks
        do {
            var graph = try buildGraph(tasks: tasks)
            var ready = graph.values
                .filter { $0.indegree == 0 }
                .map(\ .task.id)

            var completedCount = 0
            var context = initialContext
            var shouldStop = false

            while !shouldStop, completedCount < graph.count {
                if ready.isEmpty {
                    let cyclePath = findCyclePath(in: graph)
                    let error = SWOrchestratorError.dependencyCycle(path: cyclePath)
                    result.success = false
                    result.failedTaskID = "<cycle>"
                    result.errorsByTaskID["<cycle>"] = error.description
                    break
                }

                ready.sort { lhs, rhs in
                    guard let left = graph[lhs], let right = graph[rhs] else { return lhs < rhs }
                    if left.task.priority != right.task.priority {
                        return left.task.priority > right.task.priority
                    }
                    return left.registerIndex < right.registerIndex
                }

                let waveIDs = ready
                ready.removeAll(keepingCapacity: true)

                let serialAndMain = waveIDs.compactMap { graph[$0]?.task }
                    .filter { $0.lane != .concurrent }
                let concurrent = waveIDs.compactMap { graph[$0]?.task }
                    .filter { $0.lane == .concurrent }

                var succeededInWave: [String] = []

                for task in serialAndMain {
                    let outcome = await execute(task, baseContext: context, runID: result.runID)
                    apply(outcome, to: &result, context: &context)
                    if outcome.success {
                        succeededInWave.append(task.id)
                    } else {
                        shouldStop = !outcome.continueOnFailure
                    }
                    completedCount += 1
                    if shouldStop { break }
                }

                if !shouldStop, !concurrent.isEmpty {
                    do {
                        let outcomes = try await runConcurrentWave(concurrent, baseContext: context, runID: result.runID)
                            .sorted { lhs, rhs in
                                guard let left = graph[lhs.taskID], let right = graph[rhs.taskID] else {
                                    return lhs.taskID < rhs.taskID
                                }
                                if left.task.priority != right.task.priority {
                                    return left.task.priority > right.task.priority
                                }
                                return left.registerIndex < right.registerIndex
                            }

                        for outcome in outcomes {
                            apply(outcome, to: &result, context: &context)
                            if outcome.success {
                                succeededInWave.append(outcome.taskID)
                            } else {
                                shouldStop = shouldStop || !outcome.continueOnFailure
                            }
                            completedCount += 1
                        }
                    } catch {
                        let timeout = SWOrchestratorError.backgroundWaveTimeout(seconds: configuration.waveTimeoutSeconds)
                        result.success = false
                        result.failedTaskID = "<timeout>"
                        result.errorsByTaskID["<timeout>"] = timeout.description
                        shouldStop = true
                    }
                }

                for successID in succeededInWave {
                    guard let dependents = graph[successID]?.dependents else { continue }
                    for dependentID in dependents {
                        guard var depEntry = graph[dependentID] else { continue }
                        depEntry.indegree -= 1
                        graph[dependentID] = depEntry
                        if depEntry.indegree == 0 {
                            ready.append(dependentID)
                        }
                    }
                }
            }

            result.contextSnapshot = context
            observer?.didFinishRun(result.runID, success: result.success)
            return result
        } catch {
            result.success = false
            result.failedTaskID = "<graph>"
            result.errorsByTaskID["<graph>"] = String(describing: error)
            observer?.didFinishRun(result.runID, success: false)
            return result
        }
    }

    private func apply(_ outcome: TaskExecutionOutcome, to result: inout SWOrchestratorRunResult, context: inout [String: any Sendable]) {
        if !outcome.recorded {
            return
        }

        result.orderedTaskIDs.append(outcome.taskID)

        if outcome.skipped {
            result.skippedTaskIDs.append(outcome.taskID)
            return
        }

        if outcome.success {
            if let updated = outcome.resultingContext {
                for (key, value) in updated {
                    context[key] = value
                }
            }
            return
        }

        result.success = false
        if result.failedTaskID == nil {
            result.failedTaskID = outcome.taskID
        }
        if let error = outcome.error {
            result.errorsByTaskID[outcome.taskID] = String(describing: error)
        } else {
            result.errorsByTaskID[outcome.taskID] = "Unknown error"
        }
    }

    private func execute(
        _ task: SWTaskDefinition,
        baseContext: [String: any Sendable],
        runID: UUID,
        gate: ResultGate? = nil
    ) async -> TaskExecutionOutcome {
        if await stateStore.isCompleted(task.id) {
            observer?.didSkipTask(task.id, runID: runID, reason: "idempotent-state-store")
            return TaskExecutionOutcome(
                taskID: task.id,
                recorded: true,
                success: true,
                skipped: true,
                resultingContext: nil,
                error: nil,
                continueOnFailure: task.continueOnFailure
            )
        }

        observer?.willStartTask(task.id, runID: runID)
        let started = CFAbsoluteTimeGetCurrent()

        do {
            let updatedContext = try await runWithTimeout(for: task, baseContext: baseContext)
            if Task.isCancelled || (gate != nil && !(gate?.isOpen() ?? false)) {
                return TaskExecutionOutcome(
                    taskID: task.id,
                    recorded: false,
                    success: false,
                    skipped: false,
                    resultingContext: nil,
                    error: CancellationError(),
                    continueOnFailure: task.continueOnFailure
                )
            }

            await stateStore.markCompleted(task.id)
            let duration = durationMs(from: started)
            observer?.didFinishTask(task.id, runID: runID, success: true, durationMs: duration, error: nil)

            return TaskExecutionOutcome(
                taskID: task.id,
                recorded: true,
                success: true,
                skipped: false,
                resultingContext: updatedContext,
                error: nil,
                continueOnFailure: task.continueOnFailure
            )
        } catch {
            if Task.isCancelled || (gate != nil && !(gate?.isOpen() ?? false)) {
                return TaskExecutionOutcome(
                    taskID: task.id,
                    recorded: false,
                    success: false,
                    skipped: false,
                    resultingContext: nil,
                    error: error,
                    continueOnFailure: task.continueOnFailure
                )
            }

            let duration = durationMs(from: started)
            observer?.didFinishTask(task.id, runID: runID, success: false, durationMs: duration, error: error)

            return TaskExecutionOutcome(
                taskID: task.id,
                recorded: true,
                success: false,
                skipped: false,
                resultingContext: nil,
                error: error,
                continueOnFailure: task.continueOnFailure
            )
        }
    }

    private func runWithTimeout(
        for task: SWTaskDefinition,
        baseContext: [String: any Sendable]
    ) async throws -> [String: any Sendable] {
        let taskTimeoutSeconds = configuration.taskTimeoutSeconds
        return try await withThrowingTaskGroup(of: [String: any Sendable].self) { group in
            group.addTask {
                switch task.lane {
                case .serial, .concurrent:
                    return try await task.run(from: baseContext)
                case .mainActor:
                    return try await MainActorExecutor.run {
                        try await task.run(from: baseContext)
                    }
                }
            }

            group.addTask {
                try await Task.sleep(nanoseconds: nanos(from: taskTimeoutSeconds))
                throw SWOrchestratorError.taskTimeout(taskID: task.id, seconds: taskTimeoutSeconds)
            }

            guard let first = try await group.next() else {
                throw SWOrchestratorError.taskTimeout(taskID: task.id, seconds: configuration.taskTimeoutSeconds)
            }

            group.cancelAll()
            return first
        }
    }

    private func runConcurrentWave(
        _ tasks: [SWTaskDefinition],
        baseContext: [String: any Sendable],
        runID: UUID
    ) async throws -> [TaskExecutionOutcome] {
        let maxConcurrentTasks = configuration.maxConcurrentTasks
        let waveTimeoutSeconds = configuration.waveTimeoutSeconds
        let gate = ResultGate()
        return try await withThrowingTaskGroup(of: [TaskExecutionOutcome].self) { parent in
            parent.addTask {
                var allOutcomes: [TaskExecutionOutcome] = []
                var index = 0
                while index < tasks.count {
                    let end = min(index + maxConcurrentTasks, tasks.count)
                    let batch = Array(tasks[index..<end])
                    let batchOutcomes = await withTaskGroup(of: TaskExecutionOutcome.self) { group in
                        for task in batch {
                            group.addTask {
                                await self.execute(task, baseContext: baseContext, runID: runID, gate: gate)
                            }
                        }

                        var outcomes: [TaskExecutionOutcome] = []
                        for await outcome in group {
                            outcomes.append(outcome)
                        }
                        return outcomes
                    }

                    allOutcomes.append(contentsOf: batchOutcomes)
                    index = end
                }
                return allOutcomes
            }

            parent.addTask {
                try await Task.sleep(nanoseconds: nanos(from: waveTimeoutSeconds))
                gate.close()
                throw SWOrchestratorError.backgroundWaveTimeout(seconds: waveTimeoutSeconds)
            }

            guard let first = try await parent.next() else {
                throw SWOrchestratorError.backgroundWaveTimeout(seconds: configuration.waveTimeoutSeconds)
            }
            parent.cancelAll()
            return first
        }
    }

    private func buildGraph(tasks: [SWTaskDefinition]) throws -> [String: GraphEntry] {
        var map: [String: GraphEntry] = [:]
        map.reserveCapacity(tasks.count)

        for (idx, task) in tasks.enumerated() {
            guard !task.id.isEmpty, map[task.id] == nil else {
                throw SWOrchestratorError.duplicateOrEmptyTaskIdentifier
            }
            map[task.id] = GraphEntry(task: task, registerIndex: idx, indegree: 0, dependents: [])
        }

        for task in tasks {
            for dependency in task.dependencies {
                guard var depEntry = map[dependency] else {
                    if configuration.strictDependencyCheck {
                        throw SWOrchestratorError.missingDependency(taskID: task.id, dependencyID: dependency)
                    }
                    continue
                }

                guard var current = map[task.id] else { continue }
                current.indegree += 1
                map[task.id] = current

                depEntry.dependents.append(task.id)
                map[dependency] = depEntry
            }
        }

        let cycle = findCyclePath(in: map)
        if !cycle.isEmpty {
            throw SWOrchestratorError.dependencyCycle(path: cycle)
        }

        return map
    }

    private func findCyclePath(in graph: [String: GraphEntry]) -> String {
        enum VisitState: Int {
            case unvisited = 0
            case visiting = 1
            case visited = 2
        }

        var state: [String: VisitState] = [:]
        var stack: [String] = []

        func dfs(_ taskID: String) -> String? {
            state[taskID] = .visiting
            stack.append(taskID)

            guard let entry = graph[taskID] else {
                _ = stack.popLast()
                state[taskID] = .visited
                return nil
            }

            for dep in entry.task.dependencies where graph[dep] != nil {
                let depState = state[dep] ?? .unvisited
                if depState == .visiting {
                    if let index = stack.firstIndex(of: dep) {
                        let cycle = Array(stack[index...]) + [dep]
                        return cycle.joined(separator: " -> ")
                    }
                    return "\(taskID) -> \(dep)"
                }

                if depState == .unvisited, let cycle = dfs(dep) {
                    return cycle
                }
            }

            _ = stack.popLast()
            state[taskID] = .visited
            return nil
        }

        for taskID in graph.keys where (state[taskID] ?? .unvisited) == .unvisited {
            if let cycle = dfs(taskID) {
                return cycle
            }
        }

        return ""
    }
}

private enum MainActorExecutor {
    static func run<T: Sendable>(_ operation: @escaping @MainActor () async throws -> T) async throws -> T {
        try await operation()
    }
}

private func nanos(from seconds: TimeInterval) -> UInt64 {
    if seconds <= 0 { return 1 }
    let value = seconds * 1_000_000_000
    if value >= Double(UInt64.max) { return UInt64.max }
    return UInt64(value)
}

private func durationMs(from started: CFAbsoluteTime) -> Double {
    (CFAbsoluteTimeGetCurrent() - started) * 1000
}
