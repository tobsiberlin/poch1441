import CoinManifoldSolver
import Foundation
import simd

private let penetrationLimit = 0.00015
private let energyGrowthLimit = 0.01
private let requiredRest = 0.75
private let repeatCount = 100
private let fuzzCount = 1_000

private struct CaseSpec: Sendable {
    let name: String
    let shape: CoinShape
    let position: Vector3
    let orientation: simd_quatd
    let linearVelocity: Vector3
    let angularVelocity: Vector3
    let bodyFriction: Double
    let bodyRestitution: Double
    let floorFriction: Double
    let floorRestitution: Double
    let requiresRest: Bool
    let requiresLip: Bool
    let maximumDuration: Double
}

private struct RunResult: Sendable {
    let hash: UInt64
    let maximumPenetration: Double
    let maximumEnergyGrowth: Double
    let sustainedRest: Double
    let reachedRest: Bool
    let lipContact: Bool
    let remainedContained: Bool
    let finite: Bool
    let maximumManifoldPoints: Int
    let distinctPersistentContactIDs: Int
    let warmStartCount: Int
    let ccdImpacts: Int
    let sleptWithoutZeroing: Bool
    let steps: Int

    func passes(_ spec: CaseSpec) -> Bool {
        finite
            && remainedContained
            && maximumPenetration <= penetrationLimit
            && maximumEnergyGrowth <= energyGrowthLimit
            && (!spec.requiresRest || reachedRest)
            && (!spec.requiresLip || lipContact)
    }
}

private func rotationX(_ degrees: Double) -> simd_quatd {
    simd_quatd(angle: degrees * .pi / 180, axis: Vector3(1, 0, 0))
}

private func requiredCases() -> [CaseSpec] {
    let calibrationPosition = Vector3(0, 0.0011 + 0.030, 0)
    let calibrationVelocity = Vector3(0, -0.12, 0)
    let centralPosition = Vector3(0, 0.048, -0.012)
    let centralVelocity = Vector3(0.015, -0.34, 0.055)
    return [
        CaseSpec(name: "coin-convex12-face", shape: .cylinder(segments: 12),
                 position: calibrationPosition, orientation: simd_quatd(),
                 linearVelocity: calibrationVelocity, angularVelocity: .zero,
                 bodyFriction: 0.60, bodyRestitution: 0,
                 floorFriction: 0.65, floorRestitution: 0,
                 requiresRest: true, requiresLip: false, maximumDuration: 5),
        CaseSpec(name: "coin-convex48-face", shape: .cylinder(segments: 48),
                 position: calibrationPosition, orientation: simd_quatd(),
                 linearVelocity: calibrationVelocity, angularVelocity: .zero,
                 bodyFriction: 0.60, bodyRestitution: 0,
                 floorFriction: 0.65, floorRestitution: 0,
                 requiresRest: true, requiresLip: false, maximumDuration: 5),
        CaseSpec(name: "coin-convex12-tilt3", shape: .cylinder(segments: 12),
                 position: calibrationPosition, orientation: rotationX(3),
                 linearVelocity: calibrationVelocity, angularVelocity: Vector3(0.5, 0.2, 0.3),
                 bodyFriction: 0.60, bodyRestitution: 0,
                 floorFriction: 0.65, floorRestitution: 0,
                 requiresRest: true, requiresLip: false, maximumDuration: 5),
        CaseSpec(name: "coin-convex48-tilt3", shape: .cylinder(segments: 48),
                 position: calibrationPosition, orientation: rotationX(3),
                 linearVelocity: calibrationVelocity, angularVelocity: Vector3(0.5, 0.2, 0.3),
                 bodyFriction: 0.60, bodyRestitution: 0,
                 floorFriction: 0.65, floorRestitution: 0,
                 requiresRest: true, requiresLip: false, maximumDuration: 5),
        CaseSpec(name: "box-control-face", shape: .boxControl,
                 position: calibrationPosition, orientation: simd_quatd(),
                 linearVelocity: calibrationVelocity, angularVelocity: .zero,
                 bodyFriction: 0.60, bodyRestitution: 0,
                 floorFriction: 0.65, floorRestitution: 0,
                 requiresRest: true, requiresLip: false, maximumDuration: 5),
        CaseSpec(name: "central-face-0deg", shape: .cylinder(segments: 64),
                 position: centralPosition, orientation: simd_quatd(),
                 linearVelocity: centralVelocity, angularVelocity: Vector3(4, 2, 6),
                 bodyFriction: 0.58, bodyRestitution: 0.18,
                 floorFriction: 0.62, floorRestitution: 0.12,
                 requiresRest: true, requiresLip: false, maximumDuration: 6),
        CaseSpec(name: "central-face-minus3deg", shape: .cylinder(segments: 64),
                 position: centralPosition, orientation: rotationX(-3),
                 linearVelocity: centralVelocity, angularVelocity: Vector3(4, 2, 6),
                 bodyFriction: 0.58, bodyRestitution: 0.18,
                 floorFriction: 0.62, floorRestitution: 0.12,
                 requiresRest: true, requiresLip: false, maximumDuration: 6),
        CaseSpec(name: "central-face-plus3deg", shape: .cylinder(segments: 64),
                 position: centralPosition, orientation: rotationX(3),
                 linearVelocity: centralVelocity, angularVelocity: Vector3(4, 2, 6),
                 bodyFriction: 0.58, bodyRestitution: 0.18,
                 floorFriction: 0.62, floorRestitution: 0.12,
                 requiresRest: true, requiresLip: false, maximumDuration: 6),
        CaseSpec(name: "edge-lip-78deg", shape: .cylinder(segments: 64),
                 position: Vector3(0, 0.043, -0.020), orientation: rotationX(78),
                 linearVelocity: Vector3(0.02, -0.07, 0.52),
                 angularVelocity: Vector3(10, 4, 3),
                 bodyFriction: 0.58, bodyRestitution: 0.18,
                 floorFriction: 0.62, floorRestitution: 0.12,
                 requiresRest: false, requiresLip: true, maximumDuration: 2.5),
    ]
}

