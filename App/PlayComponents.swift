import PochKit
import SwiftUI

/// Shared table pieces. These are deliberately code-rendered so the app keeps
/// moving while final raster/3D assets are still being refined.

enum OpponentMood: Equatable {
    case neutral
    case thinking
    case passed
    case called
    case pressure
    case winning
    case tense
    case surprised
}

struct OpponentPortrait: View {
    let seat: Int
    let name: String
    var stack: Int? = nil
    var caption: String? = nil
    var isActive: Bool = true
    var isFocus: Bool = false
    var mood: OpponentMood = .neutral
    var size: CGFloat = 62
    var showsText: Bool = true
    let morph: Namespace.ID?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentPortraitAsset = ""
    @State private var previousPortraitAsset: String?
    @State private var portraitReveal = true
    @State private var portraitTransitionTask: Task<Void, Never>?

    private var palette: (skin: Color, coat: Color, accent: Color) {
        switch seat % 3 {
        case 1:
            return (Color(hex: 0xCFA884), Color(hex: 0x1E3432), Tokens.jewelSmaragd)
        case 2:
            return (Color(hex: 0xD9B18D), Color(hex: 0x332135), Tokens.jewelAmethyst)
        default:
            return (Color(hex: 0xB98A68), Color(hex: 0x33271C), Tokens.jewelGold)
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            portrait
                .frame(width: size, height: size)
                .opacity(isActive ? 1 : 0.46)
                .saturation(isActive ? 1 : 0.22)
                .animation(.easeInOut(duration: 0.24), value: isFocus)
                .ifLet(morph) { view, namespace in
                    view.matchedGeometryEffect(id: "token\(seat)", in: namespace)
                }

            if showsText {
                Text(name)
                    .font(.system(size: max(9, size * 0.18), weight: .semibold))
                    .foregroundStyle(isFocus ? Tokens.jewelPlatin : Tokens.slate.opacity(0.9))
                    .lineLimit(1)

                if let caption {
                    Text(caption)
                        .font(.system(size: max(8, size * 0.15), weight: .medium))
                        .foregroundStyle(isFocus ? Tokens.jewelGold.opacity(0.95) : Tokens.slate.opacity(0.75))
                        .lineLimit(1)
                } else if let stack {
                    Text("\(stack)")
                        .font(.system(size: max(8, size * 0.16), weight: .medium))
                        .foregroundStyle(Tokens.jewelGold.opacity(0.9))
                        .contentTransition(.numericText())
                }
            }
        }
        .onAppear {
            currentPortraitAsset = portraitAssetName
        }
        .onChange(of: portraitAssetName) { _, nextAsset in
            beginPortraitTransition(to: nextAsset)
        }
        .onDisappear {
            portraitTransitionTask?.cancel()
        }
    }

    private var portrait: some View {
        let p = palette
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(colors: [Color(hex: 0x2A2630), Color(hex: 0x111017)],
                                   center: .topLeading, startRadius: 4, endRadius: size * 0.75)
                )
                .overlay(Circle().strokeBorder(
                    LinearGradient(colors: [
                        (isFocus ? p.accent : Tokens.jewelGold).opacity(isFocus ? 0.95 : 0.55),
                        Tokens.jewelPlatin.opacity(0.12)
                    ], startPoint: .top, endPoint: .bottom),
                    lineWidth: isFocus ? 1.8 : 1))
                .shadow(color: isFocus ? p.accent.opacity(0.22) : .black.opacity(0.35),
                        radius: isFocus ? 10 : 4, y: 3)

