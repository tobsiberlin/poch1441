import SwiftUI

struct RhythmHarnessStage: View {
    let plan: RhythmHarnessPlan
    let snapshot: HarnessSnapshot
    let viewport = CGSize(width: 402, height: 874)

    private let cardSize = CGSize(width: 64, height: 96)
    private let source = CGPoint(x: 320, y: 328)

    var body: some View {
        ZStack {
            Color(red: 0.045, green: 0.043, blue: 0.052)
            backdrop
            VStack(spacing: 0) {
                header
                timeline
                Spacer(minLength: 0)
            }
            cardField
        }
        .frame(width: viewport.width, height: viewport.height)
        .clipped()
    }

    private var backdrop: some View {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.09, blue: 0.105),
                Color(red: 0.035, green: 0.034, blue: 0.043),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .fill(Color.black.opacity(0.22))
                .overlay {
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                }
                .padding(.horizontal, 18)
                .padding(.top, 272)
                .padding(.bottom, 20)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text("DEAL RHYTHM · V2")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .tracking(0.8)
                Spacer()
                Text(snapshot.sequence.rawValue.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(phaseColor)
            }
            HStack(spacing: 10) {
                metric("T", String(format: "%05.2f", snapshot.elapsedSeconds))
                metric("AKTIV", "\(snapshot.activeCount)/2")
                metric("DECK", "\(snapshot.deckCount)")
                Spacer()
                Text(currentRhythmPhase)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(phaseColor)
            }
            Text("W2 NEUTRAL BODY · KEIN MATERIALURTEIL · KEIN PRODUKT-AUDIO")
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .tracking(0.25)
                .foregroundStyle(.white.opacity(0.42))
        }
        .foregroundStyle(.white.opacity(0.94))
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(.white.opacity(0.38))
            Text(value)
                .foregroundStyle(.white.opacity(0.82))
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
    }

    private var timeline: some View {
        GeometryReader { geometry in
            let left = 30.0
            let width = max(1, geometry.size.width - 48)
            let timeScale = width / max(plan.evidenceEndSeconds, 0.001)
            ZStack(alignment: .topLeading) {
                ForEach(plan.schedule.indices, id: \.self) { index in
                    let card = plan.schedule[index]
                    let durations = plan.durations[index]
                    let y = 8 + Double(index) * 16
                    timelineSegment(
                        start: card.actualStartSeconds,
                        duration: durations.travelSeconds,
                        color: Color(red: 0.34, green: 0.58, blue: 0.86),
                        left: left,
                        y: y,
                        scale: timeScale
                    )
                    timelineSegment(
                        start: card.contactStartSeconds,
                        duration: durations.contactSeconds,
                        color: Color(red: 0.90, green: 0.65, blue: 0.28),
                        left: left,
                        y: y,
                        scale: timeScale
                    )
                    timelineSegment(
                        start: card.settleStartSeconds,
                        duration: durations.settleSeconds,
                        color: Color(red: 0.67, green: 0.48, blue: 0.84),
                        left: left,
                        y: y,
                        scale: timeScale
                    )
                    Text("\(index + 1)")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.44))
                        .position(x: 18, y: y + 4)
                }

                let playheadX = left + min(snapshot.elapsedSeconds, plan.evidenceEndSeconds) * timeScale
                Rectangle()
                    .fill(Color.white.opacity(0.82))
                    .frame(width: 1, height: 132)
                    .position(x: playheadX, y: 70)
                if let cancellation = plan.cancellationSeconds {
                    Rectangle()
                        .fill(Color.red.opacity(0.75))
                        .frame(width: 1, height: 132)
                        .position(x: left + cancellation * timeScale, y: 70)
                }
            }
        }
        .frame(height: 142)
        .padding(.horizontal, 8)
        .background(Color.black.opacity(0.22))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
        }
    }

    private func timelineSegment(
        start: Double,
        duration: Double,
        color: Color,
        left: Double,
        y: Double,
        scale: Double
    ) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color.opacity(0.88))
            .frame(width: max(1, duration * scale), height: 7)
            .position(x: left + (start + duration / 2) * scale, y: y + 4)
    }

    private var cardField: some View {
        ZStack {
            deck
            ForEach(snapshot.cards, id: \.index) { card in
                let pose = cardPose(for: card)
                W2CardBack(size: cardSize)
                    .shadow(
                        color: .black.opacity(card.phase == .rest ? 0.38 : 0.62),
                        radius: card.phase == .rest ? 5 : 10,
                        y: card.phase == .rest ? 3 : 7
                    )
                    .rotationEffect(.degrees(pose.rotation))
                    .rotation3DEffect(
                        .degrees(pose.pitch),
                        axis: (x: 1, y: 0, z: 0),
                        perspective: 0.55
                    )
                    .opacity(pose.opacity)
                    .position(pose.center)
                    .zIndex(card.phase == .rest ? Double(card.index) : 100 + Double(card.index))
                    .overlay(alignment: .bottom) {
                        Text("\(card.index + 1) · \(card.phase.rawValue.uppercased())")
                            .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.72))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.66), in: Capsule())
                            .offset(
                                x: pose.center.x - viewport.width / 2,
                                y: pose.center.y - viewport.height / 2 + 58
                            )
                    }
            }
        }
    }

    private var deck: some View {
        ZStack {
            ForEach(0..<min(snapshot.deckCount, 3), id: \.self) { layer in
                W2CardBack(size: cardSize)
                    .offset(x: Double(layer) * -1.8, y: Double(layer) * -2.4)
            }
            if snapshot.deckCount > 0 {
                Text("\(snapshot.deckCount)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.84))
                    .padding(6)
                    .background(.black.opacity(0.65), in: Circle())
                    .offset(x: 40, y: -50)
            }
        }
        .position(source)
    }

    private func cardPose(for card: HarnessCardSnapshot) -> CardPose {
        if card.phase == .cancelling, let cancellation = plan.cancellationSeconds {
            let origin = uninterruptedPose(index: card.index, at: cancellation)
            let eased = smooth(card.phaseProgress)
            return CardPose(
                center: interpolate(origin.center, source, eased),
                rotation: origin.rotation * (1 - eased),
                pitch: origin.pitch * (1 - eased),
                opacity: 1 - eased
            )
        }
        return uninterruptedPose(index: card.index, at: snapshot.elapsedSeconds)
    }

    private func uninterruptedPose(index: Int, at time: Double) -> CardPose {
        let card = plan.schedule[index]
        let target = targetPoint(index: index)
        let restRotation = Double(index - 3) * 2.8
        if time < card.contactStartSeconds {
            let progress = normalized(time, from: card.actualStartSeconds, to: card.contactStartSeconds)
            if plan.sequence == .reducedMotion {
                let eased = smooth(progress)
                return CardPose(
                    center: CGPoint(x: target.x, y: target.y - 15 * (1 - eased)),
                    rotation: restRotation - 3 * (1 - eased),
                    pitch: 5 * (1 - eased),
                    opacity: 0.28 + eased * 0.72
                )
            }
            let eased = smooth(progress)
            let routeBias: Double = switch plan.profile.pulses[index].route {
            case .innerArc: -18
            case .outerArc: 22
            default: 0
            }
            let linear = interpolate(source, target, eased)
            let arc = sin(.pi * eased)
            return CardPose(
                center: CGPoint(
                    x: linear.x + routeBias * arc,
                    y: linear.y - 72 * arc
                ),
                rotation: -7 + (restRotation + 7) * eased + routeBias * 0.08 * arc,
                pitch: 14 * (1 - eased),
                opacity: 1
            )
        }
        if time < card.settleStartSeconds {
            let progress = normalized(time, from: card.contactStartSeconds, to: card.settleStartSeconds)
            return CardPose(
                center: CGPoint(x: target.x, y: target.y - sin(.pi * progress) * 7),
                rotation: restRotation + sin(.pi * progress) * 2.4,
                pitch: -5 * sin(.pi * progress),
                opacity: 1
            )
        }
        if time < card.restWindowStartSeconds {
            let progress = normalized(time, from: card.settleStartSeconds, to: card.restWindowStartSeconds)
            let rebound = sin(.pi * progress) * (1 - progress)
            return CardPose(
                center: CGPoint(x: target.x, y: target.y - rebound * 8),
                rotation: restRotation - rebound * 2.8,
                pitch: rebound * 4,
                opacity: 1
            )
        }
        return CardPose(center: target, rotation: restRotation, pitch: 0, opacity: 1)
    }

    private func targetPoint(index: Int) -> CGPoint {
        let column = index % 4
        let row = index / 4
        return CGPoint(
            x: 67 + Double(column) * 89,
            y: 602 + Double(row) * 132
        )
    }

    private var currentRhythmPhase: String {
        guard let pulse = plan.profile.pulses.last(where: {
            $0.targetStartSeconds <= snapshot.elapsedSeconds
        }) else { return "BEREIT" }
        return pulse.phase.rawValue.uppercased()
    }

    private var phaseColor: Color {
        switch currentRhythmPhase {
        case "TENSION": Color(red: 0.80, green: 0.67, blue: 0.41)
        case "ACCELERATION": Color(red: 0.43, green: 0.69, blue: 0.92)
        case "RECOVERY": Color(red: 0.68, green: 0.53, blue: 0.85)
        case "RELEASE": Color(red: 0.55, green: 0.83, blue: 0.64)
        default: .white.opacity(0.6)
        }
    }

    private func normalized(_ value: Double, from start: Double, to end: Double) -> Double {
        guard end > start else { return 1 }
        return min(max((value - start) / (end - start), 0), 1)
    }

    private func smooth(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }

    private func interpolate(_ from: CGPoint, _ to: CGPoint, _ progress: Double) -> CGPoint {
        CGPoint(
            x: from.x + (to.x - from.x) * progress,
            y: from.y + (to.y - from.y) * progress
        )
    }

    private struct CardPose {
        let center: CGPoint
        let rotation: Double
        let pitch: Double
        let opacity: Double
    }
}
