import Foundation

@main
struct DealTableauLayoutTests {
    static func main() {
        elevenCardOpponentTableauKeepsEveryCardVisible()
        opponentTableauxAreStableButNotCloned()
        flightProfilesAreSubtleAndDeterministic()
        FileHandle.standardOutput.write(Data("DealTableauLayoutTests: PASS\n".utf8))
    }

    private static func elevenCardOpponentTableauKeepsEveryCardVisible() {
        let poses = (0..<11).map {
            DealTableauLayout.opponentPose(slot: $0, totalSlots: 11)
        }
        let horizontalOffsets = poses.map { Int(($0.offset.width * 1_000).rounded()) }
        let rotations = poses.map { Int(($0.rotationDegrees * 1_000).rounded()) }

        expect(Set(horizontalOffsets).count == 11,
               "every dealt card needs its own visible opponent slot")
        expect(Set(rotations).count == 11,
               "compressed tableaux must not collapse later rotations")
        expect(zip(horizontalOffsets, horizontalOffsets.dropFirst()).allSatisfy {
            $0.0 < $0.1
        },
               "opponent slots must stay ordered from left to right")
        expect(abs(poses[0].offset.width + poses[10].offset.width) <= 2.3,
               "natural edge variation must still leave the tableau visually centered")
        expect(poses.allSatisfy { $0.offset.height <= -15 },
               "opponent card fans must settle above, not across, player portraits")
    }

    private static func opponentTableauxAreStableButNotCloned() {
        let seatOne = (0..<8).map {
            DealTableauLayout.opponentPose(
                slot: $0,
                totalSlots: 8,
                seat: 1,
                roundGeneration: 7
            )
        }
        let repeatedSeatOne = (0..<8).map {
            DealTableauLayout.opponentPose(
                slot: $0,
                totalSlots: 8,
                seat: 1,
                roundGeneration: 7
            )
        }
        let seatTwo = (0..<8).map {
            DealTableauLayout.opponentPose(
                slot: $0,
                totalSlots: 8,
                seat: 2,
                roundGeneration: 7
            )
        }
        let nextRound = (0..<8).map {
            DealTableauLayout.opponentPose(
                slot: $0,
                totalSlots: 8,
                seat: 1,
                roundGeneration: 8
            )
        }

        expect(seatOne == repeatedSeatOne,
               "the same public deal coordinates must reproduce the same fan")
        expect(seatOne != seatTwo,
               "different seats must not receive cloned card fans")
        expect(seatOne != nextRound,
               "a new round should not repeat the exact same resting arrangement")
        expect(zip(seatOne, seatOne.dropFirst()).allSatisfy {
            $0.0.offset.width < $0.1.offset.width
        },
               "subtle variation must preserve left-to-right card ordering")
        expect(seatOne.allSatisfy {
            abs($0.offset.width) <= 27 &&
                $0.offset.height >= -22 && $0.offset.height <= -15 &&
                abs($0.rotationDegrees) <= 13
        },
               "resting variation must remain restrained and readable")
    }

    private static func flightProfilesAreSubtleAndDeterministic() {
        let profiles = (0..<12).map {
            DealTableauLayout.flightProfile(
                roundGeneration: 4,
                sequence: $0,
                seat: ($0 % 3) + 1,
                slot: $0 / 3
            )
        }
        let repeated = (0..<12).map {
            DealTableauLayout.flightProfile(
                roundGeneration: 4,
                sequence: $0,
                seat: ($0 % 3) + 1,
                slot: $0 / 3
            )
        }

        expect(profiles == repeated,
               "flight character must be deterministic for replay and UI tests")
        expect(Set(profiles.map { Int(($0.lateralBias * 1_000).rounded()) }).count >= 8,
               "dealing must use more than a repeating three-path cadence")
        expect(Set(profiles.map { Int(($0.pointsPerSecond * 1_000).rounded()) }).count >= 8,
               "flight timing must have subtle per-card variance")
        expect(profiles.allSatisfy {
            (610...692).contains($0.pointsPerSecond) &&
                (-3.5...4.5).contains($0.arcLift) &&
                (-10...10).contains($0.lateralBias) &&
                (0...0.022).contains($0.launchDelay) &&
                (-2.6...2.6).contains($0.midflightTwistDegrees)
        },
               "flight variance must stay inside the restrained physical envelope")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
            exit(1)
        }
    }
}
