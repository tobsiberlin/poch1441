import XCTest
import simd
@testable import CoinManifoldSolver

final class CoinManifoldSolverTests: XCTestCase {
    func testFrozenProductBudget() {
        XCTAssertEqual(SolverBudget.v4.step, 1.0 / 240.0)
        XCTAssertEqual(SolverBudget.v4.stepsPerRenderFrame, 4)
        XCTAssertEqual(CoinShape.radius * 2, 0.022)
        XCTAssertEqual(CoinShape.halfThickness * 2, 0.0022)
    }

    func testFaceManifoldHasPersistentDistributedIDs() {
        let solver = PersistentManifoldSolver()
        let body = RigidCoin(
            id: 7,
            shape: .cylinder(segments: 48),
            position: Vector3(0, CoinShape.halfThickness, 0),
            orientation: simd_quatd(),
            linearVelocity: .zero,
            angularVelocity: .zero,
            friction: 0.6,
            restitution: 0
        )
        let first = solver.manifold(body: body)
        let second = solver.manifold(body: body)
        XCTAssertEqual(first.count, 4)
        XCTAssertEqual(first.map(\.id), second.map(\.id))
        XCTAssertEqual(Set(first.map(\.id)).count, 4)
    }

    func testWarmStartCacheSurvivesSteps() {
        let solver = PersistentManifoldSolver()
        var body = RigidCoin(
            id: 2,
            shape: .cylinder(segments: 48),
            position: Vector3(0, CoinShape.halfThickness + 0.00005, 0),
            orientation: simd_quatd(),
            linearVelocity: Vector3(0, -0.1, 0),
            angularVelocity: .zero,
            friction: 0.6,
            restitution: 0
        )
        var observedWarmStart = false
        for _ in 0..<20 {
            let metrics = solver.step(body: &body)
            observedWarmStart = observedWarmStart || metrics.warmStartedContacts > 0
        }
        XCTAssertTrue(observedWarmStart)
        XCTAssertGreaterThan(solver.persistentImpulseCount(), 0)
    }

    func testCCDStopsFastFloorCrossing() {
        let solver = PersistentManifoldSolver()
        var body = RigidCoin(
            id: 3,
            shape: .cylinder(segments: 64),
            position: Vector3(0, 0.004, 0),
            orientation: simd_quatd(),
            linearVelocity: Vector3(0, -1.0, 0),
            angularVelocity: .zero,
            friction: 0.6,
            restitution: 0
        )
        let metrics = solver.step(body: &body)
        XCTAssertGreaterThan(metrics.ccdImpacts, 0)
        XCTAssertGreaterThanOrEqual(body.position.y, CoinShape.halfThickness - 0.00015)
    }

    func testSleepDoesNotZeroResidualVelocity() {
        let solver = PersistentManifoldSolver()
        var body = RigidCoin(
            id: 4,
            shape: .cylinder(segments: 48),
            position: Vector3(0, CoinShape.halfThickness, 0),
            orientation: simd_quatd(),
            linearVelocity: Vector3(0.0001, 0, 0),
            angularVelocity: Vector3(0, 0.001, 0),
            friction: 0.6,
            restitution: 0
        )
        for _ in 0..<240 where !body.asleep {
            _ = solver.step(body: &body)
        }
        XCTAssertTrue(body.asleep)
        XCTAssertGreaterThan(simd_length_squared(body.angularVelocity), 0)
    }

    func testSameInitialStateHasSameHash() {
        func hash() -> UInt64 {
            let solver = PersistentManifoldSolver()
            var body = RigidCoin(
                id: 5,
                shape: .cylinder(segments: 12),
                position: Vector3(0, 0.03, 0),
                orientation: simd_quatd(angle: 0.1, axis: Vector3(1, 0, 0)),
                linearVelocity: Vector3(0, -0.2, 0),
                angularVelocity: Vector3(0.5, 0.2, 0.3),
                friction: 0.6,
                restitution: 0
            )
            var hasher = StateHasher()
            for _ in 0..<600 {
                _ = solver.step(body: &body)
                hasher.add(body: body)
            }
            return hasher.value
        }
        XCTAssertEqual(hash(), hash())
    }
}