            portraitLayers
                .frame(width: size - 5, height: size - 5)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Tokens.jewelPlatin.opacity(0.12), lineWidth: 0.7))
        }
    }

    private var portraitLayers: some View {
        ZStack {
            if let previousPortraitAsset {
                portraitImage(previousPortraitAsset)
                    .opacity(portraitReveal ? 0 : 1)
                    .blur(radius: reduceMotion ? 0 : (portraitReveal ? 0.55 : 0))
            }

            portraitImage(currentPortraitAsset.isEmpty ? portraitAssetName : currentPortraitAsset)
                .opacity(previousPortraitAsset == nil || portraitReveal ? 1 : 0)
                .blur(radius: reduceMotion ? 0 : (portraitReveal ? 0 : 0.45))

            RadialGradient(colors: [
                palette.accent.opacity(portraitReveal ? 0 : 0.09),
                .clear
            ], center: .topLeading, startRadius: 2, endRadius: size * 0.72)
            .allowsHitTesting(false)
        }
    }

    private func portraitImage(_ asset: String) -> some View {
        Image(asset)
            .resizable()
            .interpolation(.high)
            .scaledToFill()
    }

    private func beginPortraitTransition(to nextAsset: String) {
        portraitTransitionTask?.cancel()
        let outgoing = currentPortraitAsset.isEmpty ? portraitAssetName : currentPortraitAsset
        guard outgoing != nextAsset else { return }
        previousPortraitAsset = outgoing
        currentPortraitAsset = nextAsset
        portraitReveal = false
        let duration = reduceMotion ? 0.16 : 0.42
        withAnimation(reduceMotion
                      ? .linear(duration: duration)
                      : .timingCurve(0.22, 0.72, 0.20, 1, duration: duration)) {
            portraitReveal = true
        }
        portraitTransitionTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration + 0.03))
            guard !Task.isCancelled else { return }
            previousPortraitAsset = nil
        }
    }

    private var portraitAssetName: String {
        let expression: String
        switch mood {
        case .thinking, .tense:
            expression = "Thinking"
        case .pressure:
            expression = "Pressure"
        case .winning:
            expression = "Winning"
        case .passed:
            expression = "Defeated"
        case .surprised:
            expression = "Surprised"
        case .neutral, .called:
            expression = "Neutral"
        }
        return "Opponent\(name)\(expression)"
    }

    private var expressionLayer: some View {
        ZStack {
            browLayer
            eyeLayer
            mouthLayer
            if mood == .thinking || mood == .pressure || mood == .winning {
                moodGesture
            }
        }
    }

    @ViewBuilder private var eyeLayer: some View {
        HStack(spacing: size * 0.075) {
            eyeShape
            eyeShape
        }
        .frame(width: size * 0.21, height: size * 0.035)
        .offset(y: -size * 0.012)
    }

    private var eyeShape: some View {
        Group {
            switch mood {
            case .passed:
                Capsule()
                    .fill(Color(hex: 0x141017).opacity(0.62))
                    .frame(width: size * 0.052, height: max(0.8, size * 0.011))
            case .pressure, .tense:
                RoundedRectangle(cornerRadius: size * 0.006)
                    .fill(Color(hex: 0x141017).opacity(0.82))
                    .frame(width: size * 0.044, height: size * 0.020)
            default:
                Capsule()
                    .fill(Color(hex: 0x141017).opacity(0.75))
                    .frame(width: size * 0.044, height: size * 0.014)
            }
        }
    }

    @ViewBuilder private var browLayer: some View {
        if mood == .thinking || mood == .pressure || mood == .tense {
            HStack(spacing: size * 0.075) {
                Capsule()
                    .fill(Color(hex: 0x141017).opacity(0.52))
                    .frame(width: size * 0.06, height: max(0.7, size * 0.012))
                    .rotationEffect(.degrees(mood == .pressure ? 18 : -10))
                Capsule()
                    .fill(Color(hex: 0x141017).opacity(0.52))
                    .frame(width: size * 0.06, height: max(0.7, size * 0.012))
                    .rotationEffect(.degrees(mood == .pressure ? -18 : 10))
            }
            .offset(y: -size * 0.07)
        }
    }

    private var mouthLayer: some View {
        Path { path in
            switch mood {
            case .passed:
                path.move(to: CGPoint(x: size * 0.48, y: size * 0.525))
                path.addLine(to: CGPoint(x: size * 0.55, y: size * 0.525))
            case .pressure, .called, .winning:
                path.move(to: CGPoint(x: size * 0.48, y: size * 0.51))
                path.addQuadCurve(to: CGPoint(x: size * 0.55, y: size * 0.51),
                                  control: CGPoint(x: size * 0.515, y: mood == .winning ? size * 0.565 : size * 0.545))
            case .tense:
                path.move(to: CGPoint(x: size * 0.49, y: size * 0.535))
                path.addQuadCurve(to: CGPoint(x: size * 0.55, y: size * 0.535),
                                  control: CGPoint(x: size * 0.52, y: size * 0.505))
            default:
                path.move(to: CGPoint(x: size * 0.49, y: size * 0.51))
                path.addQuadCurve(to: CGPoint(x: size * 0.54, y: size * 0.51),
                                  control: CGPoint(x: size * 0.515, y: size * 0.535))
            }
        }
        .stroke(Color(hex: 0x3A241E).opacity(0.40), lineWidth: max(0.65, size * 0.010))
    }

    private var moodGesture: some View {
        let p = palette
        return Circle()
            .fill(p.accent.opacity(mood == .thinking ? 0.22 : 0.34))
            .overlay(Circle().strokeBorder(p.accent.opacity(0.48), lineWidth: max(0.6, size * 0.012)))
            .overlay {
                if mood == .pressure || mood == .winning {
                    Circle()
                        .fill(Tokens.jewelPlatin.opacity(0.42))
                        .frame(width: size * 0.035, height: size * 0.035)
                }
            }
            .frame(width: size * 0.16, height: size * 0.16)
            .offset(x: size * 0.20, y: mood == .thinking ? -size * 0.19 : -size * 0.14)
            .shadow(color: p.accent.opacity(0.26), radius: 5)
    }
}

