import Foundation

@main
struct R1TokenLayoutTests {
    static func main() {
        emptyAndCapacityAreExact()
        landedTokensKeepTheirPose()
        posesStayInsideTheUsableFloor()
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
        let tokenToFloorRatio = 0.74
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
