import Foundation

@main
struct CoinTransferPlanTests {
    static func main() {
        planIsDeterministicAndConcurrencyBounded()
        standardTransferTraversesEveryLifecycleState()
        impactMutationRunsExactlyOnce()
        staleAndCancelledCallbacksAreInert()
        reduceMotionCompletesSynchronouslyWithoutFlightWait()
        invalidPlansFailClosed()
        FileHandle.standardOutput.write(Data("CoinTransferPlanTests: PASS\n".utf8))
    }

    private static func planIsDeterministicAndConcurrencyBounded() {
        let eventIDs = (0..<7).map { "coin-\($0)" }
        let policy = CoinTransferPolicy(maxConcurrentFlights: 3)
        let first = CoinTransferPlan(
            eventIDs: eventIDs,
            generation: 12,
            motionPreference: .standard,
            policy: policy
        )
        let second = CoinTransferPlan(
            eventIDs: eventIDs,
            generation: 12,
            motionPreference: .standard,
            policy: policy
        )

        expect(first == second, "Transfer planning must be deterministic")
        expect(first.entries.map(\.waveIndex) == [0, 0, 0, 1, 1, 1, 2],
               "Input order must partition into stable bounded waves")
        expect(first.entries.map(\.laneIndex) == [0, 1, 2, 0, 1, 2, 0],
               "Each wave must use deterministic lanes")
        for wave in Set(first.entries.map(\.waveIndex)) {
            expect(first.entries(inWave: wave).count <= policy.maxConcurrentFlights,
                   "No wave may exceed maxConcurrentFlights")
        }
        expect(CoinTransferPolicy.standard.maxConcurrentFlights == 2,
               "The product flight limit must remain a named policy value")
    }

    private static func standardTransferTraversesEveryLifecycleState() {
        var transaction = CoinTransferTransaction(
            eventID: "coin-a",
            generation: 4,
            motionPreference: .standard
        )
        var visited: [CoinTransferLifecycle] = [transaction.lifecycle]

        expect(transaction.depart(eventID: "coin-a", generation: 4) == .accepted,
               "Prepared transfer must depart")
        visited.append(transaction.lifecycle)
        expect(transaction.enterAirborne(eventID: "coin-a", generation: 4) == .accepted,
               "Departed transfer must become airborne")
        visited.append(transaction.lifecycle)
        expect(transaction.registerImpact(eventID: "coin-a", generation: 4) {} == .accepted,
               "Airborne transfer must impact")
        visited.append(transaction.lifecycle)
        expect(transaction.beginSettling(eventID: "coin-a", generation: 4) == .accepted,
               "Impacted transfer must settle")
        visited.append(transaction.lifecycle)
        expect(transaction.complete(eventID: "coin-a", generation: 4) == .accepted,
               "Settling transfer must complete")
        visited.append(transaction.lifecycle)

        expect(visited == [.prepared, .departed, .airborne, .impacted, .settling, .completed],
               "The normal transfer must preserve the complete lifecycle")
    }

    private static func impactMutationRunsExactlyOnce() {
        var transaction = CoinTransferTransaction(
            eventID: "coin-impact",
            generation: 9,
            motionPreference: .standard
        )
        var mutationCount = 0

        expect(transaction.registerImpact(eventID: "coin-impact", generation: 9) {
            mutationCount += 1
        } == .invalidTransition, "Impact before flight must fail closed")
        expect(mutationCount == 0, "An invalid impact must not mutate state")
        expect(transaction.depart(eventID: "coin-impact", generation: 9) == .accepted,
               "Impact test transfer must depart")
        expect(transaction.enterAirborne(eventID: "coin-impact", generation: 9) == .accepted,
               "Impact test transfer must become airborne")
        expect(transaction.registerImpact(eventID: "coin-impact", generation: 9) {
            mutationCount += 1
        } == .accepted, "First matching impact must be accepted")
        expect(transaction.registerImpact(eventID: "coin-impact", generation: 9) {
            mutationCount += 1
        } == .duplicate, "Repeated impact callbacks must be rejected")
        expect(mutationCount == 1, "Atomic impact mutation must execute exactly once")
    }

    private static func staleAndCancelledCallbacksAreInert() {
        var transaction = CoinTransferTransaction(
            eventID: "coin-current",
            generation: 6,
            motionPreference: .standard
        )
        var mutationCount = 0

        expect(transaction.depart(eventID: "coin-current", generation: 5) == .stale,
               "An earlier generation must be stale")
        expect(transaction.lifecycle == .prepared, "A stale callback must be inert")
        expect(transaction.cancel(eventID: "coin-current", generation: 6) == .accepted,
               "Matching cancellation must be accepted")
        expect(transaction.lifecycle == .cancelled, "Cancellation must be terminal")
        expect(transaction.enterAirborne(eventID: "coin-current", generation: 6) == .cancelled,
               "Cancelled transitions must report their gate")
        expect(transaction.registerImpact(eventID: "coin-current", generation: 6) {
            mutationCount += 1
        } == .cancelled, "Cancelled impact callbacks must be rejected")
        expect(mutationCount == 0, "Cancelled impact must never execute its mutation")
    }

    private static func reduceMotionCompletesSynchronouslyWithoutFlightWait() {
        let plan = CoinTransferPlan(
            eventIDs: ["coin-reduced"],
            generation: 11,
            motionPreference: .reduceMotion
        )
        var transaction = CoinTransferTransaction(
            eventID: "coin-reduced",
            generation: 11,
            motionPreference: .reduceMotion
        )
        var mutationCount = 0

        expect(!plan.requiresFlightWait, "Reduce Motion must not retain an invisible timer")
        expect(!plan.presentationBeats.contains(.spatialFlight),
               "Reduce Motion must remove spatial flight")
        expect(plan.presentationBeats == [
            .sourceEmphasis, .targetEmphasis, .crossfade, .materialContact, .settle
        ], "Reduce Motion must retain source, target, crossfade, contact and settling")
        expect(transaction.performReducedMotionTransfer(
            eventID: "coin-reduced",
            generation: 11
        ) {
            mutationCount += 1
        } == .accepted, "Reduce Motion must synchronously perform the transfer")
        expect(transaction.lifecycle == .completed,
               "Reduce Motion must complete without an animation completion callback")
        expect(mutationCount == 1, "Reduce Motion must preserve exactly one atomic impact")
        expect(transaction.performReducedMotionTransfer(
            eventID: "coin-reduced",
            generation: 11
        ) {
            mutationCount += 1
        } == .duplicate, "Repeated Reduce Motion callbacks must be rejected")
        expect(mutationCount == 1, "Duplicate Reduce Motion contact must be inert")
    }

    private static func invalidPlansFailClosed() {
        let invalidPolicy = CoinTransferPolicy(maxConcurrentFlights: 0)
        expect(CoinTransferPlan(
            eventIDs: ["coin-a"],
            generation: 1,
            motionPreference: .standard,
            policy: invalidPolicy
        ).entries.isEmpty, "An invalid concurrency policy must not schedule transfers")
        expect(CoinTransferPlan(
            eventIDs: ["coin-a", "coin-a"],
            generation: 1,
            motionPreference: .standard
        ).entries.isEmpty, "Duplicate event IDs must not create ambiguous transfers")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            FileHandle.standardError.write(Data("CoinTransferPlanTests: \(message)\n".utf8))
            Foundation.exit(EXIT_FAILURE)
        }
    }
}
