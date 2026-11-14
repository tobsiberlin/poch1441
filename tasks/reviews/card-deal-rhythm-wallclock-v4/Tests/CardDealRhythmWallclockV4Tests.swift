import XCTest
@testable import CardDealRhythmWallclockV4

final class CardDealRhythmWallclockV4Tests: XCTestCase {
    func testStandardPlanConsumesEightPulseV1Arc() throws {
        let plan = try RhythmHarnessPlan.make(sequence: .standard)
        XCTAssertEqual(plan.schedule.count, 8)
        XCTAssertEqual(plan.profile.pulses.map(\.phase), [
            .tension, .tension,
            .acceleration, .acceleration, .acceleration, .acceleration,
            .recovery, .release,
        ])
        for index in 2..<plan.schedule.count {
            XCTAssertEqual(
                plan.schedule[index].actualStartSeconds,
                max(
                    plan.schedule[index].rhythmTargetSeconds,
                    plan.schedule[index - 2].restWindowStartSeconds
                ),
                accuracy: 0.000_000_001
            )
        }
    }

    func testSettleIsVisibleAndCountsAsMovement() throws {
        let plan = try RhythmHarnessPlan.make(sequence: .standard)
        for card in plan.schedule {
            let middleOfSettle = (card.settleStartSeconds + card.restWindowStartSeconds) / 2
            let snapshot = plan.snapshot(at: middleOfSettle)
            let visible = try XCTUnwrap(snapshot.cards.first { $0.index == card.index })
            XCTAssertEqual(visible.phase, .settle)
            XCTAssertTrue(visible.phase.isMoving)
            XCTAssertGreaterThan(visible.phaseProgress, 0)
            XCTAssertLessThan(visible.phaseProgress, 1)
        }
    }

    func testNoContinuousOrSixtyHertzSampleContainsThirdCard() throws {
        for sequence in HarnessSequenceKind.allCases {
            let plan = try RhythmHarnessPlan.make(sequence: sequence)
            var time = 0.0
            while time <= plan.evidenceEndSeconds {
                XCTAssertLessThanOrEqual(plan.snapshot(at: time).activeCount, 2)
                time += 0.001
            }
            for frame in 0...Int(ceil(plan.evidenceEndSeconds * 60)) {
                XCTAssertLessThanOrEqual(
                    plan.snapshot(at: Double(frame) / 60).activeCount,
                    2
                )
            }
        }
    }

    func testNoThirdCardAppearsAtPeel() throws {
        for sequence in [HarnessSequenceKind.standard, .reducedMotion] {
            let plan = try RhythmHarnessPlan.make(sequence: sequence)
            for card in plan.schedule {
                let snapshot = plan.snapshot(at: card.actualStartSeconds + 0.000_001)
                XCTAssertLessThanOrEqual(snapshot.activeCount, 2)
                XCTAssertTrue(snapshot.cards.contains { $0.index == card.index })
            }
        }
    }

    func testReducedMotionHasNoInvisibleWait() throws {
        let plan = try RhythmHarnessPlan.make(sequence: .reducedMotion)
        for index in 1..<plan.schedule.count {
            let latestPriorRest = plan.schedule[..<index]
                .map(\.restWindowStartSeconds)
                .max() ?? 0
            XCTAssertLessThanOrEqual(
                plan.schedule[index].actualStartSeconds,
                latestPriorRest + 0.000_000_1
            )
        }
        for card in plan.schedule {
            let firstVisible = plan.snapshot(at: card.actualStartSeconds + 0.000_001)
                .cards.first { $0.index == card.index }
            XCTAssertNotNil(firstVisible)
        }
    }

    func testCancellationStartsNothingNewAndDrainsCommittedCards() throws {
        let plan = try RhythmHarnessPlan.make(sequence: .cancellation)
        let cancellation = try XCTUnwrap(plan.cancellationSeconds)
        let committed = Set(plan.schedule.indices.filter {
            plan.schedule[$0].actualStartSeconds < cancellation
        })
        XCTAssertEqual(
            Set(plan.snapshot(at: cancellation + 0.02).cards.map(\.index)),
            committed
        )

        for index in committed {
            let card = plan.schedule[index]
            if card.contactStartSeconds > cancellation {
                XCTAssertEqual(
                    plan.snapshot(at: (cancellation + card.contactStartSeconds) / 2)
                        .cards.first { $0.index == index }?.phase,
                    .travel
                )
            }
            XCTAssertEqual(
                plan.snapshot(at: (card.contactStartSeconds + card.settleStartSeconds) / 2)
                    .cards.first { $0.index == index }?.phase,
                .contact
            )
            XCTAssertEqual(
                plan.snapshot(at: (card.settleStartSeconds + card.restWindowStartSeconds) / 2)
                    .cards.first { $0.index == index }?.phase,
                .settle
            )
            XCTAssertEqual(
                plan.snapshot(at: card.restWindowStartSeconds + 0.000_001)
                    .cards.first { $0.index == index }?.phase,
                .rest
            )
        }

        let drain = try XCTUnwrap(plan.cancellationDrainCompleteSeconds)
        XCTAssertGreaterThan(drain, cancellation)
        let drained = plan.snapshot(at: drain + 0.000_001)
        XCTAssertEqual(drained.activeCount, 0)
        XCTAssertTrue(drained.cards.allSatisfy { $0.phase == .rest })
        let futureIndices = plan.schedule.indices.filter {
            plan.schedule[$0].actualStartSeconds >= cancellation
        }
        XCTAssertTrue(futureIndices.allSatisfy { index in
            !drained.cards.contains { $0.index == index }
        })
    }

    func testCancellationUsesTheSameMonotoneLifecycleClock() throws {
        let plan = try RhythmHarnessPlan.make(sequence: .cancellation)
        let cancellation = try XCTUnwrap(plan.cancellationSeconds)
        let activeAtCancellation = plan.schedule.indices.filter {
            let card = plan.schedule[$0]
            return card.actualStartSeconds < cancellation && cancellation < card.restWindowStartSeconds
        }
        XCTAssertEqual(activeAtCancellation, [3, 4])

        for index in activeAtCancellation {
            let card = plan.schedule[index]
            let samples = [
                (cancellation + card.contactStartSeconds) / 2,
                (card.contactStartSeconds + card.settleStartSeconds) / 2,
                (card.settleStartSeconds + card.restWindowStartSeconds) / 2,
                card.restWindowStartSeconds + 0.000_001,
            ]
            XCTAssertEqual(
                samples.compactMap { time in
                    plan.snapshot(at: time).cards.first { $0.index == index }?.phase
                },
                [.travel, .contact, .settle, .rest]
            )
        }
    }

    func testV1VariationConstraintsRemainPresentInHarnessPlan() throws {
        for sequence in HarnessSequenceKind.allCases {
            let pulses = try RhythmHarnessPlan.make(sequence: sequence).profile.pulses
            for index in 2..<pulses.count {
                XCTAssertFalse(
                    pulses[index].route == pulses[index - 1].route &&
                        pulses[index].route == pulses[index - 2].route
                )
                XCTAssertFalse(
                    pulses[index].contact == pulses[index - 1].contact &&
                        pulses[index].contact == pulses[index - 2].contact
                )
            }
        }
    }
}
