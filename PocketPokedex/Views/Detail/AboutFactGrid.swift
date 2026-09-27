import SwiftUI

struct AboutFactGrid<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 16, alignment: .topLeading),
                GridItem(.flexible(), spacing: 16, alignment: .topLeading)
            ],
            alignment: .leading,
            spacing: 16
        ) {
            content
        }
    }
}

#Preview {
    AboutFactGrid {
        AboutFactCell(label: "Height", value: "0.7 m")
        AboutFactCell(label: "Weight", value: "6.9 kg")
    }
    .padding()
    .background(PokedexTheme.canvas)
}
