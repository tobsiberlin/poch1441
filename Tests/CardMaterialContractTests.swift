import Foundation

@main
struct CardMaterialContractTests {
    static func main() {
        w2PatinaIsDeterministicAndHalfTurnSymmetric()
        w2APIHasNoCardIdentityInput()
        frontPatinaUsesStableAssetSeedsAndProtectsIndices()
        cardPoseInterpolationIsBounded()
        cardFlightContactIsGenerationBoundAndExactlyOnce()
        reduceMotionPreservesCausalContact()
        FileHandle.standardOutput.write(Data("CardMaterialContractTests: PASS\n".utf8))
    }

    private static func w2PatinaIsDeterministicAndHalfTurnSymmetric() {
        let first = W2BackPatina.marks()
        let second = W2BackPatina.marks()
        expect(first == second, "W2 patina must be deterministic")
        expect(!first.isEmpty && first.count.isMultiple(of: 2),
               "W2 patina must contain complete half-turn pairs")

        for pairStart in stride(from: 0, to: first.count, by: 2) {
            let original = first[pairStart]
            let rotated = first[pairStart + 1]
            expect(rotated == original.rotatedByHalfTurn,
                   "Every W2 mark must have an exact 180-degree partner")
        }
    }

    private static func w2APIHasNoCardIdentityInput() {
        let configuration = W2BackPatinaConfiguration.standard
        expect(W2BackPatina.marks(configuration: configuration) == W2BackPatina.marks(),
               "W2 material parameters must not depend on a card or asset identifier")
    }

    private static func frontPatinaUsesStableAssetSeedsAndProtectsIndices() {
        let assetID = "card_hearts_ace"
        let differentAssetID = "card_spades_seven"
        let first = CardFrontPatina.marks(assetID: assetID)
        let second = CardFrontPatina.marks(assetID: assetID)
        let different = CardFrontPatina.marks(assetID: differentAssetID)
        let configuration = CardFrontPatinaConfiguration.standard

        expect(CardFrontPatina.seed(assetID: assetID) == 13_042_035_730_783_989_557,
               "Asset seeds must use the documented stable hash, not Swift Hasher")
        expect(first == second, "Front patina must be deterministic for one asset")
        expect(first != different, "Different front assets need independent material variation")
        expect(first.count == configuration.markCount,
               "The standard front configuration must place its requested marks")
        for mark in first {
            expect(!configuration.protectedIndexZones.contains {
                $0.intersectsCircle(center: mark.center, radius: mark.radius)
            }, "Front patina must not touch a protected index zone")
        }
        expect(CardFrontPatina.marks(assetID: "").isEmpty,
               "An empty asset identifier must not silently share a patina seed")
    }

    private static func cardPoseInterpolationIsBounded() {
        let source = CardPose(x: 10, y: 20, depth: 2, rotationDegrees: -8, scale: 0.8)
        let target = CardPose(x: 30, y: 60, depth: 0, rotationDegrees: 4, scale: 1)
        expect(source.interpolated(to: target, progress: -1) == source,
               "Pose interpolation must clamp before its source")
        expect(source.interpolated(to: target, progress: 2) == target,
               "Pose interpolation must clamp after its target")
        expect(source.interpolated(to: target, progress: 0.5)
               == CardPose(x: 20, y: 40, depth: 1, rotationDegrees: -2, scale: 0.9),
               "Pose interpolation must be deterministic and renderer-neutral")
    }

    private static func cardFlightContactIsGenerationBoundAndExactlyOnce() {
        var transaction = CardFlightTransaction(
            eventID: "deal-12",
            generation: 7,
            source: .identity,
            target: CardPose(x: 120, y: 80),
            motionPreference: .standard
        )

        expect(transaction.registerContact(eventID: "deal-12", generation: 6) == .stale,
               "An earlier generation must not mutate the active transaction")
        expect(transaction.state == .awaitingContact, "A stale contact must be inert")
        expect(transaction.registerContact(eventID: "deal-12", generation: 7) == .accepted,
               "The matching material contact must be accepted")
        expect(transaction.registerContact(eventID: "deal-12", generation: 7) == .duplicate,
               "Animation completion may not emit a second contact")
        expect(transaction.complete(eventID: "other-event", generation: 7) == false,
               "A different event may not complete the transaction")
        expect(transaction.complete(eventID: "deal-12", generation: 7),
               "A contacted transaction may complete")
        expect(transaction.state == .completed, "The transaction must expose completion")
    }

    private static func reduceMotionPreservesCausalContact() {
        var transaction = CardFlightTransaction(
            eventID: "play-4",
            generation: 3,
            source: CardPose(x: 12, y: 18),
            target: CardPose(x: 50, y: 44),
            motionPreference: .reduceMotion
        )

        expect(!transaction.presentationBeats.contains(.spatialFlight),
               "Reduce Motion must remove spatial flight")
        expect(transaction.presentationBeats == [
            .sourceEmphasis, .targetEmphasis, .crossfade, .materialContact
        ], "Reduce Motion must retain source, target and physical contact causality")
        expect(transaction.presentationBeats.filter { $0 == .materialContact }.count == 1,
               "Reduce Motion must expose exactly one contact beat")
        expect(transaction.registerContact(eventID: "play-4", generation: 3) == .accepted,
               "Reduce Motion contact must use the same transaction gate")
        transaction.cancel()
        expect(transaction.state == .cancelled,
               "A contacted but unfinished transaction must remain cancellable")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            FileHandle.standardError.write(Data("CardMaterialContractTests: \(message)\n".utf8))
            Foundation.exit(EXIT_FAILURE)
        }
    }
}