private func finite(_ vector: Vector3) -> Bool {
    vector.x.isFinite && vector.y.isFinite && vector.z.isFinite
}

private func run(_ spec: CaseSpec, id: Int = 1) -> RunResult {
    let solver = PersistentManifoldSolver(
        floorFriction: spec.floorFriction,
        floorRestitution: spec.floorRestitution
    )
    var body = RigidCoin(
        id: id,
        shape: spec.shape,
        position: spec.position,
        orientation: spec.orientation,
        linearVelocity: spec.linearVelocity,
        angularVelocity: spec.angularVelocity,
        friction: spec.bodyFriction,
        restitution: spec.bodyRestitution
    )
    let initialEnergy = mechanicalEnergy(body: body)
    var maximumEnergy = initialEnergy
    var maximumPenetration = 0.0
    var sustainedRest = 0.0
    var maximumRest = 0.0
    var lipContact = false
    var remainedContained = true
    var isFinite = true
    var maximumManifoldPoints = 0
    var allContactIDs = Set<ContactID>()
    var warmStartCount = 0
    var ccdImpacts = 0
    var sleptWithoutZeroing = false
    var hasher = StateHasher()
    var steps = 0
    let maximumSteps = Int(ceil(spec.maximumDuration / SolverBudget.v4.step))

    for step in 0..<maximumSteps {
        let metrics = solver.step(body: &body)
        maximumPenetration = max(maximumPenetration, metrics.maximumPenetration,
                                 solver.maximumAnalyticPenetration(body: body))
        maximumManifoldPoints = max(maximumManifoldPoints, metrics.generatedContactCount)
        allContactIDs.formUnion(metrics.contactIDs)
        warmStartCount += metrics.warmStartedContacts
        ccdImpacts += metrics.ccdImpacts
        lipContact = lipContact || metrics.lipContact
        maximumEnergy = max(maximumEnergy, mechanicalEnergy(body: body))
        hasher.add(body: body)

        let quiet = simd_length(body.linearVelocity) < SolverBudget.v4.linearSleepThreshold
            && simd_length(body.angularVelocity) < SolverBudget.v4.angularSleepThreshold
        sustainedRest = quiet ? sustainedRest + SolverBudget.v4.step : 0
        maximumRest = max(maximumRest, sustainedRest)
        if body.asleep {
            sleptWithoutZeroing = sleptWithoutZeroing
                || simd_length_squared(body.linearVelocity) > 0
                || simd_length_squared(body.angularVelocity) > 0
        }
        remainedContained = remainedContained
            && abs(body.position.x) <= 0.09 + CoinShape.radius
            && body.position.z >= -0.07 - CoinShape.radius
            && body.position.z <= 0.07 + CoinShape.radius
            && body.position.y >= -0.01
        isFinite = isFinite
            && finite(body.position)
            && finite(body.linearVelocity)
            && finite(body.angularVelocity)
            && body.orientation.vector.x.isFinite
            && body.orientation.vector.y.isFinite
            && body.orientation.vector.z.isFinite
            && body.orientation.vector.w.isFinite
        steps = step + 1
        if spec.requiresRest, maximumRest + 1e-12 >= requiredRest { break }
    }
    let growth = max(0, maximumEnergy - initialEnergy) / max(abs(initialEnergy), 1e-12)
    return RunResult(
        hash: hasher.value,
        maximumPenetration: maximumPenetration,
        maximumEnergyGrowth: growth,
        sustainedRest: maximumRest,
        reachedRest: maximumRest + 1e-12 >= requiredRest,
        lipContact: lipContact,
        remainedContained: remainedContained,
        finite: isFinite,
        maximumManifoldPoints: maximumManifoldPoints,
        distinctPersistentContactIDs: allContactIDs.count,
        warmStartCount: warmStartCount,
        ccdImpacts: ccdImpacts,
        sleptWithoutZeroing: sleptWithoutZeroing,
        steps: steps
    )
}

