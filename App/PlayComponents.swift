import PochKit
import SwiftUI

/// Shared table pieces. These are deliberately code-rendered so the app keeps
/// moving while final raster/3D assets are still being refined.

struct OpponentPortrait: View {
    let seat: Int
    let name: String
    var stack: Int? = nil
    var caption: String? = nil
    var isActive: Bool = true
    var isFocus: Bool = false
    var size: CGFloat = 62
    var showsText: Bool = true
    let morph: Namespace.ID?

    private var palette: (skin: Color, coat: Color, accent: Color) {
        switch seat % 3 {
        case 1:
            return (Color(hex: 0xC98E62), Color(hex: 0x253D3A), Tokens.jewelSmaragd)
        case 2:
            return (Color(hex: 0xD6A37A), Color(hex: 0x3A2639), Tokens.jewelAmethyst)
        default:
            return (Color(hex: 0xB97858), Color(hex: 0x3C3024), Tokens.jewelGold)
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            portrait
                .frame(width: size, height: size)
                .opacity(isActive ? 1 : 0.46)
                .saturation(isActive ? 1 : 0.22)
                .scaleEffect(isFocus ? 1.06 : 1)
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

            // Warm painterly placeholder: face, hair, coat and small gesture.
            // Final portraits can replace this without changing layout contracts.
            VStack(spacing: 0) {
                ZStack {
                    if seat == 2 {
                        Path { path in
                            path.move(to: CGPoint(x: size * 0.37, y: size * 0.32))
                            path.addLine(to: CGPoint(x: size * 0.63, y: size * 0.32))
                            path.addLine(to: CGPoint(x: size * 0.56, y: size * 0.20))
                            path.addLine(to: CGPoint(x: size * 0.44, y: size * 0.20))
                            path.closeSubpath()
                        }
                        .fill(Tokens.jewelGold.opacity(0.72))
                        .offset(y: -size * 0.08)
                    }
                    Circle()
                        .fill(LinearGradient(colors: [p.skin.opacity(0.98), p.skin.opacity(0.62)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: size * 0.36, height: size * 0.36)
                    Capsule()
                        .fill(Color(hex: 0x17100D).opacity(seat == 2 ? 0.25 : 0.55))
                        .frame(width: size * 0.33, height: size * 0.13)
                        .offset(y: -size * 0.12)
                    if seat == 2 {
                        HStack(spacing: size * 0.25) {
                            Capsule()
                                .fill(Color(hex: 0xE1B98A).opacity(0.46))
                            Capsule()
                                .fill(Color(hex: 0xE1B98A).opacity(0.46))
                        }
                        .frame(width: size * 0.46, height: size * 0.22)
                        .offset(y: size * 0.03)
                    }
                    if seat == 1 {
                        Capsule()
                            .fill(Color(hex: 0x24150F).opacity(0.65))
                            .frame(width: size * 0.18, height: size * 0.08)
                            .offset(y: size * 0.07)
                    }
                    if seat == 0 || seat == 3 {
                        HStack(spacing: size * 0.015) {
                            Circle().stroke(Color(hex: 0x141017).opacity(0.74), lineWidth: max(0.7, size * 0.018))
                            Rectangle()
                                .fill(Color(hex: 0x141017).opacity(0.62))
                                .frame(width: size * 0.05, height: max(0.6, size * 0.012))
                            Circle().stroke(Color(hex: 0x141017).opacity(0.74), lineWidth: max(0.7, size * 0.018))
                        }
                        .frame(width: size * 0.24, height: size * 0.07)
                        .offset(y: -size * 0.01)
                    } else {
                        HStack(spacing: size * 0.07) {
                            Circle().fill(Color(hex: 0x141017).opacity(0.75))
                            Circle().fill(Color(hex: 0x141017).opacity(0.75))
                        }
                        .frame(width: size * 0.17, height: size * 0.026)
                        .offset(y: -size * 0.01)
                    }
                    Path { path in
                        path.move(to: CGPoint(x: size * 0.49, y: size * 0.51))
                        path.addQuadCurve(to: CGPoint(x: size * 0.54, y: size * 0.51),
                                          control: CGPoint(x: size * 0.515, y: size * 0.55))
                    }
                    .stroke(Color(hex: 0x3A241E).opacity(0.38), lineWidth: max(0.6, size * 0.01))
                }
                .offset(y: size * 0.03)

                Path { path in
                    path.move(to: CGPoint(x: size * 0.25, y: size * 0.70))
                    path.addQuadCurve(to: CGPoint(x: size * 0.75, y: size * 0.70),
                                      control: CGPoint(x: size * 0.50, y: size * 0.49))
                    path.addLine(to: CGPoint(x: size * 0.82, y: size * 0.92))
                    path.addLine(to: CGPoint(x: size * 0.18, y: size * 0.92))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [p.coat.opacity(0.98), p.coat.opacity(0.54)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(
                    ZStack {
                        Path { path in
                            path.move(to: CGPoint(x: size * 0.5, y: size * 0.57))
                            path.addLine(to: CGPoint(x: size * 0.5, y: size * 0.90))
                        }
                        .stroke(p.accent.opacity(0.45), lineWidth: max(0.8, size * 0.018))

                        if seat == 1 {
                            RoundedRectangle(cornerRadius: size * 0.025)
                                .stroke(Tokens.jewelGold.opacity(0.34), lineWidth: max(0.6, size * 0.012))
                                .frame(width: size * 0.28, height: size * 0.16)
                                .offset(y: size * 0.18)
                        }
                    }
                )
                .frame(width: size, height: size * 0.42)
                .offset(y: -size * 0.02)
            }
            .clipShape(Circle())
        }
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
    var width: CGFloat = 110
    let morph: Namespace.ID?

    private var role: String {
        switch seat % 3 {
        case 1: return "ruhig"
        case 2: return "präzise"
        default: return "wach"
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [
                        Color(hex: 0x17141C).opacity(isActive ? 0.96 : 0.56),
                        Color(hex: 0x0C0B10).opacity(isActive ? 0.98 : 0.62)
                    ], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .strokeBorder((isFocus ? actionTint : Tokens.jewelGold).opacity(isFocus ? 0.72 : 0.24),
                                      lineWidth: isFocus ? 1.5 : 1))
                    .shadow(color: isFocus ? actionTint.opacity(0.18) : .black.opacity(0.28),
                            radius: isFocus ? 12 : 5, y: 4)

                VStack(spacing: 5) {
                    ZStack(alignment: .top) {
                        miniBacks
                            .offset(y: -5)
                        OpponentPortrait(seat: seat,
                                         name: name,
                                         isActive: isActive,
                                         isFocus: isFocus,
                                         size: 52,
                                         showsText: false,
                                         morph: morph)
                            .offset(y: 2)
                    }
                    .frame(height: 62)

                    VStack(spacing: 1) {
                        Text(name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isActive ? Tokens.jewelPlatin.opacity(0.92) : Tokens.slate.opacity(0.55))
                            .lineLimit(1)
                        Text(role.uppercased())
                            .font(.system(size: 7.5, weight: .semibold))
                            .tracking(1.1)
                            .foregroundStyle(Tokens.slate.opacity(0.64))
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        stat("\(cards)", "Karten")
                        stat("\(stack)", "Chips")
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 7)
                .padding(.bottom, 8)

                if isFocus {
                    Circle()
                        .fill(actionTint)
                        .frame(width: 8, height: 8)
                        .shadow(color: actionTint.opacity(0.45), radius: 5)
                        .padding(8)
                }
            }
            .frame(width: width, height: 124)

            Text(actionText)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(actionTint == .clear ? .clear : Tokens.jewelPlatin.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(width: width)
                .background(Capsule().fill(actionTint.opacity(actionTint == .clear ? 0 : 0.26)))
                .overlay(Capsule().strokeBorder(actionTint.opacity(actionTint == .clear ? 0 : 0.36), lineWidth: 0.8))
        }
        .opacity(isActive ? 1 : 0.46)
        .saturation(isActive ? 1 : 0.18)
        .animation(.easeInOut(duration: 0.28), value: isFocus)
        .animation(.easeInOut(duration: 0.28), value: isActive)
    }

    private var miniBacks: some View {
        HStack(spacing: -15) {
            ForEach(0..<3, id: \.self) { i in
                CardBack(scale: 0.56)
                    .opacity(isActive ? 0.82 : 0.56)
                    .rotationEffect(.degrees(Double(i - 1) * 10), anchor: .bottom)
                    .offset(y: CGFloat(abs(i - 1)) * 3)
                    .shadow(color: .black.opacity(0.42), radius: 8, y: 5)
            }
        }
        .padding(.top, 4)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Tokens.jewelGold.opacity(0.92))
            Text(label)
                .font(.system(size: label.count > 2 ? 5.7 : 6.5, weight: .bold))
                .foregroundStyle(Tokens.slate.opacity(0.62))
        }
        .frame(width: 32)
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

struct TableChip: View {
    var tint: Color = Tokens.jewelGold
    var size: CGFloat = 11

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [
                    tint.opacity(0.92),
                    tint.opacity(0.72),
                    Color(hex: 0x171018).opacity(0.62)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))

            Circle()
                .strokeBorder(Color.black.opacity(0.52), lineWidth: max(0.7, size * 0.055))
                .padding(size * 0.03)

            Circle()
                .strokeBorder(Tokens.jewelPlatin.opacity(0.26), lineWidth: max(0.45, size * 0.035))
                .padding(size * 0.12)

            Circle()
                .strokeBorder(Color.black.opacity(0.34), lineWidth: max(0.4, size * 0.025))
                .padding(size * 0.30)

            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * 45 * .pi / 180
                Capsule()
                    .fill(i % 2 == 0 ? Tokens.jewelPlatin.opacity(0.18) : Color.black.opacity(0.18))
                    .frame(width: max(0.7, size * 0.055), height: max(1.8, size * 0.18))
                    .rotationEffect(.radians(angle))
                    .offset(x: cos(angle) * size * 0.31,
                            y: sin(angle) * size * 0.31)
            }

            Circle()
                .fill(RadialGradient(colors: [
                    Tokens.jewelPlatin.opacity(0.18),
                    tint.opacity(0.18),
                    Color.clear
                ], center: .topLeading, startRadius: 0, endRadius: size * 0.42))
                .padding(size * 0.16)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottom) {
            Capsule()
                .fill(Color.black.opacity(0.22))
                .frame(width: size * 0.78, height: max(1.2, size * 0.10))
                .offset(y: size * 0.13)
        }
        .shadow(color: .black.opacity(0.48), radius: size * 0.20, y: size * 0.13)
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
                        tint.opacity(theme.isNeon ? 0.95 : 0.72),
                        tint.opacity(theme.isNeon ? 0.70 : 0.22)
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
                VStack(spacing: 1) {
                    Text(pool.indexLabel)
                        .font(.system(size: pool.indexLabel.count > 2 ? diameter * 0.14 : diameter * 0.22,
                                      weight: .bold))
                    Text("·")
                        .font(.system(size: diameter * 0.18, weight: .bold))
                }
                .foregroundStyle(tint.opacity(theme.isNeon ? 0.95 : 0.78))
            }
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(isPulsing ? 1.12 : 1)
    }

    private func chipCluster(count: Int, tint: Color) -> some View {
        let shown = min(max(count, 1), 7)
        return ZStack {
            ForEach(0..<shown, id: \.self) { i in
                let angle = Double(i) * 137.5 * .pi / 180
                let radius = CGFloat(i == 0 ? 0 : 1 + (i % 3)) * diameter * 0.055
                TableChip(tint: tint, size: diameter * 0.20)
                    .offset(x: cos(angle) * radius,
                            y: sin(angle) * radius - CGFloat(i) * diameter * 0.018)
                    .zIndex(Double(i))
            }
            Text("+\(count)")
                .font(.system(size: diameter * 0.17, weight: .heavy))
                .foregroundStyle(Tokens.jewelPlatin)
                .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
                .offset(y: diameter * 0.28)
        }
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
