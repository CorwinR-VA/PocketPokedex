import Foundation

nonisolated extension Int {
    var pokedexNumber: String {
        "#" + formatted(.number.grouping(.never).precision(.integerLength(3...)))
    }
}
