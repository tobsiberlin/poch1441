import Foundation

enum HarnessSequenceKind: String, Codable, CaseIterable, Sendable {
    case standard
    case reducedMotion
    case cancellation
}

enum HarnessCardPhase: String, Codable, Sendable {
    case travel
    case contact
    case settle
    case rest

    var isMoving: Bool {
        switch self {
        case .travel, .contact, .settle: true
        case .rest: false
        }
    }
}

struct HarnessCardSnapshot: Equatable, Sendable {
    let index: Int
    let phase: HarnessCardPhase
    let phaseProgress: Double
}

struct HarnessSnapshot: Equatable, Sendable {
    let sequence: HarnessSequenceKind
    let elapsedSeconds: Double
    let cards: [HarnessCardSnapshot]
    let deckCount: Int

    var activeCount: Int {
        cards.filter { $0.phase.isMoving }.count
    }

    var activeCardIndices: [Int] {
        cards.filter { $0.phase.isMoving }.map(\.index)
    }
}

struct RhythmHarnessPlan: Sendable {
    static let dealCount = 8

    let sequence: HarnessSequenceKind
    let profile: DealRhythmProfile
    let durations: [DealMotionDurations]
    let schedule: [ScheduledDealCard]
    let cancellationSeconds: Double?
    let evidenceEndSeconds: Double

    var cancellationDrainCompleteSeconds: Double? {
        guard let cancellationSeconds else { return nil }
        return schedule
            .filter { $0.actualStartSeconds < cancellationSeconds }
            .map(\.restWindowStartSeconds)
            .max()
    }

    static func make(sequence: HarnessSequenceKind) throws -> RhythmHarnessPlan {
        let mode: DealRhythmMode = sequence == .reducedMotion ? .reducedMotion : .standard
        let seed: UInt64 = sequence == .reducedMotion ? 14_412 : 14_411
        let profile = DealRhythmProfile.make(
            dealCount: dealCount,
            seed: seed,
            mode: mode
        )
        let durations = durationPlan(for: mode)
        let schedule = try DealRhythmScheduler.schedule(profile: profile, durations: durations)
        let cancellation = sequence == .cancellation
            ? schedule[3].actualStartSeconds + durations[3].travelSeconds * 0.46
            : nil
        let end: Double
        if let cancellation {
            let committedRest = schedule
                .filter { $0.actualStartSeconds < cancellation }
                .map(\.restWindowStartSeconds)
                .max() ?? cancellation
            end = committedRest + 0.28
        } else {
            end = (schedule.last?.restWindowStartSeconds ?? 0) + 0.28
        }
        return RhythmHarnessPlan(
            sequence: sequence,
            profile: profile,
            durations: durations,
            schedule: schedule,
            cancellationSeconds: cancellation,
            evidenceEndSeconds: end
        )
    }

    func snapshot(at elapsedSeconds: Double) -> HarnessSnapshot {
        let elapsed = max(0, elapsedSeconds)
        var cards: [HarnessCardSnapshot] = []

        for index in schedule.indices {
            let card = schedule[index]
            if let cancellationSeconds,
               card.actualStartSeconds >= cancellationSeconds {
                continue
            }

            guard elapsed >= card.actualStartSeconds else { continue }
            if elapsed < card.contactStartSeconds {
                cards.append(HarnessCardSnapshot(
                    index: index,
                    phase: .travel,
                    phaseProgress: normalized(
                        elapsed,
                        from: card.actualStartSeconds,
                        to: card.contactStartSeconds
                    )
                ))
            } else if elapsed < card.settleStartSeconds {
                cards.append(HarnessCardSnapshot(
                    index: index,
                    phase: .contact,
                    phaseProgress: normalized(
                        elapsed,
                        from: card.contactStartSeconds,
                        to: card.settleStartSeconds
                    )
                ))
            } else if elapsed < card.restWindowStartSeconds {
                cards.append(HarnessCardSnapshot(
                    index: index,
                    phase: .settle,
                    phaseProgress: normalized(
                        elapsed,
                        from: card.settleStartSeconds,
                        to: card.restWindowStartSeconds
                    )
                ))
            } else {
                cards.append(HarnessCardSnapshot(index: index, phase: .rest, phaseProgress: 1))
            }
        }

        let startedCount: Int
        if let cancellationSeconds, elapsed >= cancellationSeconds {
            startedCount = schedule.filter {
                $0.actualStartSeconds < cancellationSeconds
            }.count
        } else {
            startedCount = schedule.filter { $0.actualStartSeconds <= elapsed }.count
        }
        return HarnessSnapshot(
            sequence: sequence,
            elapsedSeconds: elapsed,
            cards: cards,
            deckCount: max(0, Self.dealCount - startedCount)
        )
    }

    private static func durationPlan(for mode: DealRhythmMode) -> [DealMotionDurations] {
        switch mode {
        case .standard:
            [
                .init(travelSeconds: 0.36, contactSeconds: 0.07, settleSeconds: 0.13),
                .init(travelSeconds: 0.43, contactSeconds: 0.08, settleSeconds: 0.14),
                .init(travelSeconds: 0.34, contactSeconds: 0.07, settleSeconds: 0.12),
                .init(travelSeconds: 0.46, contactSeconds: 0.09, settleSeconds: 0.15),
                .init(travelSeconds: 0.38, contactSeconds: 0.07, settleSeconds: 0.13),
                .init(travelSeconds: 0.44, contactSeconds: 0.08, settleSeconds: 0.14),
                .init(travelSeconds: 0.35, contactSeconds: 0.07, settleSeconds: 0.12),
                .init(travelSeconds: 0.41, contactSeconds: 0.08, settleSeconds: 0.14),
            ]
        case .reducedMotion:
            [
                .init(travelSeconds: 0.10, contactSeconds: 0.045, settleSeconds: 0.065),
                .init(travelSeconds: 0.12, contactSeconds: 0.050, settleSeconds: 0.075),
                .init(travelSeconds: 0.09, contactSeconds: 0.045, settleSeconds: 0.060),
                .init(travelSeconds: 0.13, contactSeconds: 0.055, settleSeconds: 0.080),
                .init(travelSeconds: 0.10, contactSeconds: 0.045, settleSeconds: 0.065),
                .init(travelSeconds: 0.12, contactSeconds: 0.050, settleSeconds: 0.075),
                .init(travelSeconds: 0.09, contactSeconds: 0.045, settleSeconds: 0.060),
                .init(travelSeconds: 0.11, contactSeconds: 0.050, settleSeconds: 0.070),
            ]
        }
    }

    private func normalized(_ value: Double, from start: Double, to end: Double) -> Double {
        guard end > start else { return 1 }
        return min(max((value - start) / (end - start), 0), 1)
    }
}
