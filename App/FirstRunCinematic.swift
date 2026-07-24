import PochKit
import SwiftUI

enum FirstRunOpeningStyle: Sendable {
    case tableCinematic
    case timeSwipe
}

enum FirstRunCinematicScene: Int, CaseIterable, Comparable, Sendable {
    case darkness
    case contact
    case tableReveal
    case playersArrive
    case deckSettles
    case invitation
    case ready

    static func < (lhs: FirstRunCinematicScene,
                   rhs: FirstRunCinematicScene) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var qaName: String {
        switch self {
        case .darkness: "darkness"
        case .contact: "contact"
        case .tableReveal: "table-reveal"
        case .playersArrive: "players-arrive"
        case .deckSettles: "deck-settles"
        case .invitation: "invitation"
        case .ready: "ready"
        }
    }
}

/// Ein einmaliger One-Shot aus Sicht des freien vierten Platzes. Die Szene
/// erklärt keine Regeln vorab: Sie lädt durch eine echte Tischhandlung ein und
/// übergibt denselben Chip anschließend an die erste geführte Interaktion.
struct FirstRunCinematic: View {
    let opponentNames: [String]
    let theme: Theme
    let openingStyle: FirstRunOpeningStyle
    let reduceMotion: Bool
    let soundEnabled: Bool
    let hapticsEnabled: Bool
    let morph: Namespace.ID
    let onTakeSeat: () -> Void
    let onPlayWithoutGuide: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var scene: FirstRunCinematicScene = .darkness
    @State private var didStart = false
    @State private var contactTick = 0

    private var isReady: Bool { scene == .ready }
    private var showsPeople: Bool { scene >= .playersArrive }
    private var showsDeck: Bool { scene >= .deckSettles }
    private var showsInvitation: Bool { scene >= .invitation }

    @ViewBuilder
    var body: some View {
        if openingStyle == .timeSwipe {
            FirstRunTimeSwipeOpening(
                soundEnabled: soundEnabled,
                hapticsEnabled: hapticsEnabled,
                reduceMotion: reduceMotion,
                onTakeSeat: onTakeSeat,
                onPlayWithoutGuide: onPlayWithoutGuide
            )
        } else {
            tableCinematic
        }
    }

    private var tableCinematic: some View {
        GeometryReader { proxy in
            if dynamicTypeSize.isAccessibilitySize {
                accessibleLayout(size: proxy.size,
                                 safeArea: proxy.safeAreaInsets)
            } else {
                cinematicLayout(size: proxy.size,
                                safeArea: proxy.safeAreaInsets)
            }
        }
        .background(cinemaBackground.ignoresSafeArea())
        .sensoryFeedback(trigger: contactTick) { previous, current in
            guard hapticsEnabled, previous != current else { return nil }
            return .impact(weight: .heavy, intensity: 0.82)
        }
        .task { await playIfNeeded() }
    }

    private var cinemaBackground: some View {
        ZStack {
            Image("PochTableConcrete")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .saturation(0.66)
                .brightness(scene <= .contact ? -0.48 : -0.30)
                .scaleEffect(scene <= .contact ? 1.08 : 1.02)

            LinearGradient(colors: [
                Color.black.opacity(scene <= .contact ? 0.91 : 0.74),
                Color.black.opacity(0.24),
                Color.black.opacity(0.82)
            ], startPoint: .top, endPoint: .bottom)

            RadialGradient(colors: [
                Tokens.jewelGold.opacity(showsPeople ? 0.11 : 0.035),
                .clear
            ], center: UnitPoint(x: 0.5, y: 0.42),
               startRadius: 12, endRadius: 390)
        }
        .animation(reduceMotion ? .linear(duration: 0.16)
                   : .timingCurve(0.22, 0.72, 0.20, 1.0, duration: 0.72),
                   value: scene)
    }

