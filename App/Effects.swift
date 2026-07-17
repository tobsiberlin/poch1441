import AVFoundation
import os
import SwiftUI

/// Gemeinsame, deterministische Tischphysik. Die Funktionen liefern nur
/// Präsentationswerte; Regeln und Spielzustand bleiben vollständig in PochKit.
enum PhysicalMotion {
    static let materialSettle = Animation.timingCurve(0.22, 0.72, 0.18, 1,
                                                      duration: 0.34)

    static func travel(duration: Double) -> Animation {
        .timingCurve(0.22, 0.72, 0.18, 1.0, duration: duration)
    }

    static func duration(from: CGPoint,
                         to: CGPoint,
                         pointsPerSecond: CGFloat,
                         minimum: Double,
                         maximum: Double) -> Double {
        let distance = hypot(to.x - from.x, to.y - from.y)
        return min(maximum, max(minimum, Double(distance / pointsPerSecond)))
    }

    static func shallowArcHeight(from: CGPoint,
                                 to: CGPoint,
                                 minimum: CGFloat,
                                 maximum: CGFloat) -> CGFloat {
        let distance = hypot(to.x - from.x, to.y - from.y)
        return min(maximum, max(minimum, distance * 0.075))
    }

    static func quadraticPoint(progress: CGFloat,
                               from: CGPoint,
                               to: CGPoint,
                               arcHeight: CGFloat,
                               lateralBias: CGFloat = 0) -> CGPoint {
        let t = min(max(progress, 0), 1)
        let inverse = 1 - t
        let control = CGPoint(x: (from.x + to.x) / 2 + lateralBias,
                              y: (from.y + to.y) / 2 - arcHeight)
        return CGPoint(
            x: inverse * inverse * from.x + 2 * inverse * t * control.x + t * t * to.x,
            y: inverse * inverse * from.y + 2 * inverse * t * control.y + t * t * to.y
        )
    }
}

enum R1ContactSurface: Sendable {
    case outerWell
    case centerWell
}

enum R1HapticStrength: Equatable, Sendable {
    case light
    case medium
    case heavy
}

/// Ein einziger deterministischer Kontaktvertrag für Ton und Haptik. Das
/// Zielfeld prägt die Resonanz, die Gruppengröße nur die Intensität des ersten
/// gebündelten Kontakts - weitere Steine lösen keine Feedbacksalve aus.
struct R1ContactDynamics: Equatable, Sendable {
    let hapticStrength: R1HapticStrength
    let audioVolume: Float

    static func resolve(surface: R1ContactSurface,
                        groupSize: Int) -> R1ContactDynamics {
        let bundledCount = max(1, groupSize)
        switch (surface, bundledCount) {
        case (.outerWell, 1):
            return R1ContactDynamics(hapticStrength: .light,
                                     audioVolume: 0.48)
        case (.outerWell, 2...3):
            return R1ContactDynamics(hapticStrength: .medium,
                                     audioVolume: 0.52)
        case (.outerWell, _):
            return R1ContactDynamics(hapticStrength: .medium,
                                     audioVolume: 0.56)
        case (.centerWell, 1):
            return R1ContactDynamics(hapticStrength: .medium,
                                     audioVolume: 0.54)
        case (.centerWell, 2...3):
            return R1ContactDynamics(hapticStrength: .medium,
                                     audioVolume: 0.58)
        case (.centerWell, _):
            return R1ContactDynamics(hapticStrength: .heavy,
                                     audioVolume: 0.60)
        }
    }
}

/// Kontaktfeedback für R1. Der aufrufende Presentation Director ändert den
/// Trigger ausschließlich in `ImpactFlight.onImpact`; dieses Modul besitzt
/// weder Timeline noch Timer und mutiert keinen sichtbaren Spielzustand.
struct R1ContactFeedback: ViewModifier {
    let trigger: Int
    let groupSize: Int
    let surface: R1ContactSurface

