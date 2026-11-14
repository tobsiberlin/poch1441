import SwiftUI

struct CardMotionFlight: View {
    let plan: CardMotionPlan
    let progress: Double
    let revealProgress: Double
    let cardSize: CGSize

    private var sample: CardMotionSample { plan.sample(progress: progress) }

    var body: some View {
        ZStack {
            groundProjection
                .zIndex(0)
                .accessibilityIdentifier("card-motion-ground-projection")

            SpikeFlipCard(size: cardSize, revealProgress: revealProgress)
                .rotationEffect(.degrees(sample.cardRotationDegrees))
                .rotation3DEffect(
                    .degrees(sample.cardTiltDegrees),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.72
                )
                .position(x: sample.cardPoint.x, y: sample.cardPoint.y)
                .zIndex(1)
                .accessibilityIdentifier("card-motion-surface")
        }
        .accessibilityElement(children: .contain)
    }

    private var groundProjection: some View {
        RoundedRectangle(cornerRadius: cardSize.width * 0.24)
            .fill(.black.opacity(sample.shadowOpacity))
            .frame(width: cardSize.width * 0.82, height: cardSize.height * 0.30)
            .scaleEffect(x: sample.shadowScale, y: 1, anchor: .center)
            .blur(radius: cardSize.width * 0.09)
            .position(x: sample.groundPoint.x, y: sample.groundPoint.y + cardSize.height * 0.37)
    }
}

struct CardMotionStage: View {
    let progress: Double
    let revealProgress: Double
    var overlayOpacity: Double = 1
    var phaseLabel: String = "PLAY"
    var flightIdentity: Int = 0

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let shortEdge = min(width, height)
            let cardWidth = min(max(shortEdge * 0.19, 58), 88)
            let cardSize = CGSize(width: cardWidth, height: cardWidth * 74 / 52)
            let start = MotionPoint(x: width * 0.22, y: height * 0.26)
            let end = MotionPoint(x: width * 0.70, y: height * 0.70)
            let plan = CardMotionPlan(
                start: start,
                end: end,
                arcHeight: max(48, min(118, height * 0.18)),
                lateralBias: min(22, width * 0.035),
                startRotationDegrees: -7,
                endRotationDegrees: 9
            )

            ZStack {
                tableBackground

                deck(size: cardSize, point: start)
                    .zIndex(10)

                targetFan(size: cardSize, point: end)
                    .zIndex(20)

                CardMotionFlight(
                    plan: plan,
                    progress: progress,
                    revealProgress: revealProgress,
                    cardSize: cardSize
                )
                .id(flightIdentity)
                .opacity(overlayOpacity)
                .zIndex(30)

                phaseChrome(progress: progress)
                    .zIndex(40)
            }
            .clipped()
            .accessibilityIdentifier("card-motion-stage")
        }
    }

    private var tableBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.105, green: 0.12, blue: 0.11),
                         Color(red: 0.035, green: 0.045, blue: 0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [.white.opacity(0.08), .clear],
                center: .center,
                startRadius: 10,
                endRadius: 340
            )
        }
        .ignoresSafeArea()
    }

    private func deck(size: CGSize, point: MotionPoint) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                W2CardBack(size: size)
                    .offset(x: CGFloat(index) * 1.8, y: CGFloat(index) * -2.2)
            }
        }
        .rotationEffect(.degrees(-7))
        .position(x: point.x, y: point.y)
    }

    private func targetFan(size: CGSize, point: MotionPoint) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                W2CardBack(size: size)
                    .rotationEffect(.degrees(Double(index - 1) * 8), anchor: .bottom)
                    .offset(x: CGFloat(index - 1) * size.width * 0.27)
                    .zIndex(Double(index))
            }
        }
        .opacity(0.48)
        .position(x: point.x, y: point.y)
    }

    private func phaseChrome(progress: Double) -> some View {
        VStack {
            HStack {
                Text("CARD MOTION · NATIVE SPIKE")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(1.2)
                Spacer()
                Text(phaseLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.78))
            Spacer()
            HStack {
                Text("W2 BACK")
                Spacer()
                Text(String(format: "t = %.2f", progress))
                Spacer()
                Text("V10 PUBLIC")
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.58))
        }
        .padding(16)
        .allowsHitTesting(false)
    }
}
