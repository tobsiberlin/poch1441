import PochKit
import QuartzCore
import SwiftUI

/// Trumpf-Beat-Inszenierung (§6a): Kartenrücken fliegen sichtbar vom Stapel
/// (Ring-Zentrum) in die Hände; nach dem Freeze schießt der radiale Lichtpuls in
/// Trumpffarbe übers Brett. Reine Präsentations-Schicht über GameState-Zählern -
/// hitTest-frei, damit keine Taps geschluckt werden.
struct DealOverlay: View {
    let game: GameState
    let theme: Theme
    let poolPositions: [Pool: CGPoint]
    let reduceMotion: Bool
    var showsSeatTargets = true
    var showsSeatIdentities = true

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let tokenDiameter = payoutTokenDiameter
            let boardCenter = CGPoint(x: w / 2, y: h * 0.46)
            // Eigener Kartenanker: Die zentrale Gewinnmulde bleibt jederzeit lesbar.
            // The PM49 board nearly fills the width. Keep the dealing stack in
            // the quiet band below it instead of covering the right-hand well.
            let deck = CGPoint(x: w * 0.78, y: h * 0.66)
            let dealSource = DealCardPose.sourcePoint(deck)
            let transcriptMode = CertifiedDealTranscript.requestedDebugMode
            ZStack {
                if showsSeatTargets, (game.startedDeals > 0 || game.landedDeals > 0) {
                    DealSeatTargets(game: game,
                                    w: w,
                                    h: h,
                                    showsIdentities: showsSeatIdentities)
                }
                if game.landedDeals < game.totalDeals && !game.trumpRevealed {
                    if game.startedDeals > game.landedDeals {
                        DealDeckAnchor(at: deck, game: game)
                    }
                }

                // Flug-Fenster: mehrere Karten bleiben gleichzeitig lesbar, ohne dass
                // die Runde als schneller Zaehlerwechsel wirkt.
                if !reduceMotion, game.landedDeals < game.totalDeals {
                    let order = game.dealOrder
                    let generation = game.meldPresentationGeneration
                    let windowStart = transcriptMode == nil
                        ? game.landedDeals
                        : max(0, game.landedDeals - 2)
                    let window = windowStart..<min(game.startedDeals, order.count)
                    ForEach(Array(window), id: \.self) { i in
                        FlyingBack(from: dealSource,
                                   to: target(order[i], w: w, h: h),
                                   seat: order[i].seat,
                                   slot: order[i].slot,
                                   totalSlots: totalSlots(for: order[i].seat),
                                   sequence: i,
                                   generation: generation,
                                   currentGeneration: {
                                       game.meldPresentationGeneration
                                   },
                                   transcriptMode: transcriptMode,
                                   onImpact: { game.markDealLanded(i) })
                            .id("fly-\(generation)-\(i)-slot-\(order[i].slot)")
                    }
                }
                // Radialer Lichtpuls in Trumpffarbe (Belohnungs-Akzent, kein Dauer-Glow)
                if game.lightPulse > 0 {
                    PulseRing(tint: trumpTint)
                        .position(boardCenter)
                        .id("pulse\(game.lightPulse)")
                }
                // Melde-Strom (§6a b): Münzen fliegen von der pulsierenden Mulde zum Gewinner
                if !reduceMotion, let pool = game.pulsingPool,
                   game.meldShown < game.startedMelds,
                   game.meldShown < game.meldEvents.count {
                    let meld = game.meldEvents[game.meldShown]
                    let sequence = game.meldShown
                    let generation = game.meldPresentationGeneration
                    let from = poolPosition(pool, deck: boardCenter)
                    let to = playerTarget(meld.player, w: w, h: h)
                    MeldPayoutTarget(name: game.name(of: meld.player),
                                     amount: meld.chips,
                                     world: theme,
                                     pool: pool,
                                     tokenDiameter: tokenDiameter)
                        .position(to)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .accessibilityIdentifier("phase1.meld.target")
                    CoinStream(from: from,
                               to: to,
                               world: theme,
                               pool: pool,
                               tokenDiameter: tokenDiameter,
                               amount: meld.chips,
                               onImpact: {
                                   game.markMeldLanded(sequence,
                                                       generation: generation)
                               })
                        .id("meld-\(generation)-\(sequence)")
                        .accessibilityElement(children: .ignore)
                        .accessibilityValue("\(meld.chips)")
                        .accessibilityIdentifier("phase1.meld.flight")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("phase1.presentation")
            .accessibilityValue(
                transcriptMode == nil
                    ? "\(game.meldShown)/\(game.meldEvents.count)"
                    : "deal \(game.landedDeals)/\(game.totalDeals)"
            )
        }
        .allowsHitTesting(false)
    }