private func hex(_ value: UInt64) -> String {
    String(format: "0x%016llx", value)
}

private func resultDictionary(spec: CaseSpec,
                              reference: RunResult,
                              hashes: Set<UInt64>) -> [String: Any] {
    [
        "name": spec.name,
        "shape": String(describing: spec.shape),
        "verdict": reference.passes(spec) && hashes.count == 1 ? "GREEN" : "RED",
        "hash": hex(reference.hash),
        "repeatCount": repeatCount,
        "uniqueHashes": hashes.count,
        "maximumPenetrationMillimeters": reference.maximumPenetration * 1_000,
        "maximumMechanicalEnergyGrowthRatio": reference.maximumEnergyGrowth,
        "sustainedRestSeconds": reference.sustainedRest,
        "reachedRequiredRest": reference.reachedRest,
        "lipContact": reference.lipContact,
        "remainedContained": reference.remainedContained,
        "finite": reference.finite,
        "maximumGeneratedManifoldPoints": reference.maximumManifoldPoints,
        "distinctPersistentContactIDs": reference.distinctPersistentContactIDs,
        "warmStartApplications": reference.warmStartCount,
        "ccdImpacts": reference.ccdImpacts,
        "sleptWithNonzeroResidualVelocity": reference.sleptWithoutZeroing,
        "steps": reference.steps,
    ]
}

