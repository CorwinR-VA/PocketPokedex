import SwiftUI

enum PokedexTheme {

    static let canvas = Color(.canvas)
    static let surface = Color(.surface)
    static let border = Color(.border)
    static let textPrimary = Color(.textPrimary)
    static let textSecondary = Color(.textSecondary)
    static let accent = Color(.accent)
    static let mutedSurface = Color(.mutedSurface)
    static let statFill = Color(.statFill)

    static let shadow = Color(.shadow)
    static let onAccent = Color(.onAccent)

    static let iconBlue = Color(.iconBlue)
    static let iconGreen = Color(.iconGreen)
    static let iconYellow = Color(.iconYellow)
    static let iconPurple = Color(.iconPurple)

    enum Metrics {
        static let pageInset: CGFloat = 16
        static let contentMaxWidth: CGFloat = 1368

        static let cardCornerRadius: CGFloat = 8
        static let cardPadding: CGFloat = 13
        static let cardArtworkWidth: CGFloat = 120
        static let cardArtworkHeight: CGFloat = 144
        static let cardMinWidth: CGFloat = 220
        static let cardMaxWidth: CGFloat = .infinity

        static let chipHeight: CGFloat = 30
        static let chipHorizontalPadding: CGFloat = 13
        static let chipSpacing: CGFloat = 8

        static let badgeHeight: CGFloat = 18
        static let badgeHorizontalPadding: CGFloat = 11
        static let badgeSpacing: CGFloat = 4

        static let controlHeight: CGFloat = 36
        static let controlCornerRadius: CGFloat = 6
        static let tabThumbCornerRadius: CGFloat = 4

        static let minimumTapTarget: CGFloat = 44

        static let cardActionSize: CGFloat = 28
        static let cardActionHitMargin: CGFloat = (minimumTapTarget - cardActionSize) / 2

        static let themeControlWidth: CGFloat = 123
        static let themeControlIconWidth: CGFloat = 16

        static let floatingButtonSize: CGFloat = 56
        static let floatingButtonClearance: CGFloat = 88
        static let floatingButtonInset: CGFloat = 16

        static let detailWidth: CGFloat = 600
        static let detailInset: CGFloat = 25
        static let sectionCornerRadius: CGFloat = 8
    }
}
