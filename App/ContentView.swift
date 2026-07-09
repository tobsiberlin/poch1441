import PochKit
import SwiftUI

/// Spieltisch-Container: Phase 1 (Melde-Tableau, Poch-Ring) und Phase 2 (Pochen, §6b).
/// Der echte Phasen-Morph (.matchedGeometryEffect, §5b) folgt, sobald das Phase-3-Layout
/// steht - bis dahin schaltet ein harter Wechsel die Akte um.
struct ContentView: View {
    /// Die drei Akte (§5b) als View-Fortschritt; die Engine steht nach dem Melden
    /// bereits in .betting. Der echte Morph ersetzt später die harten Schnitte.
    private enum Akt: Equatable { case melden, pochen, ausspielen }
    private enum AppOverlay { case menu, tutorial, help, settings }

    @State private var game = GameState()
    /// DEBUG-Launch-Args "-pochenStart"/"-ausspielStart" öffnen Akt 2/3 direkt
    /// (Screenshot-/QA-Läufe ohne Tap).
    @State private var akt: Akt = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ausspielStart") { return .ausspielen }
        if ProcessInfo.processInfo.arguments.contains("-pochenStart") { return .pochen }
        #endif
        return .melden
    }()
    /// Theme-Umschalter (§7): Premium (matt) ↔ Vivid-Electronic/„Neon" (strahlend).
    /// Ab Start verfügbar; DEBUG-Launch-Arg "-neon YES", später Settings-Toggle.
    @AppStorage("neon") private var neon = false
    @AppStorage("sound") private var sound = true
    @AppStorage("haptics") private var haptics = true
    @AppStorage("assistHints") private var assistHints = true
    @AppStorage("tableEffects") private var tableEffects = true
    @AppStorage("moveCoach") private var moveCoach = false
    private var theme: Theme { neon ? .neon : .premium }
    @State private var activeOverlay: AppOverlay?
    @State private var phaseCurtain: Akt?
    @State private var guidedRoundActive = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Phasen-Morph (§5b): ein Namespace über alle drei Akte - Tokens, Poch-Tile und
    /// Mulden fliegen via matchedGeometryEffect an ihre neuen Positionen.
    @Namespace private var morph

    var body: some View {
        ZStack {
            // Material-Tiefe: warmes Bühnenlicht hinter dem Ring, Vignette zum Rand (kein Flat-Void).
            RadialGradient(gradient: Gradient(colors: [Tokens.bgLift, Tokens.bgDeep]),
                           center: UnitPoint(x: 0.5, y: 0.42), startRadius: 6, endRadius: 540)
                .ignoresSafeArea()
            phaseAtmosphere
            VStack(spacing: 0) {
                header
                switch akt {
                case .melden:
                    phase1Stage
                case .pochen:
                    Phase2View(game: game, theme: theme, morph: morph,
                               assistHints: assistHints,
                               onContinue: {
                                   transition(to: .ausspielen)
                                   game.beginPlayoutPresentation()
                               },
                               onNewRound: startNewRound)
                case .ausspielen:
                    Phase3View(game: game, theme: theme, morph: morph,
                               assistHints: assistHints,
                               onNewRound: startNewRound)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            // Phase 1: kein Bottom-Padding - Kartenfächer blendet am Bildschirmrand aus
            .padding(.bottom, akt == .melden ? 0 : 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // Trumpf-Beat-Inszenierung liegt als hitTest-freie Schicht über Akt 1
            .overlay { if akt == .melden && tableEffects { DealOverlay(game: game) } }
            .overlay(alignment: .topTrailing) { utilityButtons }
            // Kollaps-Vignette: farbgetönter Wimpernschlag (§6a e);
            // reduceMotion: 50-ms-Dissolve statt Flash (§6 Auflage 2)
            .overlay {
                if tableEffects, game.kollapsShock > 0, let info = game.kollapsInfo, akt == .melden {
                    KollapsVignette(tint: theme.tint(info.pool),
                                    duration: reduceMotion ? 0.05 : Tokens.kollapsFlash)
                        .id("vignette\(game.kollapsShock)")
                        .allowsHitTesting(false)
                }
            }
            .overlay { overlayPanel }
            .overlay(alignment: .bottom) {
                if (guidedRoundActive || (assistHints && moveCoach)), activeOverlay == nil {
                    guidedCoachRail
                        .padding(.horizontal, 22)
                        .padding(.bottom, guidedCoachBottomPadding)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay {
                if let phaseCurtain {
                    phaseCurtainView(phaseCurtain)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.18), value: phaseCurtain)
        }
        .onAppear {
            if akt == .melden { game.runDealPresentation(reduceMotion: reduceMotion) }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: haptics ? game.hapticTick : 0)
        .sensoryFeedback(.impact(weight: .heavy), trigger: haptics ? game.kollapsShock : 0)
        #if DEBUG
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-pochenStart") {
                transition(to: .pochen)
            }
            if args.contains("-ausspielStart") {
                game.debugSkipToPlayout()
                transition(to: .ausspielen)
                if args.contains("-roundEnd") {
                    game.debugFinishPlayout()
                } else if args.contains("-roundPunishing") {
                    game.debugShowPunishingEnd()
                }
                if !args.contains("-holdPlayout") {
                    game.beginPlayoutPresentation()
                }
                // -autoLead: niedrigste Karte anspielen (Kaskaden-QA ohne UI-Tap)
                if args.contains("-autoLead"),
                   let card = game.displayedHand(of: 0)
                       .min(by: { $0.rank.rawValue < $1.rank.rawValue }) {
                    game.humanLead(card)
                }
            }
            // -kollapsDemo: Threshold auf 1 - jede Meldung zündet (Kollaps-QA)
            if args.contains("-kollapsDemo") {
                GameState.kollapsThresholdOverride = 1
            }
            // -pochDemo: automatisches Eröffnungs-Gebot für die Tischschlag-QA
            if args.contains("-pochDemo") {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.5))
                    if let legal = game.humanLegal, let open = legal.openRange {
                        game.humanOpen(min(3, open.upperBound))
                    }
                }
            }
            // -morphDemo: automatischer Akt-Durchlauf für die Bewegungs-QA (Video ohne Tap)
            if args.contains("-morphDemo") {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    transition(to: .pochen)
                    try? await Task.sleep(for: .seconds(3))
                    game.debugSkipToPlayout()
                    transition(to: .ausspielen)
                    if !args.contains("-holdPlayout") {
                        game.beginPlayoutPresentation()
                    }
                }
            }
            if args.contains("-roundEnd"), !args.contains("-ausspielStart") {
                game.debugFinishPlayout()
                transition(to: .ausspielen)
            }
            if args.contains("-roundPunishing"), !args.contains("-ausspielStart") {
                game.debugShowPunishingEnd()
                transition(to: .ausspielen)
            }
            if args.contains("-neon") || args.contains("-vivid") {
                neon = true
            }
            if args.contains("-premium") {
                neon = false
            }
            if args.contains("-tutorialSeed") {
                startGuidedRound()
            }
            if args.contains("-guided") {
                guidedRoundActive = true
                moveCoach = true
            }
            if args.contains("-dealDone") || args.contains("-skipDeal") {
                game.skipDeal()
            }
            if args.contains("-tutorial") {
                activeOverlay = .tutorial
            } else if args.contains("-help") {
                activeOverlay = .help
            } else if args.contains("-settings") {
                activeOverlay = .settings
            } else if args.contains("-menu") || args.contains("-pause") {
                activeOverlay = .menu
            }
        }
        #endif
    }

    private var phaseAtmosphere: some View {
        let opacity = theme.isNeon ? 0.22 : 0.12
        return ZStack {
            switch akt {
            case .melden:
                RadialGradient(colors: [
                    Tokens.jewelGold.opacity(opacity * 0.56),
                    Tokens.jewelSmaragd.opacity(opacity * 0.42),
                    .clear
                ], center: UnitPoint(x: 0.50, y: 0.44), startRadius: 60, endRadius: 410)
                RadialGradient(colors: [
                    Tokens.jewelGold.opacity(opacity * 0.28),
                    .clear
                ], center: UnitPoint(x: 0.52, y: 0.73), startRadius: 28, endRadius: 270)
            case .pochen:
                RadialGradient(colors: [
                    Tokens.jewelAmethyst.opacity(opacity * 0.90),
                    .clear
                ], center: UnitPoint(x: 0.20, y: 0.50), startRadius: 20, endRadius: 310)
                RadialGradient(colors: [
                    Tokens.jewelGold.opacity(opacity * 0.36),
                    .clear
                ], center: UnitPoint(x: 0.72, y: 0.32), startRadius: 24, endRadius: 250)
            case .ausspielen:
                RadialGradient(colors: [
                    Tokens.jewelSmaragd.opacity(opacity * 0.88),
                    .clear
                ], center: UnitPoint(x: 0.50, y: 0.46), startRadius: 42, endRadius: 340)
                RadialGradient(colors: [
                    Tokens.jewelPlatin.opacity(opacity * 0.22),
                    .clear
                ], center: UnitPoint(x: 0.50, y: 0.78), startRadius: 26, endRadius: 250)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.45), value: akt)
        .animation(.easeInOut(duration: 0.28), value: theme.isNeon)
    }

    private func startNewRound() {
        guidedRoundActive = false
        game.newRound()
        transition(to: .melden)
        game.runDealPresentation(reduceMotion: reduceMotion)
    }

    private func startGuidedRound() {
        guidedRoundActive = true
        moveCoach = true
        activeOverlay = nil
        game.startTutorialRound()
        transition(to: .melden)
        game.runDealPresentation(reduceMotion: reduceMotion)
    }

    private func transition(to next: Akt) {
        withAnimation(.spring(duration: Tokens.aktMorph)) { akt = next }
        showPhaseCurtain(next)
    }

    private func showPhaseCurtain(_ next: Akt) {
        guard tableEffects, !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.16)) { phaseCurtain = next }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(850))
            guard phaseCurtain == next else { return }
            withAnimation(.easeOut(duration: 0.18)) { phaseCurtain = nil }
        }
    }

    @ViewBuilder private func phaseCurtainView(_ target: Akt) -> some View {
        let copy = curtainCopy(target)
        PhaseCurtain(phase: copy.phase,
                     title: copy.title,
                     subtitle: copy.subtitle,
                     tint: copy.tint)
    }

    private func curtainCopy(_ target: Akt) -> (phase: String, title: String, subtitle: String, tint: Color) {
        switch target {
        case .melden:
            return ("PHASE 1", "MELDEN",
                    "Werte sammeln. Die Mitte bleibt fuer den Schluss.",
                    Tokens.jewelGold)
        case .pochen:
            return ("PHASE 2", "POCHEN",
                    "Paar zeigen, Druck machen, Limit lesen.",
                    Tokens.jewelAmethyst)
        case .ausspielen:
            return ("PHASE 3", "AUSSPIELEN",
                    "Ketten laufen. Wer zuerst leer ist, gewinnt die Mitte.",
                    Tokens.jewelSmaragd)
        }
    }

    // MARK: - Kopf

    private var aktLabel: (phase: String, title: String, tint: Color) {
        switch akt {
        case .melden: return ("PHASE 1", "MELDEN", Tokens.jewelGold)
        case .pochen: return ("PHASE 2", "POCHEN", Tokens.amethystVivid.opacity(0.85))
        case .ausspielen: return ("PHASE 3", "AUSSPIELEN", Tokens.smaragdVivid.opacity(0.85))
        }
    }

    private var header: some View {
        let label = aktLabel
        return VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text("POCH").font(.system(size: 26, weight: .bold)).foregroundStyle(Tokens.jewelPlatin)
                Text("1441").font(.system(size: 26, weight: .light)).foregroundStyle(Tokens.jewelGold)
            }
            VStack(spacing: 1) {
                Text(label.phase)
                    .font(.system(size: 8.5, weight: .heavy))
                    .tracking(2.1)
                    .foregroundStyle(Tokens.slate.opacity(0.72))
                Text(label.title)
                    .font(.system(size: 19, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(Tokens.jewelPlatin)
                    .shadow(color: label.tint.opacity(theme.isNeon ? 0.28 : 0.10),
                            radius: theme.isNeon ? 9 : 4, y: 2)
            }
            trumpChip
            if guidedRoundActive {
                guidedPill
            }
        }
    }

    private var guidedPill: some View {
        Text(guidedRoundActive ? "GEFÜHRTE RUNDE" : "ZUG-BEGLEITER")
            .font(.system(size: 8.5, weight: .heavy))
            .tracking(1.4)
            .foregroundStyle(Tokens.bgDeep)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(guidedTint.opacity(0.92)))
            .shadow(color: guidedTint.opacity(0.18), radius: 8, y: 3)
    }

    private var guidedTint: Color {
        switch akt {
        case .melden: return Tokens.jewelGold
        case .pochen: return Tokens.jewelAmethyst
        case .ausspielen: return Tokens.jewelSmaragd
        }
    }

    private var guidedCoachBottomPadding: CGFloat {
        switch akt {
        case .melden: return 106
        case .pochen: return 430
        case .ausspielen: return 196
        }
    }

    private var guidedCoachRail: some View {
        let copy = guidedCopy
        return HStack(spacing: 10) {
            Text(copy.step)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Tokens.bgDeep)
                .frame(width: 30, height: 30)
                .background(Circle().fill(guidedTint))
            VStack(alignment: .leading, spacing: 3) {
                Text(copy.title)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Tokens.jewelPlatin)
                Text(copy.text)
                    .font(.system(size: 10.7, weight: .semibold))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.76))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button {
                withAnimation(.easeOut(duration: 0.16)) {
                    guidedRoundActive = false
                    moveCoach = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Tokens.slate)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(hex: 0x111018).opacity(0.94))
                .overlay(Capsule().strokeBorder(guidedTint.opacity(0.28), lineWidth: 1))
                .shadow(color: .black.opacity(0.44), radius: 18, y: 9)
        )
    }

    private var guidedCopy: (step: String, title: String, text: String) {
        switch akt {
        case .melden:
            let openPools = PochRing.anchors
                .map(\.pool)
                .filter { game.displayedChips(in: $0) > 0 }
                .prefix(2)
                .map(\.indexLabel)
                .joined(separator: " · ")
            let focus = openPools.isEmpty ? "Suche Wertungen in Hand und Tisch." : "Jetzt zahlen: \(openPools)."
            return ("1/3", "Melden lesen", "\(focus) Die Mitte bleibt fürs Finale.")
        case .pochen:
            guard game.turnIndex == 0, let legal = game.humanLegal else {
                return ("2/3", "Druck lesen", "\(game.name(of: game.turnIndex)) entscheidet. Achte auf Einsatz, Wand und Reaktion.")
            }
            let current = game.betting.currentBet
            let callCost = max(0, current - game.betting.seats[0].committed)
            if let range = legal.openRange {
                return ("2/3", "Pochen eröffnen", "Du hast ein Paar. \(range.lowerBound)-\(range.upperBound) Chips setzen; klein testet, hoch erzwingt Antwort.")
            }
            if let range = legal.raiseRange {
                return ("2/3", "Antwort erzwingen", "Mitgehen kostet \(callCost). Erhöhen bis \(range.upperBound) baut Druck, Passen spart Chips.")
            }
            if legal.canCall {
                return ("2/3", "Mitgehen oder raus", "Mitgehen kostet \(callCost) und hält dich im Pott. Passen beendet dein Risiko.")
            }
            return ("2/3", "Keine Poch-Hand", "Ohne Paar bleibt nur Passen. Lies die Gegner, bevor die Kartenkette startet.")
        case .ausspielen:
            guard let playout = game.playout else {
                return ("3/3", "Kartenstrom", "Die Mitte wartet. Wer zuerst leer ist, nimmt den Hauptpott.")
            }
            if playout.leader == 0, game.cascadeIdle {
                let first = game.displayedHand(of: 0).first.map { "\($0.rank.index)\($0.suit.symbol)" } ?? "eine Karte"
                return ("3/3", "Kette starten", "Du führst. \(first) ist bereit; niedrig starten hält Anschlusskarten offen.")
            }
            if game.cascadeIdle {
                return ("3/3", "Neues Anspiel", "\(game.name(of: playout.leader)) führt. Der letzte Leger bestimmt die nächste Kette.")
            }
            return ("3/3", "Kette läuft", "Folgekarten springen automatisch. Beim Riss friert der Moment, dann führt der letzte Leger.")
        }
    }

    private var utilityButtons: some View {
        HStack(spacing: 8) {
            Button { activeOverlay = .menu } label: {
                Image(systemName: "pause.fill")
                    .font(.system(size: 13, weight: .semibold))
            }
            Button { activeOverlay = .tutorial } label: {
                Image(systemName: "graduationcap")
                    .font(.system(size: 14, weight: .semibold))
            }
            Button { activeOverlay = .help } label: {
                Image(systemName: "questionmark")
                    .font(.system(size: 14, weight: .semibold))
            }
            Button { activeOverlay = .settings } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Tokens.jewelPlatin.opacity(0.86))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Capsule().fill(.black.opacity(0.24))
            .overlay(Capsule().strokeBorder(Tokens.jewelGold.opacity(0.18), lineWidth: 1)))
        .padding(.top, 6)
        .padding(.trailing, 2)
        .scaleEffect(0.82, anchor: .topTrailing)
    }

    @ViewBuilder private var overlayPanel: some View {
        if let activeOverlay {
            ZStack {
                Color.black.opacity(0.56)
                    .ignoresSafeArea()
                    .onTapGesture { self.activeOverlay = nil }

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(overlayTitle(activeOverlay))
                                .font(.system(size: 24, weight: .heavy))
                                .foregroundStyle(Tokens.jewelPlatin)
                            Text(overlaySubtitle(activeOverlay))
                                .font(.system(size: 10.5, weight: .semibold))
                                .tracking(1.3)
                                .foregroundStyle(overlayTint(activeOverlay).opacity(0.82))
                        }
                        Spacer()
                        Button { self.activeOverlay = nil } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Tokens.slate)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(.white.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                    }

                    if activeOverlay == .menu {
                        menuPhaseStrip
                    } else {
                        overlayTabs(activeOverlay)
                    }

                    ScrollView(showsIndicators: false) {
                        switch activeOverlay {
                        case .menu:
                            menuContent
                        case .tutorial:
                            tutorialContent
                        case .help:
                            helpContent
                        case .settings:
                            settingsContent
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: 78)
                    }
                    .frame(maxHeight: 436)

                    overlayFooter(activeOverlay)
                }
                .padding(20)
                .frame(maxWidth: 356)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient(colors: [Color(hex: 0x17141D), Color(hex: 0x0B0A10)],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay(RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(Tokens.jewelGold.opacity(0.25), lineWidth: 1))
                        .shadow(color: .black.opacity(0.65), radius: 28, y: 16)
                )
                .padding(.horizontal, 18)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
            .animation(.spring(duration: 0.28), value: self.activeOverlay != nil)
        }
    }

    private func overlayTitle(_ overlay: AppOverlay) -> String {
        switch overlay {
        case .menu: return "Pause"
        case .tutorial: return "Tutorial"
        case .help: return "Spielhilfe"
        case .settings: return "Einstellungen"
        }
    }

    private func overlaySubtitle(_ overlay: AppOverlay) -> String {
        switch overlay {
        case .menu: return "WEITER · HILFE · TISCH"
        case .tutorial: return "DREI AKTE · EIN RHYTHMUS"
        case .help: return "REGELN · MULDE · KETTE"
        case .settings: return "PREMIUM · VIVID · FEEDBACK"
        }
    }

    private func overlayTint(_ overlay: AppOverlay) -> Color {
        switch overlay {
        case .menu: return guidedTint
        case .tutorial: return Tokens.jewelGold
        case .help: return Tokens.jewelSmaragd
        case .settings: return Tokens.jewelAmethyst
        }
    }

    private func overlayTabs(_ selected: AppOverlay) -> some View {
        HStack(spacing: 6) {
            overlayTab(.tutorial, selected: selected, icon: "graduationcap.fill", title: "Lernen")
            overlayTab(.help, selected: selected, icon: "book.closed.fill", title: "Regeln")
            overlayTab(.settings, selected: selected, icon: "slider.horizontal.3", title: "Tisch")
        }
        .padding(4)
        .background(Capsule().fill(Color.white.opacity(0.045))
            .overlay(Capsule().strokeBorder(Tokens.jewelGold.opacity(0.14), lineWidth: 1)))
    }

    private func overlayTab(_ overlay: AppOverlay, selected: AppOverlay,
                            icon: String, title: String) -> some View {
        let active = overlay == selected
        let tint = overlayTint(overlay)
        return Button { activeOverlay = overlay } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9.5, weight: .bold))
                Text(title)
                    .font(.system(size: 10.5, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(active
                             ? overlayActiveForeground(overlay)
                             : Tokens.jewelPlatin.opacity(0.70))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(Capsule().fill(active ? tint.opacity(0.92) : Color.clear))
        }
        .buttonStyle(.plain)
    }

    private var tutorialContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            coachBubble("Wirt", "Merke dir nur den Rhythmus: erst Mulden lesen, dann Druck machen, dann Karten leer spielen.")
            tutorialProgressStrip
            phaseGuide("1", "Melden", "Außenmulden zahlen sofort. Die Mitte bleibt liegen.",
                       tint: Tokens.jewelGold, visual: .ring)
            phaseGuide("2", "Pochen", "Paar? Dann bietest du um die Poch-Mulde.",
                       tint: Tokens.jewelAmethyst, visual: .bid)
            phaseGuide("3", "Ausspielen", "Ketten laufen. Wer zuerst leer ist, nimmt die Mitte.",
                       tint: Tokens.jewelSmaragd, visual: .fan)
            overlayStep("✓", "Intuitiver Tisch", "Gold zeigt Werte, Violett den Poch, Grün die Sequenz, Platin die Mitte.")
        }
    }

    private var menuPhaseStrip: some View {
        HStack(spacing: 8) {
            phaseToken("1", "Melden", active: akt == .melden, tint: Tokens.jewelGold)
            Capsule().fill(Tokens.slate.opacity(0.18)).frame(height: 1)
            phaseToken("2", "Pochen", active: akt == .pochen, tint: Tokens.jewelAmethyst)
            Capsule().fill(Tokens.slate.opacity(0.18)).frame(height: 1)
            phaseToken("3", "Ausspielen", active: akt == .ausspielen, tint: Tokens.jewelSmaragd)
        }
        .padding(.horizontal, 4)
    }

    private func phaseToken(_ mark: String, _ title: String, active: Bool, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(mark)
                .font(.system(size: 9.5, weight: .heavy))
                .foregroundStyle(active ? Tokens.bgDeep : Tokens.slate)
                .frame(width: 24, height: 24)
                .background(Circle().fill(active ? tint : Color.white.opacity(0.055)))
                .overlay(Circle().strokeBorder(tint.opacity(active ? 0.0 : 0.25), lineWidth: 1))
            Text(title)
                .font(.system(size: 8.2, weight: .semibold))
                .foregroundStyle(active ? Tokens.jewelPlatin : Tokens.slate.opacity(0.72))
                .lineLimit(1)
        }
        .frame(width: 64)
    }

    private var menuContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            overlayHero(menuHeroTitle, menuHeroText, tint: guidedTint)
            HStack(spacing: 8) {
                menuMetric("Phase", menuMetricPhase, guidedTint)
                menuMetric("Trumpf", "\(game.upcard.rank.index)\(game.upcard.suit.symbol)", Tokens.jewelGold)
                menuMetric("Mitte", "\(game.displayedChips(in: .center))", Tokens.jewelPlatin)
            }
            VStack(spacing: 8) {
                menuActionButton("Weiter spielen", systemImage: "play.fill", tint: guidedTint) {
                    activeOverlay = nil
                }
                HStack(spacing: 8) {
                    menuActionButton("Regeln", systemImage: "book.closed.fill", tint: Tokens.jewelSmaragd) {
                        activeOverlay = .help
                    }
                    menuActionButton("Tisch", systemImage: "slider.horizontal.3", tint: Tokens.jewelAmethyst) {
                        activeOverlay = .settings
                    }
                }
                HStack(spacing: 8) {
                    menuActionButton("Tutorial", systemImage: "graduationcap.fill", tint: Tokens.jewelGold) {
                        activeOverlay = .tutorial
                    }
                    menuActionButton("Neue Runde", systemImage: "arrow.clockwise", tint: Tokens.jewelRose) {
                        activeOverlay = nil
                        startNewRound()
                    }
                }
            }
            if guidedRoundActive {
                overlayStep("✓", "Geführte Runde aktiv", "Der Coach bleibt am Tisch und erklärt nur den nächsten Schritt.")
            } else {
                overlayStep("?", "Lernen ohne Druck", "Starte jederzeit eine geführte Runde über das Tutorial.")
            }
        }
    }

    private var menuHeroTitle: String {
        switch akt {
        case .melden: return "Tisch angehalten"
        case .pochen: return "Druckmoment pausiert"
        case .ausspielen: return "Kartenstrom pausiert"
        }
    }

    private var menuHeroText: String {
        switch akt {
        case .melden:
            return "Meldewerte und Mitte bleiben sichtbar. Du kannst fortsetzen, Regeln prüfen oder den Tisch neu starten."
        case .pochen:
            return "Der Einsatzstand bleibt erhalten. Prüfe Hilfe oder Einstellungen, ohne den Bietfluss zu verlieren."
        case .ausspielen:
            return "Anspielrecht, Centerpot und Hand bleiben erhalten. Der nächste Kartenimpuls wartet auf dich."
        }
    }

    private var menuMetricPhase: String {
        switch akt {
        case .melden: return "1"
        case .pochen: return "2"
        case .ausspielen: return "3"
        }
    }

    private func menuMetric(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 7.4, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(Tokens.slate.opacity(0.76))
            Text(value)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.038))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(tint.opacity(0.22), lineWidth: 1)))
    }

    private func menuActionButton(_ title: String, systemImage: String, tint: Color,
                                  action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 12.5, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(Tokens.jewelPlatin.opacity(0.94))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.white.opacity(0.052))
                .overlay(Capsule().strokeBorder(tint.opacity(0.34), lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    private var helpContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            overlayHero("Schnellhilfe", "Alles Wichtige bleibt am Tisch sichtbar. Diese Seite ist die kompakte Regelkarte.")
            rulesGrid
            visualRuleExamples
            glossaryStrip
            overlayStep("A", "9 Mulden", "A, K, Q, J, 10, Mariage, Sequenz, Poch und Mitte. Außen wird gemeldet, innen wird am Ende gewonnen.")
            overlayStep("K", "Mariage", "König und Dame einer Farbe. In Trumpf zählt sie stärker.")
            overlayStep("Q", "Sequenz", "Zusammenhängende Karten einer Farbe. Trumpf entscheidet, wenn nötig.")
            overlayStep("J", "Poch", "Bieten nur mit Paar. Passen gibt Information, Mitgehen hält Druck, Erhöhen setzt die Wand.")
            overlayStep("10", "Ketten", "Ausspielen läuft aufsteigend weiter. Fehlt die nächste Karte, wechselt das Anspiel.")
        }
    }

    private var glossaryStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Begriffe")
                .font(.system(size: 13.5, weight: .heavy))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.92))
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                glossaryChip("Trumpf", "entscheidet Gleichstand", Tokens.jewelGold)
                glossaryChip("Mitte", "Hauptpott am Ende", Tokens.jewelPlatin)
                glossaryChip("Wand", "aktuelles Bietlimit", Tokens.jewelAmethyst)
                glossaryChip("Kette", "laufende Kartenfolge", Tokens.jewelSmaragd)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.032))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Tokens.jewelGold.opacity(0.16), lineWidth: 1)))
    }

    private func glossaryChip(_ title: String, _ text: String, _ tint: Color) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(tint.opacity(0.82))
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11.5, weight: .heavy))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.92))
                Text(text)
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(Tokens.slate)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.black.opacity(0.20))
            .overlay(Capsule().strokeBorder(tint.opacity(0.20), lineWidth: 1)))
    }

    private var visualRuleExamples: some View {
        VStack(spacing: 8) {
            visualRuleExample("Melden",
                              "Werte und Figuren räumen Außenmulden ab.",
                              tint: Tokens.jewelGold,
                              visual: .meld)
            visualRuleExample("Pochen",
                              "Ein Paar öffnet den Pott. Die Wand begrenzt Druck.",
                              tint: Tokens.jewelAmethyst,
                              visual: .poch)
            visualRuleExample("Ausspielen",
                              "Ketten laufen weiter, bis die nächste Karte fehlt.",
                              tint: Tokens.jewelSmaragd,
                              visual: .play)
        }
    }

    private enum RuleExampleVisual { case meld, poch, play }

    private func visualRuleExample(_ title: String, _ text: String,
                                   tint: Color,
                                   visual: RuleExampleVisual) -> some View {
        HStack(spacing: 12) {
            ruleExampleVisual(visual, tint: tint)
                .frame(width: 82, height: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13.5, weight: .heavy))
                    .foregroundStyle(tint)
                Text(text)
                    .font(.system(size: 10.6, weight: .medium))
                    .foregroundStyle(Tokens.slate)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.035))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(tint.opacity(0.20), lineWidth: 1)))
    }

    @ViewBuilder private func ruleExampleVisual(_ visual: RuleExampleVisual, tint: Color) -> some View {
        switch visual {
        case .meld:
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(Color.black.opacity(0.40))
                        .overlay(Circle().strokeBorder(i == 2 ? tint.opacity(0.82) : tint.opacity(0.35),
                                                       lineWidth: i == 2 ? 1.8 : 1))
                        .frame(width: 27, height: 27)
                        .offset(x: CGFloat(i - 2) * 17, y: CGFloat(abs(i - 2)) * 4 - 1)
                }
                HStack(spacing: -10) {
                    CardFace(card: Card(suit: .spades, rank: .ace), scale: 0.34)
                    CardFace(card: Card(suit: .diamonds, rank: .queen), scale: 0.34)
                }
                .rotationEffect(.degrees(-7), anchor: .bottom)
                .offset(x: -24, y: 7)
                HStack(spacing: -2) {
                    ForEach(0..<3, id: \.self) { i in
                        TableChip(tint: tint, size: 8.5)
                            .offset(y: CGFloat(i) * -2)
                    }
                }
                .offset(x: 28, y: 7)
            }
        case .poch:
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.34))
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Tokens.jewelGold.opacity(0.25), lineWidth: 1))
                    .frame(width: 16, height: 52)
                    .offset(x: -36)
                RoundedRectangle(cornerRadius: 5)
                    .fill(tint.opacity(0.72))
                    .frame(width: 10, height: 22)
                    .offset(x: -36, y: 13)
                HStack(spacing: -14) {
                    CardFace(card: Card(suit: .hearts, rank: .king), scale: 0.38)
                    CardFace(card: Card(suit: .clubs, rank: .king), scale: 0.38)
                }
                .offset(x: 0, y: 4)
                Circle()
                    .fill(Color.black.opacity(0.44))
                    .overlay(Circle().strokeBorder(tint.opacity(0.60), lineWidth: 1.5))
                    .frame(width: 34, height: 34)
                    .offset(x: 37, y: 8)
                Text("7")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(tint)
                    .offset(x: 37, y: 8)
            }
        case .play:
            ZStack {
                HStack(spacing: -13) {
                    CardFace(card: Card(suit: .clubs, rank: .seven), scale: 0.38)
                        .rotationEffect(.degrees(-10), anchor: .bottom)
                    CardFace(card: Card(suit: .clubs, rank: .eight), scale: 0.38)
                    CardFace(card: Card(suit: .clubs, rank: .nine), scale: 0.38)
                        .rotationEffect(.degrees(10), anchor: .bottom)
                }
                .offset(x: -10, y: 4)
                Circle()
                    .fill(tint.opacity(0.85))
                    .frame(width: 8, height: 8)
                    .offset(x: 38, y: -17)
                Text("RISS")
                    .font(.system(size: 7.5, weight: .heavy))
                    .tracking(0.7)
                    .foregroundStyle(tint)
                    .offset(x: 39, y: -4)
            }
        }
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            overlayHero("Tischgefühl", "Form bleibt gleich. Du steuerst nur Intensität, Hilfe und Feedback.")
            themePreview
            settingToggle("Vivid Theme", "Sattere Juwelenfarben, gleiche Premium-Geometrie.", isOn: $neon, tint: Tokens.smaragdVivid)
            settingToggle("Sound", "Vorbereitet für Münzen, Tischschlag und Kartenstrom.", isOn: $sound, tint: Tokens.jewelGold)
            settingToggle("Haptik", "Münzflüge, Poch-Schlag und Kettenstopps fühlbar machen.", isOn: $haptics, tint: Tokens.jewelGold)
            settingToggle("Assist-Hinweise", "Kurze Kontext-Hinweise, ohne verdeckte Karten zu verraten.", isOn: $assistHints, tint: Tokens.jewelSmaragd)
            settingToggle("Zug-Begleiter", "Erklärt Optionen, Risiko und nächsten Fokus während der Runde.", isOn: $moveCoach, tint: Tokens.jewelSmaragd)
            settingToggle("Tischeffekte", "Kartenwölbung, Schatten, Münzstrom und kurze Akzente.", isOn: $tableEffects, tint: Tokens.jewelAmethyst)
            settingRow("Bewegung", "Folgt iOS Reduce Motion", tint: Tokens.slate)
            settingRow("Sprache", "Deutsch · vorbereitet", tint: Tokens.jewelSmaragd)
            settingRow("Tutorial", "Wiederholen über den Hut-Button", tint: Tokens.jewelGold)
            settingRow("Rechtliches", "Impressum/Datenschutz vorbereitet", tint: Tokens.slate)
            HStack(spacing: 8) {
                overlayInlineButton("Neue Runde", tint: Tokens.jewelGold) {
                    activeOverlay = nil
                    startNewRound()
                }
                overlayInlineButton("Tutorial", tint: Tokens.jewelSmaragd) {
                    activeOverlay = .tutorial
                }
            }
            #if DEBUG
            settingRow("DEBUG", "-pochenStart · -ausspielStart · -holdPlayout", tint: Tokens.amethystVivid)
            #endif
        }
    }

    private var themePreview: some View {
        HStack(spacing: 10) {
            themeSwatch(title: "Premium",
                        subtitle: "matt",
                        selected: !neon,
                        vivid: false) {
                withAnimation(.easeOut(duration: 0.18)) { neon = false }
            }
            themeSwatch(title: "Vivid",
                        subtitle: "satter",
                        selected: neon,
                        vivid: true) {
                withAnimation(.easeOut(duration: 0.18)) { neon = true }
            }
        }
    }

    private func themeSwatch(title: String, subtitle: String, selected: Bool,
                             vivid: Bool, action: @escaping () -> Void) -> some View {
        let palette = vivid
            ? [Tokens.goldVivid, Tokens.roseVivid, Tokens.smaragdVivid, Tokens.amethystVivid]
            : [Tokens.jewelGold, Tokens.jewelRose, Tokens.jewelSmaragd, Tokens.jewelAmethyst]
        let stroke = selected ? Tokens.jewelPlatin.opacity(0.62) : Tokens.jewelGold.opacity(0.16)

        return Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [
                            Color(hex: 0x24212A).opacity(vivid ? 0.95 : 0.76),
                            Color(hex: 0x07060A)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(Circle().strokeBorder(Tokens.jewelGold.opacity(vivid ? 0.38 : 0.22), lineWidth: 1))
                        .frame(width: 48, height: 48)
                    ForEach(0..<8, id: \.self) { i in
                        Circle()
                            .strokeBorder(palette[i % palette.count].opacity(vivid ? 0.92 : 0.68),
                                          lineWidth: vivid ? 2.2 : 1.4)
                            .background(Circle().fill(Color.black.opacity(0.36)))
                            .frame(width: 10, height: 10)
                            .offset(y: -18)
                            .rotationEffect(.degrees(Double(i) * 45))
                    }
                    Circle()
                        .fill(Color.black.opacity(0.42))
                        .overlay(Circle().strokeBorder(Tokens.jewelPlatin.opacity(vivid ? 0.56 : 0.34), lineWidth: 1))
                        .frame(width: 18, height: 18)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .heavy))
                        .foregroundStyle(selected ? Tokens.jewelPlatin : Tokens.jewelPlatin.opacity(0.74))
                    Text(subtitle.uppercased())
                        .font(.system(size: 8.5, weight: .heavy))
                        .tracking(1.1)
                        .foregroundStyle((vivid ? Tokens.smaragdVivid : Tokens.jewelGold).opacity(selected ? 0.9 : 0.48))
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 13)
                .fill(Color.white.opacity(selected ? 0.060 : 0.032))
                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(stroke, lineWidth: selected ? 1.2 : 1)))
        }
        .buttonStyle(.plain)
    }

    private var tutorialProgressStrip: some View {
        HStack(spacing: 8) {
            tutorialBeat("1", "Melden", Tokens.jewelGold)
            Capsule().fill(Tokens.slate.opacity(0.25)).frame(height: 1)
            tutorialBeat("2", "Pochen", Tokens.jewelAmethyst)
            Capsule().fill(Tokens.slate.opacity(0.25)).frame(height: 1)
            tutorialBeat("3", "Ausspielen", Tokens.jewelSmaragd)
        }
        .padding(.horizontal, 4)
    }

    private func tutorialBeat(_ mark: String, _ title: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(mark)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Tokens.bgDeep)
                .frame(width: 24, height: 24)
                .background(Circle().fill(tint))
            Text(title)
                .font(.system(size: 8.2, weight: .semibold))
                .foregroundStyle(Tokens.slate)
                .lineLimit(1)
        }
        .frame(width: 58)
    }

    @ViewBuilder private func overlayFooter(_ overlay: AppOverlay) -> some View {
        switch overlay {
        case .menu:
            overlayPrimaryButton("Weiter spielen", tint: guidedTint) {
                activeOverlay = nil
            }
        case .tutorial:
            overlayPrimaryButton("Geführte Runde starten", tint: Tokens.jewelGold) {
                startGuidedRound()
            }
        case .help:
            HStack(spacing: 8) {
                overlayInlineButton("Tutorial", tint: Tokens.jewelGold) {
                    activeOverlay = .tutorial
                }
                overlayInlineButton("Schließen", tint: Tokens.jewelSmaragd) {
                    activeOverlay = nil
                }
            }
        case .settings:
            overlayPrimaryButton("Fertig", tint: Tokens.jewelAmethyst) {
                activeOverlay = nil
            }
        }
    }

    private func overlayPrimaryButton(_ title: String, tint: Color,
                                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13.5, weight: .heavy))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.94))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    Capsule()
                        .fill(LinearGradient(colors: [
                            Color.white.opacity(0.07),
                            tint.opacity(0.23),
                            Color.black.opacity(0.20)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(Capsule().strokeBorder(tint.opacity(0.58), lineWidth: 1))
                        .shadow(color: .black.opacity(0.34), radius: 10, y: 5)
                )
        }
        .buttonStyle(.plain)
    }

    private func overlayInlineButton(_ title: String, tint: Color,
                                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.92))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color.white.opacity(0.045))
                    .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    private func overlayActiveForeground(_ overlay: AppOverlay) -> Color {
        overlay == .settings || overlay == .menu ? Tokens.jewelPlatin : Tokens.bgDeep
    }

    private func overlayHero(_ title: String, _ text: String, tint: Color = Tokens.jewelGold) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Tokens.slate)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.045))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(tint.opacity(0.18), lineWidth: 1)))
    }

    private enum GuideVisual { case ring, bid, fan }

    private func coachBubble(_ name: String, _ text: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            OpponentPortrait(seat: 1,
                             name: name,
                             isActive: true,
                             isFocus: true,
                             size: 44,
                             showsText: false,
                             morph: morph)
            VStack(alignment: .leading, spacing: 3) {
                Text(name.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.6)
                    .foregroundStyle(Tokens.jewelGold.opacity(0.86))
                Text(text)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.045))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Tokens.jewelGold.opacity(0.18), lineWidth: 1)))
    }

    private func phaseGuide(_ mark: String, _ title: String, _ text: String,
                            tint: Color, visual: GuideVisual) -> some View {
        HStack(spacing: 12) {
            guideVisual(visual, tint: tint)
                .frame(width: 74, height: 58)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(mark)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Tokens.bgDeep)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(tint))
                    Text(title)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Tokens.jewelPlatin)
                }
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Tokens.slate)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.035))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(tint.opacity(0.20), lineWidth: 1)))
    }

    @ViewBuilder private func guideVisual(_ visual: GuideVisual, tint: Color) -> some View {
        switch visual {
        case .ring:
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.22))
                    .overlay(Circle().strokeBorder(Tokens.jewelGold.opacity(0.40), lineWidth: 1))
                    .frame(width: 54, height: 54)
                ForEach(0..<8, id: \.self) { i in
                    Circle()
                        .fill(i % 2 == 0 ? Tokens.jewelGold.opacity(0.88) : tint.opacity(0.80))
                        .frame(width: 7, height: 7)
                        .offset(y: -22)
                        .rotationEffect(.degrees(Double(i) * 45))
                }
                Circle()
                    .fill(Tokens.jewelPlatin.opacity(0.22))
                    .overlay(Circle().strokeBorder(Tokens.jewelPlatin.opacity(0.45), lineWidth: 1))
                    .frame(width: 23, height: 23)
            }
        case .bid:
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.black.opacity(0.30))
                    .overlay(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(tint.opacity(0.72))
                            .frame(width: 13, height: 29)
                            .padding(.bottom, 4)
                    }
                    .overlay(RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(Tokens.jewelGold.opacity(0.26), lineWidth: 1))
                    .frame(width: 24, height: 52)
                VStack(spacing: 3) {
                    Text("POTT")
                        .font(.system(size: 6, weight: .heavy))
                        .tracking(0.8)
                        .foregroundStyle(Tokens.slate)
                    Text("7")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(tint)
                }
                .frame(width: 38, height: 38)
                .background(Circle().fill(tint.opacity(0.16))
                    .overlay(Circle().strokeBorder(tint.opacity(0.48), lineWidth: 1)))
            }
        case .fan:
            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Color.black.opacity(0.18), lineWidth: 1))
                        .frame(width: 28, height: 40)
                        .rotationEffect(.degrees(Double(i - 1) * 13))
                        .offset(x: CGFloat(i - 1) * 13, y: CGFloat(abs(i - 1)) * 2)
                        .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
                }
                Circle()
                    .fill(Color(hex: 0x17141D))
                    .overlay(Circle().strokeBorder(tint.opacity(0.74), lineWidth: 1.5))
                    .frame(width: 28, height: 28)
                    .offset(y: 10)
            }
        }
    }

    private var rulesGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ruleTile("A K Q J 10", "Werte", Tokens.jewelGold)
            ruleTile("K+Q", "Mariage", Tokens.jewelRose)
            ruleTile("7-10", "Sequenz", Tokens.jewelSmaragd)
            ruleTile("Paar", "Poch", Tokens.jewelAmethyst)
            ruleTile("Mitte", "Finale", Tokens.jewelPlatin)
            ruleTile("Leer", "Sieg", Tokens.smaragdVivid)
        }
    }

    private func ruleTile(_ mark: String, _ title: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(mark)
                .font(.system(size: mark.count > 5 ? 9 : 12, weight: .heavy))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Tokens.slate)
                .lineLimit(1)
        }
        .frame(height: 46)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10)
            .fill(Color.white.opacity(0.035))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(tint.opacity(0.20), lineWidth: 1)))
    }

    private func overlayStep(_ mark: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(mark)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Tokens.bgDeep)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Tokens.jewelGold))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Tokens.jewelPlatin)
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Tokens.slate)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func settingRow(_ title: String, _ value: String, tint: Color) -> some View {
        HStack {
            Circle().fill(tint.opacity(0.75)).frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.9))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Tokens.slate)
        }
        .padding(.vertical, 2)
    }

    private func settingToggle(_ title: String, _ text: String,
                               isOn: Binding<Bool>, tint: Color) -> some View {
        HStack(spacing: 12) {
            Circle().fill(tint.opacity(0.78)).frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.94))
                Text(text)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Tokens.slate)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(tint)
        }
        .padding(.vertical, 2)
    }

    private var trumpChip: some View {
        let up = game.upcard
        // Der Trumpf bleibt verdeckt, bis der Beat ihn flippt (§6a)
        let revealed = game.trumpRevealed || akt != .melden
        return HStack(spacing: 5) {
            Text("Trumpf").font(.system(size: 12, weight: .medium)).foregroundStyle(Tokens.slate)
            Text(revealed ? "\(up.rank.index)\(up.suit.symbol)" : "· ·")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(revealed
                                 ? (up.suit.isRed ? Color(hex: 0xD07A85) : Tokens.jewelPlatin)
                                 : Tokens.slate)
                .contentTransition(.opacity)
                .animation(.easeIn(duration: 0.2), value: revealed)
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(Capsule().fill(.white.opacity(0.05))
            .overlay(Capsule().strokeBorder(Tokens.jewelGold.opacity(0.35), lineWidth: 1)))
        .padding(.top, 3)
    }

    // MARK: - §5c Phase-1: Gegner als schmale Top-Bar

    private var opponentTopBar: some View {
        HStack(spacing: 20) {
            ForEach(1..<4, id: \.self) { seat in
                OpponentPortrait(seat: seat,
                                 name: game.name(of: seat),
                                 stack: game.displayedStack(of: seat),
                                 isActive: true,
                                 isFocus: false,
                                 size: 34,
                                 morph: morph)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.3), value: game.meldShown)
            }
        }
        .padding(.top, 10)
    }

    // MARK: - Der Poch-Ring

    /// Phase 1 folgt dem Mockup: Brett als Hauptdarsteller, keine Gegnerleiste im
    /// ersten Blick, Kartenfächer als unterer Bleed.
    private var phase1Stage: some View {
        VStack(spacing: 0) {
            ringView
                .contentShape(Circle())
                .onTapGesture {
                    if game.humanDealtVisible < game.humanHand.count {
                        game.skipDeal()
                    } else {
                        transition(to: .pochen)
                    }
                }
                .modifier(TableShake(
                    amplitude: reduceMotion ? 0 : Tokens.kollapsShakeAmp,
                    animatableData: CGFloat(game.kollapsShock)))
                .animation(.linear(duration: Tokens.kollapsShake),
                           value: game.kollapsShock)
                .padding(.top, 4)
            Spacer(minLength: 0)
            handView
        }
    }

    private var ringView: some View {
        let d = Tokens.ringRadius * 2 + Tokens.tileDiameter
        let overlayRadius = Tokens.ringRadius * 0.78
        // .position statt .offset: echte Layout-Frames, damit matchedGeometryEffect
        // beim Morph die korrekten Flugbahnen misst (§5b).
        return ZStack {
            Image("PochRingPM49")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: d, height: d)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.70), radius: 18, y: 10)
                .position(x: d / 2, y: d / 2)
                .overlay {
                    if theme.isNeon {
                        Circle()
                            .strokeBorder(Tokens.smaragdVivid.opacity(0.12), lineWidth: 10)
                            .blur(radius: 6)
                    }
                }
            centerTile
                .position(x: d / 2, y: d / 2)
            ForEach(PochRing.anchors) { anchor in
                pm49PoolOverlay(anchor.pool)
                    .matchedGeometryEffect(
                        id: anchor.pool == .poch ? "pochPot" : "tile-\(anchor.pool.rawValue)",
                        in: morph)
                    .position(x: d / 2 + pm49Offset(anchor.angle, radius: overlayRadius).width,
                              y: d / 2 + pm49Offset(anchor.angle, radius: overlayRadius).height)
            }
        }
        .frame(width: d, height: d)
    }

    private func pm49Offset(_ angle: Double, radius: CGFloat) -> CGSize {
        let rad = angle * .pi / 180
        return CGSize(width: radius * sin(rad), height: -radius * cos(rad))
    }

    private func pm49PoolOverlay(_ pool: Pool) -> some View {
        let pulsing = game.pulsingPool == pool
        let chips = game.displayedChips(in: pool)
        let tint = theme.tint(pool)
        return ZStack {
            if pulsing {
                PoolWinAccent(tint: tint, chips: chips)
                    .transition(.scale(scale: 0.82).combined(with: .opacity))
            }
            if chips > 0 {
                ZStack {
                    ForEach(0..<min(chips, 7), id: \.self) { i in
                        let angle = Double(i) * 137.5 * .pi / 180
                        let radius = CGFloat(i % 3) * 3.6
                        TableChip(tint: tint, size: 10.5)
                            .offset(x: cos(angle) * radius,
                                    y: sin(angle) * radius - CGFloat(i) * 0.5)
                            .zIndex(Double(i))
                    }
                    Text("+\(chips)")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Tokens.jewelPlatin)
                        .shadow(color: .black.opacity(0.9), radius: 2, y: 1)
                        .offset(y: 21)
                        .contentTransition(.numericText())
                }
            } else {
                VStack(spacing: 3) {
                    Text(pool.indexLabel)
                        .font(.system(size: pool.indexLabel.count > 2 ? 8 : 14, weight: .heavy))
                    Text("·")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(tint.opacity(theme.isNeon ? 0.95 : 0.74))
                .shadow(color: .black.opacity(0.85), radius: 2, y: 1)
            }
        }
        .frame(width: 58, height: 58)
        .scaleEffect(pulsing ? 1.12 : 1)
        .animation(.spring(duration: 0.25), value: pulsing)
        .animation(.easeOut(duration: 0.3), value: game.meldShown)
    }

    /// Kurzer Melde-/Gewinnakzent direkt in der PM49-Mulde: Materialkanten und
    /// kleine Messing-Splitter statt Glow. Dadurch ist klar, welche Schatulle zahlt.
    private struct PoolWinAccent: View {
        let tint: Color
        let chips: Int
        @State private var fired = false

        var body: some View {
            ZStack {
                Circle()
                    .strokeBorder(
                        LinearGradient(colors: [
                            tint.opacity(fired ? 0.10 : 0.78),
                            Tokens.jewelPlatin.opacity(fired ? 0.04 : 0.42)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: fired ? 1.2 : 3.4)
                    .frame(width: fired ? 53 : 42, height: fired ? 53 : 42)
                    .opacity(fired ? 0 : 1)

                ForEach(0..<8, id: \.self) { i in
                    let angle = Double(i) * 45 * .pi / 180
                    Capsule()
                        .fill(i % 2 == 0 ? tint.opacity(0.88) : Tokens.jewelGold.opacity(0.72))
                        .frame(width: 2.1, height: 7.5)
                        .rotationEffect(.radians(angle + .pi / 2))
                        .offset(x: (fired ? 28 : 17) * cos(angle),
                                y: (fired ? 28 : 17) * sin(angle))
                        .opacity(fired ? 0 : 0.92)
                        .animation(.easeOut(duration: 0.42).delay(Double(i) * 0.012), value: fired)
                }

                Text("+\(chips)")
                    .font(.system(size: 11.5, weight: .heavy))
                    .foregroundStyle(Tokens.jewelPlatin)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.58))
                        .overlay(Capsule().strokeBorder(tint.opacity(0.38), lineWidth: 0.8)))
                    .offset(y: fired ? -15 : -2)
                    .opacity(fired ? 0 : 1)
                    .shadow(color: .black.opacity(0.7), radius: 3, y: 1)
                    .animation(.easeOut(duration: 0.48), value: fired)
            }
            .frame(width: 58, height: 58)
            .onAppear {
                fired = false
                withAnimation(.easeOut(duration: 0.52)) { fired = true }
            }
        }
    }

    private var centerTile: some View {
        let chips = game.displayedChips(in: .center)
        return ZStack {
            if chips > 0 {
                ZStack {
                    ForEach(0..<min(chips, 10), id: \.self) { i in
                        let angle = Double(i) * 137.5 * .pi / 180
                        let radius = CGFloat(i % 4) * 4.2
                        TableChip(tint: Tokens.jewelPlatin.opacity(0.9), size: 13)
                            .offset(x: cos(angle) * radius,
                                    y: sin(angle) * radius - CGFloat(i) * 0.6)
                    }
                    Text("\(chips)")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(Tokens.jewelPlatin)
                        .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
                        .offset(y: 28)
                        .contentTransition(.numericText())
                }
            } else {
                VStack(spacing: 2) {
                    Text("MITTE").font(.system(size: 8, weight: .semibold)).tracking(1)
                    Text("·").font(.system(size: 22, weight: .bold))
                }
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.82))
                .shadow(color: .black.opacity(0.9), radius: 2, y: 1)
            }
        }
        .frame(width: Tokens.centerDiameter, height: Tokens.centerDiameter)
    }

    // MARK: - Hand (Mockup-Fächer: groß, angewinkelt, Bleed am unteren Bildschirmrand)

    private var handView: some View {
        let cards = Array(game.humanHand.prefix(game.humanDealtVisible))
        let N = cards.count
        // Fächer-Parameter: breite Spreizung, Karten leicht überlappend, Mockup-Optik
        let spreadDeg = min(Double(N) * 7.0, 38.0)
        let totalW: CGFloat = min(CGFloat(N) * 30, 224)
        let cardScale: CGFloat = 1.62

        return ZStack {
            ForEach(Array(cards.enumerated()), id: \.offset) { i, card in
                let t: CGFloat = N > 1 ? CGFloat(i) / CGFloat(N - 1) : 0.5
                let angle = N > 1 ? -spreadDeg / 2 + Double(t) * spreadDeg : 0
                let xOff: CGFloat = N > 1 ? -totalW / 2 + t * totalW : 0

                CardFace(card: card, scale: cardScale)
                    .offset(x: xOff)
                    .rotationEffect(.degrees(angle), anchor: .bottom)
                    .zIndex(Double(i))
                    .transition(.scale(scale: 0.86, anchor: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.12), value: game.humanDealtVisible)
        // Nur ~60% der Kartenhöhe sichtbar - Rest blendet am Bildschirmrand aus
        .frame(height: 74 * cardScale * 0.62)
    }
}

#Preview { ContentView() }
