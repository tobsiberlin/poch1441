import Foundation

struct Vector3: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    var z: Double

    static let up = Self(x: 0, y: 0, z: 1)

    var lengthSquared: Double { x * x + y * y + z * z }
    var length: Double { sqrt(lengthSquared) }

    func dot(_ other: Self) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    func cross(_ other: Self) -> Self {
        Self(
            x: y * other.z - z * other.y,
            y: z * other.x - x * other.z,
            z: x * other.y - y * other.x
        )
    }

    func normalized(or fallback: Self = .up) -> Self {
        let magnitude = length
        return magnitude > 1e-15 ? self / magnitude : fallback
    }

    static func + (lhs: Self, rhs: Self) -> Self {
        Self(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    static func - (lhs: Self, rhs: Self) -> Self {
        Self(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    static prefix func - (value: Self) -> Self {
        Self(x: -value.x, y: -value.y, z: -value.z)
    }

    static func * (lhs: Self, rhs: Double) -> Self {
        Self(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }

    static func * (lhs: Double, rhs: Self) -> Self { rhs * lhs }

    static func / (lhs: Self, rhs: Double) -> Self {
        Self(x: lhs.x / rhs, y: lhs.y / rhs, z: lhs.z / rhs)
    }
}

struct Quaternion: Codable, Equatable, Sendable {
    var w: Double
    var x: Double
    var y: Double
    var z: Double

    static let identity = Self(w: 1, x: 0, y: 0, z: 0)

    init(w: Double, x: Double, y: Double, z: Double) {
        self.w = w
        self.x = x
        self.y = y
        self.z = z
    }

    init(axis: Vector3, angle: Double) {
        let unit = axis.normalized()
        let half = angle * 0.5
        let sine = sin(half)
        self.init(
            w: cos(half),
            x: unit.x * sine,
            y: unit.y * sine,
            z: unit.z * sine
        )
    }

    var norm: Double { sqrt(w * w + x * x + y * y + z * z) }

    var normalized: Self {
        let magnitude = norm
        guard magnitude > 1e-15 else { return .identity }
        return Self(w: w / magnitude, x: x / magnitude, y: y / magnitude, z: z / magnitude)
    }

    var conjugate: Self { Self(w: w, x: -x, y: -y, z: -z) }

    static func * (lhs: Self, rhs: Self) -> Self {
        Self(
            w: lhs.w * rhs.w - lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z,
            x: lhs.w * rhs.x + lhs.x * rhs.w + lhs.y * rhs.z - lhs.z * rhs.y,
            y: lhs.w * rhs.y - lhs.x * rhs.z + lhs.y * rhs.w + lhs.z * rhs.x,
            z: lhs.w * rhs.z + lhs.x * rhs.y - lhs.y * rhs.x + lhs.z * rhs.w
        ).normalized
    }

    func rotate(_ vector: Vector3) -> Vector3 {
        let pure = Quaternion(w: 0, x: vector.x, y: vector.y, z: vector.z)
        let rotated = self * pure * conjugate
        return Vector3(x: rotated.x, y: rotated.y, z: rotated.z)
    }

    func integrated(worldAngularVelocity: Vector3, duration: Double) -> Self {
        let speed = worldAngularVelocity.length
        guard speed > 1e-15 else { return self }
        return Quaternion(axis: worldAngularVelocity, angle: speed * duration) * self
    }

    func slerped(to target: Self, fraction rawFraction: Double) -> Self {
        let fraction = min(max(rawFraction, 0), 1)
        var destination = target.normalized
        var cosine = w * destination.w + x * destination.x
            + y * destination.y + z * destination.z
        if cosine < 0 {
            destination = Self(w: -destination.w, x: -destination.x,
                               y: -destination.y, z: -destination.z)
            cosine = -cosine
        }
        if cosine > 0.9995 {
            return Self(
                w: w + fraction * (destination.w - w),
                x: x + fraction * (destination.x - x),
                y: y + fraction * (destination.y - y),
                z: z + fraction * (destination.z - z)
            ).normalized
        }
        let angle = acos(min(max(cosine, -1), 1))
        let sine = sin(angle)
        let a = sin((1 - fraction) * angle) / sine
        let b = sin(fraction * angle) / sine
        return Self(
            w: a * w + b * destination.w,
            x: a * x + b * destination.x,
            y: a * y + b * destination.y,
            z: a * z + b * destination.z
        ).normalized
    }

    var yaw: Double {
        atan2(2 * (w * z + x * y), 1 - 2 * (y * y + z * z))
    }
}

struct SeededRandom: Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    mutating func unit(in range: ClosedRange<Double>) -> Double {
        let unit = Double(next() >> 11) / Double(1 << 53)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }
}
