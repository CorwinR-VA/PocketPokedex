import SwiftUI

struct StatBar: View {
    let value: Int

    @State private var trackWidth: CGFloat = 0

    private var fraction: Double {
        min(max(Double(value) / StatKind.maximumBaseValue, 0), 1)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(PokedexTheme.mutedSurface)
            Capsule()
                .fill(PokedexTheme.statFill)
                .frame(width: max(trackWidth * fraction, fraction > 0 ? 4 : 0))
        }
        .frame(height: 8)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            trackWidth = width
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 12) {
        StatBar(value: 45)
        StatBar(value: 255)
        StatBar(value: 0)
    }
    .padding()
    .background(PokedexTheme.canvas)
}