    @AppStorage("sound") private var soundEnabled = true
    @AppStorage("haptics") private var hapticsEnabled = true

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(trigger: trigger) { previous, current in
                guard hapticsEnabled, previous != current else { return nil }
                let dynamics = R1ContactDynamics.resolve(surface: surface,
                                                         groupSize: groupSize)
                switch dynamics.hapticStrength {
                case .light:
                    return .impact(weight: .light)
                case .medium:
                    return .impact(weight: .medium)
                case .heavy:
                    return .impact(weight: .heavy)
                }
            }
            .onAppear {
                guard soundEnabled else { return }
                R1ContactAudio.shared.prepare()
            }
            .onChange(of: soundEnabled) { _, enabled in
                guard enabled else { return }
                R1ContactAudio.shared.prepare()
            }
            .onChange(of: trigger) { previous, current in
                guard soundEnabled, previous != current else { return }
                R1ContactAudio.shared.play(surface: surface,
                                           groupSize: groupSize,
                                           variantSeed: current)
            }
    }
}

extension View {
    /// An eine stabile Bühnenwurzel hängen. `trigger` muss genau im
    /// `onImpact`-Callback wechseln, gemeinsam mit Kompression und Zähler.
    func r1ContactFeedback(trigger: Int,
                           groupSize: Int = 1,
                           surface: R1ContactSurface = .outerWell) -> some View {
        modifier(R1ContactFeedback(trigger: trigger,
                                   groupSize: max(1, groupSize),
                                   surface: surface))
    }
}

@MainActor
private final class R1ContactAudio {
    static let shared = R1ContactAudio()

    private static let log = Logger(subsystem: "com.tobc.poch1441",
                                    category: "R1ContactAudio")
    private let outerVariants = [
        "r1-ceramic-outer-01",
        "r1-ceramic-outer-02",
        "r1-ceramic-outer-03"
    ]
    private let centerVariants = [
        "r1-ceramic-center-01",
        "r1-ceramic-center-02",
        "r1-ceramic-center-03"
    ]
    private var players: [String: AVAudioPlayer] = [:]
    private var lastContactTime: TimeInterval = -.infinity

    func prepare() {
        for name in outerVariants + centerVariants {
            _ = player(named: name)
        }
    }

    func play(surface: R1ContactSurface,
              groupSize: Int,
              variantSeed: Int) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastContactTime >= 0.12 else { return }

        let variants = surface == .centerWell ? centerVariants : outerVariants
        let index = Int(UInt(bitPattern: variantSeed) % UInt(variants.count))
        let name = variants[index]
        guard let player = player(named: name) else { return }
        let dynamics = R1ContactDynamics.resolve(surface: surface,
                                                 groupSize: groupSize)

        lastContactTime = now
        player.currentTime = 0
        player.volume = dynamics.audioVolume
        player.play()
    }

    private func player(named name: String) -> AVAudioPlayer? {
        if let cached = players[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "caf") else {
            Self.log.error("Missing R1 contact sound: \(name, privacy: .public)")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            players[name] = player
            return player
        } catch {
            Self.log.error("Unable to prepare R1 contact sound: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

/// Tisch-Zittern für den Poch-Schlag: N volle Oszillationen pro Trigger,
/// endet exakt bei 0 (Integer-Zustände sind Ruhelage) - nur Offset, kein
/// Layout-Thrashing (§9). Geteilt zwischen Phase 1 und 2.
struct TableShake: GeometryEffect {
    var amplitude: Double
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let x = amplitude * sin(Double(animatableData) * .pi * 6)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

struct PhaseCurtain: View {
    let phase: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                Text(phase)
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2.2)
                    .foregroundStyle(tint.opacity(0.92))
                Text(title)
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(Tokens.jewelPlatin)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Tokens.slate)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: 330)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: [
                        Color(hex: 0x17141D),
                        Color(hex: 0x0B0A10)
                    ], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(tint.opacity(0.34), lineWidth: 1))
                    .shadow(color: .black.opacity(0.62), radius: 26, y: 14)
            )
        }
        .allowsHitTesting(false)
    }
}
