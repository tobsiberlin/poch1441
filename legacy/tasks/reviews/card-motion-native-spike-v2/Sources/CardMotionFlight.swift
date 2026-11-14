import SwiftUI

private struct PerspectiveCardFootprint: Shape {
    func path(in rect: CGRect) -> Path {
        let insetX = rect.width * 0.055
        let insetY = rect.height * 0.07
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + insetX, y: rect.minY + insetY))
        path.addLine(to: CGPoint(x: rect.maxX - insetX * 1.45, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - insetY * 0.25))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct CardMotionFlight: View {
    let sample: CardMotionSample
    let cardSize: CardDimensions

    var body: some View {
        ZStack {
            groundProjection
                .zIndex(0)
                .accessibilityIdentifier("card-motion-ground-projection")

            cardSurface
                .scaleEffect(sample.cardPose.scale)
                .rotationEffect(.degrees(sample.cardPose.rotationDegrees))
                .rotation3DEffect(
                    .degrees(sample.cardTiltDegrees),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.72
                )
                .position(x: sample.cardPose.center.x, y: sample.cardPose.center.y)
                .zIndex(1)
                .accessibilityIdentifier("card-motion-surface")
        }
    }

    private var cardSurface: some View {
        Group {
            switch sample.surface {
            case .back:
                W2CardBack(size: cgSize)
            case let .reveal(progress):
                SpikeFlipCard(size: cgSize, revealProgress: progress)
            case .face:
                V10PublicCardFace(size: cgSize)
            }
        }
    }

    private var groundProjection: some View {
        PerspectiveCardFootprint()
            .fill(.black.opacity(sample.shadowOpacity))
            .frame(
                width: cardSize.width * sample.shadowWidthScale,
                height: cardSize.height * 0.70 * sample.shadowLengthScale
            )
            .blur(radius: sample.shadowBlur)
            .position(
                x: sample.groundPose.center.x,
                y: sample.groundPose.center.y + cardSize.height * 0.035
            )
    }

    private var cgSize: CGSize {
        CGSize(width: cardSize.width, height: cardSize.height)
    }
}

struct CardMotionStage: View {
    let segment: CardMotionSegment
    let progress: Double
    var returnInterruptionProgress = 0.58
    var overlayOpacity = 1.0
    var flightIdentity = 0

    var body: some View {
        GeometryReader { proxy in
            let layout = CardMotionLayout(width: proxy.size.width, height: proxy.size.height)
            if let plan = layout.plan(
                for: segment,
                interruptionProgress: returnInterruptionProgress
            ) {
                let sample = plan.sample(progress: progress)
                ZStack {
                    tableBackground
                    sourceDeck(layout: layout)
                        .zIndex(10)
                    handFan(layout: layout)
                        .zIndex(20)
                    playTargetGuide(layout: layout)
                        .zIndex(21)
                    CardMotionFlight(sample: sample, cardSize: layout.cardSize)
                        .id(flightIdentity)
                        .opacity(overlayOpacity)
                        .zIndex(30)
                    phaseChrome
                        .zIndex(40)
                }
                .clipped()
                .accessibilityIdentifier("card-motion-stage-\(segment.rawValue)")
            }
        }
    }

    private var tableBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.105, green: 0.12, blue: 0.11),
                    Color(red: 0.035, green: 0.045, blue: 0.04),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [.white.opacity(0.075), .clear],
                center: .center,
                startRadius: 8,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
    }

    private func sourceDeck(layout: CardMotionLayout) -> some View {
        ZStack {
            ForEach(1...3, id: \.self) { index in
                W2CardBack(size: cgSize(layout.cardSize))
                    .offset(x: CGFloat(index) * -1.6, y: CGFloat(index) * 2.1)
            }
        }
        .scaleEffect(layout.deckTop.scale)
        .rotationEffect(.degrees(layout.deckTop.rotationDegrees))
        .position(x: layout.deckTop.center.x, y: layout.deckTop.center.y)
    }

    private func handFan(layout: CardMotionLayout) -> some View {
        let size = layout.cardSize
        let center = layout.handSlot.center
        return ZStack {
            W2CardBack(size: cgSize(size))
                .scaleEffect(layout.handSlot.scale)
                .rotationEffect(.degrees(layout.handSlot.rotationDegrees - 9), anchor: .bottom)
                .position(x: center.x - size.width * 0.28, y: center.y + 2)
            RoundedRectangle(cornerRadius: size.width * 0.15)
                .stroke(.white.opacity(0.15), style: StrokeStyle(lineWidth: 0.75, dash: [3, 3]))
                .frame(width: size.width, height: size.height)
                .scaleEffect(layout.handSlot.scale)
                .rotationEffect(.degrees(layout.handSlot.rotationDegrees))
                .position(x: center.x, y: center.y)
            W2CardBack(size: cgSize(size))
                .scaleEffect(layout.handSlot.scale)
                .rotationEffect(.degrees(layout.handSlot.rotationDegrees + 9), anchor: .bottom)
                .position(x: center.x + size.width * 0.28, y: center.y + 2)
        }
        .opacity(segment == .deal ? 0.78 : 0.62)
    }

    private func playTargetGuide(layout: CardMotionLayout) -> some View {
        RoundedRectangle(cornerRadius: layout.cardSize.width * 0.15)
            .stroke(.white.opacity(0.13), style: StrokeStyle(lineWidth: 0.8, dash: [4, 4]))
            .frame(width: layout.cardSize.width, height: layout.cardSize.height)
            .scaleEffect(layout.playTarget.scale)
            .rotationEffect(.degrees(layout.playTarget.rotationDegrees))
            .position(x: layout.playTarget.center.x, y: layout.playTarget.center.y)
    }

    private var phaseChrome: some View {
        VStack {
            HStack {
                Text("CARD MOTION · NATIVE SPIKE V2")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(1.1)
                Spacer()
                Text(segment.rawValue.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.78))
            Spacer()
            HStack {
                Text("W2 DECK")
                Spacer()
                Text(String(format: "segment t = %.2f", progress))
                Spacer()
                Text("V10 PUBLIC")
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.58))
        }
        .padding(16)
        .allowsHitTesting(false)
    }

    private func cgSize(_ size: CardDimensions) -> CGSize {
        CGSize(width: size.width, height: size.height)
    }
}