struct OpponentPanel: View {
    let seat: Int
    let name: String
    let stack: Int
    let cards: Int
    let actionText: String
    let actionTint: Color
    let isActive: Bool
    let isFocus: Bool
    var mood: OpponentMood = .neutral
    var width: CGFloat = 110
    let morph: Namespace.ID?

    private var role: String {
        switch seat % 3 {
        case 1: return "ruhig"
        case 2: return "taktisch"
        default: return "wach"
        }
    }

    var body: some View {
        let compact = width < 100
        VStack(spacing: 3) {
            ZStack {
                opponentCardBacks
                    .offset(y: -14)
                    .opacity(isActive ? 0.78 : 0.18)

                Circle()
                    .fill(RadialGradient(colors: [
                        Color(hex: 0x19151F).opacity(isActive ? 0.96 : 0.42),
                        Color(hex: 0x08070B).opacity(isActive ? 0.92 : 0.58)
                    ], center: .topLeading, startRadius: 4, endRadius: 58))
                    .overlay(Circle().strokeBorder(
                        LinearGradient(colors: [
                            (isFocus ? actionTint : Tokens.jewelGold).opacity(isFocus ? 0.84 : 0.32),
                            Tokens.jewelPlatin.opacity(isFocus ? 0.20 : 0.06)
                        ], startPoint: .top, endPoint: .bottom),
                        lineWidth: isFocus ? 1.4 : 0.9))
                    .frame(width: compact ? 58 : 66, height: compact ? 58 : 66)
                    .shadow(color: isFocus ? actionTint.opacity(0.16) : .black.opacity(0.30),
                            radius: isFocus ? 12 : 7, y: 4)

                OpponentPortrait(seat: seat,
                                 name: name,
                                 isActive: isActive,
                                 isFocus: isFocus,
                                 mood: mood,
                                 size: compact ? 54 : 62,
                                 showsText: false,
                                 morph: morph)

                if !reactionIsQuiet {
                    reactionSpeechBubble
                        .offset(y: -43)
                        .transition(.scale(scale: 0.82, anchor: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: width, height: compact ? 62 : 68)

            VStack(spacing: 1) {
                Text(name)
                    .font(.system(size: compact ? 12.2 : 13.2, weight: .heavy))
                    .foregroundStyle(isActive ? Tokens.jewelPlatin.opacity(0.95) : Tokens.slate.opacity(0.42))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(role.uppercased())
                    .font(.system(size: 6.7, weight: .heavy))
                    .tracking(1.18)
                    .foregroundStyle((isFocus ? actionTint : Tokens.slate).opacity(isActive ? 0.70 : 0.25))
                    .lineLimit(1)
            }

            if reactionIsQuiet {
                reactionBar
                    .frame(width: width)
            } else {
                Color.clear.frame(height: 18)
            }
        }
        .frame(width: width, height: compact ? 96 : 104)
        .opacity(isActive ? 1 : 0.64)
        .saturation(isActive ? 1 : 0.34)
        .animation(.easeInOut(duration: 0.28), value: isFocus)
        .animation(.easeInOut(duration: 0.28), value: isActive)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(format: String(localized: "opponent.a11y.summary",
                                  defaultValue: "%@, %d Karten, %d Chips, %@"),
                   name, cards, stack, actionText)
        )
    }

    private var seatBase: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(LinearGradient(colors: [
                Color(hex: 0x17141B).opacity(isActive ? 0.54 : 0.22),
                Color(hex: 0x08070B).opacity(isActive ? 0.82 : 0.42)
            ], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: 22)
                .strokeBorder((isFocus ? actionTint : Tokens.jewelGold).opacity(isFocus ? 0.68 : 0.14),
                              lineWidth: isFocus ? 1.25 : 0.8))
            .shadow(color: isFocus ? actionTint.opacity(0.12) : .black.opacity(0.16),
                    radius: isFocus ? 12 : 5, y: 4)
            .frame(width: width, height: 46)
            .offset(y: 8)
    }

    private var opponentCardBacks: some View {
        HStack(spacing: -18) {
            ForEach(0..<3, id: \.self) { i in
                CardBack(scale: 0.205)
                    .rotationEffect(.degrees(Double(i - 1) * 8))
                    .offset(y: i == 1 ? -6 : -1)
                    .shadow(color: .black.opacity(0.38), radius: 5, y: 3)
                    .zIndex(Double(i))
            }
        }
        .frame(width: width, height: 42)
    }

    private var roleIcon: String {
        switch seat % 3 {
        case 1: return "cup.and.saucer.fill"
        case 2: return "crown.fill"
        default: return "eyeglasses"
        }
    }

    private var reactionPill: some View {
        reactionBar
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(width: width)
            .background(
                Capsule()
                    .fill(LinearGradient(colors: [
                        reactionIsQuiet ? Color.white.opacity(0.045) : actionTint.opacity(0.24),
                        reactionIsQuiet ? Color.white.opacity(0.025) : Color(hex: 0x111018).opacity(0.82)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Capsule().strokeBorder(
                        reactionIsQuiet ? Tokens.slate.opacity(0.18) : actionTint.opacity(0.40),
                        lineWidth: 0.9))
                    .shadow(color: reactionIsQuiet ? .clear : actionTint.opacity(0.14), radius: 7, y: 3)
            )
    }

    private var reactionIsQuiet: Bool {
        actionTint == .clear || actionText == "bereit"
    }

    private var reactionBadge: some View {
        let quiet = reactionIsQuiet
        let tint = quiet ? Tokens.slate : actionTint
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [
                    tint.opacity(quiet ? 0.20 : 0.54),
                    Color(hex: 0x0B0910).opacity(0.94)
                ], center: .topLeading, startRadius: 2, endRadius: 24))
                .overlay(Circle().strokeBorder(tint.opacity(quiet ? 0.30 : 0.72), lineWidth: 1))
                .shadow(color: tint.opacity(quiet ? 0.08 : 0.24), radius: quiet ? 4 : 9, y: 3)

            Image(systemName: reactionIcon)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(quiet ? Tokens.slate.opacity(0.82) : Tokens.jewelPlatin.opacity(0.96))
                .symbolEffect(.pulse, options: .speed(0.75), value: isFocus)
        }
        .frame(width: 25, height: 25)
        .accessibilityHidden(true)
    }

