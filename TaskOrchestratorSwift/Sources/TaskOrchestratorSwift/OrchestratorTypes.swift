import Foundation

public enum SWExecutionLane: Sendable {
    case serial
    case mainActor
    case concurrent
}

public struct SWTaskContext: Sendable {
    fileprivate var storage: [String: any Sendable]

    public init(_ initialValues: [String: any Sendable] = [:]) {
        self.storage = initialValues
    }

    public func value<T: Sendable>(for key: String, as type: T.Type = T.self) -> T? {
        storage[key] as? T
    }

    public func string(for key: String) -> String? {
        value(for: key, as: String.self)
    }

    public func int(for key: String) -> Int? {
        value(for: key, as: Int.self)
    }

    public func bool(for key: String) -> Bool? {
        value(for: key, as: Bool.self)
    }

    public func double(for key: String) -> Double? {
        value(for: key, as: Double.self)
    }

    public subscript<T: Sendable>(key: String) -> T? {
        get { value(for: key, as: T.self) }
        set {
            if let newValue {
                storage[key] = newValue
            } else {
                storage.removeValue(forKey: key)
            }
        }
    }

    public mutating func set<T: Sendable>(_ value: T, for key: String) {
        storage[key] = value
    }

    public mutating func set<T: Sendable>(_ value: T?, for key: String) {
        if let value {
            storage[key] = value
        } else {
            storage.removeValue(forKey: key)
        }
    }

    public mutating func removeValue(for key: String) {
        storage.removeValue(forKey: key)
    }

    public var snapshot: [String: any Sendable] {
        storage
    }
}

public struct SWTaskDefinition: Sendable {
    public typealias Operation = @Sendable (inout SWTaskContext) async throws -> Void

    public let id: String
    public let priority: Int
    public let dependencies: [String]
    public let lane: SWExecutionLane
    public let continueOnFailure: Bool
    private let operation: Operation

    public init(
        id: String,
        priority: Int = 0,
        dependencies: [String] = [],
        lane: SWExecutionLane = .serial,
        continueOnFailure: Bool = false,
        operation: @escaping Operation
    ) {
        self.id = id
        self.priority = priority
        self.dependencies = dependencies
        self.lane = lane
        self.continueOnFailure = continueOnFailure
        self.operation = operation
    }

    func run(from base: [String: any Sendable]) async throws -> [String: any Sendable] {
        var context = SWTaskContext(base)
        try await operation(&context)
        return context.snapshot
    }
}

public struct SWOrchestratorConfiguration: Sendable {
    public var maxConcurrentTasks: Int
    public var strictDependencyCheck: Bool
    public var waveTimeoutSeconds: TimeInterval
    public var taskTimeoutSeconds: TimeInterval

    public init(
        maxConcurrentTasks: Int = 4,
        strictDependencyCheck: Bool = true,
        waveTimeoutSeconds: TimeInterval = 30,
        taskTimeoutSeconds: TimeInterval = 30
    ) {
        self.maxConcurrentTasks = min(max(1, maxConcurrentTasks), 16)
        self.strictDependencyCheck = strictDependencyCheck
        self.waveTimeoutSeconds = waveTimeoutSeconds
        self.taskTimeoutSeconds = taskTimeoutSeconds
    }
}

public struct SWOrchestratorRunResult: Sendable {
    public let runID: UUID
    public var success: Bool
    public var orderedTaskIDs: [String]
    public var skippedTaskIDs: [String]
    public var failedTaskID: String?
    public var errorsByTaskID: [String: String]
    public var contextSnapshot: [String: any Sendable]

    public init(runID: UUID = UUID()) {
        self.runID = runID
        self.success = true
        self.orderedTaskIDs = []
        self.skippedTaskIDs = []
        self.failedTaskID = nil
        self.errorsByTaskID = [:]
        self.contextSnapshot = [:]
    }
}

public enum SWOrchestratorError: Error, CustomStringConvertible {
    case duplicateOrEmptyTaskIdentifier
    case missingDependency(taskID: String, dependencyID: String)
    case dependencyCycle(path: String)
    case taskTimeout(taskID: String, seconds: Double)
    case backgroundWaveTimeout(seconds: Double)

    public var description: String {
        switch self {
        case .duplicateOrEmptyTaskIdentifier:
            return "Duplicate or empty task identifier found."
        case let .missingDependency(taskID, dependencyID):
            return "Task \(taskID) depends on missing task \(dependencyID)."
        case let .dependencyCycle(path):
            return "Dependency cycle detected: \(path)."
        case let .taskTimeout(taskID, seconds):
            return "Task \(taskID) timed out after \(seconds)s."
        case let .backgroundWaveTimeout(seconds):
            return "Background wave timed out after \(seconds)s."
        }
    }
}

public protocol SWTaskStateStore: Sendable {
    func isCompleted(_ taskID: String) async -> Bool
    func markCompleted(_ taskID: String) async
    func resetAll() async
}

public protocol SWOrchestratorObserver: AnyObject {
    func didStartRun(_ runID: UUID)
    func willStartTask(_ taskID: String, runID: UUID)
    func didSkipTask(_ taskID: String, runID: UUID, reason: String)
    func didFinishTask(_ taskID: String, runID: UUID, success: Bool, durationMs: Double, error: Error?)
    func didFinishRun(_ runID: UUID, success: Bool)
}

public extension SWOrchestratorObserver {
    func didStartRun(_ runID: UUID) {}
    func willStartTask(_ taskID: String, runID: UUID) {}
    func didSkipTask(_ taskID: String, runID: UUID, reason: String) {}
    func didFinishTask(_ taskID: String, runID: UUID, success: Bool, durationMs: Double, error: Error?) {}
    func didFinishRun(_ runID: UUID, success: Bool) {}
}