    private var trumpTint: Color {
        game.trump == .hearts || game.trump == .diamonds
            ? Tokens.jewelRose : Tokens.jewelPlatin
    }

    private func target(_ entry: (seat: Int, slot: Int), w: CGFloat, h: CGFloat) -> CGPoint {
        if entry.seat == 0 {
            let pose = DealTableauLayout.humanPose(
                slot: entry.slot,
                totalSlots: game.humanHand.count,
                cardScale: 1.62
            )
            return CGPoint(x: w / 2 + pose.offset.width, y: h - 116)
        }
        let target = opponentTarget(entry.seat, w: w, h: h)
        let offset = DealCardPose.opponentOffset(
            slot: entry.slot,
            totalSlots: totalSlots(for: entry.seat),
            seat: entry.seat,
            generation: game.meldPresentationGeneration
        )
        return CGPoint(x: target.x + offset.width,
                       y: target.y + offset.height)
    }

    private func playerTarget(_ seat: Int, w: CGFloat, h: CGFloat) -> CGPoint {
        seat == 0 ? CGPoint(x: w / 2, y: h - 158)
                  : opponentTarget(seat, w: w, h: h)
    }

    private func totalSlots(for seat: Int) -> Int {
        max(1, game.dealOrder.lazy.filter { $0.seat == seat }.count)
    }

    private func opponentTarget(_ seat: Int, w: CGFloat, h: CGFloat) -> CGPoint {
        let count = max(1, game.playerCount - 1)
        let idx = CGFloat(seat - 1)
        let center = CGFloat(count - 1) / 2
        let spacing = min(CGFloat(126), w / CGFloat(max(count, 2)) * 0.88)
        let arc = abs(idx - center) * 14
        return CGPoint(x: w / 2 + (idx - center) * spacing,
                       y: h * 0.225 + arc * 0.18)
    }

    private func poolPosition(_ pool: Pool, deck: CGPoint) -> CGPoint {
        if let resolved = poolPositions[pool] {
            return resolved
        }
        if let anchor = PochRing.anchors.first(where: { $0.pool == pool }) {
            return CGPoint(x: deck.x + anchor.offset.width,
                           y: deck.y + anchor.offset.height)
        }
        return deck  // .center
    }

    private var payoutTokenDiameter: CGFloat {
        let outerPositions = poolPositions.filter { $0.key != .center }.map(\.value)
        guard let minimumX = outerPositions.map(\.x).min(),
              let maximumX = outerPositions.map(\.x).max(),
              maximumX > minimumX else {
            return Tokens.p1MeldTokenDiameter
        }
        let canonicalDiameter = Tokens.ringRadius * 2 + Tokens.tileDiameter
        let canonicalSpan = canonicalDiameter * Tokens.p1MeldOuterAnchorSpanRatio
        let renderedScale = (maximumX - minimumX) / canonicalSpan
        return min(Tokens.p1MeldTokenMaximumDiameter,
                   max(Tokens.p1MeldTokenMinimumDiameter,
                       Tokens.tableTokenDiameter * renderedScale))
    }
}

/// Sichtbares Ziel eines Meldegewinns. Der Transfer endet nie im leeren Raum:
/// Name, Betrag und Materialanker bleiben bis zum Kontakt eindeutig lesbar.
private struct MeldPayoutTarget: View {
    let name: String
    let amount: Int
    let world: TableWorld
    let pool: Pool
    let tokenDiameter: CGFloat

