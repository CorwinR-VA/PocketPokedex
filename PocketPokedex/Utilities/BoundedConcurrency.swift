import Foundation

nonisolated func withBoundedTaskGroup<Element: Sendable, Result: Sendable>(
    over elements: [Element],
    maxConcurrent: Int = 6,
    operation: @Sendable @escaping (Element) async -> Result
) async -> [Result] {
    guard !elements.isEmpty else { return [] }

    let limit = max(1, min(maxConcurrent, elements.count))
    return await withTaskGroup(of: (Int, Result).self) { group in
        var results = [Result?](repeating: nil, count: elements.count)
        var nextIndex = 0

        while nextIndex < limit {
            let index = nextIndex
            group.addTask { (index, await operation(elements[index])) }
            nextIndex += 1
        }

        while let (index, result) = await group.next() {
            results[index] = result

            guard !Task.isCancelled, nextIndex < elements.count else { continue }
            let index = nextIndex
            group.addTask { (index, await operation(elements[index])) }
            nextIndex += 1
        }

        return results.compactMap { $0 }
    }
}
