import Foundation

@main
struct R1TokenLayoutTests {
    static func main() {
        emptyAndCapacityAreExact()
        landedTokensKeepTheirPose()
        posesStayInsideTheUsableFloor()
        visibleR1MatchesTheNorthstarScale()
        measuredR1HullFitsEveryBoardWellAtOnePhysicalSize()
        twoTokenGroupsUseTheAvailableFloor()
        twoTokensMatchTheReferenceOverlap()
        fourTokensRemainVisuallyDistinct()
        openingGroupsAvoidCenterRosettes()
        compartmentsDoNotCloneOnePile()
        occupiedWellsUseAtLeastThreeNonCongruentSilhouettes()
        FileHandle.standardOutput.write(Data("R1TokenLayoutTests: PASS\n".utf8))
    }

    private static func emptyAndCapacityAreExact() {
        expect(R1TokenSlots.layout(for: 0).isEmpty,
               "an empty count must stay empty")
        expect(R1TokenSlots.layout(for: 99).count == R1TokenSlots.capacity,
               "the renderer must stop at its physical capacity")
    }

    private static func landedTokensKeepTheirPose() {
        for compartment in TravelCompartment.allCases {
            let four = R1TokenSlots.layout(for: 4,
                                           seed: 1_444,
                                           compartment: compartment)
            let five = R1TokenSlots.layout(for: 5,
                                           seed: 1_444,
                                           compartment: compartment)
            expect(Array(five.prefix(4)) == four,
                   "adding a token must not move an already landed token")
            expect(four == R1TokenSlots.layout(for: 4,
                                               seed: 1_444,
                                               compartment: compartment),
                   "identical seed and compartment must replay exactly")
        }
    }

    private static func posesStayInsideTheUsableFloor() {
        let tokenToFloorRatio = Tokens.tableTokenToFloorRatio
        for compartment in TravelCompartment.allCases {
            for seed: UInt64 in [1, 1_441, 1_444, .max] {
                for pose in R1TokenSlots.layout(for: 12,
                                                seed: seed,
                                                compartment: compartment) {
                    let radius = hypot(pose.offset.width, pose.offset.height)
                    let occupiedRadius = (radius + 0.5) * tokenToFloorRatio
                    expect(occupiedRadius <= 0.5,
                           "a token must remain fully inside the circular well floor")
                }
            }
        }
    }

    private static func measuredR1HullFitsEveryBoardWellAtOnePhysicalSize() {
        let measuredAlphaRadius = Tokens.r1MeasuredAlphaRadiusRatio * Tokens.r1AssetScale
        let fullSize = Tokens.tableTokenDiameter
        let compactSize = fullSize
            * Tokens.phase2BoardScale
            * Tokens.r1CompactTokenScale

        let phase1Outer = physicalTokenDiameter(
            requested: fullSize,
            wellDiameter: Tokens.phase1OuterWellDiameter
        )
        let phase1Center = physicalTokenDiameter(
            requested: fullSize,
            wellDiameter: Tokens.phase1CenterWellDiameter
        )
        expect(abs(phase1Outer - phase1Center) < 0.001,
               "the same physical R1 must not grow in the center well")

        let phase2OuterDiameter = Tokens.tileDiameter * Tokens.phase2BoardScale
        let phase2CenterDiameter = Tokens.centerDiameter * 0.42
        let phase2Outer = physicalTokenDiameter(
            requested: compactSize,
            wellDiameter: phase2OuterDiameter
        )
        let phase2Center = physicalTokenDiameter(
            requested: compactSize,
            wellDiameter: phase2CenterDiameter
        )
        expect(abs(phase2Outer - phase2Center) < 0.001,
               "the compact R1 must keep one physical size in outer and center wells")

        let outerCompartments = TravelCompartment.allCases.filter { $0 != .center }
        let configurations: [(CGFloat, CGFloat, CGFloat, [TravelCompartment])] = [
            (phase1Outer,
             Tokens.phase1OuterWellDiameter,
             Tokens.r1OuterPileSpread,
             outerCompartments),
            (phase1Center,
             Tokens.phase1CenterWellDiameter,
             Tokens.r1CenterPileSpread,
             [.center]),
            (phase2Outer,
             phase2OuterDiameter,
             Tokens.r1OuterPileSpread,
             outerCompartments),
            (phase2Center,
             phase2CenterDiameter,
             Tokens.r1CenterPileSpread,
             [.center])
        ]
        for (tokenDiameter, wellDiameter, pileSpread, compartments) in configurations {
            let floorRadius = wellDiameter * Tokens.outerWellFloorRatio / 2
            for compartment in compartments {
                for seed: UInt64 in [1, 1_441, 1_444, .max] {
                    for pose in R1TokenSlots.layout(for: 12,
                                                    seed: seed,
                                                    compartment: compartment) {
                        let occupiedRadius = (
                            hypot(pose.offset.width, pose.offset.height) * pileSpread
                                + measuredAlphaRadius
                        ) * tokenDiameter
                        expect(occupiedRadius <= floorRadius,
                               "the measured R1 alpha hull must stay inside the textile floor")
                    }
                }
            }
        }
    }

