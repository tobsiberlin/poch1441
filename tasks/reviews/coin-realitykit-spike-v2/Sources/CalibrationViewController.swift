import Combine
import Foundation
import os
import RealityKit
import UIKit
import simd

@MainActor
final class CalibrationViewController: UIViewController {
    private enum Constants {
        static let coinRadius: Float = 0.011
        static let coinThickness: Float = 0.0022
        static let coinMass: Float = 0.0045
        static let floorCenterY: Float = -0.100
        static let floorThickness: Float = 0.004
        static let floorTopY = floorCenterY + floorThickness * 0.5
        static let sceneZ: Float = -0.340
        static let penetrationLimit: Double = 0.00015
        static let linearRestLimit: Float = 0.015
        static let angularRestLimit: Float = 0.8
        static let requiredRestDuration: Double = 0.75
        static let maximumDuration: Double = 5.0
    }

    private enum BodyKind: String {
        case coinConvex12 = "coin-convex-12"
        case coinConvex48 = "coin-convex-48"
        case boxControl = "box-control"

        var collisionSegments: Int? {
            switch self {
            case .coinConvex12: 12
            case .coinConvex48: 48
            case .boxControl: nil
            }
        }

        var isCoin: Bool { self != .boxControl }
    }

    private struct CaseSpec {
        let name: String
        let kind: BodyKind
        let laneX: Float
        let orientation: simd_quatf
        let angularVelocity: SIMD3<Float>
    }

    private struct ActiveMeasurement {
        let spec: CaseSpec
        var elapsed = 0.0
        var contactCount = 0
        var penetrationSampleCount = 0
        var firstContact: ContactRecord?
        var maximumReportedContact: ContactRecord?
        var lastReportedContact: ContactRecord?
        var settledReportedContact: ContactRecord?
        var minimumGeometryGap = Double.greatestFiniteMagnitude
        var sustainedRest = 0.0
    }

    private static let log = Logger(
        subsystem: "com.tobc.reviews.coin-realitykit-calibration",
        category: "CalibrationRunner"
    )

    private let status: CalibrationStatusModel
    private let arView = ARView(
        frame: .zero,
        cameraMode: .nonAR,
        automaticallyConfigureSession: false
    )
    private let rootAnchor = AnchorEntity(world: .zero)
    private var subscriptions: [any Cancellable] = []
    private var visualCoinMesh: MeshResource?
    private var convex12Shape: ShapeResource?
    private var convex48Shape: ShapeResource?
    private var floorEntity: ModelEntity?
    private var activeBody: ModelEntity?
    private var activeMeasurement: ActiveMeasurement?
    private var caseIndex = 0
    private var results: [CalibrationCaseResult] = []
    private var frameDurations: [Double] = []
    private var finished = false

    init(status: CalibrationStatusModel) {
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
        [
            CaseSpec(
                name: "coin-convex12-face",
                kind: .coinConvex12,
                laneX: -0.100,
                orientation: simd_quatf(angle: 0, axis: SIMD3<Float>(1, 0, 0)),
                angularVelocity: .zero
            ),
            CaseSpec(
                name: "coin-convex48-face",
                kind: .coinConvex48,
                laneX: -0.050,
                orientation: simd_quatf(angle: 0, axis: SIMD3<Float>(1, 0, 0)),
                angularVelocity: .zero
            ),
            CaseSpec(
                name: "coin-convex12-tilt3",
                kind: .coinConvex12,
                laneX: 0,
                orientation: simd_quatf(angle: 3 * .pi / 180, axis: SIMD3<Float>(1, 0, 0)),
                angularVelocity: SIMD3<Float>(0.5, 0.2, 0.3)
            ),
            CaseSpec(
                name: "coin-convex48-tilt3",
                kind: .coinConvex48,
                laneX: 0.050,
                orientation: simd_quatf(angle: 3 * .pi / 180, axis: SIMD3<Float>(1, 0, 0)),
                angularVelocity: SIMD3<Float>(0.5, 0.2, 0.3)
            ),
            CaseSpec(
                name: "box-control-face",
                kind: .boxControl,
                laneX: 0.100,
                orientation: simd_quatf(angle: 0, axis: SIMD3<Float>(1, 0, 0)),
                angularVelocity: .zero
            ),
        ]
    }