    private var tint: Color { world.tint(pool) }

    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(Color(hex: 0x0B0910).opacity(0.92))
                    .overlay(Circle().strokeBorder(tint.opacity(0.42), lineWidth: 1))
                Circle()
                    .strokeBorder(tint.opacity(0.52), lineWidth: 1.4)
                    .frame(width: tokenDiameter * 0.62,
                           height: tokenDiameter * 0.62)
                Circle()
                    .strokeBorder(Tokens.jewelPlatin.opacity(0.24), lineWidth: 0.8)
                    .frame(width: tokenDiameter * 0.34,
                           height: tokenDiameter * 0.34)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 0) {
                Text(name.uppercased())
                    .font(.system(size: 7.5, weight: .heavy))
                    .tracking(0.9)
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.72))
                    .lineLimit(1)
                Text("+\(amount)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
            }
        }
        .padding(.leading, 5)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color(hex: 0x0B0910).opacity(0.90))
                .overlay(Capsule().strokeBorder(tint.opacity(0.28), lineWidth: 1))
                .shadow(color: .black.opacity(0.44), radius: 8, y: 4)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(name))
        .accessibilityValue(Text("+\(amount)"))
    }
}

private struct DealSeatTargets: View {
    let game: GameState
    let w: CGFloat
    let h: CGFloat
    let showsIdentities: Bool

    var body: some View {
        ZStack {
            ForEach(1..<game.playerCount, id: \.self) { seat in
                opponentSeat(seat)
            }
            humanSeat
        }
        .transition(.opacity)
    }

    private func opponentSeat(_ seat: Int) -> some View {
        let point = opponentPoint(seat)
        let dealt = dealtCount(for: seat)
        let total = totalCount(for: seat)
        return ZStack {
            if dealt > 0 {
                ZStack {
                    ForEach(0..<dealt, id: \.self) { i in
                    CardBack(
                        materialVariant: materialVariant(seat: seat, slot: i),
                        scale: DealCardPose.opponentTargetScale
                    )
                        .rotationEffect(.degrees(DealCardPose.opponentRotation(
                            slot: i,
                            totalSlots: total,
                            seat: seat,
                            generation: game.meldPresentationGeneration
                        )))
                        .offset(DealCardPose.opponentOffset(slot: i,
                                                           totalSlots: total,
                                                           seat: seat,
                                                           generation: game.meldPresentationGeneration))
                        .shadow(color: .black.opacity(0.62), radius: 8, y: 5)
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Tokens.jewelPlatin.opacity(0.12),
                                  style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .frame(width: 43, height: 61)
            }

            if showsIdentities {
                OpponentPortrait(seat: seat,
                                 name: game.name(of: seat),
                                 isActive: true,
                                 isFocus: dealt > 0,
                                 mood: dealt > 0 ? .thinking : .neutral,
                                 size: 44,
                                 showsText: false,
                                 morph: nil)

                Text(game.name(of: seat).uppercased())
                    .font(.system(size: 7.5, weight: .heavy))
                    .tracking(1.0)
                    .foregroundStyle(Tokens.jewelPlatin.opacity(dealt > 0 ? 0.76 : 0.38))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.46)))
                    .offset(y: 47)
            }
        }
        .frame(width: 108, height: 94)
        .position(point)
        .opacity(dealt == 0 ? 0.48 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(game.name(of: seat))
        .accessibilityValue("\(dealt)")
        .accessibilityIdentifier("phase1.deal.seat.\(seat)")
    }

    @ViewBuilder
    private var humanSeat: some View {
        if humanCardAwaitingContact != nil {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Tokens.jewelPlatin.opacity(0.12),
                              style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                .frame(width: 52 * DealCardPose.humanTargetScale,
                       height: 74 * DealCardPose.humanTargetScale)
                .position(x: w / 2, y: h - 82)
                .accessibilityHidden(true)
        }
    }

    private var humanCardAwaitingContact: (sequence: Int, seat: Int, slot: Int)? {
        let order = game.dealOrder
        let lowerBound = min(game.landedDeals, order.count)
        let upperBound = min(max(game.startedDeals, lowerBound), order.count)
        guard let sequence = order[lowerBound..<upperBound]
            .firstIndex(where: { $0.seat == 0 }) else { return nil }
        let entry = order[sequence]
        return (sequence, entry.seat, entry.slot)
    }

    private func materialVariant(seat: Int, slot: Int) -> Int {
        let sequence = game.dealOrder.firstIndex {
            $0.seat == seat && $0.slot == slot
        } ?? slot
        return DealBackMaterial.variant(
            roundGeneration: game.meldPresentationGeneration,
            dealSequence: sequence,
            seat: seat,
            slot: slot
        )
    }

