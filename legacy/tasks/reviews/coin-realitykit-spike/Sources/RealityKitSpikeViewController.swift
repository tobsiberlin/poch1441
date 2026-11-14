import Combine
import Foundation
import os
import RealityKit
import UIKit
import simd

@MainActor
final class RealityKitSpikeViewController: UIViewController {
    private enum Constants {
        static let coinRadius: Float = 0.011
        static let coinThickness: Float = 0.0022
        static let coinMass: Float = 0.0045
        static let gravity: Float = 9.81
        static let floorY: Float = -0.125
        static let floorTopY: Float = -0.123
        static let trayCenterZ: Float = -0.360
        static let trayHalfWidth: Float = 0.090
        static let trayHalfDepth: Float = 0.070
        static let penetrationLimit: Double = 0.00015
        static let energyGrowthLimit: Double = 0.01
        static let linearRestLimit: Float = 0.015
        static let angularRestLimit: Float = 0.8
        static let requiredRestDuration: Double = 0.5
    }

    private struct CaseSpec {
        let name: String
        let position: SIMD3<Float>
        let orientation: simd_quatf
        let linearVelocity: SIMD3<Float>
        let angularVelocity: SIMD3<Float>
        let requiresRest: Bool
        let requiresLipContact: Bool
        let maximumDuration: Double
    }

    private struct ActiveMeasurement {
        let spec: CaseSpec
        let initialEnergy: Double
        var elapsed = 0.0
        var contactCount = 0
        var penetrationSampleCount = 0
        var maximumPenetration = 0.0
        var maximumEnergy = -Double.infinity
        var maximumOrientationDeltaDegrees = 0.0
        var sustainedRest = 0.0
        var lipContact = false
        var remainedContained = true
    }

    private static let log = Logger(
        subsystem: "com.tobc.reviews.coin-realitykit-spike",
        category: "GateRunner"
    )

    private let status: SpikeStatusModel
    private let arView = ARView(
        frame: .zero,
        cameraMode: .nonAR,
        automaticallyConfigureSession: false
    )
    private let rootAnchor = AnchorEntity(world: .zero)
    private var subscriptions: [any Cancellable] = []
    private var coinMesh: MeshResource?
    private var coinShape: ShapeResource?
    private var coin: ModelEntity?
    private var lipEntity: ModelEntity?
    private var activeMeasurement: ActiveMeasurement?
    private var caseIndex = 0
    private var results: [SpikeCaseResult] = []
    private var frameDurations: [Double] = []
    private var finished = false

    init(status: SpikeStatusModel) {
        self.status = status
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        do {
            try configureScene()
            installSubscriptions()
            startNextCase()
        } catch {
            finishWithSetupFailure(error)
        }
    }

    private var cases: [CaseSpec] {
        let facePosition = SIMD3<Float>(0, Constants.floorTopY + 0.048, Constants.trayCenterZ - 0.012)
        let faceVelocity = SIMD3<Float>(0.015, -0.34, 0.055)
        return [
            CaseSpec(
                name: "central-face-0deg",
                position: facePosition,
                orientation: simd_quatf(angle: 0, axis: SIMD3<Float>(1, 0, 0)),
                linearVelocity: faceVelocity,
                angularVelocity: SIMD3<Float>(4, 2, 6),
                requiresRest: true,
                requiresLipContact: false,
                maximumDuration: 6.0
            ),
            CaseSpec(
                name: "central-face-minus3deg",
                position: facePosition,
                orientation: simd_quatf(angle: -3 * .pi / 180, axis: SIMD3<Float>(1, 0, 0)),
                linearVelocity: faceVelocity,
                angularVelocity: SIMD3<Float>(4, 2, 6),
                requiresRest: true,
                requiresLipContact: false,
                maximumDuration: 6.0
            ),
            CaseSpec(
                name: "central-face-plus3deg",
                position: facePosition,
                orientation: simd_quatf(angle: 3 * .pi / 180, axis: SIMD3<Float>(1, 0, 0)),
                linearVelocity: faceVelocity,
                angularVelocity: SIMD3<Float>(4, 2, 6),
                requiresRest: true,
                requiresLipContact: false,
                maximumDuration: 6.0
            ),
            CaseSpec(
                name: "edge-lip-78deg",
                position: SIMD3<Float>(0, Constants.floorTopY + 0.043, Constants.trayCenterZ - 0.020),
                orientation: simd_quatf(angle: 78 * .pi / 180, axis: SIMD3<Float>(1, 0, 0)),
                linearVelocity: SIMD3<Float>(0.02, -0.07, 0.52),
                angularVelocity: SIMD3<Float>(10, 4, 3),
                requiresRest: false,
                requiresLipContact: true,
                maximumDuration: 2.5
            ),
        ]
    }