private func randomEarlyGate() -> [String: Any] {
    var rng = SplitMix64(seed: 1_441)
    var failures = 0
    var penetrationFailures = 0
    var energyFailures = 0
    var restFailures = 0
    var containmentFailures = 0
    var finiteFailures = 0
    var maximumPenetration = 0.0
    var maximumEnergyGrowth = 0.0
    var combinedHash = StateHasher()

    for index in 0..<fuzzCount {
        let tiltX = rng.value(in: -70...70)
        let tiltZ = rng.value(in: -30...30)
        let orientation = simd_normalize(
            simd_quatd(angle: tiltZ * .pi / 180, axis: Vector3(0, 0, 1))
                * rotationX(tiltX)
        )
        let shape = CoinShape.cylinder(segments: 64)
        let localUp = orientation.inverse.act(Vector3(0, 1, 0))
        let extent = shape.supportExtent(direction: -localUp)
        let gap = rng.value(in: 0.001...0.025)
        let spec = CaseSpec(
            name: "random-\(index)",
            shape: shape,
            position: Vector3(rng.value(in: -0.055...0.055), extent + gap,
                              rng.value(in: -0.045...0.025)),
            orientation: orientation,
            linearVelocity: Vector3(rng.value(in: -0.08...0.08),
                                    rng.value(in: -0.45 ... -0.02),
                                    rng.value(in: -0.08...0.08)),
            angularVelocity: Vector3(rng.value(in: -8...8),
                                     rng.value(in: -8...8),
                                     rng.value(in: -8...8)),
            bodyFriction: 0.60,
            bodyRestitution: 0.05,
            floorFriction: 0.65,
            floorRestitution: 0,
            requiresRest: true,
            requiresLip: false,
            maximumDuration: 3.0
        )
        let result = run(spec, id: index + 10)
        maximumPenetration = max(maximumPenetration, result.maximumPenetration)
        maximumEnergyGrowth = max(maximumEnergyGrowth, result.maximumEnergyGrowth)
        if result.maximumPenetration > penetrationLimit { penetrationFailures += 1 }
        if result.maximumEnergyGrowth > energyGrowthLimit { energyFailures += 1 }
        if !result.reachedRest { restFailures += 1 }
        if !result.remainedContained { containmentFailures += 1 }
        if !result.finite { finiteFailures += 1 }
        if !result.passes(spec) { failures += 1 }
        combinedHash.add(Double(result.hash))
    }

    return [
        "seed": 1_441,
        "count": fuzzCount,
        "verdict": failures == 0 ? "GREEN" : "RED",
        "failures": failures,
        "penetrationFailures": penetrationFailures,
        "energyFailures": energyFailures,
        "restFailures": restFailures,
        "containmentFailures": containmentFailures,
        "finiteFailures": finiteFailures,
        "maximumPenetrationMillimeters": maximumPenetration * 1_000,
        "maximumMechanicalEnergyGrowthRatio": maximumEnergyGrowth,
        "combinedHash": hex(combinedHash.value),
    ]
}

private func percentile(_ values: [Double], _ fraction: Double) -> Double {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted()
    let index = min(sorted.count - 1, max(0, Int(ceil(Double(sorted.count) * fraction)) - 1))
    return sorted[index]
}

private func nineCoinPerformance() -> [String: Any] {
    var bodies: [RigidCoin] = []
    var solvers: [PersistentManifoldSolver] = []
    var id = 0
    for row in 0..<3 {
        for column in 0..<3 {
            id += 1
            let tilt = Double((row * 3 + column) - 4) * 1.5
            bodies.append(RigidCoin(
                id: id,
                shape: .cylinder(segments: 64),
                position: Vector3(Double(column - 1) * 0.035, 0.025 + Double(row) * 0.004,
                                  Double(row - 1) * 0.025),
                orientation: rotationX(tilt),
                linearVelocity: Vector3(Double(column - 1) * 0.02, -0.25,
                                        Double(row - 1) * 0.025),
                angularVelocity: Vector3(3 + Double(row), 2, 4 + Double(column)),
                friction: 0.60,
                restitution: 0.05
            ))
            solvers.append(PersistentManifoldSolver())
        }
    }

    let clock = ContinuousClock()
    var stepMicroseconds: [Double] = []
    var renderFrameMicroseconds: [Double] = []
    let renderFrames = 600
    for _ in 0..<renderFrames {
        let frameStart = clock.now
        for _ in 0..<SolverBudget.v4.stepsPerRenderFrame {
            let start = clock.now
            for index in bodies.indices {
                _ = solvers[index].step(body: &bodies[index])
            }
            let duration = start.duration(to: clock.now)
            stepMicroseconds.append(Double(duration.components.attoseconds) / 1e12
                                    + Double(duration.components.seconds) * 1e6)
        }
        let frameDuration = frameStart.duration(to: clock.now)
        renderFrameMicroseconds.append(Double(frameDuration.components.attoseconds) / 1e12
                                       + Double(frameDuration.components.seconds) * 1e6)
    }

    return [
        "scope": "nine independent coins against shared-shape static floor/lip; no coin-coin contacts",
        "coinCount": 9,
        "renderFrames": renderFrames,
        "solverSteps": stepMicroseconds.count,
        "stepP50Microseconds": percentile(stepMicroseconds, 0.50),
        "stepP95Microseconds": percentile(stepMicroseconds, 0.95),
        "stepP99Microseconds": percentile(stepMicroseconds, 0.99),
        "stepMaximumMicroseconds": stepMicroseconds.max() ?? 0,
        "fourStepFrameP99Microseconds": percentile(renderFrameMicroseconds, 0.99),
        "fourStepFrameMaximumMicroseconds": renderFrameMicroseconds.max() ?? 0,
        "budgetMicrosecondsAt60Hz": 16_666.666667,
        "verdict": percentile(renderFrameMicroseconds, 0.99) <= 16_666.666667 ? "GREEN" : "RED",
    ]
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: CoinManifoldSpike <result.json>\n".utf8))
    exit(2)
}