    private var reactionSpeechBubble: some View {
        VStack(spacing: -1) {
            HStack(spacing: 5) {
                Image(systemName: reactionIcon)
                    .font(.system(size: 8.5, weight: .heavy))
                Text(actionText)
                    .font(.system(size: 9.5, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(Tokens.jewelPlatin.opacity(0.96))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: 94)
            .background(
                Capsule()
                    .fill(Color(hex: 0x121017).opacity(0.96))
                    .overlay(Capsule().strokeBorder(actionTint.opacity(0.60), lineWidth: 1))
                    .shadow(color: .black.opacity(0.46), radius: 8, y: 4)
            )

            Image(systemName: "triangle.fill")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(Color(hex: 0x121017).opacity(0.96))
                .rotationEffect(.degrees(180))
        }
        .accessibilityHidden(true)
    }

    private var reactionIcon: String {
        if actionText.contains("überlegt") { return "ellipsis" }
        if actionText.contains("passt") { return "xmark" }
        if actionText.contains("geht") { return "checkmark" }
        if actionText.contains("erhöht") { return "chevron.up" }
        if actionText.contains("pocht") || actionText.contains("setzt") { return "hand.tap.fill" }
        return isFocus ? "eye.fill" : "circle.fill"
    }

    private var reactionBar: some View {
        let quiet = actionTint == .clear || actionText == "bereit"
        return HStack(spacing: 5) {
            Circle()
                .fill(quiet ? Tokens.slate.opacity(0.42) : actionTint.opacity(0.92))
                .frame(width: 5.5, height: 5.5)
                .shadow(color: quiet ? .clear : actionTint.opacity(0.36), radius: 4)
            Text(actionText)
                .font(.system(size: 8.4, weight: quiet ? .semibold : .heavy))
                .tracking(quiet ? 0.1 : 0.25)
                .foregroundStyle(quiet ? Tokens.slate.opacity(0.78) : Tokens.jewelPlatin.opacity(0.96))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2.8)
        .frame(maxWidth: .infinity)
        .background(
            Capsule()
                .fill(LinearGradient(colors: [
                    quiet ? Color.white.opacity(0.045) : actionTint.opacity(0.24),
                    quiet ? Color.white.opacity(0.025) : Color(hex: 0x111018).opacity(0.82)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Capsule().strokeBorder(
                    quiet ? Tokens.slate.opacity(0.18) : actionTint.opacity(0.40),
                    lineWidth: 0.9))
                .shadow(color: quiet ? .clear : actionTint.opacity(0.14), radius: 7, y: 3)
        )
    }

    private func microStat(value: Int, suffix: String) -> some View {
        HStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 11.8, weight: .heavy))
                .foregroundStyle(Tokens.jewelGold.opacity(0.92))
                .contentTransition(.numericText())
            Text(suffix)
                .font(.system(size: 6.5, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(Tokens.slate.opacity(0.64))
        }
        .lineLimit(1)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 10.4, weight: .heavy))
                .foregroundStyle(Tokens.jewelGold.opacity(0.92))
            Text(label)
                .font(.system(size: 5.2, weight: .heavy))
                .tracking(0.25)
                .foregroundStyle(Tokens.slate.opacity(0.62))
        }
        .frame(maxWidth: .infinity)
    }
}

