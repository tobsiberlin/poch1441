/// SplitMix64: deterministischer RNG - komplette Partien sind aus Seed + Aktionsliste reproduzierbar (Spec Abschnitt 5).
public struct SeededRNG: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Unverzerrte Ganzzahl in 0..<bound (Rejection-Sampling) - plattform- und
    /// versionsstabil, unabhängig vom stdlib-Range-Mapping.
    public mutating func nextUInt(below bound: UInt64) -> UInt64 {
        precondition(bound > 0, "bound muss > 0 sein")
        let threshold = (0 &- bound) % bound   // 2^64 mod bound
        var r = next()
        while r < threshold { r = next() }
        return r % bound
    }

    /// Ganzzahl im halboffenen Bereich.
    public mutating func nextInt(in range: Range<Int>) -> Int {
        precondition(!range.isEmpty, "range darf nicht leer sein")
        return range.lowerBound + Int(nextUInt(below: UInt64(range.upperBound - range.lowerBound)))
    }

    /// Ganzzahl im geschlossenen Bereich.
    public mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(nextUInt(below: UInt64(range.upperBound - range.lowerBound) + 1))
    }

    /// Double in [0, 1) mit 53-Bit-Mantisse.
    public mutating func nextDouble01() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0)   // 2^53
    }

    /// Double im geschlossenen Bereich.
    public mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + nextDouble01() * (range.upperBound - range.lowerBound)
    }

    /// Deterministischer Fisher-Yates-Shuffle - plattform-stabil, unabhängig von der
    /// stdlib-Shuffle-Implementierung (die nicht versionsübergreifend garantiert ist).
    public mutating func shuffled<T>(_ array: [T]) -> [T] {
        var a = array
        var i = a.count - 1
        while i > 0 {
            a.swapAt(i, Int(nextUInt(below: UInt64(i + 1))))
            i -= 1
        }
        return a
    }
}
