import SwiftUI

struct PokedexWatermark: View {
    let motif: PokedexMotif
    let color: Color

    private let tile: CGFloat = 112
    private let radius: CGFloat = 21
    private let lineWidth: CGFloat = 1.5

    var body: some View {
        Canvas { context, size in
            let drawing = motif.drawing()
            var artwork: GraphicsContext.ResolvedImage?
            if let resource = motif.artwork {
                artwork = context.resolve(Image(resource).renderingMode(.template))
                artwork?.shading = .color(color)
            }

            var row = 0
            var y = -tile

            while y < size.height + tile {
                var x = row.isMultiple(of: 2) ? -tile : -tile / 2

                while x < size.width + tile {
                    let centre = CGPoint(x: x + tile / 2, y: y + tile / 2)
                    if let artwork {
                        let side = radius * 2
                        context.draw(artwork, in: CGRect(
                            x: centre.x - radius,
                            y: centre.y - radius,
                            width: side,
                            height: side
                        ))
                    } else {
                        draw(drawing, in: context, centre: centre)
                    }
                    x += tile
                }

                y += tile
                row += 1
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(_ drawing: PokedexMotif.Drawing, in context: GraphicsContext, centre: CGPoint) {
        let transform = CGAffineTransform(translationX: centre.x, y: centre.y)
            .scaledBy(x: radius, y: radius)

        for path in drawing.strokes {
            context.stroke(
                path.applying(transform),
                with: .color(color),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

#Preview {
    ZStack {
        PokedexTheme.canvas
        PokedexWatermark(motif: .pokeball, color: PokemonGame.red.watermark.opacity(0.16))
    }
    .ignoresSafeArea()
}