    private func cinematicLayout(size: CGSize,
                                 safeArea: EdgeInsets) -> some View {
        let landscape = size.width > size.height
        let compactHeight = !landscape && size.height < 720
        let boardDiameter = min(
            landscape ? size.height * 0.60 : size.width * (compactHeight ? 0.62 : 0.72),
            landscape ? size.width * 0.40 : size.height * (compactHeight ? 0.31 : 0.38),
            330
        )
        let stageCenter = CGPoint(
            x: landscape ? size.width * 0.64 : size.width * 0.5,
            y: landscape ? size.height * 0.52 : size.height * (compactHeight ? 0.36 : 0.43)
        )

        return ZStack {
            cinematicHeader(safeArea: safeArea)

            tableStage(diameter: boardDiameter,
                       center: stageCenter,
                       landscape: landscape)
                .cameraTransform(scene: scene,
                                 reduceMotion: reduceMotion,
                                 landscape: landscape)
                .zIndex(1)

            if isReady {
                invitationPanel
                    .frame(width: min(360, size.width - 38))
                    .position(
                        x: landscape ? size.width * 0.23 : size.width * 0.5,
                        y: landscape
                            ? size.height * 0.50
                            : size.height - safeArea.bottom - (compactHeight ? 104 : 116)
                    )
                    .transition(reduceMotion
                                ? .opacity
                                : .move(edge: .bottom).combined(with: .opacity))
                    .zIndex(5)
            }

            sceneProbe
        }
    }

    private func tableStage(diameter: CGFloat,
                            center: CGPoint,
                            landscape: Bool) -> some View {
        ZStack {
            Circle()
                .fill(Tokens.jewelGold.opacity(scene == .contact ? 0.12 : 0.035))
                .frame(width: diameter * 1.20, height: diameter * 1.20)
                .blur(radius: diameter * 0.075)
                .position(center)

            TableWorldBoardBase(world: theme, diameter: diameter)
                .tableWorldSpatialPresentation(world: theme, diameter: diameter)
                .scaleEffect(scene == .contact && !reduceMotion ? 0.975 : 1)
                .shadow(color: .black.opacity(0.78), radius: 28, y: 19)
                .position(center)
                .accessibilityIdentifier("firstRun.cinematic.table")

            opponentArc(boardDiameter: diameter,
                        center: center,
                        landscape: landscape)

            cinematicDeck(diameter: diameter)
                .position(x: center.x - diameter * 0.34,
                          y: center.y + diameter * 0.31)

            invitationChip(diameter: diameter,
                           center: center)
        }
        .accessibilityElement(children: .contain)
    }

