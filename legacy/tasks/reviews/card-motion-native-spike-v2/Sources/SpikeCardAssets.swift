import SwiftUI

private extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

/// Frozen W2 geometry from `App/CardBack.swift`, rendered locally so the spike
/// remains independent of the product target. `W2Damage` is a copied production
/// material layer and remains identity-neutral.
struct W2CardBack: View {
    let size: CGSize

    private let facetColors = [
        Color(hex: 0xC5A059),
        Color(hex: 0x8E2A43),
        Color(hex: 0x1A5E4E),
        Color(hex: 0x4A2E65),
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.width * 0.154)
                .fill(Color(hex: 0x14110F))
            deterministicPatina
            Image("W2Damage")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: size.width * 0.154))
            facetLozenge
            if size.width / 52 >= 1.2 {
                monograms
            }
        }
        .frame(width: size.width, height: size.height)
        .overlay {
            RoundedRectangle(cornerRadius: size.width * 0.154)
                .strokeBorder(Color(hex: 0x626268).opacity(0.9), lineWidth: 0.9)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("W2 Kartenrückseite")
    }

    private var deterministicPatina: some View {
        Canvas { context, canvasSize in
            for mark in W2Patina.marks {
                let center = CGPoint(x: canvasSize.width * mark.x, y: canvasSize.height * mark.y)
                let radians = mark.rotationDegrees * .pi / 180
                let halfLength = canvasSize.height * mark.radius * 1.8
                let offset = CGPoint(x: cos(radians) * halfLength, y: sin(radians) * halfLength)
                var path = Path()
                path.move(to: CGPoint(x: center.x - offset.x, y: center.y - offset.y))
                path.addLine(to: CGPoint(x: center.x + offset.x, y: center.y + offset.y))
                context.stroke(
                    path,
                    with: .color(Color(hex: 0x8B7C70).opacity(mark.opacity * 0.62)),
                    style: StrokeStyle(
                        lineWidth: max(0.2, canvasSize.height * mark.radius * 0.22),
                        lineCap: .round
                    )
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: size.width * 0.154))
    }

    private var facetLozenge: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radiusX = canvasSize.width * 0.40
            let radiusY = canvasSize.height * 0.40
            let corners = [
                CGPoint(x: center.x, y: center.y - radiusY),
                CGPoint(x: center.x + radiusX, y: center.y),
                CGPoint(x: center.x, y: center.y + radiusY),
                CGPoint(x: center.x - radiusX, y: center.y),
            ]
            var rim: [CGPoint] = []
            for index in 0..<4 {
                let first = corners[index]
                let second = corners[(index + 1) % 4]
                rim.append(first)
                rim.append(CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2))
            }
            let inner = rim.map {
                CGPoint(
                    x: center.x + ($0.x - center.x) * 0.64,
                    y: center.y + ($0.y - center.y) * 0.64
                )
            }
            for index in 0..<8 {
                let next = (index + 1) % 8
                var outer = Path()
                outer.move(to: rim[index])
                outer.addLines([rim[next], inner[next], inner[index]])
                outer.closeSubpath()
                context.fill(outer, with: .color(facetColors[index % 4]))

                var innerFacet = Path()
                innerFacet.move(to: inner[index])
                innerFacet.addLines([inner[next], center])
                innerFacet.closeSubpath()
                context.fill(innerFacet, with: .color(facetColors[index % 4]))
                context.fill(innerFacet, with: .color(.black.opacity(0.45)))
                context.stroke(outer, with: .color(.white.opacity(0.45)), lineWidth: 0.6)
            }
        }
        .padding(size.width * 0.096)
    }

    private var monograms: some View {
        VStack {
            HStack {
                monogramText
                Spacer()
            }
            Spacer()
            HStack {
                Spacer()
                monogramText.rotationEffect(.degrees(180))
            }
        }
        .padding(size.width * 4 / 52)
    }

    private var monogramText: some View {
        Text(verbatim: "1441")
            .font(.system(size: size.width * 4.4 / 52, weight: .medium, design: .serif))
            .foregroundStyle(Color(hex: 0xE2E8F0).opacity(0.8))
    }
}

private struct W2PatinaMark: Sendable {
    let x: Double
    let y: Double
    let radius: Double
    let opacity: Double
    let rotationDegrees: Double
}

private enum W2Patina {
    static let marks: [W2PatinaMark] = {
        var generator = Generator(seed: 0x57_32_50_41_54_49_4E_41)
        var result: [W2PatinaMark] = []
        result.reserveCapacity(24)
        for _ in 0..<12 {
            let mark = W2PatinaMark(
                x: generator.value(in: 0.055...0.945),
                y: generator.value(in: 0.055...0.945),
                radius: generator.value(in: 0.0035...0.012),
                opacity: generator.value(in: 0.025...0.075),
                rotationDegrees: generator.value(in: 0..<360)
            )
            result.append(mark)
            result.append(W2PatinaMark(
                x: 1 - mark.x,
                y: 1 - mark.y,
                radius: mark.radius,
                opacity: mark.opacity,
                rotationDegrees: (mark.rotationDegrees + 180).truncatingRemainder(dividingBy: 360)
            ))
        }
        return result
    }()

    private struct Generator {
        private static let multiplier: UInt64 = 6_364_136_223_846_793_005
        private static let increment: UInt64 = 1_442_695_040_888_963_407
        private static let mantissaBits = 53
        private static let mantissaDivisor = Double(UInt64(1) << mantissaBits)
        private var state: UInt64

        init(seed: UInt64) {
            state = seed
        }

        mutating func value(in range: ClosedRange<Double>) -> Double {
            range.lowerBound + unitValue() * (range.upperBound - range.lowerBound)
        }

        mutating func value(in range: Range<Double>) -> Double {
            range.lowerBound + unitValue() * (range.upperBound - range.lowerBound)
        }

        private mutating func unitValue() -> Double {
            state = state &* Self.multiplier &+ Self.increment
            return Double(state >> (UInt64.bitWidth - Self.mantissaBits)) / Self.mantissaDivisor
        }
    }
}

struct V10PublicCardFace: View {
    let size: CGSize

    var body: some View {
        Image("V10HeartsAce")
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size.width, height: size.height)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Öffentliche V10 Herz-Ass-Karte")
    }
}

struct SpikeFlipCard: View {
    let size: CGSize
    let revealProgress: Double

    private var angle: Double { min(max(revealProgress, 0), 1) * 180 }

    var body: some View {
        ZStack {
            W2CardBack(size: size)
                .opacity(angle < 90 ? 1 : 0)
            V10PublicCardFace(size: size)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(angle >= 90 ? 1 : 0)
        }
        .rotation3DEffect(
            .degrees(angle),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.72
        )
    }
}