struct CoachHint: View {
    let seat: Int
    let name: String
    let text: String
    var tint: Color = Tokens.jewelGold
    var compact: Bool = false
    let morph: Namespace.ID?

    var body: some View {
        HStack(spacing: compact ? 6 : 9) {
            if !compact {
                OpponentPortrait(seat: seat,
                                 name: name,
                                 isActive: true,
                                 isFocus: true,
                                 size: 30,
                                 showsText: false,
                                 morph: morph)
            }
            Text(text)
                .font(.system(size: compact ? 10.5 : 11.5, weight: .semibold))
                .foregroundStyle(Tokens.jewelPlatin.opacity(compact ? 0.80 : 0.88))
                .lineLimit(compact ? 1 : 2)
                .minimumScaleFactor(0.82)
            Spacer(minLength: 0)
        }
        .padding(.leading, compact ? 12 : 8)
        .padding(.trailing, compact ? 12 : 11)
        .padding(.vertical, compact ? 5 : 7)
        .background(
            Capsule()
                .fill(LinearGradient(colors: [
                    Color(hex: 0x17141D).opacity(compact ? 0.68 : 0.92),
                    Color(hex: 0x0D0B11).opacity(compact ? 0.72 : 0.92)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Capsule().strokeBorder(tint.opacity(compact ? 0.18 : 0.28), lineWidth: 1))
                .shadow(color: .black.opacity(compact ? 0.18 : 0.36),
                        radius: compact ? 5 : 10,
                        y: compact ? 2 : 5)
        )
        .accessibilityLabel("\(name): \(text)")
    }
}

enum R1Colorway: CaseIterable, Sendable {
    case naturalWhite
    case terracotta
    case sage
    case slate

    fileprivate var face: Color {
        switch self {
        case .naturalWhite: Color(hex: 0xCEC7B8)
        case .terracotta: Color(hex: 0x9B5D48)
        case .sage: Color(hex: 0x758071)
        case .slate: Color(hex: 0x62666A)
        }
    }

    fileprivate var edge: Color {
        switch self {
        case .naturalWhite: Color(hex: 0x928B7D)
        case .terracotta: Color(hex: 0x693D31)
        case .sage: Color(hex: 0x4D564C)
        case .slate: Color(hex: 0x3D4145)
        }
    }
}

/// Track-A-Spielstein R1. `tint` bleibt vorerst als quellkompatibler Parameter
/// bestehen, bezeichnet aber ausdrücklich weder Pool noch Besitzer: Innerhalb
/// einer Partie verwenden alle Steine dieselbe keramische Farbwelt.
struct R1Token: View {
    var size: CGFloat
    var colorway: R1Colorway
    var markRotation: Double
    var surfaceVariant: Int
    var elevation: Double

    init(tint: Color = Tokens.jewelGold,
         size: CGFloat = 11,
         colorway: R1Colorway = .naturalWhite,
         markRotation: Double = 0,
         surfaceVariant: Int = 0,
         elevation: Double = 0) {
        // Legacy-Aufrufer übergeben weiterhin Pool-/Spielerfarben. R1 ignoriert
        // diese absichtlich, bis die zentralen Bühnen auf `R1Token` migriert sind.
        _ = tint
        self.size = size
        self.colorway = colorway
        self.markRotation = markRotation
        self.surfaceVariant = surfaceVariant
        self.elevation = min(max(elevation, 0), 1)
    }

    var body: some View {
        let surfaceCenter = UnitPoint(
            x: 0.40 + CGFloat(surfaceVariant % 3) * 0.07,
            y: 0.34 + CGFloat((surfaceVariant / 3) % 3) * 0.06
        )
        ZStack {
            // Weicher Höhenschatten: zeigt die 3-mm-Stärke, ohne den trockenen
            // Materialkontakt darunter aufzuweichen.
            Ellipse()
                .fill(Color.black.opacity(0.28 - elevation * 0.06))
                .frame(width: size * (0.94 + elevation * 0.05),
                       height: max(1, size * (0.18 + elevation * 0.025)))
                .blur(radius: size * 0.065)
                .offset(y: size * 0.43)

            // Harter Kontaktschatten: bleibt eng an der unteren Kante.
            Ellipse()
                .fill(Color.black.opacity(0.76 - elevation * 0.13))
                .frame(width: size * (0.84 + elevation * 0.04),
                       height: max(1, size * (0.10 + elevation * 0.018)))
                .blur(radius: size * 0.018)
                .offset(y: size * 0.40)

            // Sichtbare 3-mm-Kante mit feiner Rändelung. Die Kante ist bewusst
            // flach und trocken statt transparent, hochglänzend oder metallisch.
            Circle()
                .fill(colorway.edge)
                .frame(width: size * 0.97, height: size * 0.97)
                .offset(y: size * 0.045)
                .overlay {
                    Circle()
                        .strokeBorder(
                            AngularGradient(colors: [
                                Color.black.opacity(0.30),
                                Color.white.opacity(0.07),
                                Color.black.opacity(0.22),
                                Color.white.opacity(0.06),
                                Color.black.opacity(0.30)
                            ], center: .center),
                            lineWidth: max(0.55, size * 0.055)
                        )
                }
                .overlay {
                    Circle()
                        .strokeBorder(
                            Color.black.opacity(0.18),
                            style: StrokeStyle(
                                lineWidth: max(0.3, size * 0.014),
                                dash: [max(0.35, size * 0.016),
                                       max(0.5, size * 0.024)]
                            )
                        )
                        .padding(size * 0.01)
                }

            Circle()
                .fill(colorway.face)
                .overlay {
                    Circle()
                        .fill(
                            RadialGradient(colors: [
                                Color.white.opacity(0.075),
                                .clear,
                                Color.black.opacity(0.055)
                            ], center: surfaceCenter,
                               startRadius: size * 0.05,
                               endRadius: size * 0.62)
                        )
                }
                .overlay {
                    R1BlindEmboss()
                        .stroke(colorway.edge.opacity(0.30),
                                lineWidth: max(0.42, size * 0.025))
                        .padding(size * 0.20)
                        .rotationEffect(.degrees(markRotation))
                        .shadow(color: Color.white.opacity(0.08),
                                radius: 0,
                                x: -max(0.2, size * 0.01),
                                y: -max(0.2, size * 0.01))
                }
                .overlay(Circle().strokeBorder(Color.white.opacity(0.075),
                                               lineWidth: max(0.35, size * 0.016)))
                .padding(size * 0.055)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Übergangsname für noch nicht migrierte Bühnen. Neue Materialdarstellung
/// verwendet `R1Token`; der Alias verändert weder Farbe noch Physik.
typealias TableChip = R1Token

/// Tonale Blindprägung des rotationssymmetrischen Kartenrücken-Signets.
private struct R1BlindEmboss: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let width = rect.width * 0.48
        let height = rect.height * 0.48
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - height))
        path.addLine(to: CGPoint(x: center.x + width, y: center.y))
        path.addLine(to: CGPoint(x: center.x, y: center.y + height))
        path.addLine(to: CGPoint(x: center.x - width, y: center.y))
        path.closeSubpath()

        let coreWidth = width * 0.36
        let coreHeight = height * 0.36
        path.move(to: CGPoint(x: center.x, y: center.y - coreHeight))
        path.addLine(to: CGPoint(x: center.x + coreWidth, y: center.y))
        path.addLine(to: CGPoint(x: center.x, y: center.y + coreHeight))
        path.addLine(to: CGPoint(x: center.x - coreWidth, y: center.y))
        path.closeSubpath()
        return path
    }
}

/// R1-Steine liegen als natürlich geschichtete Gruppe in der Mulde. Der
/// Kontakt-Schatten bleibt hart, der Höhenschatten weich.
struct TableTokenPile: View {
    let count: Int
    let tint: Color
    var diameter: CGFloat
    var showCount = true
    var seed: UInt64 = 1_441
    var compartment: TravelCompartment = .center
    var tokenDiameterOverride: CGFloat?