    private func configureView() {
        view.backgroundColor = .black
        arView.translatesAutoresizingMaskIntoConstraints = false
        arView.environment.background = .color(UIColor(red: 0.035, green: 0.031, blue: 0.030, alpha: 1))
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
        visualCoinMesh = try CylinderMeshFactory.make(
            radius: Constants.coinRadius,
            height: Constants.coinThickness,
            segments: 64
        )
        let mesh12 = try CylinderMeshFactory.make(
            radius: Constants.coinRadius,
            height: Constants.coinThickness,
            segments: 12
        )
        let mesh48 = try CylinderMeshFactory.make(
            radius: Constants.coinRadius,
            height: Constants.coinThickness,
            segments: 48
        )
        convex12Shape = ShapeResource.generateConvex(from: mesh12)
        convex48Shape = ShapeResource.generateConvex(from: mesh48)

        let floorSize = SIMD3<Float>(0.280, Constants.floorThickness, 0.130)
        let floor = ModelEntity(
            mesh: .generateBox(size: floorSize, cornerRadius: 0),
            materials: [UnlitMaterial(color: UIColor(red: 0.22, green: 0.14, blue: 0.10, alpha: 1))]
        )
        floor.name = "calibrated-box-floor"
        floor.position = SIMD3<Float>(0, Constants.floorCenterY, Constants.sceneZ)
        var collision = CollisionComponent(shapes: [.generateBox(size: floorSize)])
        if #available(iOS 18.0, *) {
            collision.mode = .colliding
        }
        floor.components.set(collision)
        floor.components.set(PhysicsBodyComponent(
            massProperties: .default,
            material: .generate(staticFriction: 0.65, dynamicFriction: 0.52, restitution: 0),
            mode: .static
        ))
        rootAnchor.addChild(floor)
        floorEntity = floor

        let markerMaterial = UnlitMaterial(color: UIColor(white: 0.60, alpha: 1))
        for laneX in cases.map(\.laneX) {
            let marker = ModelEntity(
                mesh: .generateBox(size: SIMD3<Float>(0.001, 0.0002, 0.105)),
                materials: [markerMaterial]
            )
            marker.position = SIMD3<Float>(laneX, Constants.floorTopY + 0.0001, Constants.sceneZ)
            rootAnchor.addChild(marker)
        }

        let light = DirectionalLight()
        light.light.intensity = 5_000
        light.orientation = simd_quatf(angle: -35 * .pi / 180, axis: SIMD3<Float>(1, 0, 0))
        rootAnchor.addChild(light)

        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 60
        camera.look(
            at: SIMD3<Float>(0, Constants.floorTopY, Constants.sceneZ),
            from: SIMD3<Float>(0, 0.150, 0.050),
            relativeTo: nil
        )
        rootAnchor.addChild(camera)
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

