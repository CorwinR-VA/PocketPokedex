import Foundation

nonisolated enum MeasurementFormat {
    static let placeholder = "—"

    static func height(_ metres: Double?) -> String {
        guard let metres else { return placeholder }
        return "\(metres.formatted(.number.precision(.fractionLength(0...1)))) m"
    }

    static func weight(_ kilograms: Double?) -> String {
        guard let kilograms else { return placeholder }
        return "\(kilograms.formatted(.number.precision(.fractionLength(0...1)))) kg"
    }
}