    private func dealtCount(for seat: Int) -> Int {
        game.dealOrder.prefix(game.landedDeals).filter { $0.seat == seat }.count
    }

    private func totalCount(for seat: Int) -> Int {
        max(1, game.dealOrder.lazy.filter { $0.seat == seat }.count)
    }

    private func opponentPoint(_ seat: Int) -> CGPoint {
        let count = max(1, game.playerCount - 1)
        let idx = CGFloat(seat - 1)
        let center = CGFloat(count - 1) / 2
        let spacing = min(CGFloat(126), w / CGFloat(max(count, 2)) * 0.88)
        let arc = abs(idx - center) * 14
        return CGPoint(x: w / 2 + (idx - center) * spacing,
                       y: h * 0.225 + arc * 0.18)
    }
}

private struct DealDeckAnchor: View {
    let at: CGPoint
    let game: GameState

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [
                    Tokens.jewelGold.opacity(0.13),
                    Color.clear
                ], center: .center, startRadius: 4, endRadius: 56))
                .frame(width: 116, height: 116)
            ForEach(0..<3, id: \.self) { i in
                deckBack(index: i)
                    .rotationEffect(.degrees(DealCardPose.deckRotation(index: i)))
                    .offset(DealCardPose.deckOffset(index: i))
                    .shadow(color: .black.opacity(0.50), radius: 11, y: 6)
            }
            Circle()
                .strokeBorder(Tokens.jewelPlatin.opacity(0.18), lineWidth: 1)
                .frame(width: 72, height: 72)
        }
        .position(at)
        .opacity(0.92)
        .transition(.scale(scale: 0.96).combined(with: .opacity))
    }

    @ViewBuilder
    private func deckBack(index: Int) -> some View {
        let order = game.dealOrder
        let sequence = min(
            game.startedDeals + max(2 - index, 0),
            max(order.count - 1, 0)
        )
        if order.indices.contains(sequence) {
            let entry = order[sequence]
            CardBack(
                materialVariant: DealBackMaterial.variant(
                    roundGeneration: game.meldPresentationGeneration,
                    dealSequence: sequence,
                    seat: entry.seat,
                    slot: entry.slot
                ),
                scale: DealCardPose.sourceScale
            )
        } else {
            EmptyView()
        }
    }
}

/// Single identity-neutral route shared by source, flight, and landed backs.
private enum DealBackMaterial {
    static func variant(
        roundGeneration: Int,
        dealSequence: Int,
        seat: Int,
        slot: Int
    ) -> Int {
        CardBackMaterialPlan.variantIndex(
            roundGeneration: roundGeneration,
            dealSequence: dealSequence,
            seat: seat,
            slot: slot
        )
    }
}

/// Gemeinsame Ruheposen für Quelle und Ziele. Die Flugkarte beginnt und endet
/// exakt in diesen Maßen, damit der Kontakt keinen zweiten Skalensprung erzeugt.
private enum DealCardPose {
    static let sourceScale: CGFloat = 0.96
    static let humanTargetScale: CGFloat = 1.08
    static let opponentTargetScale: CGFloat = 0.82
    static let shadowSettleStart: CGFloat = 0.62

    private static let sourceIndex = 2
    static func sourcePoint(_ deck: CGPoint) -> CGPoint {
        let offset = deckOffset(index: sourceIndex)
        return CGPoint(x: deck.x + offset.width, y: deck.y + offset.height)
    }

    static func deckRotation(index: Int) -> Double {
        Double(index - 1) * 4
    }

    static var sourceRotation: Double {
        deckRotation(index: sourceIndex)
    }

    static func deckOffset(index: Int) -> CGSize {
        CGSize(width: CGFloat(index - 1) * 3, height: CGFloat(index) * -2)
    }

    static func targetScale(seat: Int) -> CGFloat {
        seat == 0 ? humanTargetScale : opponentTargetScale
    }

    static func opponentRotation(
        slot: Int,
        totalSlots: Int,
        seat: Int,
        generation: Int
    ) -> Double {
        DealTableauLayout.opponentPose(slot: slot,
                                       totalSlots: totalSlots,
                                       seat: seat,
                                       roundGeneration: generation).rotationDegrees
    }

