import Foundation

/// Stable variation without the audible 1-2-3 loop produced by `seed % count`.
/// A semantic index may lock dense stack transfers to their matching recording.
enum R1ContactVariantResolver {
    static func resolve(variantCount: Int,
                        seed: Int,
                        familySalt: UInt64,
                        semanticIndex: Int? = nil,
                        previousIndex: Int?) -> Int {
        guard variantCount > 1 else { return 0 }
        if let semanticIndex {
            return min(max(semanticIndex, 0), variantCount - 1)
        }

        var mixed = UInt64(bitPattern: Int64(seed)) ^ familySalt
        mixed &+= 0x9E37_79B9_7F4A_7C15
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        mixed ^= mixed >> 31

        var index = Int(mixed % UInt64(variantCount))
        if index == previousIndex {
            let step = 1 + Int((mixed >> 8) % UInt64(variantCount - 1))
            index = (index + step) % variantCount
        }
        return index
    }
}
