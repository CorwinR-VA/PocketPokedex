import SwiftUI

nonisolated enum PokedexMotif: Sendable {
    case pokeball
    case sprout
    case droplet
    case bolt
    case star
    case crescent
    case gem
    case wave
    case leaf
    case snowflake
    case sun
    case flame
    case blossom

    @MainActor
    var artwork: ImageResource? {
        switch self {
        case .pokeball: .motifPokeball
        case .snowflake: .motifSnowflake
        case .flame: .motifFlame
        case .blossom: .motifBlossom
        case .sprout, .droplet, .bolt, .star, .crescent, .gem, .wave, .leaf, .sun: nil
        }
    }

    struct Drawing {
        var strokes: [Path] = []
    }

    func drawing() -> Drawing {
        switch self {
        case .sprout: sprout
        case .droplet: droplet
        case .bolt: bolt
        case .star: star
        case .crescent: crescent
        case .gem: gem
        case .wave: wave
        case .leaf: leaf
        case .sun: sun
        case .pokeball, .snowflake, .flame, .blossom: Drawing()
        }
    }

    private static func point(_ degrees: Double, _ radius: Double = 1) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(x: cos(radians) * radius, y: sin(radians) * radius)
    }

    private static func polygon(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let start = points.first else { return path }
        path.move(to: start)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    private static func circle(_ centre: CGPoint, _ radius: Double) -> Path {
        Path(ellipseIn: CGRect(
            x: centre.x - radius,
            y: centre.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
    }

    private static func line(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }

    private static func curve(from start: CGPoint, through steps: [(CGPoint, CGPoint)], closed: Bool = true) -> Path {
        var path = Path()
        path.move(to: start)
        for (control, end) in steps {
            path.addQuadCurve(to: end, control: control)
        }
        if closed { path.closeSubpath() }
        return path
    }

    private var sprout: Drawing {
        var stem = Path()
        stem.move(to: CGPoint(x: 0, y: 1))
        stem.addQuadCurve(to: CGPoint(x: 0, y: -0.15), control: CGPoint(x: -0.12, y: 0.4))

        let left = Self.curve(
            from: CGPoint(x: -0.05, y: 0.2),
            through: [
                (CGPoint(x: -0.5, y: 0.35), CGPoint(x: -0.82, y: -0.3)),
                (CGPoint(x: -0.42, y: -0.32), CGPoint(x: -0.05, y: 0.2))
            ]
        )
        let right = Self.curve(
            from: CGPoint(x: 0.05, y: 0.2),
            through: [
                (CGPoint(x: 0.5, y: 0.35), CGPoint(x: 0.82, y: -0.3)),
                (CGPoint(x: 0.42, y: -0.32), CGPoint(x: 0.05, y: 0.2))
            ]
        )

        return Drawing(strokes: [stem, left, right])
    }

    private var droplet: Drawing {
        let body = Self.curve(
            from: CGPoint(x: 0, y: -1),
            through: [
                (CGPoint(x: -0.52, y: -0.5), CGPoint(x: -0.72, y: 0.12)),
                (CGPoint(x: -0.72, y: 0.62), CGPoint(x: 0, y: 0.84)),
                (CGPoint(x: 0.72, y: 0.62), CGPoint(x: 0.72, y: 0.12)),
                (CGPoint(x: 0.52, y: -0.5), CGPoint(x: 0, y: -1))
            ]
        )
        return Drawing(strokes: [body])
    }

    private var bolt: Drawing {
        Drawing(strokes: [
            Self.polygon([
                CGPoint(x: 0.25, y: -1),
                CGPoint(x: -0.6, y: 0.12),
                CGPoint(x: -0.02, y: 0.12),
                CGPoint(x: -0.28, y: 1),
                CGPoint(x: 0.6, y: -0.12),
                CGPoint(x: 0.02, y: -0.12)
            ])
        ])
    }

    private var star: Drawing {
        let points = (0..<10).map { index in
            Self.point(-90 + Double(index) * 36, index.isMultiple(of: 2) ? 1 : 0.44)
        }
        return Drawing(strokes: [Self.polygon(points)])
    }

    private var crescent: Drawing {
        var moon = Path()
        moon.addArc(center: .zero, radius: 1, startAngle: .degrees(74), endAngle: .degrees(286), clockwise: false)
        moon.addArc(
            center: CGPoint(x: 0.55, y: 0),
            radius: 1,
            startAngle: .degrees(254),
            endAngle: .degrees(106),
            clockwise: true
        )
        moon.closeSubpath()
        return Drawing(strokes: [moon])
    }

    private var gem: Drawing {
        let outline = Self.polygon([
            CGPoint(x: -0.5, y: -0.85),
            CGPoint(x: 0.5, y: -0.85),
            CGPoint(x: 1, y: -0.15),
            CGPoint(x: 0, y: 1),
            CGPoint(x: -1, y: -0.15)
        ])

        var facets = Path()
        facets.move(to: CGPoint(x: -1, y: -0.15))
        facets.addLine(to: CGPoint(x: 1, y: -0.15))
        for x in [-0.5, 0.5] {
            facets.move(to: CGPoint(x: x, y: -0.85))
            facets.addLine(to: CGPoint(x: x * 0.7, y: -0.15))
        }
        for x in [-0.35, 0.35] {
            facets.move(to: CGPoint(x: x, y: -0.15))
            facets.addLine(to: CGPoint(x: 0, y: 1))
        }

        return Drawing(strokes: [outline, facets])
    }

    private var wave: Drawing {
        let crests = (0..<3).map { index -> Path in
            let y = -0.5 + Double(index) * 0.5
            return Self.curve(
                from: CGPoint(x: -1, y: y),
                through: [
                    (CGPoint(x: -0.5, y: y - 0.38), CGPoint(x: 0, y: y)),
                    (CGPoint(x: 0.5, y: y + 0.38), CGPoint(x: 1, y: y))
                ],
                closed: false
            )
        }
        return Drawing(strokes: crests)
    }

    private var leaf: Drawing {
        let tip = CGPoint(x: -0.72, y: -0.72)
        let base = CGPoint(x: 0.42, y: 0.42)

        let blade = Self.curve(
            from: tip,
            through: [
                (CGPoint(x: -0.72, y: 0.42), base),
                (CGPoint(x: 0.42, y: -0.72), tip)
            ]
        )

        var stem = Path()
        stem.move(to: base)
        stem.addQuadCurve(to: CGPoint(x: 0.8, y: 0.9), control: CGPoint(x: 0.6, y: 0.62))

        var vein = Path()
        vein.move(to: CGPoint(x: 0.3, y: 0.3))
        vein.addQuadCurve(to: CGPoint(x: -0.56, y: -0.56), control: CGPoint(x: -0.32, y: 0.06))

        return Drawing(strokes: [blade, stem, vein])
    }

    private var sun: Drawing {
        var strokes: [Path] = [Self.circle(.zero, 0.58)]

        for ray in 0..<8 {
            let angle = -90 + Double(ray) * 45
            strokes.append(Self.line(from: Self.point(angle, 0.74), to: Self.point(angle, 1)))
        }

        return Drawing(strokes: strokes)
    }

}