    private func configureView() {
        view.backgroundColor = .black
        arView.translatesAutoresizingMaskIntoConstraints = false
        arView.environment.background = .color(UIColor(red: 0.055, green: 0.042, blue: 0.038, alpha: 1))
        arView.renderOptions.insert(.disableCameraGrain)
        arView.renderOptions.insert(.disableMotionBlur)
        view.addSubview(arView)
        NSLayoutConstraint.activate([
            arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            arView.topAnchor.constraint(equalTo: view.topAnchor),
            arView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func configureScene() throws {
        arView.scene.addAnchor(rootAnchor)

        let mesh = try CylinderMeshFactory.make(
            radius: Constants.coinRadius,
            height: Constants.coinThickness
        )
        coinMesh = mesh
        coinShape = ShapeResource.generateConvex(from: mesh)

        let trayMaterial = UnlitMaterial(
            color: UIColor(red: 0.28, green: 0.17, blue: 0.12, alpha: 1)
        )
        let lipMaterial = UnlitMaterial(
            color: UIColor(red: 0.90, green: 0.39, blue: 0.08, alpha: 1)
        )

        _ = makeStaticBox(
            name: "floor",
            size: SIMD3<Float>(0.180, 0.004, 0.140),
            position: SIMD3<Float>(0, Constants.floorY, Constants.trayCenterZ),
            orientation: simd_quatf(angle: 0, axis: SIMD3<Float>(1, 0, 0)),
            material: trayMaterial
        )
        _ = makeStaticBox(
            name: "left-wall",
            size: SIMD3<Float>(0.005, 0.038, 0.145),
            position: SIMD3<Float>(-0.0925, Constants.floorY + 0.019, Constants.trayCenterZ),
            orientation: simd_quatf(angle: 0, axis: SIMD3<Float>(1, 0, 0)),
            material: trayMaterial
        )
        _ = makeStaticBox(
            name: "right-wall",
            size: SIMD3<Float>(0.005, 0.038, 0.145),
            position: SIMD3<Float>(0.0925, Constants.floorY + 0.019, Constants.trayCenterZ),
            orientation: simd_quatf(angle: 0, axis: SIMD3<Float>(1, 0, 0)),
            material: trayMaterial
        )
        _ = makeStaticBox(
            name: "back-wall",
            size: SIMD3<Float>(0.190, 0.038, 0.005),
            position: SIMD3<Float>(0, Constants.floorY + 0.019, Constants.trayCenterZ - 0.0725),
            orientation: simd_quatf(angle: 0, axis: SIMD3<Float>(1, 0, 0)),
            material: trayMaterial
        )
        lipEntity = makeStaticBox(
            name: "front-lip",
            size: SIMD3<Float>(0.190, 0.006, 0.030),
            position: SIMD3<Float>(0, Constants.floorY + 0.012, Constants.trayCenterZ + 0.064),
            orientation: simd_quatf(angle: -25 * .pi / 180, axis: SIMD3<Float>(1, 0, 0)),
            material: lipMaterial
        )

        let light = DirectionalLight()
        light.light.intensity = 4_500
        light.orientation = simd_quatf(angle: -35 * .pi / 180, axis: SIMD3<Float>(1, 0, 0))
        rootAnchor.addChild(light)
    }

    @discardableResult
    private func makeStaticBox(
        name: String,
        size: SIMD3<Float>,
        position: SIMD3<Float>,
        orientation: simd_quatf,
        material: any Material
    ) -> ModelEntity {
        let mesh = MeshResource.generateBox(size: size, cornerRadius: 0.001)
        let shape = ShapeResource.generateBox(size: size)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = name
        entity.position = position
        entity.orientation = orientation
        var collision = CollisionComponent(shapes: [shape])
        if #available(iOS 18.0, *) {
            collision.mode = .colliding
        }
        entity.components.set(collision)
        entity.components.set(PhysicsBodyComponent(
            massProperties: .default,
            material: PhysicsMaterialResource.generate(
                staticFriction: 0.62,
                dynamicFriction: 0.48,
                restitution: 0.12
            ),
            mode: .static
        ))
        rootAnchor.addChild(entity)
        return entity
    }

    private func installSubscriptions() {
        let update = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            self?.handleUpdate(deltaTime: event.deltaTime)
        }
        let began = arView.scene.subscribe(to: CollisionEvents.Began.self) { [weak self] event in
            self?.handleCollisionBegan(event)
        }
        let updated = arView.scene.subscribe(to: CollisionEvents.Updated.self) { [weak self] event in
            self?.handleCollisionUpdated(event)
        }
        subscriptions = [update, began, updated]
    }

    private func startNextCase() {
        guard !finished else { return }
        guard caseIndex < cases.count else {
            finishReport()
            return
        }
        guard let coinMesh, let coinShape else {
            finishWithSetupFailure(SpikeSetupError.missingCoinResources)
            return
        }

        coin?.removeFromParent()
        let spec = cases[caseIndex]
        let coinMaterial = SimpleMaterial(
            color: UIColor(red: 0.72, green: 0.39, blue: 0.12, alpha: 1),
            roughness: 0.32,
            isMetallic: true
        )
        let entity = ModelEntity(mesh: coinMesh, materials: [coinMaterial])
        entity.name = "dynamic-coin"
        entity.position = spec.position
        entity.orientation = spec.orientation
        var collision = CollisionComponent(shapes: [coinShape])
        if #available(iOS 18.0, *) {
            collision.mode = .colliding
        }
        entity.components.set(collision)

        let radialInertia = Constants.coinMass * (
            3 * Constants.coinRadius * Constants.coinRadius
                + Constants.coinThickness * Constants.coinThickness
        ) / 12
        let axialInertia = 0.5 * Constants.coinMass * Constants.coinRadius * Constants.coinRadius
        let massProperties = PhysicsMassProperties(
            mass: Constants.coinMass,
            inertia: SIMD3<Float>(radialInertia, axialInertia, radialInertia)
        )
        var body = PhysicsBodyComponent(
            massProperties: massProperties,
            material: PhysicsMaterialResource.generate(
                staticFriction: 0.58,
                dynamicFriction: 0.44,
                restitution: 0.18
            ),
            mode: .dynamic
        )
        body.isContinuousCollisionDetectionEnabled = true
        if #available(iOS 18.0, *) {
            body.isAffectedByGravity = true
            body.linearDamping = 0
            body.angularDamping = 0
        }
        entity.components.set(body)
        entity.components.set(PhysicsMotionComponent(
            linearVelocity: spec.linearVelocity,
            angularVelocity: spec.angularVelocity
        ))
        rootAnchor.addChild(entity)
        coin = entity