    var body: some View {
        let poses = R1TokenSlots.layout(for: count,
                                        seed: seed,
                                        compartment: compartment)
        let tokenDiameter = tokenDiameterOverride
            ?? min(Tokens.tableTokenDiameter,
                   diameter * Tokens.tableTokenToFloorRatio)
        ZStack {
            ForEach(poses.indices, id: \.self) { index in
                let pose = poses[index]
                R1Token(tint: tint,
                        size: tokenDiameter,
                        markRotation: pose.rotation,
                        surfaceVariant: index,
                        elevation: pose.elevation / 0.22)
                    .offset(x: pose.offset.width * tokenDiameter,
                            y: pose.offset.height * tokenDiameter
                                - pose.elevation * tokenDiameter * 0.06)
                    .zIndex(pose.elevation * 100 + Double(index) * 0.01)
            }

            if showCount {
                Text("\(count)")
                    .font(.system(size: diameter * 0.17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Tokens.jewelPlatin)
                    .shadow(color: .black.opacity(0.92), radius: 2, y: 1)
                    .padding(.horizontal, diameter * 0.10)
                    .padding(.vertical, diameter * 0.025)
                    .background(Capsule().fill(Color.black.opacity(0.68)))
                    .offset(y: diameter * 0.30)
            }
        }
        .frame(width: diameter, height: diameter)
    }

}

/// Places a token group on the visible floor of a recessed board well. The
/// lower wall is redrawn in front of the tokens so they read as contained.
struct RecessedTokenPile: View {
    let count: Int
    let tint: Color
    var diameter: CGFloat
    var showCount = false
    var seed: UInt64 = 1_441
    var compartment: TravelCompartment = .center
    var tokenDiameterOverride: CGFloat?