    static func opponentOffset(
        slot: Int,
        totalSlots: Int,
        seat: Int,
        generation: Int
    ) -> CGSize {
        DealTableauLayout.opponentPose(slot: slot,
                                       totalSlots: totalSlots,
                                       seat: seat,
                                       roundGeneration: generation).offset
    }

    static func shadowSettlement(progress: CGFloat) -> CGFloat {
        let span = 1 - shadowSettleStart
        let linear = min(max((progress - shadowSettleStart) / span, 0), 1)
        return linear * linear * (3 - 2 * linear)
    }
}

/// Münz-Strom einer Meldung: gestaffelte Chips in Kategorie-Farbe fliegen zur
/// Gewinner-Position (Bogen-Flugbahn = Hand-Gate, v1 gerade + gestaffelt).
private struct CoinStream: View {
    let from: CGPoint
    let to: CGPoint
    let world: TableWorld
    let pool: Pool
    let tokenDiameter: CGFloat
    let amount: Int
    let onImpact: () -> Void

    var body: some View {
        let count = min(max(amount, 1), Tokens.p1MeldPhysicalLimit)
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                let destination = CGPoint(x: to.x + landingOffset(index).width,
                                          y: to.y + landingOffset(index).height)
                ImpactFlight(
                    from: from,
                    to: destination,
                    duration: Tokens.p1CoinFlight,
                    delay: Double(index) * Tokens.p1MeldTokenStagger,
                    arcHeight: PhysicalMotion.shallowArcHeight(from: from,
                                                               to: destination,
                                                               minimum: 9,
                                                               maximum: 18),
                    lateralBias: CGFloat(index - count / 2) * 8.5,
                    onImpact: {
                        guard index == count - 1 else { return }
                        onImpact()
                    }
                ) { _ in
                    TableWorldPiece(world: world,
                                    size: tokenDiameter,
                                    seed: UInt64(max(amount, 0)) + 14_410,
                                    index: index,
                                    compartment: TravelCompartment(pool: pool))
                        .shadow(color: .black.opacity(0.48), radius: 6, y: 4)
                }
            }
        }
    }

    private func landingOffset(_ index: Int) -> CGSize {
        let offsets = [
            CGSize(width: -7, height: 2),
            CGSize(width: 6, height: 4),
            CGSize(width: -2, height: -5),
            CGSize(width: 8, height: -2),
            CGSize(width: 1, height: 7)
        ]
        return offsets[index % offsets.count]
    }
}

/// Ein einzelner fliegender Rücken. Im Kontakt-Frame wächst nur der gegnerische
/// Zielstapel; beim Menschen übernimmt danach ausschließlich die echte Handfront.
private struct FlyingBack: View {
    let from: CGPoint
    let to: CGPoint
    let seat: Int
    let slot: Int
    let totalSlots: Int
    let sequence: Int
    let generation: Int
    let currentGeneration: () -> Int
    let transcriptMode: TranscriptPlaybackMode?
    let onImpact: () -> Void
    @State private var transaction: CardFlightTransaction

    init(from: CGPoint,
         to: CGPoint,
         seat: Int,
         slot: Int,
         totalSlots: Int,
         sequence: Int,
         generation: Int,
         currentGeneration: @escaping () -> Int,
         transcriptMode: TranscriptPlaybackMode?,
         onImpact: @escaping () -> Void) {
        self.from = from
        self.to = to
        self.seat = seat
        self.slot = slot
        self.totalSlots = totalSlots
        self.sequence = sequence
        self.generation = generation
        self.currentGeneration = currentGeneration
        self.transcriptMode = transcriptMode
        self.onImpact = onImpact
        _transaction = State(initialValue: CardFlightTransaction(
            eventID: Self.eventID(sequence: sequence),
            generation: generation,
            source: CardPose(x: Double(from.x),
                             y: Double(from.y),
                             depth: 1,
                             rotationDegrees: DealCardPose.sourceRotation,
                             scale: Double(DealCardPose.sourceScale)),
            target: CardPose(x: Double(to.x),
                             y: Double(to.y),
                             rotationDegrees: Self.landingAngle(seat: seat,
                                                                slot: slot,
                                                                totalSlots: totalSlots,
                                                                generation: generation),
                             scale: Double(DealCardPose.targetScale(seat: seat))),
            motionPreference: .standard
        ))
    }