    private static func visibleR1MatchesTheNorthstarScale() {
        let semanticDiscDiameter = Tokens.ringRadius * 2 + Tokens.tileDiameter
        let measuredDiscDiameterRatio: CGFloat = 978.0 / 1_254.0
        let visibleDiscDiameter = semanticDiscDiameter
            * measuredDiscDiameterRatio
            * Tokens.pochDiscAssetScale
        let visibleR1Diameter = Tokens.tableTokenDiameter
            * Tokens.r1MeasuredAlphaWidthRatio
            * Tokens.r1AssetScale
        let ratio = visibleR1Diameter / visibleDiscDiameter
        expect((0.102...0.107).contains(ratio),
               "the visible R1 width must match the direct-reference 0.102-0.107 D scale")

        let outerFloorDiameter = Tokens.phase1OuterWellDiameter
            * Tokens.outerWellFloorRatio
        let visibleTokenToFloor = Tokens.tableTokenDiameter
            * Tokens.r1MeasuredAlphaWidthRatio
            * Tokens.r1AssetScale
            / outerFloorDiameter
        expect((0.68...0.71).contains(visibleTokenToFloor),
               "one visible R1 body must use 68-71 percent of the textile floor")
    }

    private static func physicalTokenDiameter(requested: CGFloat,
                                              wellDiameter: CGFloat) -> CGFloat {
        min(requested,
            wellDiameter * Tokens.outerWellFloorRatio * Tokens.tableTokenToFloorRatio)
    }

    private static func twoTokenGroupsUseTheAvailableFloor() {
        let measuredAlphaWidth = Tokens.r1MeasuredAlphaWidthRatio * Tokens.r1AssetScale
        let floorDiameter = Tokens.phase1OuterWellDiameter * Tokens.outerWellFloorRatio
        for compartment in TravelCompartment.allCases {
            let pair = R1TokenSlots.layout(for: 2,
                                           seed: 1_441,
                                           compartment: compartment)
            let centerDistance = hypot(pair[0].offset.width - pair[1].offset.width,
                                       pair[0].offset.height - pair[1].offset.height)
            let visibleGroupDiameter = (
                centerDistance * Tokens.r1OuterPileSpread + measuredAlphaWidth
            )
                * Tokens.tableTokenDiameter
            let utilization = visibleGroupDiameter / floorDiameter
            expect((0.88...0.96).contains(utilization),
                   "a two-token R1 group must use the floor without touching the metal ring")
        }
    }

    private static func twoTokensMatchTheReferenceOverlap() {
        for compartment in TravelCompartment.allCases {
            let pair = R1TokenSlots.layout(for: 2,
                                           seed: 1_441,
                                           compartment: compartment)
            let distance = hypot(pair[0].offset.width - pair[1].offset.width,
                                 pair[0].offset.height - pair[1].offset.height)
            expect((0.28...0.40).contains(distance),
                   "two R1 tokens need the dense directional overlap of the product reference")
        }
    }

    private static func fourTokensRemainVisuallyDistinct() {
        for compartment in TravelCompartment.allCases {
            for seed: UInt64 in [1, 1_441, 1_444, .max] {
                let poses = R1TokenSlots.layout(for: 4,
                                                seed: seed,
                                                compartment: compartment)
                for left in poses.indices {
                    for right in poses.indices where right > left {
                        let distance = hypot(poses[left].offset.width - poses[right].offset.width,
                                             poses[left].offset.height - poses[right].offset.height)
                        expect(distance >= 0.15,
                               "four-token groups need four distinguishable silhouettes")
                    }
                }
            }
        }
    }

    private static func openingGroupsAvoidCenterRosettes() {
        for compartment in TravelCompartment.allCases {
            let opening = R1TokenSlots.layout(for: 4,
                                              seed: 1_441,
                                              compartment: compartment)
            expect(opening.allSatisfy { hypot($0.offset.width, $0.offset.height) >= 0.11 },
                   "the first four tokens must form a directed stack without a center rosette")
        }
    }

    private static func occupiedWellsUseAtLeastThreeNonCongruentSilhouettes() {
        let occupied: [TravelCompartment] = [.poch, .mariage, .sequence, .jack]
        let fingerprints = Set(occupied.map { compartment in
            let poses = R1TokenSlots.layout(for: 3,
                                            seed: 1_441,
                                            compartment: compartment)
            var distances: [Int] = []
            for left in poses.indices {
                for right in poses.indices where right > left {
                    let distance = hypot(poses[left].offset.width - poses[right].offset.width,
                                         poses[left].offset.height - poses[right].offset.height)
                    distances.append(Int((distance * 1_000).rounded()))
                }
            }
            return distances.sorted().map(String.init).joined(separator: ",")
        })
        expect(fingerprints.count >= 3,
               "the four occupied opening wells need at least three non-congruent silhouettes")
    }

    private static func compartmentsDoNotCloneOnePile() {
        let fingerprints = Set(TravelCompartment.allCases.map { compartment in
            R1TokenSlots.layout(for: 4,
                                seed: 1_441,
                                compartment: compartment)
                .map { pose in
                    "\(rounded(pose.offset.width)),\(rounded(pose.offset.height)),\(rounded(pose.rotation))"
                }
                .joined(separator: ";")
        })
        expect(fingerprints.count == TravelCompartment.allCases.count,
               "all nine wells need distinct deterministic end layouts")
    }

    private static func rounded(_ value: Double) -> Int {
        Int((value * 1_000).rounded())
    }

    private static func expect(_ condition: @autoclosure () -> Bool,
                               _ message: String) {
        guard condition() else {
            FileHandle.standardError.write(Data("R1TokenLayoutTests: \(message)\n".utf8))
            Foundation.exit(EXIT_FAILURE)
        }
    }
}