    var body: some View {
        let floorDiameter = diameter * Tokens.outerWellFloorRatio
        let physicalTokenDiameter = tokenDiameterOverride ?? min(
            Tokens.tableTokenDiameter,
            floorDiameter * Tokens.tableTokenToFloorRatio
        )
        ZStack {
            TableTokenPile(count: count,
                           tint: tint,
                           diameter: floorDiameter,
                           showCount: showCount,
                           seed: seed,
                           compartment: compartment,
                           tokenDiameterOverride: physicalTokenDiameter)
                .offset(y: diameter * 0.025)
                .frame(width: floorDiameter, height: floorDiameter)
                .clipShape(Circle())

            R1WellFrontLip()
                .stroke(
                    LinearGradient(colors: [
                        Color.black.opacity(0.03),
                        Color.black.opacity(0.18)
                    ], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: max(0.55, diameter * 0.025),
                                       lineCap: .round)
                )
                .frame(width: diameter * 0.70, height: diameter * 0.70)
                .offset(y: diameter * 0.028)
                .allowsHitTesting(false)

        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}

/// Nur die vordere Wand der Mulde liegt vor den Steinen. Der textile Boden
/// bleibt frei von der früheren kreisförmigen Abdunklung.
private struct R1WellFrontLip: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                    radius: min(rect.width, rect.height) * 0.5,
                    startAngle: .degrees(18),
                    endAngle: .degrees(162),
                    clockwise: false)
        return path
    }
}

/// Gemeinsame Materialkante der beiden kanonischen Tischwelten. Die Basis
/// enthält bewusst weder Regeln noch Zählstände: zentrale Bühnen legen ihre
/// semantischen Pool-Overlays über dieselbe physische Grundplatte.
struct TableWorldBoardBase: View {
    let world: TableWorld
    let diameter: CGFloat

    @ViewBuilder
    var body: some View {
        switch world {
        case .pochDisc:
            Image("PochDisc2026")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: diameter, height: diameter)
                .accessibilityHidden(true)
        case .unterwegs:
            Image("TravelTray")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: diameter, height: diameter)
                .shadow(color: .black.opacity(0.48),
                        radius: diameter * 0.055,
                        y: diameter * 0.035)
                .accessibilityHidden(true)
        }
    }
}

/// Gemeinsame physische Kamera für Track A. Der Effekt sitzt absichtlich über
/// Board, Gravuren und Spielsteinen statt nur auf dem Rasterasset; dadurch
/// bleiben Muldenkontakt und Flugziele in derselben Perspektive.
private struct TableWorldSpatialPresentation: ViewModifier {
    let world: TableWorld
    let diameter: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        switch world {
        case .pochDisc:
            content
                .compositingGroup()
                .rotation3DEffect(
                    .degrees(Tokens.pochDiscPitch),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .center,
                    perspective: Tokens.pochDiscPerspective
                )
                .shadow(color: Color.black.opacity(0.70),
                        radius: diameter * Tokens.pochDiscShadowRadiusRatio,
                        x: diameter * 0.010,
                        y: diameter * Tokens.pochDiscShadowYOffsetRatio)
                .shadow(color: Tokens.jewelPlatin.opacity(0.035),
                        radius: diameter * Tokens.pochDiscAmbientLiftRatio,
                        x: -diameter * 0.010,
                        y: -diameter * 0.008)
        case .unterwegs:
            content
        }
    }
}

extension View {
    func tableWorldSpatialPresentation(world: TableWorld,
                                       diameter: CGFloat) -> some View {
        modifier(TableWorldSpatialPresentation(world: world, diameter: diameter))
    }
}

/// Ein einzelner regelneutraler Spielstein. Track A bleibt in einer Partie
/// durchgehend R1-Naturweiß; Track B wählt reproduzierbar eine der sechs
/// freigegebenen 1-Cent-Oberflächen.
struct TableWorldPiece: View {
    let world: TableWorld
    let size: CGFloat
    var seed: UInt64 = 1_441
    var index = 0
    var compartment: TravelCompartment = .center

    @ViewBuilder
    var body: some View {
        switch world {
        case .pochDisc:
            R1Token(size: size, colorway: .naturalWhite)
        case .unterwegs:
            TravelCentPiece(seed: seed,
                            index: index,
                            compartment: compartment,
                            size: size)
        }
    }
}

enum TableWorldPiecePlacement: Sendable {
    case free
    case well
}

