import Foundation

nonisolated enum MeasurementFormat {
    static let placeholder = "—"

    static func height(_ metres: Double?) -> String {
        guard let metres else { return placeholder }
        return "\(number(metres)) m"
    }

    static func weight(_ kilograms: Double?) -> String {
        guard let kilograms else { return placeholder }
        return "\(number(kilograms)) kg"
    }

    /// Grouping is off on purpose. The design's measurement strings are short, and a grouped
    /// value would read as a decimal in a locale whose separators are the other way round
    /// (a 2345 kg weight rendering as "2.345 kg" next to "0,7 m"). The decimal separator still
    /// follows the device locale, which is why the strings are not identical everywhere.
    private static func number(_ value: Double) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(0...1)))
    }
}
