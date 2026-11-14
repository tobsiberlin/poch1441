import Foundation

@main
struct CardBackMaterialPlanTests {
    static func main() throws {
        determinism()
        dealSequenceDoesNotChangeAStableSlot()
        indexRange()
        roundRotation()
        distribution()
        try identityNeutralAPISurface()
        try runtimeCallSitesStayIdentityNeutral()

        FileHandle.standardOutput.write(Data("CardBackMaterialPlanTests: PASS\n".utf8))
    }

    private static func dealSequenceDoesNotChangeAStableSlot() {
        let expected = CardBackMaterialPlan.variantIndex(
            roundGeneration: 8,
            dealSequence: 0,
            seat: 3,
            slot: 6
        )

        for dealSequence in -20...80 {
            expect(
                CardBackMaterialPlan.variantIndex(
                    roundGeneration: 8,
                    dealSequence: dealSequence,
                    seat: 3,
                    slot: 6
                ) == expected,
                "Flight and landed views must agree for the same round, seat, and slot"
            )
        }
    }

    private static func determinism() {
        let expected = CardBackMaterialPlan.variantIndex(
            roundGeneration: 37,
            dealSequence: 19,
            seat: 3,
            slot: 4
        )

        for _ in 0..<1_000 {
            expect(
                CardBackMaterialPlan.variantIndex(
                    roundGeneration: 37,
                    dealSequence: 19,
                    seat: 3,
                    slot: 4
                ) == expected,
                "The same public placement must always keep the same variant"
            )
        }
    }

    private static func indexRange() {
        let boundaryValues = [
            Int.min, Int.min + 1, -10_001, -10, -1,
            0, 1, 9, 10, 10_001, Int.max - 1, Int.max,
        ]

        for roundGeneration in boundaryValues {
            for dealSequence in boundaryValues {
                let index = CardBackMaterialPlan.variantIndex(
                    roundGeneration: roundGeneration,
                    dealSequence: dealSequence,
                    seat: roundGeneration,
                    slot: dealSequence
                )
                expect(
                    (0..<CardBackMaterialPlan.variantCount).contains(index),
                    "Every assignment must stay inside the ten-variant range"
                )
            }
        }
    }

    private static func roundRotation() {
        let cycle = (0..<CardBackMaterialPlan.variantCount).map { round in
            CardBackMaterialPlan.variantIndex(
                roundGeneration: round,
                dealSequence: 23,
                seat: 2,
                slot: 5
            )
        }

        expect(
            Set(cycle).count == CardBackMaterialPlan.variantCount,
            "A stable placement must visit every variant over ten rounds"
        )
        for round in 0..<40 {
            let current = CardBackMaterialPlan.variantIndex(
                roundGeneration: round,
                dealSequence: 23,
                seat: 2,
                slot: 5
            )
            let next = CardBackMaterialPlan.variantIndex(
                roundGeneration: round + 1,
                dealSequence: 23,
                seat: 2,
                slot: 5
            )
            expect(
                next == (current + 1) % CardBackMaterialPlan.variantCount,
                "Each new round must rotate a placement by exactly one variant"
            )
        }
    }

    private static func distribution() {
        var counts = Array(repeating: 0, count: CardBackMaterialPlan.variantCount)

        for roundGeneration in 0..<100 {
            for seat in 0..<4 {
                for slot in 0..<10 {
                    let dealSequence = slot * 4 + seat
                    let index = CardBackMaterialPlan.variantIndex(
                        roundGeneration: roundGeneration,
                        dealSequence: dealSequence,
                        seat: seat,
                        slot: slot
                    )
                    counts[index] += 1
                }
            }
        }

        let expected = counts.reduce(0, +) / CardBackMaterialPlan.variantCount
        expect(
            counts.allSatisfy { $0 == expected },
            "Public deal coordinates must distribute exactly across long runs: \(counts)"
        )
    }

    private static func identityNeutralAPISurface() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("App/CardBackMaterialPlan.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        for requiredInput in ["roundGeneration: Int", "dealSequence: Int", "seat: Int", "slot: Int"] {
            expect(source.contains(requiredInput), "Missing public presentation input: \(requiredInput)")
        }

        let forbiddenIdentityInputs = [
            #"\bCard\b"#,
            #"\bRank\b"#,
            #"\bSuit\b"#,
            #"asset(Name|ID)"#,
            #"cardID"#,
            #"hashValue"#,
            #"\bHasher\b"#,
            #"\.random\("#,
            #"SystemRandomNumberGenerator"#,
            #"\bUUID\b"#,
        ]
        for pattern in forbiddenIdentityInputs {
            expect(
                !contains(pattern: pattern, in: source),
                "Material assignment must not accept identity or unstable entropy: \(pattern)"
            )
        }
    }

    private static func runtimeCallSitesStayIdentityNeutral() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let dealOverlay = try String(
            contentsOf: root.appendingPathComponent("App/DealOverlay.swift"),
            encoding: .utf8
        )
        let phase3 = try String(
            contentsOf: root.appendingPathComponent("App/Phase3View.swift"),
            encoding: .utf8
        )

        let backCount = dealOverlay.components(separatedBy: "CardBack(").count - 1
        let variantCount = dealOverlay.components(separatedBy: "materialVariant:").count - 1
        expect(backCount == variantCount,
               "Every visible deal back must receive a public material variant")
        expect(!dealOverlay.contains("CardBack(scale:"),
               "Deal runtime must not silently fall back to a neutral visible back")

        guard let routeStart = dealOverlay.range(of: "private enum DealBackMaterial"),
              let routeEnd = dealOverlay.range(
                of: "/// Gemeinsame Ruheposen",
                range: routeStart.upperBound..<dealOverlay.endIndex
              ) else {
            fail("DealOverlay must isolate the identity-neutral material route")
        }
        let route = String(dealOverlay[routeStart.lowerBound..<routeEnd.lowerBound])
        for required in [
            "roundGeneration: roundGeneration",
            "dealSequence: dealSequence",
            "seat: seat",
            "slot: slot",
        ] {
            expect(route.contains(required), "Deal material route must forward \(required)")
        }
        for pattern in [#"\bCard\b"#, #"\bRank\b"#, #"\bSuit\b"#, #"asset(Name|ID)"#] {
            expect(!contains(pattern: pattern, in: route),
                   "Deal material route must not accept gameplay identity: \(pattern)")
        }

        expect(
            phase3.contains("materialVariant: CardBackMaterialPlan.variantIndex("),
            "The visible Phase 3 side deck must receive a public material variant"
        )
        expect(
            phase3.contains("roundGeneration: game.meldPresentationGeneration"),
            "Phase 3 must rotate its neutral side-deck material between rounds"
        )
    }

    private static func contains(pattern: String, in source: String) -> Bool {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return true }
        return expression.firstMatch(
            in: source,
            range: NSRange(source.startIndex..<source.endIndex, in: source)
        ) != nil
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: @autoclosure () -> String
    ) {
        guard condition() else {
            FileHandle.standardError.write(Data("FAIL: \(message())\n".utf8))
            Foundation.exit(EXIT_FAILURE)
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        Foundation.exit(EXIT_FAILURE)
    }
}