        let initialEnergy = mechanicalEnergy(entity: entity) ?? 0
        activeMeasurement = ActiveMeasurement(
            spec: spec,
            initialEnergy: initialEnergy,
            maximumEnergy: initialEnergy
        )
        status.verdict = "RUNNING"
        status.title = spec.name
        status.detail = "Kontakt 0 | Penetration - | Ruhe 0.000 s"
        Self.log.info("CASE_START \(spec.name, privacy: .public)")
    }

    private func handleUpdate(deltaTime: TimeInterval) {
        guard !finished, var measurement = activeMeasurement, let coin else { return }
        let dt = min(max(deltaTime, 0), 0.1)
        measurement.elapsed += dt
        if deltaTime > 0, deltaTime < 0.1 {
            frameDurations.append(deltaTime)
        }

        if let energy = mechanicalEnergy(entity: coin) {
            measurement.maximumEnergy = max(measurement.maximumEnergy, energy)
        }
        let orientation = coin.orientation(relativeTo: nil)
        let orientationDot = min(1, max(-1, abs(simd_dot(
            orientation.vector,
            measurement.spec.orientation.vector
        ))))
        measurement.maximumOrientationDeltaDegrees = max(
            measurement.maximumOrientationDeltaDegrees,
            Double(2 * acos(orientationDot) * 180 / .pi)
        )
        let position = coin.position(relativeTo: nil)
        let inside = abs(position.x) <= Constants.trayHalfWidth + 0.025
            && position.z >= Constants.trayCenterZ - Constants.trayHalfDepth - 0.030
            && position.z <= Constants.trayCenterZ + Constants.trayHalfDepth + 0.035
            && position.y >= Constants.floorY - 0.050
        measurement.remainedContained = measurement.remainedContained && inside

        if measurement.contactCount > 0,
           let motion = coin.components[PhysicsMotionComponent.self] {
            let linearSpeed = simd_length(motion.linearVelocity)
            let angularSpeed = simd_length(motion.angularVelocity)
            let quiet = linearSpeed < Constants.linearRestLimit
                && angularSpeed < Constants.angularRestLimit
            measurement.sustainedRest = quiet ? measurement.sustainedRest + dt : 0
        }

        activeMeasurement = measurement
        if Int(measurement.elapsed * 10).isMultiple(of: 2) {
            updateStatus(measurement)
        }

        let restSatisfied = !measurement.spec.requiresRest
            || measurement.sustainedRest >= Constants.requiredRestDuration
        let lipSatisfied = !measurement.spec.requiresLipContact || measurement.lipContact
        if restSatisfied, lipSatisfied, measurement.elapsed >= 1.0 {
            completeCurrentCase(timedOut: false)
        } else if measurement.elapsed >= measurement.spec.maximumDuration {
            completeCurrentCase(timedOut: true)
        }
    }

    private func handleCollisionBegan(_ event: CollisionEvents.Began) {
        guard let coin, event.entityA === coin || event.entityB === coin else { return }
        var measurement = activeMeasurement
        measurement?.contactCount += 1
        let other = event.entityA === coin ? event.entityB : event.entityA
        if other === lipEntity {
            measurement?.lipContact = true
        }
        if #available(iOS 18.0, *) {
            recordPenetration(event.penetrationDistance, in: &measurement)
        }
        activeMeasurement = measurement
    }

    private func handleCollisionUpdated(_ event: CollisionEvents.Updated) {
        guard let coin, event.entityA === coin || event.entityB === coin else { return }
        var measurement = activeMeasurement
        if #available(iOS 18.0, *) {
            recordPenetration(event.penetrationDistance, in: &measurement)
        }
        activeMeasurement = measurement
    }

    @available(iOS 18.0, *)
    private func recordPenetration(_ penetration: Float, in measurement: inout ActiveMeasurement?) {
        guard var value = measurement else { return }
        value.penetrationSampleCount += 1
        value.maximumPenetration = max(value.maximumPenetration, Double(max(0, penetration)))
        measurement = value
    }

    private func mechanicalEnergy(entity: ModelEntity) -> Double? {
        guard let motion = entity.components[PhysicsMotionComponent.self] else { return nil }
        let velocitySquared = simd_length_squared(motion.linearVelocity)
        let angular = motion.angularVelocity
        let axis = entity.orientation(relativeTo: nil).act(SIMD3<Float>(0, 1, 0))
        let axialSpeed = simd_dot(angular, axis)
        let radialAngular = angular - axis * axialSpeed
        let radialInertia = Constants.coinMass * (
            3 * Constants.coinRadius * Constants.coinRadius
                + Constants.coinThickness * Constants.coinThickness
        ) / 12
        let axialInertia = 0.5 * Constants.coinMass * Constants.coinRadius * Constants.coinRadius
        let translational = 0.5 * Constants.coinMass * velocitySquared
        let rotational = 0.5 * radialInertia * simd_length_squared(radialAngular)
            + 0.5 * axialInertia * axialSpeed * axialSpeed
        let height = entity.position(relativeTo: nil).y - Constants.floorTopY
        let potential = Constants.coinMass * Constants.gravity * height
        return Double(translational + rotational + potential)
    }

    private func updateStatus(_ measurement: ActiveMeasurement) {
        let penetration = measurement.penetrationSampleCount > 0
            ? String(format: "%.3f mm", measurement.maximumPenetration * 1_000)
            : "keine Samples"
        let growth = relativeEnergyGrowth(measurement)
        status.detail = String(
            format: "t %.2f s | Kontakte %d\nPenetration %@ | dE %.3f%%\nRuhe %.3f s | Lippe %@",
            measurement.elapsed,
            measurement.contactCount,
            penetration,
            growth * 100,
            measurement.sustainedRest,
            measurement.lipContact ? "ja" : "nein"
        )
    }

    private func completeCurrentCase(timedOut: Bool) {
        guard let measurement = activeMeasurement else { return }
        var failures: [String] = []
        if measurement.contactCount == 0 {
            failures.append("kein Münzkontakt")
        }
        if #available(iOS 18.0, *) {
            if measurement.penetrationSampleCount == 0 {
                failures.append("keine Kontaktpenetrations-Samples")
            } else if measurement.maximumPenetration > Constants.penetrationLimit {
                failures.append(String(
                    format: "Kontaktpenetration %.3f mm > %.3f mm",
                    measurement.maximumPenetration * 1_000,
                    Constants.penetrationLimit * 1_000
                ))
            }
        } else {
            failures.append("Kontaktpenetration ist unter iOS 17 nicht öffentlich messbar")
        }
        let energyGrowth = relativeEnergyGrowth(measurement)
        if energyGrowth > Constants.energyGrowthLimit {
            failures.append(String(format: "Energiegewinn %.3f%% > 1.000%%", energyGrowth * 100))
        }
        if measurement.maximumOrientationDeltaDegrees < 5 {
            failures.append(String(
                format: "3D-Rotationsänderung %.3f° < 5.000°",
                measurement.maximumOrientationDeltaDegrees
            ))
        }
        if measurement.spec.requiresRest,
           measurement.sustainedRest < Constants.requiredRestDuration {
            failures.append(String(
                format: "Ruhefenster %.3f s < %.3f s",
                measurement.sustainedRest,
                Constants.requiredRestDuration
            ))
        }
        if measurement.spec.requiresLipContact, !measurement.lipContact {
            failures.append("kein echter Kontakt mit front-lip")
        }
        if !measurement.remainedContained {
            failures.append("Münze hat die Mulde verlassen")
        }
        if timedOut, failures.isEmpty {
            failures.append("Fall lief in das Zeitlimit")
        }

        let result = SpikeCaseResult(
            name: measurement.spec.name,
            contactCount: measurement.contactCount,
            maximumReportedPenetrationMeters: measurement.maximumPenetration,
            maximumRelativeEnergyGrowth: energyGrowth,
            maximumOrientationDeltaDegrees: measurement.maximumOrientationDeltaDegrees,
            sustainedRestSeconds: measurement.sustainedRest,
            lipContact: measurement.lipContact,
            remainedContained: measurement.remainedContained,
            passed: failures.isEmpty,
            failures: failures
        )
        results.append(result)
        Self.log.info("CASE_END \(result.name, privacy: .public) pass=\(result.passed, privacy: .public)")
        caseIndex += 1
        activeMeasurement = nil
        startNextCase()
    }

    private func relativeEnergyGrowth(_ measurement: ActiveMeasurement) -> Double {
        let scale = max(abs(measurement.initialEnergy), 1e-9)
        return max(0, measurement.maximumEnergy - measurement.initialEnergy) / scale
    }

    private func finishReport() {
        guard !finished else { return }
        finished = true
        let verdict = results.allSatisfy(\.passed) ? "GREEN" : "RED"
        let report = SpikeReport(
            sdkRuntime: UIDevice.current.systemVersion,
            verdict: verdict,
            frameP95Milliseconds: percentile95FrameDuration() * 1_000,
            cases: results,
            commands: [
                "xcodegen generate --spec project.yml",
                "xcodebuild -project CoinRealityKitSpike.xcodeproj -scheme CoinRealityKitSpike -sdk iphonesimulator -destination 'platform=iOS Simulator,id=<UDID>' -derivedDataPath .derived build",
                "xcrun simctl install <UDID> .derived/Build/Products/Debug-iphonesimulator/CoinRealityKitSpike.app",
                "xcrun simctl launch <UDID> com.tobc.reviews.coin-realitykit-spike",
            ]
        )
        do {
            let url = try SpikeReportWriter.write(report)
            Self.log.notice("SPIKE_RESULT \(verdict, privacy: .public) \(url.path, privacy: .public)")
            status.verdict = verdict
            status.title = "RealityKit Coin Spike"
            status.detail = results.map { result in
                "\(result.passed ? "PASS" : "FAIL") \(result.name)"
            }.joined(separator: "\n")
        } catch {
            Self.log.error("RESULT_WRITE_FAILED \(error.localizedDescription, privacy: .public)")
            status.verdict = "RED"
            status.detail = "Report konnte nicht geschrieben werden: \(error.localizedDescription)"
        }
    }

    private func finishWithSetupFailure(_ error: Error) {
        guard !finished else { return }
        finished = true
        let result = SpikeCaseResult(
            name: "scene-setup",
            contactCount: 0,
            maximumReportedPenetrationMeters: 0,
            maximumRelativeEnergyGrowth: 0,
            maximumOrientationDeltaDegrees: 0,
            sustainedRestSeconds: 0,
            lipContact: false,
            remainedContained: false,
            passed: false,
            failures: [error.localizedDescription]
        )
        let report = SpikeReport(
            sdkRuntime: UIDevice.current.systemVersion,
            verdict: "RED",
            frameP95Milliseconds: 0,
            cases: [result],
            commands: []
        )
        _ = try? SpikeReportWriter.write(report)
        status.verdict = "RED"
        status.detail = error.localizedDescription
        Self.log.error("SETUP_FAILED \(error.localizedDescription, privacy: .public)")
    }

    private func percentile95FrameDuration() -> Double {
        guard !frameDurations.isEmpty else { return 0 }
        let sorted = frameDurations.sorted()
        let index = min(sorted.count - 1, Int(Double(sorted.count - 1) * 0.95))
        return sorted[index]
    }
}

private enum SpikeSetupError: LocalizedError {
    case missingCoinResources

    var errorDescription: String? {
        switch self {
        case .missingCoinResources:
            "Münzmesh oder Collision Shape fehlt"
        }
    }
}