        let spec = cases[caseIndex]
        do {
            let entity = try makeDynamicBody(for: spec)
            activeBody = entity
            activeMeasurement = ActiveMeasurement(spec: spec)
            rootAnchor.addChild(entity)
            status.verdict = "RUNNING"
            status.title = spec.name
            status.detail = "Kontakt 0 | Event -\nTransform-Gap - | Ruhe 0.000 s"
            Self.log.info("CASE_START \(spec.name, privacy: .public)")
        } catch {
            finishWithSetupFailure(error)
        }
    }

    private func makeDynamicBody(for spec: CaseSpec) throws -> ModelEntity {
        let dimensions = SIMD3<Float>(
            Constants.coinRadius * 2,
            Constants.coinThickness,
            Constants.coinRadius * 2
        )
        let mesh: MeshResource
        let shape: ShapeResource
        let material: SimpleMaterial

        switch spec.kind {
        case .coinConvex12:
            guard let visualCoinMesh, let convex12Shape else {
                throw CalibrationSetupError.missingResources
            }
            mesh = visualCoinMesh
            shape = convex12Shape
            material = SimpleMaterial(color: UIColor(red: 0.79, green: 0.38, blue: 0.10, alpha: 1), roughness: 0.30, isMetallic: true)
        case .coinConvex48:
            guard let visualCoinMesh, let convex48Shape else {
                throw CalibrationSetupError.missingResources
            }
            mesh = visualCoinMesh
            shape = convex48Shape
            material = SimpleMaterial(color: UIColor(red: 0.93, green: 0.66, blue: 0.18, alpha: 1), roughness: 0.30, isMetallic: true)
        case .boxControl:
            mesh = .generateBox(size: dimensions, cornerRadius: 0)
            shape = .generateBox(size: dimensions)
            material = SimpleMaterial(color: UIColor(red: 0.19, green: 0.58, blue: 0.72, alpha: 1), roughness: 0.40, isMetallic: false)
        }

        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = spec.name
        entity.position = SIMD3<Float>(
            spec.laneX,
            Constants.floorTopY + Constants.coinThickness * 0.5 + 0.030,
            Constants.sceneZ
        )
        entity.orientation = spec.orientation
        var collision = CollisionComponent(shapes: [shape])
        if #available(iOS 18.0, *) {
            collision.mode = .colliding
        }
        entity.components.set(collision)

        let massProperties = massProperties(for: spec.kind)
        var body = PhysicsBodyComponent(
            massProperties: massProperties,
            material: .generate(staticFriction: 0.60, dynamicFriction: 0.48, restitution: 0),
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
            linearVelocity: SIMD3<Float>(0, -0.12, 0),
            angularVelocity: spec.angularVelocity
        ))
        return entity
    }

    private func massProperties(for kind: BodyKind) -> PhysicsMassProperties {
        let mass = Constants.coinMass
        if kind.isCoin {
            let radial = mass * (
                3 * Constants.coinRadius * Constants.coinRadius
                    + Constants.coinThickness * Constants.coinThickness
            ) / 12
            let axial = 0.5 * mass * Constants.coinRadius * Constants.coinRadius
            return PhysicsMassProperties(mass: mass, inertia: SIMD3<Float>(radial, axial, radial))
        }

        let width = Constants.coinRadius * 2
        let height = Constants.coinThickness
        let depth = Constants.coinRadius * 2
        return PhysicsMassProperties(
            mass: mass,
            inertia: SIMD3<Float>(
                mass * (height * height + depth * depth) / 12,
                mass * (width * width + depth * depth) / 12,
                mass * (width * width + height * height) / 12
            )
        )
    }

    private func handleUpdate(deltaTime: TimeInterval) {
        guard !finished, var measurement = activeMeasurement, let activeBody else { return }
        let dt = min(max(deltaTime, 0), 0.1)
        measurement.elapsed += dt
        if deltaTime > 0, deltaTime < 0.1 {
            frameDurations.append(deltaTime)
        }

        let gap = transformGeometrySignedGap(entity: activeBody, kind: measurement.spec.kind)
        measurement.minimumGeometryGap = min(measurement.minimumGeometryGap, gap)

        if measurement.contactCount > 0,
           let motion = activeBody.components[PhysicsMotionComponent.self] {
            let quiet = simd_length(motion.linearVelocity) < Constants.linearRestLimit
                && simd_length(motion.angularVelocity) < Constants.angularRestLimit
            measurement.sustainedRest = quiet ? measurement.sustainedRest + dt : 0
            if quiet, let last = measurement.lastReportedContact {
                measurement.settledReportedContact = ContactRecord(
                    timeSeconds: measurement.elapsed,
                    reportedPenetrationMeters: last.reportedPenetrationMeters,
                    transformGeometrySignedGapMeters: gap
                )
            }
        }

        activeMeasurement = measurement
        if Int(measurement.elapsed * 10).isMultiple(of: 2) {
            updateStatus(measurement, currentGap: gap)
        }

        if measurement.sustainedRest >= Constants.requiredRestDuration {
            completeCurrentCase(timedOut: false)
        } else if measurement.elapsed >= Constants.maximumDuration {
            completeCurrentCase(timedOut: true)
        }
    }

    private func handleCollisionBegan(_ event: CollisionEvents.Began) {
        guard let activeBody,
              event.entityA === activeBody || event.entityB === activeBody,
              event.entityA === floorEntity || event.entityB === floorEntity else { return }
        var measurement = activeMeasurement
        measurement?.contactCount += 1
        if #available(iOS 18.0, *) {
            recordPenetration(event.penetrationDistance, in: &measurement)
        }
        activeMeasurement = measurement
    }

    private func handleCollisionUpdated(_ event: CollisionEvents.Updated) {
        guard let activeBody,
              event.entityA === activeBody || event.entityB === activeBody,
              event.entityA === floorEntity || event.entityB === floorEntity else { return }
        var measurement = activeMeasurement
        if #available(iOS 18.0, *) {
            recordPenetration(event.penetrationDistance, in: &measurement)
        }
        activeMeasurement = measurement
    }

    @available(iOS 18.0, *)
    private func recordPenetration(_ penetration: Float, in measurement: inout ActiveMeasurement?) {
        guard var value = measurement, let activeBody else { return }
        let reported = Double(max(0, penetration))
        let gap = transformGeometrySignedGap(entity: activeBody, kind: value.spec.kind)
        let contact = ContactRecord(
            timeSeconds: value.elapsed,
            reportedPenetrationMeters: reported,
            transformGeometrySignedGapMeters: gap
        )
        value.penetrationSampleCount += 1
        if value.firstContact == nil {
            value.firstContact = contact
        }
        if value.maximumReportedContact == nil
            || reported > (value.maximumReportedContact?.reportedPenetrationMeters ?? 0) {
            value.maximumReportedContact = contact
        }
        value.lastReportedContact = contact
        value.minimumGeometryGap = min(value.minimumGeometryGap, gap)
        measurement = value
    }

    private func transformGeometrySignedGap(entity: ModelEntity, kind: BodyKind) -> Double {
        let orientation = entity.orientation(relativeTo: nil)
        let verticalExtent: Float
        if kind.isCoin {
            let axis = orientation.act(SIMD3<Float>(0, 1, 0))
            let axialVertical = min(1, max(0, abs(axis.y)))
            let radialVertical = sqrt(max(0, 1 - axialVertical * axialVertical))
            verticalExtent = Constants.coinThickness * 0.5 * axialVertical
                + Constants.coinRadius * radialVertical
        } else {
            let half = SIMD3<Float>(
                Constants.coinRadius,
                Constants.coinThickness * 0.5,
                Constants.coinRadius
            )
            let xAxis = orientation.act(SIMD3<Float>(1, 0, 0))
            let yAxis = orientation.act(SIMD3<Float>(0, 1, 0))
            let zAxis = orientation.act(SIMD3<Float>(0, 0, 1))
            verticalExtent = half.x * abs(xAxis.y) + half.y * abs(yAxis.y) + half.z * abs(zAxis.y)
        }
        let supportBottomY = entity.position(relativeTo: nil).y - verticalExtent
        return Double(supportBottomY - Constants.floorTopY)
    }

    private func geometryRecord(entity: ModelEntity, kind: BodyKind) -> GeometryRecord {
        let gap = transformGeometrySignedGap(entity: entity, kind: kind)
        let supportBottom = Double(Constants.floorTopY) + gap
        return GeometryRecord(
            floorTopYMeters: Double(Constants.floorTopY),
            supportBottomYMeters: supportBottom,
            signedGapMeters: gap,
            overlapMeters: max(0, -gap)
        )
    }

    private func transformRecord(entity: ModelEntity) -> TransformRecord {
        let position = entity.position(relativeTo: nil)
        let quaternion = entity.orientation(relativeTo: nil).vector
        return TransformRecord(
            centerPositionMeters: Vector3Record(
                x: Double(position.x),
                y: Double(position.y),
                z: Double(position.z)
            ),
            orientationXYZW: QuaternionRecord(
                x: Double(quaternion.x),
                y: Double(quaternion.y),
                z: Double(quaternion.z),
                w: Double(quaternion.w)
            )
        )
    }

    private func updateStatus(_ measurement: ActiveMeasurement, currentGap: Double) {
        let eventText = measurement.maximumReportedContact.map {
            String(format: "%.3f mm", $0.reportedPenetrationMeters * 1_000)
        } ?? "keine Samples"
        status.detail = String(
            format: "t %.2f s | Kontakte %d\nEvent max %@\nTransform-Gap %.3f mm | Ruhe %.3f s",
            measurement.elapsed,
            measurement.contactCount,
            eventText,
            currentGap * 1_000,
            measurement.sustainedRest
        )
    }

    private func completeCurrentCase(timedOut: Bool) {
        guard let measurement = activeMeasurement, let activeBody else { return }
        let finalGeometry = geometryRecord(entity: activeBody, kind: measurement.spec.kind)
        let maximumReported = measurement.maximumReportedContact?.reportedPenetrationMeters
        var failures: [String] = []

        if measurement.contactCount == 0 {
            failures.append("kein Bodenkontakt")
        }
        if #available(iOS 18.0, *) {
            if let maximumReported {
                if maximumReported > Constants.penetrationLimit {
                    failures.append(String(
                        format: "gemeldete Kontaktpenetration %.3f mm > %.3f mm",
                        maximumReported * 1_000,
                        Constants.penetrationLimit * 1_000
                    ))
                }
            } else {
                failures.append("keine Kontaktpenetrations-Samples")
            }
        } else {
            failures.append("Kontaktpenetration ist unter iOS 17 nicht öffentlich messbar")
        }
        if finalGeometry.overlapMeters > Constants.penetrationLimit {
            failures.append(String(
                format: "finale Transform-Geometrieüberlappung %.3f mm > %.3f mm",
                finalGeometry.overlapMeters * 1_000,
                Constants.penetrationLimit * 1_000
            ))
        }
        let maximumTransformGeometryOverlap = max(0, -measurement.minimumGeometryGap)
        if maximumTransformGeometryOverlap > Constants.penetrationLimit {
            failures.append(String(
                format: "maximale Transform-Geometrieüberlappung %.3f mm > %.3f mm",
                maximumTransformGeometryOverlap * 1_000,
                Constants.penetrationLimit * 1_000
            ))
        }
        if measurement.sustainedRest < Constants.requiredRestDuration {
            failures.append(String(
                format: "Ruhefenster %.3f s < %.3f s",
                measurement.sustainedRest,
                Constants.requiredRestDuration
            ))
        }
        if timedOut, failures.isEmpty {
            failures.append("Fall lief in das Zeitlimit")
        }

        let dimensions = Vector3Record(
            x: Double(Constants.coinRadius * 2),
            y: Double(Constants.coinThickness),
            z: Double(Constants.coinRadius * 2)
        )
        let segments = measurement.spec.kind.collisionSegments
        let sagitta = segments.map {
            Double(Constants.coinRadius) * (1 - cos(Double.pi / Double($0)))
        }
        let result = CalibrationCaseResult(
            name: measurement.spec.name,
            bodyKind: measurement.spec.kind.rawValue,
            nominalDimensionsMeters: dimensions,
            visualMeshSegments: measurement.spec.kind.isCoin ? 64 : nil,
            collisionMeshSegments: segments,
            collisionRadialSagittaMeters: sagitta,
            contactCount: measurement.contactCount,
            penetrationSampleCount: measurement.penetrationSampleCount,
            firstContact: measurement.firstContact,
            maximumReportedContact: measurement.maximumReportedContact,
            lastReportedContact: measurement.lastReportedContact,
            settledReportedContact: measurement.settledReportedContact,
            minimumTransformGeometrySignedGapMeters: measurement.minimumGeometryGap,
            finalTransform: transformRecord(entity: activeBody),
            finalGeometry: finalGeometry,
            sustainedRestSeconds: measurement.sustainedRest,
            passed: failures.isEmpty,
            failures: failures
        )
        results.append(result)
        Self.log.info("CASE_END \(result.name, privacy: .public) pass=\(result.passed, privacy: .public)")
        caseIndex += 1
        self.activeBody = nil
        activeMeasurement = nil
        startNextCase()
    }

    private func finishReport() {
        guard !finished else { return }
        finished = true
        let verdict = results.allSatisfy(\.passed) ? "GREEN" : "RED"
        let report = CalibrationReport(
            sdkRuntime: UIDevice.current.systemVersion,
            verdict: verdict,
            penetrationLimitMeters: Constants.penetrationLimit,
            finding: classifyFinding(),
            frameP95Milliseconds: percentile95FrameDuration() * 1_000,
            cases: results,
            commands: [
                "xcodegen generate --spec project.yml",
                "xcodebuild -project CoinRealityKitCalibration.xcodeproj -scheme CoinRealityKitCalibration -sdk iphonesimulator -destination 'platform=iOS Simulator,id=<UDID>' -derivedDataPath .derived build",
                "xcrun simctl install <UDID> .derived/Build/Products/Debug-iphonesimulator/CoinRealityKitCalibration.app",
                "xcrun simctl launch <UDID> com.tobc.reviews.coin-realitykit-calibration",
            ]
        )
        do {
            let url = try CalibrationReportWriter.write(report)
            Self.log.notice("CALIBRATION_RESULT \(verdict, privacy: .public) \(url.path, privacy: .public)")
            status.verdict = verdict
            status.title = "RealityKit Contact Calibration"
            status.detail = results.map { result in
                let event = result.maximumReportedContact?.reportedPenetrationMeters ?? 0
                let gap = result.finalGeometry.signedGapMeters
                return String(format: "%@ %@ E %.3f | G %.3f mm", result.passed ? "PASS" : "FAIL", result.name, event * 1_000, gap * 1_000)
            }.joined(separator: "\n")
        } catch {
            Self.log.error("RESULT_WRITE_FAILED \(error.localizedDescription, privacy: .public)")
            status.verdict = "RED"
            status.detail = "Report konnte nicht geschrieben werden: \(error.localizedDescription)"
        }
    }

    private func classifyFinding() -> String {
        let eventFailures = results.filter {
            ($0.maximumReportedContact?.reportedPenetrationMeters ?? 0) > Constants.penetrationLimit
        }
        let finalOverlapFailures = results.filter {
            $0.finalGeometry.overlapMeters > Constants.penetrationLimit
        }
        let separatedAtRest = results.filter {
            $0.finalGeometry.signedGapMeters > Constants.penetrationLimit
        }
        let transientMatches = results.filter { result in
            guard let reported = result.maximumReportedContact?.reportedPenetrationMeters else {
                return false
            }
            let transformOverlap = max(0, -result.minimumTransformGeometrySignedGapMeters)
            let tolerance = max(0.00001, reported * 0.10)
            return abs(reported - transformOverlap) <= tolerance
        }

        if !finalOverlapFailures.isEmpty {
            return "transform-geometrisch bestätigte Solverüberlappung"
        }
        if transientMatches.count == results.count {
            return "transiente Solverüberlappung bestätigt: Eventmaximum und transformbasierte Maximalüberlappung stimmen überein; kein persistenter Collision-Margin"
        }
        if !separatedAtRest.isEmpty, separatedAtRest.count == results.count {
            return "konsistenter positiver Endabstand, Collision-Margin-Hypothese"
        }
        if !eventFailures.isEmpty {
            return "Event-Penetration divergiert von transformbasierter Endgeometrie; Messsemantik oder transienter Solver-Kontaktwert"
        }
        return "kein Überschreiten des unveränderten Penetrationslimits"
    }

    private func finishWithSetupFailure(_ error: Error) {
        guard !finished else { return }
        finished = true
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

private enum CalibrationSetupError: LocalizedError {
    case missingResources

    var errorDescription: String? {
        switch self {
        case .missingResources:
            "Kalibrierungsmesh oder Collision Shape fehlt"
        }
    }
}