    @ViewBuilder
    var body: some View {
        if let transcriptMode {
            TranscriptFlyingBack(
                from: from,
                to: to,
                seat: seat,
                slot: slot,
                totalSlots: totalSlots,
                sequence: sequence,
                generation: generation,
                mode: transcriptMode,
                onContact: registerTranscriptContact,
                onRest: registerTranscriptRest
            )
        } else {
            impactFlight
        }
    }

    private var impactFlight: some View {
        let profile = DealTableauLayout.flightProfile(
            roundGeneration: generation,
            sequence: sequence,
            seat: seat,
            slot: slot
        )
        let duration = PhysicalMotion.duration(from: from,
                                               to: to,
                                               pointsPerSecond: profile.pointsPerSecond,
                                               minimum: Tokens.p1Flight,
                                               maximum: Tokens.p1Flight + 0.16)
        return ImpactFlight(from: from,
                     to: to,
                     duration: duration,
                     delay: profile.launchDelay,
                     arcHeight: PhysicalMotion.shallowArcHeight(from: from,
                                                                to: to,
                                                                minimum: 18,
                                                                maximum: 34)
                        + profile.arcLift,
                     lateralBias: profile.lateralBias,
                     onImpact: registerImpact,
                     onCancel: cancelTransaction) { progress in
            let pose = transaction.source.interpolated(to: transaction.target,
                                                       progress: Double(progress))
            let settlement = DealCardPose.shadowSettlement(progress: progress)
            CardBack(
                materialVariant: DealBackMaterial.variant(
                    roundGeneration: generation,
                    dealSequence: sequence,
                    seat: seat,
                    slot: slot
                ),
                scale: DealCardPose.sourceScale
            )
                .shadow(color: .black.opacity(0.56),
                        radius: 12 + (4 - 12) * settlement,
                        y: 8 + (3 - 8) * settlement)
                .rotationEffect(.degrees(
                    pose.rotationDegrees
                        + sin(Double(progress) * .pi) * profile.midflightTwistDegrees
                ))
                .scaleEffect(CGFloat(pose.scale) / DealCardPose.sourceScale)
            }
    }

    private static func eventID(sequence: Int) -> String {
        "deal-card-\(sequence)"
    }

    private func registerImpact() {
        let eventID = Self.eventID(sequence: sequence)
        guard transaction.registerContact(
            eventID: eventID,
            generation: currentGeneration()
        ) == .accepted else { return }
        onImpact()
        _ = transaction.complete(eventID: eventID, generation: generation)
    }

    private func registerTranscriptContact() {
        let eventID = Self.eventID(sequence: sequence)
        guard transaction.registerContact(
            eventID: eventID,
            generation: currentGeneration()
        ) == .accepted else { return }
        onImpact()
    }

    private func registerTranscriptRest() {
        let eventID = Self.eventID(sequence: sequence)
        _ = transaction.complete(eventID: eventID, generation: generation)
    }

    private func cancelTransaction() {
        transaction.cancel()
    }

    fileprivate static func landingAngle(
        seat: Int,
        slot: Int,
        totalSlots: Int,
        generation: Int
    ) -> Double {
        if seat == 0 {
            return DealTableauLayout.humanPose(slot: slot,
                                               totalSlots: totalSlots,
                                               cardScale: 1.62).rotationDegrees
        }
        return DealCardPose.opponentRotation(slot: slot,
                                             totalSlots: totalSlots,
                                             seat: seat,
                                             generation: generation)
    }
}

/// The only Stage-3 consumer. It samples the admitted plan from a monotone host
/// clock and keeps contact and rest as separate lifecycle edges.
private struct TranscriptFlyingBack: View {
    let from: CGPoint
    let to: CGPoint
    let seat: Int
    let slot: Int
    let totalSlots: Int
    let sequence: Int
    let generation: Int
    let mode: TranscriptPlaybackMode
    let onContact: @MainActor () -> Void
    let onRest: @MainActor () -> Void

    @State private var player: TranscriptMotionPlayer
    @State private var snapshot: TranscriptPlaybackSnapshot

