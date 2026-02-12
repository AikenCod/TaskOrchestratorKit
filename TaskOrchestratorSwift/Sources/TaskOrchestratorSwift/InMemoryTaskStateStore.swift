import Foundation

public actor SWInMemoryTaskStateStore: SWTaskStateStore {
    private var completed: Set<String> = []

    public init() {}

    public func isCompleted(_ taskID: String) async -> Bool {
        completed.contains(taskID)
    }

    public func markCompleted(_ taskID: String) async {
        completed.insert(taskID)
    }

    public func resetAll() async {
        completed.removeAll()
    }
}
