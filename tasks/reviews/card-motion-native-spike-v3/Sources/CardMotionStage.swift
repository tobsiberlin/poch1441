import SwiftUI

enum CardStageLayer {
    static let table = 0.0
    static let projectedShadows = 10.0
    static let restingCards = 20.0
    static let flyingCards = 30.0
    static let chrome = 40.0
}

private struct AbsolutePolygon: Shape {
    let points: [MotionVector]

    func path(in _: CGRect) -> Path {
        guard let first = points.first else { return Path() }
        var path = Path()
        path.move(to: CGPoint(x: first.x, y: first.y))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: point.x, y: point.y))
        }
        path.closeSubpath()
        return path
    }
}

struct CardMotionStage: View {
    let snapshot: StageSnapshot
    let layout: CardMotionLayout
    var showDiagnostics = true

    var body: some View {
        ZStack {
            table
                .zIndex(CardStageLayer.table)

            ForEach(snapshot.flights) { flight in
                shadow(for: flight)
            }
            .zIndex(CardStageLayer.projectedShadows)

            restingCards
                .zIndex(CardStageLayer.restingCards)

            ForEach(snapshot.flights) { flight in
                flyingCard(flight)
            }
            .zIndex(CardStageLayer.flyingCards)

            if showDiagnostics {
                diagnostics
                    .zIndex(CardStageLayer.chrome)
            }
        }
        .frame(width: layout.viewport.width, height: layout.viewport.height)
        .clipped()
        .accessibilityIdentifier("card-motion-v3-stage")
    }

    private var table: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.105, green: 0.102, blue: 0.091),
                    Color(red: 0.032, green: 0.038, blue: 0.035),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Canvas { context, size in
                var generator = GrainGenerator(seed: 0x1441)
                for _ in 0..<180 {
                    let point = CGPoint(
                        x: generator.next() * size.width,
                        y: generator.next() * size.height
                    )
                    context.fill(
                        Path(ellipseIn: CGRect(x: point.x, y: point.y, width: 0.8, height: 0.8)),
                        with: .color(.white.opacity(0.026))
                    )
                }
            }
            RadialGradient(
                colors: [.white.opacity(0.07), .clear],
                center: UnitPoint(x: 0.23, y: 0.18),
                startRadius: 2,
                endRadius: max(layout.viewport.width, layout.viewport.height) * 0.72
            )
        }
    }

    private var restingCards: some View {
        ZStack {
            sourceDeck
            handCards
            tableCards
            playTarget
        }
    }

    private var sourceDeck: some View {
        ZStack {
            ForEach(0..<min(snapshot.deckLayerCount, 4), id: \.self) { index in
                W2CardBack(size: cardCGSize)
                    .offset(x: Double(index) * -1.45, y: Double(index) * 1.85)
            }
        }
        .rotationEffect(.degrees(layout.deckYaw))
        .position(x: layout.deckCenter.x, y: layout.deckCenter.y)
        .accessibilityIdentifier("deck-static-layers-\(snapshot.deckLayerCount)")
    }

    private var handCards: some View {
        ZStack {
            ForEach(0..<snapshot.handCardCount, id: \.self) { index in
                let centered = Double(index) - Double(max(0, snapshot.handCardCount - 1)) / 2
                W2CardBack(size: cardCGSize)
                    .rotationEffect(.degrees(layout.handYaw + centered * 4.2), anchor: .bottom)
                    .position(
                        x: layout.handCenter.x + centered * layout.cardSize.width * 0.13,
                        y: layout.handCenter.y + abs(centered) * 1.8
                    )
            }
        }
    }

    private var tableCards: some View {
        ZStack {
            ForEach(0..<snapshot.tableCardCount, id: \.self) { index in
                V10PublicCardFace(size: cardCGSize)
                    .rotationEffect(.degrees(layout.playYaw + Double(index) * 1.8))
                    .position(
                        x: layout.playCenter.x + Double(index) * 2.2,
                        y: layout.playCenter.y + Double(index) * 1.5
                    )
            }
        }
    }

    private var playTarget: some View {
        RoundedRectangle(cornerRadius: layout.cardSize.width * 0.15)
            .stroke(.white.opacity(0.09), style: StrokeStyle(lineWidth: 0.7, dash: [3, 5]))
            .frame(width: layout.cardSize.width, height: layout.cardSize.height)
            .rotationEffect(.degrees(layout.playYaw))
            .position(x: layout.playCenter.x, y: layout.playCenter.y)
    }

    private func shadow(for flight: CardFlightSnapshot) -> some View {
        let projection = ProjectedShadow.project(pose: flight.pose, cardSize: layout.cardSize)
        return AbsolutePolygon(points: projection.points)
            .fill(.black.opacity(projection.opacity))
            .blur(radius: projection.blurRadius)
            .accessibilityIdentifier("projected-card-shadow-\(flight.id)")
    }

    private func flyingCard(_ flight: CardFlightSnapshot) -> some View {
        Group {
            switch flight.surface {
            case .back:
                W2CardBack(size: cardCGSize)
            case .face:
                V10PublicCardFace(size: cardCGSize)
            }
        }
        .rotationEffect(.degrees(flight.pose.yawDegrees))
        .rotation3DEffect(
            .degrees(flight.pose.pitchDegrees),
            axis: (
                x: flight.pose.pitchAxis.x,
                y: flight.pose.pitchAxis.y,
                z: 0
            ),
            perspective: 0.67
        )
        .position(x: flight.pose.center.x, y: flight.pose.center.y)
        .accessibilityIdentifier("flying-card-\(flight.id)")
    }

    private var diagnostics: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("NATIVE CARD MOTION · V3")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(1.1)
                Spacer()
                Text("LIVE CONTROLLER")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            Spacer()
            HStack {
                Text("DECK \(snapshot.deckLayerCount)")
                Spacer()
                Text("FLIGHT \(snapshot.flights.count) · MAX \(snapshot.maximumConcurrentFlights)")
                Spacer()
                Text("CONTACT \(snapshot.contacts.count)")
            }
            .font(.system(size: 9, weight: .medium, design: .monospaced))
        }
        .padding(16)
        .foregroundStyle(.white.opacity(0.63))
        .allowsHitTesting(false)
    }

    private var cardCGSize: CGSize {
        CGSize(width: layout.cardSize.width, height: layout.cardSize.height)
    }
}

private struct GrainGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) / Double(UInt64.max >> 11)
    }
}
