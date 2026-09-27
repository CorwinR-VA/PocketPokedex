import Foundation

actor ResourceMemo<Key: Hashable & Sendable, Value: Sendable> {
    private var storage: [Key: Value] = [:]
    private var inFlight: [Key: Task<Value, any Error>] = [:]

    func value(for key: Key, load: @Sendable @escaping () async throws -> Value) async throws -> Value {
        if let cached = storage[key] { return cached }
        if let existing = inFlight[key] { return try await existing.value }

        let task = Task { try await load() }
        inFlight[key] = task

        defer { inFlight[key] = nil }
        let value = try await task.value
        storage[key] = value
        return value
    }
}
