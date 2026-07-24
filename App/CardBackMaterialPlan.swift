/// Identity-neutral assignment of presentation-only back material variants.
///
/// The inputs describe public placement and presentation state. The plan never
/// receives gameplay identity and does not own asset loading or rendering.
enum CardBackMaterialPlan {
    static let variantCount = 10

    /// Returns a stable zero-based material index for one public deal placement.
    /// Advancing `roundGeneration` rotates every placement to the next variant.
    static func variantIndex(
        roundGeneration: Int,
        dealSequence: Int,
        seat: Int,
        slot: Int
    ) -> Int {
        let roundComponent = normalized(roundGeneration)
        let seatComponent = normalized(seat)
        let slotComponent = normalized(slot)
        // Flight and landed-stack call sites can observe different presentation
        // counters. Seat and slot are the stable public placement identity.
        _ = dealSequence

        return (
            roundComponent
                + 3 * seatComponent
                + 7 * slotComponent
        ) % variantCount
    }

    /// Normalizing before multiplication avoids overflow even for extreme
    /// transient counters while preserving the modulo-10 assignment.
    private static func normalized(_ value: Int) -> Int {
        let remainder = value % variantCount
        return remainder >= 0 ? remainder : remainder + variantCount
    }
}
