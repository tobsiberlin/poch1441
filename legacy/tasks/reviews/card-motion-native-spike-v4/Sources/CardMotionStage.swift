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
        .accessibilityIdentifier("card-motion-v4-stage")
    }

    private var table: some View {
        ZStack {
            Image("TrackBWorld")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: layout.viewport.width, height: layout.viewport.height)
                .clipped()
            Color.black.opacity(0.055)
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
            ForEach(snapshot.handCards) { card in
                restingCard(card)
            }
        }
    }

    private var tableCards: some View {
        ZStack {
            ForEach(snapshot.tableCards) { card in
                restingCard(card)
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

    private func restingCard(_ card: RestingCard) -> some View {
        Group {
            switch card.surface {
            case .back: W2CardBack(size: cardCGSize)
            case .face: V10PublicCardFace(size: cardCGSize)
            }
        }
        .rotationEffect(.degrees(card.yawDegrees))
        .position(x: card.center.x, y: card.center.y)
    }

    private var diagnostics: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("POCH") + Text(" 1441").foregroundColor(Color(red: 0.82, green: 0.66, blue: 0.35))
                    Spacer()
                    Text("Runde 4 · 36")
                        .foregroundStyle(Color(red: 0.92, green: 0.75, blue: 0.40))
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                HStack(spacing: 22) {
                    Text("Melden")
                    Text("Pochen")
                    Text("Ausspielen")
                        .foregroundStyle(.white)
                }
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.54))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.black.opacity(0.70))
            Spacer()
            VStack(spacing: 6) {
                HStack {
                    Text("AUSSPIELEN")
                    Spacer()
                    Text("DECK \(snapshot.deckLayerCount) · FLUG \(snapshot.flights.count)/\(snapshot.maximumConcurrentFlights)")
                }
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                Text("Karte auf die Mitte legen")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(.black.opacity(0.76))
        }
        .foregroundStyle(.white.opacity(0.82))
        .allowsHitTesting(false)
    }

    private var cardCGSize: CGSize {
        CGSize(width: layout.cardSize.width, height: layout.cardSize.height)
    }
}