    private func opponentArc(boardDiameter: CGFloat,
                             center: CGPoint,
                             landscape: Bool) -> some View {
        let names = Array(opponentNames.prefix(3))
        let horizontalSpacing = landscape
            ? boardDiameter * 0.42
            : boardDiameter * 0.32

        return HStack(spacing: horizontalSpacing * 0.18) {
            ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                OpponentPortrait(
                    seat: index + 1,
                    name: name,
                    isActive: true,
                    isFocus: showsInvitation && index == 0,
                    mood: opponentMood(index: index),
                    size: index == 0 ? 64 : 56,
                    showsText: showsPeople,
                    morph: morph,
                    reduceMotionOverride: reduceMotion
                )
                .frame(width: horizontalSpacing)
                .opacity(showsPeople ? 1 : 0)
                .offset(y: showsPeople
                        ? (index == 0 ? -7 : (index == 1 ? 3 : -1))
                        : -18)
                .animation(
                    reduceMotion
                        ? .linear(duration: 0.14)
                        : .timingCurve(0.22, 0.72, 0.20, 1.0,
                                       duration: 0.46)
                            .delay(Double(index) * 0.075),
                    value: scene
                )
                .accessibilityIdentifier("firstRun.cinematic.opponent.\(index + 1)")
            }
        }
        .frame(width: boardDiameter * 1.20)
        .position(x: center.x,
                  y: center.y - boardDiameter * (landscape ? 0.54 : 0.68))
    }

    private func opponentMood(index: Int) -> OpponentMood {
        if index == 0 {
            return showsInvitation ? .winning : .neutral
        }
        if index == 1 {
            return showsDeck ? .thinking : .neutral
        }
        return .neutral
    }

    private func cinematicDeck(diameter: CGFloat) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                CardBack(materialVariant: [8, 4, 7][index],
                         scale: diameter / 360)
                    .rotationEffect(.degrees(Double(index - 1) * 1.8))
                    .offset(x: CGFloat(index) * 1.8,
                            y: CGFloat(index) * -2.4)
            }
        }
        .opacity(showsDeck ? 1 : 0)
        .offset(x: showsDeck ? 0 : -diameter * 0.34,
                y: showsDeck ? 0 : diameter * 0.12)
        .rotationEffect(.degrees(showsDeck ? -5 : -16))
        .animation(reduceMotion
                   ? .linear(duration: 0.16)
                   : .timingCurve(0.23, 1, 0.32, 1, duration: 0.62),
                   value: scene)
        .accessibilityHidden(true)
    }

    private func invitationChip(diameter: CGFloat,
                                center: CGPoint) -> some View {
        let target = CGPoint(x: center.x,
                             y: center.y + diameter * 0.57)
        let source = CGPoint(x: center.x - diameter * 0.32,
                             y: center.y - diameter * 0.46)
        let position = showsInvitation ? target : source

        return R1Token(size: max(34, diameter * 0.14),
                       colorway: .ochre,
                       markRotation: -17,
                       surfaceVariant: 4,
                       elevation: showsInvitation ? 0.08 : 0.16)
            .matchedGeometryEffect(id: "firstRunInvitationChip", in: morph)
            .position(position)
            .opacity(showsInvitation ? 1 : 0)
            .scaleEffect(showsInvitation ? 1 : 0.92)
            .shadow(color: Tokens.jewelGold.opacity(showsInvitation ? 0.28 : 0),
                    radius: 13, y: 7)
            .animation(reduceMotion
                       ? .linear(duration: 0.16)
                       : .timingCurve(0.22, 0.72, 0.20, 1.0,
                                      duration: 0.78),
                       value: scene)
            .accessibilityHidden(true)
    }

    private func cinematicHeader(safeArea: EdgeInsets) -> some View {
        VStack {
            HStack(alignment: .center) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("POCH")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(Tokens.jewelPlatin)
                    Text("1441")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(Tokens.jewelGold)
                }
                .accessibilityElement(children: .combine)
                .accessibilityHidden(showsPeople)
                .opacity(showsPeople ? 0 : 1)
                .animation(reduceMotion
                           ? .linear(duration: 0.12)
                           : .easeOut(duration: 0.24),
                           value: showsPeople)

                Spacer()

                if !isReady {
                    Button(action: revealSeat) {
                        Text(String(localized: "firstRun.cinematic.skip",
                                    defaultValue: "Überspringen"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Tokens.jewelPlatin.opacity(0.76))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(Capsule().fill(Color.black.opacity(0.26)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("firstRun.cinematic.skip")
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, safeArea.top + 10)
            Spacer()
        }
        .zIndex(8)
    }

    private var invitationPanel: some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                Text(String(localized: "firstRun.cinematic.invitation.eyebrow",
                            defaultValue: "HANA"))
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(2.0)
                    .foregroundStyle(Tokens.jewelGold.opacity(0.92))

                Text(String(localized: "firstRun.cinematic.invitation.title",
                            defaultValue: "Setz dich dazu."))
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(Tokens.jewelPlatin)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("firstRun.intro.title")

                Text(String(localized: "firstRun.cinematic.invitation.body",
                            defaultValue: "Die erste Runde spielen wir zusammen."))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.74))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("firstRun.intro.body")
            }

            seatActions
        }
        .padding(.horizontal, 14)
        .accessibilityElement(children: .contain)
    }

    private var seatActions: some View {
        VStack(spacing: 6) {
            Button(action: onTakeSeat) {
                HStack(spacing: 9) {
                    Text(String(localized: "firstRun.cinematic.takeSeat",
                                defaultValue: "Mitspielen"))
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.bold))
                }
                .font(.headline.weight(.heavy))
                .foregroundStyle(Tokens.bgDeep)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Capsule().fill(Tokens.jewelGold))
                .contentShape(Capsule())
            }
            .buttonStyle(CinematicPressStyle(reduceMotion: reduceMotion))
            .accessibilityIdentifier("firstRun.intro.primary")

            Button(action: onPlayWithoutGuide) {
                Text(String(localized: "firstRun.cinematic.withoutGuide",
                            defaultValue: "Ohne Hinweise starten"))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.70))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("firstRun.intro.secondary")
        }
    }

    private func accessibleLayout(size: CGSize,
                                  safeArea: EdgeInsets) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("POCH").font(.title2.weight(.heavy))
                    Text("1441").font(.title2.weight(.light))
                        .foregroundStyle(Tokens.jewelGold)
                }
                .foregroundStyle(Tokens.jewelPlatin)
                .padding(.top, safeArea.top + 14)

                HStack(spacing: 24) {
                    ForEach(Array(opponentNames.prefix(3).enumerated()), id: \.offset) { index, name in
                        OpponentPortrait(seat: index + 1,
                                         name: name,
                                         isActive: true,
                                         isFocus: index == 0,
                                         mood: index == 0 ? .winning : .neutral,
                                         size: 54,
                                         showsText: true,
                                         morph: morph,
                                         reduceMotionOverride: true)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(String(localized: "firstRun.cinematic.accessibility.people",
                                            defaultValue: "Hana, Noah und Jonas sitzen am Tisch. Hana lädt dich zur ersten Runde ein."))

                TableWorldBoardBase(world: theme,
                                    diameter: min(240, size.width * 0.66))
                    .tableWorldSpatialPresentation(world: theme,
                                                   diameter: min(240, size.width * 0.66))
                    .frame(width: min(240, size.width * 0.66),
                           height: min(240, size.width * 0.66))
                    .accessibilityHidden(true)

                VStack(spacing: 7) {
                    Text(String(localized: "firstRun.cinematic.invitation.title",
                                defaultValue: "Setz dich dazu."))
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(Tokens.jewelPlatin)
                        .accessibilityIdentifier("firstRun.intro.title")
                    Text(String(localized: "firstRun.cinematic.accessibility.body",
                                defaultValue: "Hana spielt die erste Runde mit dir. Bestimmte Trumpfkarten gewinnen Bonus-Töpfe, gleiche Karten öffnen das Pochen und die letzte Karte gewinnt die Mitte."))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Tokens.jewelPlatin.opacity(0.80))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("firstRun.intro.body")
                }
                .padding(.horizontal, 24)

                seatActions
                    .padding(.horizontal, 22)
                    .padding(.bottom, max(24, safeArea.bottom + 12))
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .overlay { sceneProbe }
    }

    private var sceneProbe: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement()
            .accessibilityLabel(scene.qaName)
            .accessibilityIdentifier("firstRun.cinematic.scene")
            .allowsHitTesting(false)
    }

    private func playIfNeeded() async {
        guard !didStart else { return }
        didStart = true

        #if DEBUG
        if let argument = ProcessInfo.processInfo.arguments.first(where: {
            $0.hasPrefix("-firstRunScene=")
        }), let raw = Int(argument.split(separator: "=").last ?? "6"),
           let frozen = FirstRunCinematicScene(rawValue: raw.clamped(to: 0...6)) {
            scene = frozen
            return
        }
        if let argument = ProcessInfo.processInfo.arguments.first(where: {
            $0.hasPrefix("-firstRunBeat=")
        }), let legacy = Int(argument.split(separator: "=").last ?? "4") {
            scene = legacy >= 4 ? .ready
                : FirstRunCinematicScene(rawValue: min(legacy + 1, 5)) ?? .ready
            return
        }
        #endif

        if voiceOverEnabled || reduceMotion {
            scene = .ready
            return
        }

        let timeline: [(FirstRunCinematicScene, Duration)] = [
            (.contact, .milliseconds(550)),
            (.tableReveal, .milliseconds(950)),
            (.playersArrive, .milliseconds(1_200)),
            (.deckSettles, .milliseconds(1_000)),
            (.invitation, .milliseconds(1_050)),
            (.ready, .milliseconds(1_450))
        ]

        for (next, delay) in timeline {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, !isReady else { return }
            if next == .contact { contactTick += 1 }
            advance(to: next)
        }
    }

    private func advance(to next: FirstRunCinematicScene) {
        withAnimation(reduceMotion
                      ? .linear(duration: 0.14)
                      : .timingCurve(0.22, 0.72, 0.20, 1.0,
                                     duration: next == .ready ? 0.52 : 0.72)) {
            scene = next
        }
    }

    private func revealSeat() {
        withAnimation(reduceMotion
                      ? .linear(duration: 0.12)
                      : .timingCurve(0.23, 1, 0.32, 1, duration: 0.36)) {
            scene = .ready
        }
    }
}

private extension View {
    @ViewBuilder
    func cameraTransform(scene: FirstRunCinematicScene,
                         reduceMotion: Bool,
                         landscape: Bool) -> some View {
        if reduceMotion {
            self
        } else {
            let scale: CGFloat = {
                switch scene {
                case .darkness: 1.62
                case .contact: 1.48
                case .tableReveal: 1.22
                case .playersArrive: 1.09
                case .deckSettles: 1.04
                case .invitation, .ready: 1.0
                }
            }()
            let y: CGFloat = {
                switch scene {
                case .darkness: landscape ? 48 : 98
                case .contact: landscape ? 38 : 78
                case .tableReveal: landscape ? 20 : 42
                case .playersArrive: 12
                case .deckSettles, .invitation, .ready: 0
                }
            }()
            self
                .scaleEffect(scale, anchor: .center)
                .offset(y: y)
                .opacity(scene == .darkness ? 0.30 : 1)
                .blur(radius: scene == .darkness ? 2.4 : 0)
                .animation(.timingCurve(0.22, 0.72, 0.20, 1.0,
                                        duration: 0.78),
                           value: scene)
        }
    }
}

private struct CinematicPressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
