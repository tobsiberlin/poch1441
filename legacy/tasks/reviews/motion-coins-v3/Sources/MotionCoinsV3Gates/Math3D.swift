import Foundation

struct Vector3: Equatable, Sendable {
    var x: Double
    var y: Double
    var z: Double

    static let zero = Vector3(x: 0, y: 0, z: 0)
    static let up = Vector3(x: 0, y: 0, z: 1)

    var lengthSquared: Double { dot(self) }
    var length: Double { sqrt(lengthSquared) }

    func dot(_ other: Vector3) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    func cross(_ other: Vector3) -> Vector3 {
        Vector3(
            x: y * other.z - z * other.y,
            y: z * other.x - x * other.z,
            z: x * other.y - y * other.x
        )
    }

    func normalized(or fallback: Vector3 = .zero) -> Vector3 {
        let magnitude = length
        guard magnitude > 1e-14 else { return fallback }
        return self / magnitude
    }

    static prefix func - (value: Vector3) -> Vector3 {
        Vector3(x: -value.x, y: -value.y, z: -value.z)
    }

    static func + (left: Vector3, right: Vector3) -> Vector3 {
        Vector3(x: left.x + right.x, y: left.y + right.y, z: left.z + right.z)
    }

    static func - (left: Vector3, right: Vector3) -> Vector3 {
        Vector3(x: left.x - right.x, y: left.y - right.y, z: left.z - right.z)
    }

    static func * (left: Vector3, right: Double) -> Vector3 {
        Vector3(x: left.x * right, y: left.y * right, z: left.z * right)
    }

    static func * (left: Double, right: Vector3) -> Vector3 { right * left }

    static func / (left: Vector3, right: Double) -> Vector3 {
        Vector3(x: left.x / right, y: left.y / right, z: left.z / right)
    }
}

struct Quaternion: Equatable, Sendable {
    var real: Double
    var imaginary: Vector3

    static let identity = Quaternion(real: 1, imaginary: .zero)

    init(real: Double, imaginary: Vector3) {
        self.real = real
        self.imaginary = imaginary
    }

    init(axis: Vector3, angle: Double) {
        let unitAxis = axis.normalized(or: .up)
        let halfAngle = angle * 0.5
        self.init(real: cos(halfAngle), imaginary: unitAxis * sin(halfAngle))
    }

    var norm: Double { sqrt(real * real + imaginary.lengthSquared) }

    var conjugate: Quaternion {
        Quaternion(real: real, imaginary: -imaginary)
    }

    var normalized: Quaternion {
        let magnitude = norm
        guard magnitude > 1e-14 else { return .identity }
        return Quaternion(real: real / magnitude, imaginary: imaginary / magnitude)
    }

    func rotate(_ vector: Vector3) -> Vector3 {
        let pure = Quaternion(real: 0, imaginary: vector)
        return (self * pure * conjugate).imaginary
    }

    func integrated(worldAngularVelocity omega: Vector3, duration: Double) -> Quaternion {
        let speed = omega.length
        guard speed > 1e-14, duration > 0 else { return self }
        let delta = Quaternion(axis: omega / speed, angle: speed * duration)
        return (delta * self).normalized
    }

    func angularDistance(to other: Quaternion) -> Double {
        let a = normalized
        let b = other.normalized
        let value = min(1, max(-1, abs(a.real * b.real + a.imaginary.dot(b.imaginary))))
        return 2 * acos(value)
    }

    static func * (left: Quaternion, right: Quaternion) -> Quaternion {
        Quaternion(
            real: left.real * right.real - left.imaginary.dot(right.imaginary),
            imaginary: right.imaginary * left.real
                + left.imaginary * right.real
                + left.imaginary.cross(right.imaginary)
        )
    }
}

extension Double {
    var degrees: Double { self * 180 / .pi }
}