    init(
        from: CGPoint,
        to: CGPoint,
        seat: Int,
        slot: Int,
        totalSlots: Int,
        sequence: Int,
        generation: Int,
        mode: TranscriptPlaybackMode,
        onContact: @escaping @MainActor () -> Void,
        onRest: @escaping @MainActor () -> Void
    ) {
        self.from = from
        self.to = to
        self.seat = seat
        self.slot = slot
        self.totalSlots = totalSlots
        self.sequence = sequence
        self.generation = generation
        self.mode = mode
        self.onContact = onContact
        self.onRest = onRest

        guard let player = TranscriptMotionPlayer(
            plan: CertifiedDealTranscript.plan,
            mode: mode,
            onContact: onContact,
            onRest: onRest,
            onCancelBeforeRelease: {}
        ) else {
            preconditionFailure("The admitted Stage-2 transcript must remain valid")
        }
        _player = State(initialValue: player)
        _snapshot = State(initialValue: player.currentSnapshot)
    }

    var body: some View {
        CardBack(
            materialVariant: DealBackMaterial.variant(
                roundGeneration: generation,
                dealSequence: sequence,
                seat: seat,
                slot: slot
            ),
            scale: DealCardPose.sourceScale
        )
            .shadow(
                color: .black.opacity(snapshot.sample.shadow.opacity),
                radius: snapshot.sample.shadow.blurRadius,
                x: snapshot.sample.shadow.offset.x,
                y: snapshot.sample.shadow.offset.y
            )
            .rotation3DEffect(
                .degrees(snapshot.sample.curlMillimeters * 1.25),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.68
            )
            .rotationEffect(.degrees(rotationDegrees))
            .scaleEffect(scale / DealCardPose.sourceScale)
            .position(position)
            .opacity(snapshot.phase == .resting ? 0 : 1)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("phase1.deal.transcript.flight.\(sequence)")
            .accessibilityValue(
                "\(snapshot.phase.rawValue), contact \(snapshot.contactDelivered ? 1 : 0), rest \(snapshot.restDelivered ? 1 : 0)"
            )
            .task { await play() }
    }

    private var normalizedPosition: CGPoint {
        let sample = snapshot.sample.position
        let x = (sample.x - 0.18) / (0.90 - 0.18)
        let y = (sample.y - 0.15) / (0.86 - 0.15)
        return CGPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
    }

    private var pathProgress: CGFloat {
        (normalizedPosition.x + normalizedPosition.y) / 2
    }

    private var position: CGPoint {
        CGPoint(
            x: from.x + (to.x - from.x) * normalizedPosition.x,
            y: from.y + (to.y - from.y) * normalizedPosition.y
                - CGFloat(snapshot.sample.depth) * 30
        )
    }

    private var scale: CGFloat {
        let target = DealCardPose.targetScale(seat: seat)
        return DealCardPose.sourceScale
            + (target - DealCardPose.sourceScale) * pathProgress
            + CGFloat(snapshot.sample.depth) * 0.025
    }

    private var rotationDegrees: Double {
        let target = FlyingBack.landingAngle(seat: seat,
                                             slot: slot,
                                             totalSlots: totalSlots,
                                             generation: generation)
        let progress = Double(pathProgress)
        let runtimeBaseline = DealCardPose.sourceRotation
            + (target - DealCardPose.sourceRotation) * progress
        let certifiedBaseline = -5.2 + 5.2 * progress
        return runtimeBaseline + snapshot.sample.rotationDegrees - certifiedBaseline
    }

    @MainActor
    private func play() async {
        snapshot = player.release(at: CACurrentMediaTime())
        while snapshot.isMoving {
            do {
                try await Task.sleep(for: .milliseconds(4))
            } catch {
                // Removal, skip, or generation replacement owns final state. Do
                // not emit a callback after SwiftUI has cancelled this task.
                return
            }
            guard !Task.isCancelled else { return }
            snapshot = player.advance(to: CACurrentMediaTime())
        }
    }
}

/// Der Puls: ein expandierender Ring, der ausklingt - einmalig pro Trigger.
private struct PulseRing: View {
    let tint: Color
    @State private var fired = false

    var body: some View {
        Circle()
            .strokeBorder(tint.opacity(fired ? 0 : 0.16), lineWidth: fired ? 0.7 : 4.5)
            .frame(width: 96, height: 96)
            .scaleEffect(fired ? 3.15 : 0.82)
            .blur(radius: fired ? 1.8 : 0.2)
            .onAppear {
                withAnimation(.easeOut(duration: min(Tokens.p1Pulse, 0.34))) { fired = true }
            }
    }
}
