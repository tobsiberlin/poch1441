import Foundation

@main
struct TravelTableContractTests {
    static func main() {
        exactTopologyIsStable()
        normalizedCentersAreDistinctAndContained()
        wellsStayDistinct()
        variantsReplayAndDiffer()
        restingPosesReplayAndDoNotJump()
        restingPosesFitTheirPreparedFloor()
        clampingIsSafe()

        FileHandle.standardOutput.write(Data("TravelTableContractTests: PASS\n".utf8))
    }

    private static func exactTopologyIsStable() {
        expect(TravelTableGeometry.compartments.count == 9, "Track B must expose exactly 8+1 fields")
        expect(
            Array(TravelTableGeometry.compartments.prefix(8)) == [
                .king, .queen, .mariage, .jack,
                .ten, .sequence, .poch, .ace
            ],
            "Outer fields must stay clockwise from twelve o'clock"
        )
        expect(TravelTableGeometry.compartments.last == .center, "The ninth field must be center")
    }

    private static func normalizedCentersAreDistinctAndContained() {
        let centers = TravelTableGeometry.compartments.map(TravelTableGeometry.center(for:))
        expect(Set(centers.map { "\($0.x):\($0.y)" }).count == 9, "Every field needs a unique center")
        expect(
            centers.allSatisfy { (0.08...0.92).contains($0.x) && (0.08...0.92).contains($0.y) },
            "Every field center must stay inside the tray's safe region"
        )
    }

    private static func wellsStayDistinct() {
        let compartments = TravelTableGeometry.compartments
        for firstIndex in compartments.indices {
            for secondIndex in compartments.indices where secondIndex > firstIndex {
                let first = compartments[firstIndex]
                let second = compartments[secondIndex]
                let firstCenter = TravelTableGeometry.center(for: first)
                let secondCenter = TravelTableGeometry.center(for: second)
                let distance = hypot(
                    firstCenter.x - secondCenter.x,
                    firstCenter.y - secondCenter.y
                )
                let minimumDistance = (
                    TravelTableGeometry.normalizedWellDiameter(for: first)
                        + TravelTableGeometry.normalizedWellDiameter(for: second)
                ) * 0.5
                expect(
                    distance >= minimumDistance,
                    "Prepared wells must not overlap each other"
                )
            }
        }
    }

    private static func variantsReplayAndDiffer() {
        let first = TravelCentVariant.resolve(seed: 1_441, index: 3)
        let replay = TravelCentVariant.resolve(seed: 1_441, index: 3)
        let next = TravelCentVariant.resolve(seed: 1_441, index: 4)

        expect(first == replay, "Coin wear must replay for the same seed and index")
        expect(first != next, "Visible coins must not all share one wear pattern")
        expect((0.03...0.30).contains(first.oxidation), "Oxidation must remain controlled")
        expect((0.04...0.34).contains(first.edgeWear), "Edge wear must remain controlled")
        expect((2...4).contains(first.scratches.count), "Scratch density must remain restrained")
    }

    private static func restingPosesReplayAndDoNotJump() {
        let firstSix = TravelCoinLayout.poses(count: 6, seed: 19, compartment: .poch)
        let replay = TravelCoinLayout.poses(count: 6, seed: 19, compartment: .poch)
        let firstNine = TravelCoinLayout.poses(count: 9, seed: 19, compartment: .poch)

        expect(firstSix == replay, "End positions must replay exactly")
        expect(Array(firstNine.prefix(6)) == firstSix, "Existing coins must not jump when count grows")
        expect(
            TravelCoinLayout.poses(count: 3, seed: 19, compartment: .ace)
                != TravelCoinLayout.poses(count: 3, seed: 19, compartment: .king),
            "Compartments must not repeat the same visible wear set"
        )
    }

    private static func restingPosesFitTheirPreparedFloor() {
        let coinRadius = 0.5
        let maximumAllowedCenterRadius = 0.68
        let poses = TravelCoinLayout.poses(
            count: TravelCoinLayout.capacity,
            seed: 2_026,
            compartment: .center
        )

        for pose in poses {
            let centerRadius = hypot(pose.offset.x, pose.offset.y)
            expect(
                centerRadius <= maximumAllowedCenterRadius,
                "Prepared coin center must remain inside the tested floor"
            )
            expect(
                centerRadius + coinRadius <= 1.18,
                "Full coin silhouette must remain inside the prepared floor"
            )
        }
    }

    private static func clampingIsSafe() {
        expect(
            TravelCoinLayout.poses(count: -4, seed: 1, compartment: .center).isEmpty,
            "Negative counts must render no coins"
        )
        expect(
            TravelCoinLayout.poses(count: 100, seed: 1, compartment: .center).count
                == TravelCoinLayout.capacity,
            "Oversized piles must clamp to prepared stable poses"
        )
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            FileHandle.standardError.write(Data("TravelTableContractTests: \(message)\n".utf8))
            Foundation.exit(EXIT_FAILURE)
        }
    }
}