private let cases = requiredCases()
var caseReports: [[String: Any]] = []
var requiredGreen = true
for spec in cases {
    let reference = run(spec)
    var hashes: Set<UInt64> = [reference.hash]
    for _ in 1..<repeatCount {
        hashes.insert(run(spec).hash)
    }
    let report = resultDictionary(spec: spec, reference: reference, hashes: hashes)
    requiredGreen = requiredGreen && (report["verdict"] as? String == "GREEN")
    caseReports.append(report)
}

let earlyGate = randomEarlyGate()
let performance = nineCoinPerformance()
let earlyGreen = earlyGate["verdict"] as? String == "GREEN"
let performanceGreen = performance["verdict"] as? String == "GREEN"
let overallGreen = requiredGreen && earlyGreen && performanceGreen

let report: [String: Any] = [
    "schemaVersion": 1,
    "verdict": overallGreen ? "GREEN" : "RED",
    "requiredCasesVerdict": requiredGreen ? "GREEN" : "RED",
    "earlyGateVerdict": earlyGreen ? "GREEN" : "RED",
    "performanceVerdict": performanceGreen ? "GREEN" : "RED",
    "productBudget": [
        "solverStepSeconds": SolverBudget.v4.step,
        "solverStepsPer60HzFrame": SolverBudget.v4.stepsPerRenderFrame,
        "velocityIterations": SolverBudget.v4.velocityIterations,
        "contactBandMillimeters": SolverBudget.v4.contactBand * 1_000,
        "penetrationSlopMillimeters": SolverBudget.v4.penetrationSlop * 1_000,
        "baumgarte": SolverBudget.v4.baumgarte,
        "rollingResistance": SolverBudget.v4.rollingResistance,
        "penetrationLimitMillimeters": penetrationLimit * 1_000,
        "energyGrowthLimitRatio": energyGrowthLimit,
        "requiredRestSeconds": requiredRest,
        "repeatCount": repeatCount,
        "randomStartCount": fuzzCount,
    ],
    "features": [
        "persistent feature IDs",
        "up to four distributed contact points per plane",
        "warm-started sequential normal and Coulomb friction impulses",
        "bounded rolling-resistance angular impulse",
        "quaternion and world-inertia integration",
        "translation-and-rotation plane TOI CCD",
        "natural sleep retaining nonzero residual velocity",
    ],
    "requiredCases": caseReports,
    "randomStartEarlyGate": earlyGate,
    "nineCoinPerformance": performance,
    "limitations": [
        "headless macOS only",
        "finite one-sided floor and lip plane patches, not closed tray solids",
        "no coin-coin collision in the nine-coin benchmark",
        "no renderer or app integration",
    ],
]

let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
print("solver=\(overallGreen ? "GREEN" : "RED") required=\(requiredGreen ? "GREEN" : "RED") early=\(earlyGreen ? "GREEN" : "RED") performance=\(performanceGreen ? "GREEN" : "RED")")
exit(overallGreen ? 0 : 1)
