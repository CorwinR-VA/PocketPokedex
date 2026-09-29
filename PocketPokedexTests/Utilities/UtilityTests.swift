import Foundation
import Testing
@testable import PocketPokedex

@Suite("Pokedex numbers")
struct PokedexNumberTests {
    @Test("Pads short dex numbers to three digits")
    func padsShortNumbers() {
        #expect(1.pokedexNumber == "#001")
        #expect(25.pokedexNumber == "#025")
        #expect(99.pokedexNumber == "#099")
    }

    @Test("Leaves three-digit dex numbers alone and grows past them")
    func handlesLongerNumbers() {
        #expect(100.pokedexNumber == "#100")
        #expect(999.pokedexNumber == "#999")
        #expect(1_025.pokedexNumber == "#1025")
    }

    @Test("Never groups digits")
    func neverGroupsDigits() {
        #expect(1_351.pokedexNumber == "#1351")
        #expect(!1_351.pokedexNumber.contains(","))
        #expect(!1_351.pokedexNumber.contains("\u{202F}"))
    }
}

@Suite("Slug display names")
struct SlugDisplayNameTests {
    @Test("Capitalises each hyphen-separated word")
    func capitalisesWords() {
        #expect("bulbasaur".pokemonDisplayName == "Bulbasaur")
        #expect("mr-mime".pokemonDisplayName == "Mr Mime")
        #expect("special-attack".pokemonDisplayName == "Special Attack")
        #expect("medium-slow".pokemonDisplayName == "Medium Slow")
    }

    @Test("Lowercases nothing it was not asked to")
    func preservesRemainingCharacters() {
        #expect("POKéMON".pokemonDisplayName == "POKéMON")
        #expect("ho-oh".pokemonDisplayName == "Ho Oh")
        #expect("type-null".pokemonDisplayName == "Type Null")
    }

    @Test("Returns an empty string for an empty slug")
    func handlesEmptyInput() {
        #expect("".pokemonDisplayName == "")
    }

    @Test("Keeps a single word intact")
    func handlesSingleWord() {
        #expect("hp".pokemonDisplayName == "Hp")
    }
}

@Suite("Measurement formatting")
struct MeasurementFormatTests {
    @Test("Formats a height in metres with at most one decimal place")
    func formatsHeight() {
        #expect(MeasurementFormat.height(0.7) == "\(LocalizedNumber.text(0.7)) m")
        #expect(MeasurementFormat.height(2.0) == "2 m")
        #expect(MeasurementFormat.height(14.5) == "\(LocalizedNumber.text(14.5)) m")
    }

    @Test("Formats a weight in kilograms with at most one decimal place")
    func formatsWeight() {
        #expect(MeasurementFormat.weight(6.9) == "\(LocalizedNumber.text(6.9)) kg")
        #expect(MeasurementFormat.weight(24.0) == "24 kg")
    }

    @Test("Never groups digits, even past a thousand")
    func neverGroupsDigits() {
        // A four-figure weight must not pick up a grouping separator, which the design's
        // measurement strings do not have room for.
        // 2 345.0 kg has four integer digits, so a grouping style would render a separator.
        let heavy = MeasurementFormat.weight(2_345.0)
        #expect(heavy == "2345 kg")

        if let separator = LocalizedNumber.groupingSeparator {
            #expect(!heavy.contains(separator))
        }
    }

    @Test("Appends the unit the design asks for")
    func appendsUnits() {
        #expect(MeasurementFormat.height(1.0).hasSuffix(" m"))
        #expect(MeasurementFormat.weight(1.0).hasSuffix(" kg"))
    }

    @Test("Falls back to the placeholder when the value is unknown")
    func formatsMissingValues() {
        #expect(MeasurementFormat.height(nil) == MeasurementFormat.placeholder)
        #expect(MeasurementFormat.weight(nil) == MeasurementFormat.placeholder)
        #expect(MeasurementFormat.height(nil) == "\u{2014}")
    }

    @Test("Rounds rather than truncating, and drops a trailing zero")
    func roundsValues() {
        #expect(MeasurementFormat.height(0.66) == "\(LocalizedNumber.text(0.7)) m")
        #expect(MeasurementFormat.weight(0.04) == "0 kg")
        #expect(MeasurementFormat.height(2.0) == "2 m")
    }
}

@Suite("Bounded concurrency")
struct BoundedConcurrencyTests {
    @Test("Returns no results for no elements")
    func handlesEmptyInput() async {
        let results: [Int] = await withBoundedTaskGroup(over: [Int]()) { $0 * 2 }
        #expect(results.isEmpty)
    }

    @Test("Visits every element exactly once")
    func visitsEveryElement() async {
        let results = await withBoundedTaskGroup(over: Array(1...50)) { $0 }
        #expect(results.sorted() == Array(1...50))
    }

    @Test("Preserves input order regardless of completion order")
    func preservesOrder() async {
        // Later elements sleep for less time, so completion order is the reverse of input order.
        let results = await withBoundedTaskGroup(over: Array(1...20), maxConcurrent: 20) { value in
            try? await Task.sleep(for: .milliseconds((21 - value) * 5))
            return value
        }
        #expect(results == Array(1...20))
    }

    @Test("Never runs more than the requested number of operations at once")
    func respectsConcurrencyLimit() async {
        let tracker = ConcurrencyTracker()
        _ = await withBoundedTaskGroup(over: Array(1...40), maxConcurrent: 4) { value in
            tracker.enter()
            try? await Task.sleep(for: .milliseconds(5))
            tracker.leave()
            return value
        }
        #expect(tracker.peak <= 4)
        #expect(tracker.completed == 40)
    }

    @Test("Clamps a limit below one so work still happens")
    func clampsInvalidLimit() async {
        let results = await withBoundedTaskGroup(over: [1, 2, 3], maxConcurrent: 0) { $0 }
        #expect(results == [1, 2, 3])
    }

    @Test("Clamps a limit above the element count")
    func clampsOversizedLimit() async {
        let results = await withBoundedTaskGroup(over: [1, 2], maxConcurrent: 1_000) { $0 }
        #expect(results == [1, 2])
    }

    @Test("Stops starting new work once the surrounding task is cancelled")
    func stopsStartingWorkWhenCancelled() async {
        let tracker = ConcurrencyTracker()
        let task = Task {
            await withBoundedTaskGroup(over: Array(1...200), maxConcurrent: 2) { value in
                tracker.enter()
                try? await Task.sleep(for: .milliseconds(40))
                tracker.leave()
                return value
            }
        }

        try? await Task.sleep(for: .milliseconds(60))
        task.cancel()
        _ = await task.value

        #expect(tracker.started < 200)
        #expect(tracker.completed == tracker.started)
    }
}

/// Counts concurrent entries so a test can assert on the peak.
nonisolated private final class ConcurrencyTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var active = 0
    private var peakActive = 0
    private var startedCount = 0
    private var completedCount = 0

    func enter() {
        lock.lock()
        defer { lock.unlock() }
        active += 1
        startedCount += 1
        peakActive = max(peakActive, active)
    }

    func leave() {
        lock.lock()
        defer { lock.unlock() }
        active -= 1
        completedCount += 1
    }

    var peak: Int { locked { $0.peakActive } }
    var started: Int { locked { $0.startedCount } }
    var completed: Int { locked { $0.completedCount } }

    private func locked<T>(_ body: (ConcurrencyTracker) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(self)
    }
}
