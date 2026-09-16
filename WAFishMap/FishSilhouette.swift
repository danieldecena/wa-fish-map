import SwiftUI

/// Body plans, not species: every finfish in the guide draws as one of these.
/// Shapes are hand-drawn in a unit box, head to the right like `fish.fill`, so
/// a salmon and a halibut read differently at a glance. Recognisable outline,
/// not a field-guide illustration.
enum FishForm: CaseIterable, Sendable {
    case salmon, trout, bass, rockfish, panfish, perch, flatfish, lingcod, tuna, catfish

    /// Height over width of the drawn box.
    var aspect: CGFloat {
        switch self {
        case .salmon: 0.38
        case .trout: 0.38
        case .bass: 0.46
        case .rockfish: 0.52
        case .panfish: 0.62
        case .perch: 0.32
        case .flatfish: 0.52
        case .lingcod: 0.28
        case .tuna: 0.42
        case .catfish: 0.34
        }
    }
}

struct FishSilhouette: Shape {
    let form: FishForm

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * w, y: rect.minY + y * h) }
        func poly(_ points: [(CGFloat, CGFloat)]) -> Path {
            var path = Path()
            path.addLines(points.map { p($0.0, $0.1) })
            path.closeSubpath()
            return path
        }
        /// A swept fin: convex leading edge from `front` up to `tip`, then a
        /// straighter trailing edge back down to `rear`.
        func fin(_ front: (CGFloat, CGFloat), _ tip: (CGFloat, CGFloat), _ rear: (CGFloat, CGFloat)) -> Path {
            var f = Path()
            f.move(to: p(front.0, front.1))
            f.addQuadCurve(to: p(tip.0, tip.1), control: p(front.0, tip.1))
            f.addQuadCurve(to: p(rear.0, rear.1),
                           control: p(tip.0 + (rear.0 - tip.0) * 0.2, tip.1 + (rear.1 - tip.1) * 0.6))
            f.closeSubpath()
            return f
        }
        func eye(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat = 0.028) -> Path {
            Path(ellipseIn: CGRect(x: rect.minX + x * w - r * w, y: rect.minY + y * h - r * w,
                                   width: 2 * r * w, height: 2 * r * w))
        }
        /// A thin cut through the silhouette, so a fin or gill lying over the
        /// body still shows its edge.
        func cut(_ build: (inout Path) -> Void) -> Path {
            var line = Path()
            build(&line)
            return line.strokedPath(StrokeStyle(lineWidth: max(1, 0.018 * w), lineCap: .round))
        }
        func forkedTail(_ x: CGFloat, top: CGFloat, bottom: CGFloat, notch: CGFloat) -> Path {
            var t = Path()
            t.move(to: p(x, top))
            t.addQuadCurve(to: p(0.01, 0.10), control: p(x - 0.08, top - 0.08))
            t.addQuadCurve(to: p(notch, 0.5), control: p(notch - 0.02, 0.32))
            t.addQuadCurve(to: p(0.01, 0.90), control: p(notch - 0.02, 0.68))
            t.addQuadCurve(to: p(x, bottom), control: p(x - 0.08, bottom + 0.08))
            t.closeSubpath()
            return t
        }

        var parts: [Path] = []
        var holes: [Path] = []

        switch form {
        case .salmon, .trout:
            var body = Path()
            body.move(to: p(0.98, 0.54))
            body.addCurve(to: p(0.60, 0.18), control1: p(0.90, 0.26), control2: p(0.76, 0.18))
            body.addCurve(to: p(0.17, 0.40), control1: p(0.40, 0.18), control2: p(0.26, 0.34))
            body.addLine(to: p(0.17, 0.60))
            body.addCurve(to: p(0.62, 0.82), control1: p(0.28, 0.68), control2: p(0.42, 0.82))
            body.addCurve(to: p(0.98, 0.54), control1: p(0.82, 0.82), control2: p(0.94, 0.66))
            body.closeSubpath()
            parts.append(body)
            if form == .salmon {
                parts.append(forkedTail(0.20, top: 0.40, bottom: 0.60, notch: 0.10))
            } else {
                // Trout: squarer tail, spotted flank reads as texture at this size.
                parts.append(poly([(0.20, 0.40), (0.02, 0.18), (0.05, 0.50), (0.02, 0.82), (0.20, 0.60)]))
                for (x, y) in [(0.50, 0.36), (0.40, 0.32), (0.32, 0.40), (0.58, 0.30), (0.45, 0.46)] {
                    holes.append(eye(x, y, 0.010))
                }
            }
            parts.append(fin((0.64, 0.19), (0.50, 0.02), (0.48, 0.21)))
            parts.append(fin((0.33, 0.33), (0.25, 0.26), (0.24, 0.38)))          // adipose
            parts.append(fin((0.40, 0.76), (0.28, 0.90), (0.28, 0.68)))          // anal
            parts.append(fin((0.57, 0.81), (0.47, 0.96), (0.46, 0.80)))          // pelvic
            holes.append(eye(0.87, 0.44))
            holes.append(cut { $0.move(to: p(0.78, 0.30)); $0.addQuadCurve(to: p(0.78, 0.72), control: p(0.72, 0.50)) })

        case .bass, .rockfish:
            let deep: CGFloat = form == .rockfish ? 0.04 : 0
            var body = Path()
            body.move(to: p(0.98, 0.40))
            body.addCurve(to: p(0.68, 0.20 - deep), control1: p(0.92, 0.26), control2: p(0.80, 0.20 - deep))
            body.addCurve(to: p(0.18, 0.40), control1: p(0.45, 0.20 - deep), control2: p(0.28, 0.32))
            body.addLine(to: p(0.18, 0.60))
            body.addCurve(to: p(0.60, 0.84 + deep), control1: p(0.30, 0.70), control2: p(0.44, 0.84 + deep))
            body.addCurve(to: p(0.95, 0.60), control1: p(0.80, 0.84 + deep), control2: p(0.92, 0.72))
            body.addLine(to: p(0.84, 0.50))                                      // big mouth
            body.closeSubpath()
            parts.append(body)
            if form == .bass {
                parts.append(poly([(0.21, 0.40), (0.02, 0.16), (0.07, 0.50), (0.02, 0.84), (0.21, 0.60)]))
                parts.append(poly([(0.70, 0.22), (0.67, 0.05), (0.63, 0.13), (0.59, 0.03), (0.55, 0.14),
                                   (0.51, 0.06), (0.48, 0.22)]))
                parts.append(fin((0.47, 0.22), (0.34, 0.06), (0.24, 0.36)))
            } else {
                // Rockfish: one long, tall run of spines and a square tail.
                parts.append(poly([(0.21, 0.40), (0.02, 0.22), (0.02, 0.78), (0.21, 0.60)]))
                parts.append(poly([(0.72, 0.18), (0.70, 0.00), (0.66, 0.12), (0.62, 0.00), (0.58, 0.12),
                                   (0.54, 0.01), (0.50, 0.13), (0.46, 0.03), (0.42, 0.14), (0.34, 0.06),
                                   (0.26, 0.14), (0.24, 0.36)]))
                holes.append(cut { $0.move(to: p(0.90, 0.30)); $0.addLine(to: p(0.94, 0.24)) })
            }
            parts.append(fin((0.42, 0.78), (0.28, 0.94), (0.25, 0.66)))
            parts.append(fin((0.66, 0.82), (0.54, 0.99), (0.53, 0.84)))
            holes.append(eye(0.84, 0.36, 0.032))
            holes.append(cut { $0.move(to: p(0.74, 0.28)); $0.addQuadCurve(to: p(0.74, 0.74), control: p(0.66, 0.52)) })

        case .panfish:
            var body = Path()
            body.move(to: p(0.97, 0.46))
            body.addCurve(to: p(0.60, 0.12), control1: p(0.90, 0.28), control2: p(0.76, 0.12))
            body.addCurve(to: p(0.22, 0.42), control1: p(0.42, 0.12), control2: p(0.28, 0.30))
            body.addLine(to: p(0.22, 0.58))
            body.addCurve(to: p(0.58, 0.88), control1: p(0.28, 0.72), control2: p(0.42, 0.88))
            body.addCurve(to: p(0.97, 0.46), control1: p(0.78, 0.88), control2: p(0.94, 0.66))
            body.closeSubpath()
            parts.append(body)
            parts.append(forkedTail(0.24, top: 0.42, bottom: 0.58, notch: 0.10))
            parts.append(poly([(0.66, 0.15), (0.61, 0.01), (0.57, 0.10), (0.52, 0.00), (0.48, 0.10),
                               (0.44, 0.03), (0.42, 0.12)]))
            parts.append(fin((0.43, 0.12), (0.28, 0.04), (0.24, 0.38)))
            parts.append(fin((0.54, 0.86), (0.30, 1.00), (0.25, 0.66)))
            parts.append(fin((0.70, 0.84), (0.60, 0.99), (0.58, 0.87)))          // pelvic
            holes.append(eye(0.84, 0.40, 0.034))
            holes.append(cut { $0.move(to: p(0.74, 0.24)); $0.addQuadCurve(to: p(0.74, 0.76), control: p(0.66, 0.50)) })

        case .perch:
            var body = Path()
            body.move(to: p(0.99, 0.50))
            body.addCurve(to: p(0.62, 0.22), control1: p(0.90, 0.30), control2: p(0.76, 0.22))
            body.addCurve(to: p(0.16, 0.42), control1: p(0.40, 0.22), control2: p(0.26, 0.36))
            body.addLine(to: p(0.16, 0.58))
            body.addCurve(to: p(0.58, 0.78), control1: p(0.26, 0.66), control2: p(0.42, 0.78))
            body.addCurve(to: p(0.99, 0.50), control1: p(0.80, 0.78), control2: p(0.94, 0.62))
            body.closeSubpath()
            parts.append(body)
            parts.append(forkedTail(0.19, top: 0.42, bottom: 0.58, notch: 0.08))
            // Two separate dorsals — the perch-family tell.
            parts.append(poly([(0.66, 0.24), (0.63, 0.04), (0.59, 0.11), (0.55, 0.02), (0.51, 0.11),
                               (0.47, 0.05), (0.44, 0.23)]))
            parts.append(fin((0.41, 0.23), (0.30, 0.05), (0.23, 0.36)))
            parts.append(fin((0.38, 0.74), (0.26, 0.92), (0.23, 0.64)))
            parts.append(fin((0.64, 0.77), (0.54, 0.94), (0.53, 0.78)))
            holes.append(eye(0.87, 0.42, 0.030))
            holes.append(cut { $0.move(to: p(0.78, 0.30)); $0.addQuadCurve(to: p(0.78, 0.70), control: p(0.72, 0.50)) })

        case .flatfish:
            var body = Path()
            body.move(to: p(0.98, 0.48))
            body.addCurve(to: p(0.56, 0.06), control1: p(0.92, 0.22), control2: p(0.74, 0.06))
            body.addCurve(to: p(0.18, 0.42), control1: p(0.38, 0.06), control2: p(0.24, 0.26))
            body.addLine(to: p(0.18, 0.58))
            body.addCurve(to: p(0.56, 0.94), control1: p(0.24, 0.74), control2: p(0.38, 0.94))
            body.addCurve(to: p(0.96, 0.58), control1: p(0.74, 0.94), control2: p(0.90, 0.80))
            body.closeSubpath()
            parts.append(body)
            // Crescent tail, and both eyes on the upper side.
            var tail = Path()
            tail.move(to: p(0.20, 0.42))
            tail.addQuadCurve(to: p(0.01, 0.12), control: p(0.10, 0.20))
            tail.addQuadCurve(to: p(0.01, 0.88), control: p(0.14, 0.50))
            tail.addQuadCurve(to: p(0.20, 0.58), control: p(0.10, 0.80))
            tail.closeSubpath()
            parts.append(tail)
            holes.append(eye(0.86, 0.34, 0.026))
            holes.append(eye(0.80, 0.26, 0.026))
            // Fin fringe: the dorsal and anal fins run the body's whole edge.
            holes.append(cut { $0.move(to: p(0.84, 0.20)); $0.addCurve(to: p(0.24, 0.40), control1: p(0.66, 0.10), control2: p(0.36, 0.14)) })
            holes.append(cut { $0.move(to: p(0.84, 0.80)); $0.addCurve(to: p(0.24, 0.60), control1: p(0.66, 0.90), control2: p(0.36, 0.86)) })

        case .lingcod:
            var body = Path()
            body.move(to: p(0.99, 0.42))
            body.addCurve(to: p(0.72, 0.20), control1: p(0.92, 0.24), control2: p(0.82, 0.20))
            body.addCurve(to: p(0.14, 0.40), control1: p(0.40, 0.22), control2: p(0.22, 0.34))
            body.addLine(to: p(0.14, 0.60))
            body.addCurve(to: p(0.62, 0.80), control1: p(0.24, 0.68), control2: p(0.42, 0.80))
            body.addCurve(to: p(0.97, 0.62), control1: p(0.82, 0.80), control2: p(0.92, 0.72))
            body.addLine(to: p(0.85, 0.52))                                      // gaping jaw
            body.closeSubpath()
            parts.append(body)
            // Broad rounded fan tail.
            var tail = Path()
            tail.move(to: p(0.17, 0.42))
            tail.addQuadCurve(to: p(0.03, 0.14), control: p(0.10, 0.24))
            tail.addQuadCurve(to: p(0.03, 0.86), control: p(-0.03, 0.50))
            tail.addQuadCurve(to: p(0.17, 0.58), control: p(0.10, 0.76))
            tail.closeSubpath()
            parts.append(tail)
            parts.append(poly([(0.74, 0.22), (0.71, 0.03), (0.67, 0.12), (0.63, 0.02), (0.59, 0.12),
                               (0.55, 0.05), (0.53, 0.20)]))
            // One long soft dorsal and anal, running almost to the tail.
            var soft = Path()
            soft.move(to: p(0.52, 0.21))
            soft.addCurve(to: p(0.16, 0.38), control1: p(0.48, 0.02), control2: p(0.20, 0.06))
            soft.closeSubpath()
            parts.append(soft)
            var anal = Path()
            anal.move(to: p(0.54, 0.79))
            anal.addCurve(to: p(0.16, 0.62), control1: p(0.48, 0.98), control2: p(0.20, 0.94))
            anal.closeSubpath()
            parts.append(anal)
            holes.append(cut { $0.move(to: p(0.72, 0.56)); $0.addQuadCurve(to: p(0.60, 0.72), control: p(0.62, 0.56)) })
            holes.append(eye(0.87, 0.33, 0.030))
            holes.append(cut { $0.move(to: p(0.76, 0.28)); $0.addQuadCurve(to: p(0.76, 0.66), control: p(0.70, 0.46)) })

        case .tuna:
            var body = Path()
            body.move(to: p(0.99, 0.52))
            body.addCurve(to: p(0.62, 0.18), control1: p(0.90, 0.28), control2: p(0.78, 0.18))
            body.addCurve(to: p(0.19, 0.47), control1: p(0.42, 0.18), control2: p(0.27, 0.40))
            body.addLine(to: p(0.19, 0.53))
            body.addCurve(to: p(0.62, 0.84), control1: p(0.27, 0.62), control2: p(0.42, 0.84))
            body.addCurve(to: p(0.99, 0.52), control1: p(0.80, 0.84), control2: p(0.94, 0.66))
            body.closeSubpath()
            parts.append(body)
            // Tall lunate tail.
            var tail = Path()
            tail.move(to: p(0.21, 0.46))
            tail.addQuadCurve(to: p(0.02, 0.00), control: p(0.12, 0.18))
            tail.addQuadCurve(to: p(0.11, 0.50), control: p(0.10, 0.30))
            tail.addQuadCurve(to: p(0.02, 1.00), control: p(0.10, 0.70))
            tail.addQuadCurve(to: p(0.21, 0.54), control: p(0.12, 0.82))
            tail.closeSubpath()
            parts.append(tail)
            parts.append(fin((0.67, 0.19), (0.56, 0.02), (0.52, 0.20)))
            parts.append(fin((0.47, 0.20), (0.39, 0.05), (0.37, 0.25)))
            parts.append(fin((0.47, 0.80), (0.39, 0.95), (0.37, 0.75)))
            for x in stride(from: CGFloat(0.35), to: 0.22, by: -0.04) {         // finlets
                let dy = (0.35 - x) * 0.9
                parts.append(poly([(x, 0.27 + dy), (x - 0.02, 0.21 + dy), (x - 0.03, 0.30 + dy)]))
                parts.append(poly([(x, 0.73 - dy), (x - 0.02, 0.79 - dy), (x - 0.03, 0.70 - dy)]))
            }
            // Albacore's signature: a pectoral fin reaching past the second dorsal.
            holes.append(cut {
                $0.move(to: p(0.76, 0.50))
                $0.addQuadCurve(to: p(0.30, 0.52), control: p(0.52, 0.40))
                $0.addQuadCurve(to: p(0.76, 0.58), control: p(0.52, 0.60))
            })
            holes.append(eye(0.88, 0.44, 0.028))

        case .catfish:
            var body = Path()
            body.move(to: p(0.90, 0.54))
            body.addCurve(to: p(0.64, 0.24), control1: p(0.86, 0.36), control2: p(0.76, 0.24))
            body.addCurve(to: p(0.16, 0.42), control1: p(0.42, 0.24), control2: p(0.26, 0.36))
            body.addLine(to: p(0.16, 0.58))
            body.addCurve(to: p(0.60, 0.80), control1: p(0.26, 0.68), control2: p(0.42, 0.80))
            body.addCurve(to: p(0.90, 0.62), control1: p(0.78, 0.80), control2: p(0.88, 0.72))
            body.closeSubpath()
            parts.append(body)
            parts.append(forkedTail(0.19, top: 0.42, bottom: 0.58, notch: 0.09))
            parts.append(fin((0.65, 0.25), (0.56, 0.03), (0.52, 0.25)))
            parts.append(fin((0.32, 0.34), (0.24, 0.27), (0.22, 0.40)))          // adipose
            var anal = Path()
            anal.move(to: p(0.48, 0.79))
            anal.addCurve(to: p(0.20, 0.64), control1: p(0.42, 0.94), control2: p(0.24, 0.88))
            anal.closeSubpath()
            parts.append(anal)
            // Barbels: the catfish tell.
            var whiskers = Path()
            whiskers.move(to: p(0.89, 0.54)); whiskers.addQuadCurve(to: p(1.00, 0.34), control: p(0.97, 0.50))
            whiskers.move(to: p(0.89, 0.60)); whiskers.addQuadCurve(to: p(1.00, 0.84), control: p(0.98, 0.64))
            whiskers.move(to: p(0.86, 0.64)); whiskers.addQuadCurve(to: p(0.93, 0.98), control: p(0.90, 0.84))
            parts.append(whiskers.strokedPath(StrokeStyle(lineWidth: max(1, 0.016 * w), lineCap: .round)))
            holes.append(eye(0.80, 0.40, 0.022))
        }

        var shape = parts.dropFirst().reduce(parts[0]) { $0.union($1) }
        for hole in holes { shape = shape.subtracting(hole) }
        return shape
    }
}