/// Gemeinsame Haufen-Schnittstelle für zentrale Bühnen. `diameter` bezeichnet
/// die verfügbare Fläche beziehungsweise bei `.well` den sichtbaren
/// Muldendurchmesser. Bereits gelandete Steine behalten in beiden Welten ihren
/// deterministischen Slot, wenn der Zähler wächst.
struct TableWorldPiecePile: View {
    let world: TableWorld
    let count: Int
    let diameter: CGFloat
    var seed: UInt64 = 1_441
    var compartment: TravelCompartment = .center
    var placement: TableWorldPiecePlacement = .free
    var pieceDiameterOverride: CGFloat?

    @ViewBuilder
    var body: some View {
        switch world {
        case .pochDisc:
            switch placement {
            case .free:
                TableTokenPile(count: count,
                               tint: Tokens.jewelGold,
                               diameter: diameter,
                               showCount: false,
                               seed: seed,
                               compartment: compartment,
                               tokenDiameterOverride: pieceDiameterOverride)
            case .well:
                RecessedTokenPile(count: count,
                                  tint: Tokens.jewelGold,
                                  diameter: diameter,
                                  showCount: false,
                                  seed: seed,
                                  compartment: compartment,
                                  tokenDiameterOverride: pieceDiameterOverride)
            }
        case .unterwegs:
            TravelCoinPile(count: count,
                           seed: seed,
                           compartment: compartment,
                           wellDiameter: diameter)
        }
    }
}

/// Engraved board notation placed on the inner guide ring, never on the coin floor.
/// The mark remains readable when a well fills and keeps the physical bowl unobstructed.
struct PocketValueMarker: View {
    let world: TableWorld
    let pool: Pool
    let chips: Int
    let tint: Color
    var compact = false
    var showChipCount = true

    private var engraved: Bool { world == .pochDisc }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: compact ? 1.5 : 3) {
            Text(pool.indexLabel)
                .foregroundStyle(engraved
                    ? Tokens.jewelPlatin.opacity(compact ? 0.52 : 0.58)
                    : (pool.indexLabel.count > 2
                        ? Tokens.jewelPlatin.opacity(compact ? 0.84 : 0.96)
                        : tint.opacity(compact ? 0.90 : 1)))
            if showChipCount, chips > 0 {
                Text("·")
                    .foregroundStyle(Tokens.jewelGold.opacity(0.68))
                Text("\(chips)")
                    .foregroundStyle(Tokens.jewelGold.opacity(compact ? 0.88 : 1))
                    .contentTransition(.numericText())
            }
        }
        .font(.system(size: engraved
            ? (compact ? 5.5 : 7.4)
            : (compact ? 6.2 : 9.6),
            weight: engraved ? .semibold : .heavy,
            design: engraved ? .default : .rounded))
        .tracking(engraved
            ? (pool.indexLabel.count > 2 ? 0.18 : 0.48)
            : (pool.indexLabel.count > 2 ? (compact ? 0 : 0.25) : (compact ? 0.25 : 0.55)))
        .shadow(color: .black.opacity(engraved ? 0.55 : 0.95),
                radius: engraved ? 0.7 : (compact ? 1.5 : 2.5),
                y: engraved ? 0.4 : 1)
        .accessibilityLabel("\(pool.indexLabel), \(chips)")
    }
}

struct PocketTile: View {
    let pool: Pool
    let chips: Int
    let theme: Theme
    var diameter: CGFloat = Tokens.tileDiameter
    var showLabel: Bool = true
    var isPulsing: Bool = false

    var body: some View {
        let tint = theme.tint(pool)
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [
                    Color.white.opacity(0.065),
                    Color(hex: 0x15141A),
                    Color.black.opacity(0.72)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Circle().strokeBorder(Color.black.opacity(0.72), lineWidth: max(1, diameter * 0.05)))
                .overlay(Circle().strokeBorder(
                    LinearGradient(colors: [
                        tint.opacity(theme.isTravelTable ? 0.78 : 0.72),
                        tint.opacity(theme.isTravelTable ? 0.30 : 0.22)
                    ], startPoint: .top, endPoint: .bottom),
                    lineWidth: max(1, diameter * 0.045))
                    .padding(diameter * 0.075))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: max(0.5, diameter * 0.012))
                        .padding(diameter * 0.18)
                )
                .shadow(color: .black.opacity(0.45), radius: diameter * 0.12, y: diameter * 0.06)
                .shadow(color: tint.opacity(theme.glowOpacity * 0.55), radius: theme.tileGlow * 0.55)

            if chips > 0 {
                chipCluster(count: chips, tint: tint)
            } else if showLabel {
                Circle()
                    .fill(tint.opacity(theme.isTravelTable ? 0.50 : 0.42))
                    .frame(width: diameter * 0.08, height: diameter * 0.08)
            }
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(isPulsing ? 1.12 : 1)
    }

    private func chipCluster(count: Int, tint: Color) -> some View {
        TableTokenPile(count: count, tint: tint, diameter: diameter * 0.72, showCount: false)
    }
}

extension View {
    @ViewBuilder
    fileprivate func ifLet<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}
