import Combine
import Foundation
import os
import RealityKit
import UIKit
import simd

@MainActor
final class VisualRunnerViewController: UIViewController {
    private enum Constants {
        static let coinRadius: Float = 0.011
        static let coinThickness: Float = 0.0022
        static let coinMass: Float = 0.0045
        static let gravity: Float = 9.81
        static let floorY: Float = -0.125
        static let floorThickness: Float = 0.004
        static let floorTopY: Float = -0.123
        static let trayCenterZ: Float = -0.360
        static let trayHalfWidth: Float = 0.090
        static let trayHalfDepth: Float = 0.070
        static let lipPosition = SIMD3<Float>(0, floorY + 0.012, trayCenterZ + 0.064)
        static let lipSize = SIMD3<Float>(0.190, 0.006, 0.030)
        static let lipOrientation = simd_quatf(angle: -25 * .pi / 180, axis: SIMD3<Float>(1, 0, 0))
        static let visualPixelLimit = 0.5
        static let restOverlapLimitMeters = 0.00015
        static let energyGainLimit = 0.01
        static let linearRestLimit: Float = 0.015
        static let angularRestLimit: Float = 0.8
        static let restDuration = 0.75
        static let captureInterval = 0.10
    }

    private struct Viewport {
        let name: String
        let width: Int
        let height: Int
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

    private struct ActiveRun {
        let viewport: Viewport
        let spec: CaseSpec
        let initialEnergy: Double
        let directory: URL
        var elapsed = 0.0
        var frameCount = 0
        var captureCount = 0
        var lastCaptureTime = -Double.infinity
        var allImagesExact = true
        var contactCount = 0
        var lipContact = false
        var maximumReportedPenetration = 0.0
        var maximumAnalyticOverlap = 0.0
        var maximumProjectedPenetration = 0.0
        var maximumEnergy = 0.0
        var sustainedRest = 0.0
        var remainedContained = true
        var contactPoint = CGPoint.zero
        var completionRequested = false
        var timedOut = false
        var trace: [DisplayFrameTraceRecord] = []
    }

    private static let log = Logger(
        subsystem: "com.tobc.reviews.coin-realitykit-visual-v3",
        category: "VisualContract"
    )

    private let status: VisualStatusModel
    private let arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
    private let rootAnchor = AnchorEntity(world: .zero)
    private var subscriptions: [any Cancellable] = []
    private var coinMesh: MeshResource?
    private var coinShape: ShapeResource?
    private var coin: ModelEntity?
    private var floorEntity: ModelEntity?
    private var lipEntity: ModelEntity?
    private var activeRun: ActiveRun?
    private var results: [VisualRunResult] = []
    private var runIndex = 0
    private var capturePending = false
    private var finished = false

    init(status: VisualStatusModel) {
        self.status = status
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    private let viewports = [
        Viewport(name: "390x844", width: 390, height: 844),
        Viewport(name: "667x375", width: 667, height: 375),
        Viewport(name: "402x874", width: 402, height: 874),
    ]

    private var cases: [CaseSpec] {
        [
            CaseSpec(
                name: "floor-convex48-tilt3",
                position: SIMD3<Float>(0, Constants.floorTopY + 0.048, Constants.trayCenterZ - 0.012),
                orientation: simd_quatf(angle: 3 * .pi / 180, axis: SIMD3<Float>(1, 0, 0)),
                linearVelocity: SIMD3<Float>(0.015, -0.34, 0.055),
                angularVelocity: SIMD3<Float>(4, 2, 6),
                requiresRest: true,
                requiresLipContact: false,
                maximumDuration: 6
            ),
            CaseSpec(
                name: "edge-lip-convex48-78deg",
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

    private var runs: [(Viewport, CaseSpec)] {
        viewports.flatMap { viewport in cases.map { (viewport, $0) } }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            try configureViewAndScene()
            installSubscriptions()
            startNextRun()
        } catch {
            failSetup(error)
        }
    }

    private func configureViewAndScene() throws {
        view.backgroundColor = UIColor(red: 0.025, green: 0.020, blue: 0.018, alpha: 1)
        view.clipsToBounds = false
        arView.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        arView.contentScaleFactor = 1
        arView.layer.contentsScale = 1
        arView.environment.background = .color(UIColor(red: 0.050, green: 0.035, blue: 0.028, alpha: 1))
        arView.renderOptions.insert(.disableCameraGrain)
        arView.renderOptions.insert(.disableMotionBlur)
        view.insertSubview(arView, at: 0)
        arView.scene.addAnchor(rootAnchor)

        coinMesh = try CylinderMeshFactory.make(
            radius: Constants.coinRadius,
            height: Constants.coinThickness,
            segments: 48
        )
        guard let coinMesh else { throw VisualSetupError.missingCoinMesh }
        coinShape = ShapeResource.generateConvex(from: coinMesh)

        let floorMaterial = SimpleMaterial(
            color: UIColor(red: 0.24, green: 0.125, blue: 0.075, alpha: 1),
            roughness: 0.78,
            isMetallic: false
        )
        floorEntity = makeStaticBox(
            name: "floor",
            size: SIMD3<Float>(0.180, Constants.floorThickness, 0.140),
            position: SIMD3<Float>(0, Constants.floorY, Constants.trayCenterZ),
            orientation: simd_quatf(angle: 0, axis: SIMD3<Float>(1, 0, 0)),
            material: floorMaterial
        )
        _ = makeStaticBox(
            name: "left-wall",
            size: SIMD3<Float>(0.005, 0.038, 0.145),
            position: SIMD3<Float>(-0.0925, Constants.floorY + 0.019, Constants.trayCenterZ),
            orientation: simd_quatf(angle: 0, axis: SIMD3<Float>(1, 0, 0)),
            material: floorMaterial
        )
        _ = makeStaticBox(
            name: "right-wall",
            size: SIMD3<Float>(0.005, 0.038, 0.145),
            position: SIMD3<Float>(0.0925, Constants.floorY + 0.019, Constants.trayCenterZ),
            orientation: simd_quatf(angle: 0, axis: SIMD3<Float>(1, 0, 0)),
            material: floorMaterial
        )
        _ = makeStaticBox(
            name: "back-wall",
            size: SIMD3<Float>(0.190, 0.038, 0.005),
            position: SIMD3<Float>(0, Constants.floorY + 0.019, Constants.trayCenterZ - 0.0725),
            orientation: simd_quatf(angle: 0, axis: SIMD3<Float>(1, 0, 0)),
            material: floorMaterial
        )
        let lipMaterial = SimpleMaterial(
            color: UIColor(red: 0.79, green: 0.24, blue: 0.055, alpha: 1),
            roughness: 0.42,
            isMetallic: false
        )
        lipEntity = makeStaticBox(
            name: "front-lip",
            size: Constants.lipSize,
            position: Constants.lipPosition,
            orientation: Constants.lipOrientation,
            material: lipMaterial
        )

        let light = DirectionalLight()
        light.light.intensity = 9_000
        light.orientation = simd_quatf(angle: -42 * .pi / 180, axis: SIMD3<Float>(1, 0, 0))
        light.shadow = DirectionalLightComponent.Shadow(maximumDistance: 1.0, depthBias: 0.002)
        rootAnchor.addChild(light)

        let fill = PointLight()
        fill.light.intensity = 1_500
        fill.light.attenuationRadius = 1.0
        fill.position = SIMD3<Float>(-0.12, 0.08, -0.22)
        rootAnchor.addChild(fill)

        let camera = PerspectiveCamera()
        camera.name = "fixed-board-camera"
        camera.camera.fieldOfViewInDegrees = 52
        camera.look(
            at: SIMD3<Float>(0, Constants.floorTopY + 0.004, Constants.trayCenterZ),
            from: SIMD3<Float>(0, 0.200, 0.100),
            relativeTo: nil
        )
        rootAnchor.addChild(camera)
    }

    @discardableResult
    private func makeStaticBox(
        name: String,
        size: SIMD3<Float>,
        position: SIMD3<Float>,
        orientation: simd_quatf,
        material: any Material
    ) -> ModelEntity {
        let entity = ModelEntity(
            mesh: .generateBox(size: size, cornerRadius: 0.001),
            materials: [material]
        )
        entity.name = name
        entity.position = position
        entity.orientation = orientation
        var collision = CollisionComponent(shapes: [.generateBox(size: size)])
        if #available(iOS 18.0, *) { collision.mode = .colliding }
        entity.components.set(collision)
        entity.components.set(PhysicsBodyComponent(
            massProperties: .default,
            material: .generate(staticFriction: 0.62, dynamicFriction: 0.48, restitution: 0.12),
            mode: .static
        ))
        rootAnchor.addChild(entity)
        return entity
    }

    private func installSubscriptions() {
        subscriptions = [
            arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
                self?.handleUpdate(deltaTime: event.deltaTime)
            },
            arView.scene.subscribe(to: CollisionEvents.Began.self) { [weak self] event in
                self?.handleCollisionBegan(event)
            },
            arView.scene.subscribe(to: CollisionEvents.Updated.self) { [weak self] event in
                self?.handleCollisionUpdated(event)
            },
        ]
    }

    private func startNextRun() {
        guard !finished else { return }
        guard runIndex < runs.count else {
            finishReport()
            return
        }
        guard let coinMesh, let coinShape else {
            failSetup(VisualSetupError.missingCoinMesh)
            return
        }

        coin?.removeFromParent()
        let (viewport, spec) = runs[runIndex]
        arView.frame = CGRect(x: 0, y: 0, width: viewport.width, height: viewport.height)
        arView.bounds = CGRect(x: 0, y: 0, width: viewport.width, height: viewport.height)
        arView.contentScaleFactor = 1
        arView.layer.contentsScale = 1

        let material = SimpleMaterial(
            color: UIColor(red: 0.92, green: 0.57, blue: 0.12, alpha: 1),
            roughness: 0.27,
            isMetallic: true
        )
        let entity = ModelEntity(mesh: coinMesh, materials: [material])
        entity.name = "dynamic-coin"
        entity.position = spec.position
        entity.orientation = spec.orientation
        var collision = CollisionComponent(shapes: [coinShape])
        if #available(iOS 18.0, *) { collision.mode = .colliding }
        entity.components.set(collision)

        let radialInertia = Constants.coinMass * (
            3 * Constants.coinRadius * Constants.coinRadius
                + Constants.coinThickness * Constants.coinThickness
        ) / 12
        let axialInertia = 0.5 * Constants.coinMass * Constants.coinRadius * Constants.coinRadius
        var body = PhysicsBodyComponent(
            massProperties: PhysicsMassProperties(
                mass: Constants.coinMass,
                inertia: SIMD3<Float>(radialInertia, axialInertia, radialInertia)
            ),
            material: .generate(staticFriction: 0.58, dynamicFriction: 0.44, restitution: 0.18),
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

        do {
            let directory = try VisualReportWriter.outputDirectory()
                .appendingPathComponent("frames", isDirectory: true)
                .appendingPathComponent(viewport.name, isDirectory: true)
                .appendingPathComponent(spec.name, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let initialEnergy = mechanicalEnergy(entity) ?? 0
            activeRun = ActiveRun(
                viewport: viewport,
                spec: spec,
                initialEnergy: initialEnergy,
                directory: directory,
                maximumEnergy: initialEnergy
            )
            status.title = "\(viewport.name) · \(spec.name)"
            status.verdict = "RUNNING"
            status.detail = "Displayframes 0 · PNG 0"
            Self.log.notice("RUN_START \(viewport.name, privacy: .public) \(spec.name, privacy: .public)")
        } catch {
            failSetup(error)
        }
    }

    private func handleUpdate(deltaTime: TimeInterval) {
        guard !finished, var run = activeRun, let coin else { return }
        if run.completionRequested {
            if !capturePending { completeCurrentRun() }
            return
        }
        let dt = min(max(deltaTime, 0), 0.1)
        run.elapsed += dt
        run.frameCount += 1

        let penetration = projectedPenetration(for: coin)
        run.maximumAnalyticOverlap = max(run.maximumAnalyticOverlap, penetration.overlapMeters)
        run.maximumProjectedPenetration = max(run.maximumProjectedPenetration, penetration.pixels)
        if penetration.pixels >= run.maximumProjectedPenetration {
            run.contactPoint = penetration.screenPoint
        }
        let position = coin.position(relativeTo: nil)
        let quaternion = coin.orientation(relativeTo: nil).vector
        run.trace.append(DisplayFrameTraceRecord(
            frame: run.frameCount,
            timeSeconds: run.elapsed,
            centerXMeters: Double(position.x),
            centerYMeters: Double(position.y),
            centerZMeters: Double(position.z),
            orientationX: Double(quaternion.x),
            orientationY: Double(quaternion.y),
            orientationZ: Double(quaternion.z),
            orientationW: Double(quaternion.w),
            analyticOverlapMillimeters: penetration.overlapMeters * 1_000,
            cameraProjectedPenetrationPixels: penetration.pixels
        ))

        if let energy = mechanicalEnergy(coin) { run.maximumEnergy = max(run.maximumEnergy, energy) }
        let inside = abs(position.x) <= Constants.trayHalfWidth + 0.025
            && position.z >= Constants.trayCenterZ - Constants.trayHalfDepth - 0.030
            && position.z <= Constants.trayCenterZ + Constants.trayHalfDepth + 0.035
            && position.y >= Constants.floorY - 0.050
        run.remainedContained = run.remainedContained && inside

        if run.contactCount > 0, let motion = coin.components[PhysicsMotionComponent.self] {
            let quiet = simd_length(motion.linearVelocity) < Constants.linearRestLimit
                && simd_length(motion.angularVelocity) < Constants.angularRestLimit
            run.sustainedRest = quiet ? run.sustainedRest + dt : 0
        }

        let shouldCapture = run.frameCount == 1
            || run.elapsed - run.lastCaptureTime >= Constants.captureInterval
        if shouldCapture, !capturePending {
            run.lastCaptureTime = run.elapsed
            activeRun = run
            captureFrame()
        } else {
            activeRun = run
        }

        status.detail = String(
            format: "t %.2f s · Displayframes %d · PNG %d\nmax %.3f mm · %.2f px",
            run.elapsed,
            run.frameCount,
            run.captureCount,
            run.maximumAnalyticOverlap * 1_000,
            run.maximumProjectedPenetration
        )

        let restSatisfied = !run.spec.requiresRest || run.sustainedRest >= Constants.restDuration
        let lipSatisfied = !run.spec.requiresLipContact || run.lipContact
        if restSatisfied, lipSatisfied, run.elapsed >= 1.0 {
            run.completionRequested = true
            activeRun = run
        } else if run.elapsed >= run.spec.maximumDuration {
            run.timedOut = true
            run.completionRequested = true
            activeRun = run
        }
    }

    private func projectedPenetration(for entity: ModelEntity) -> (overlapMeters: Double, pixels: Double, screenPoint: CGPoint) {
        let center = entity.position(relativeTo: nil)
        let orientation = entity.orientation(relativeTo: nil)
        let floorSupport = cylinderSupport(center: center, orientation: orientation, direction: SIMD3<Float>(0, -1, 0))
        let floorGap = floorSupport.y - Constants.floorTopY
        let supportInsideFloor = abs(floorSupport.x) <= Constants.trayHalfWidth
            && floorSupport.z >= Constants.trayCenterZ - Constants.trayHalfDepth
            && floorSupport.z <= Constants.trayCenterZ + Constants.trayHalfDepth
        let floorOverlap = supportInsideFloor ? max(0, -Double(floorGap)) : 0
        let floorPlanePoint = SIMD3<Float>(floorSupport.x, Constants.floorTopY, floorSupport.z)
        var best = projectedDistance(from: floorPlanePoint, to: floorSupport, overlap: floorOverlap)

        let lipNormal = Constants.lipOrientation.act(SIMD3<Float>(0, 1, 0))
        let lipPlanePoint = Constants.lipPosition + lipNormal * (Constants.lipSize.y * 0.5)
        let lipSupport = cylinderSupport(center: center, orientation: orientation, direction: -lipNormal)
        let lipGap = simd_dot(lipSupport - lipPlanePoint, lipNormal)
        let local = Constants.lipOrientation.inverse.act(lipSupport - Constants.lipPosition)
        let withinLip = abs(local.x) <= Constants.lipSize.x * 0.5
            && abs(local.z) <= Constants.lipSize.z * 0.5
        if withinLip, lipGap < 0 {
            let lipOverlap = Double(-lipGap)
            let projectedPlane = lipSupport - lipNormal * lipGap
            let candidate = projectedDistance(from: projectedPlane, to: lipSupport, overlap: lipOverlap)
            if candidate.pixels > best.pixels { best = candidate }
        }
        return best
    }

    private func projectedDistance(
        from planePoint: SIMD3<Float>,
        to supportPoint: SIMD3<Float>,
        overlap: Double
    ) -> (overlapMeters: Double, pixels: Double, screenPoint: CGPoint) {
        guard overlap > 0,
              let a = arView.project(planePoint),
              let b = arView.project(supportPoint) else {
            return (overlap, 0, .zero)
        }
        return (overlap, hypot(b.x - a.x, b.y - a.y), b)
    }

    private func cylinderSupport(
        center: SIMD3<Float>,
        orientation: simd_quatf,
        direction: SIMD3<Float>
    ) -> SIMD3<Float> {
        let normalized = simd_normalize(direction)
        let axis = orientation.act(SIMD3<Float>(0, 1, 0))
        let axial = simd_dot(normalized, axis)
        let cap = axis * (axial >= 0 ? Constants.coinThickness * 0.5 : -Constants.coinThickness * 0.5)
        let radialVector = normalized - axis * axial
        let radialLength = simd_length(radialVector)
        let radial = radialLength > 0.000001
            ? radialVector / radialLength * Constants.coinRadius
            : SIMD3<Float>.zero
        return center + cap + radial
    }

    private func captureFrame() {
        guard !capturePending, let run = activeRun else { return }
        capturePending = true
        let index = run.captureCount
        let size = CGSize(width: run.viewport.width, height: run.viewport.height)
        let contactPoint = run.contactPoint == .zero
            ? CGPoint(x: size.width * 0.5, y: size.height * 0.60)
            : run.contactPoint
        let directory = run.directory
        arView.snapshot(saveToHDR: false) { [weak self] image in
            Task { @MainActor [weak self] in
                guard let self else { return }
                defer { self.capturePending = false }
                guard var current = self.activeRun else { return }
                if let image {
                    let normalized = self.normalize(image: image, to: size)
                    let frameURL = directory.appendingPathComponent(String(format: "frame-%04d.png", index))
                    let cropURL = directory.appendingPathComponent(String(format: "crop-%04d.png", index))
                    do {
                        try normalized.pngData()?.write(to: frameURL, options: .atomic)
                        if let crop = self.crop(image: normalized, around: contactPoint, side: 128) {
                            try crop.pngData()?.write(to: cropURL, options: .atomic)
                        }
                        let exact = normalized.cgImage?.width == Int(size.width)
                            && normalized.cgImage?.height == Int(size.height)
                        current.allImagesExact = current.allImagesExact && exact
                        current.captureCount += 1
                        self.activeRun = current
                    } catch {
                        current.allImagesExact = false
                        self.activeRun = current
                        Self.log.error("FRAME_WRITE_FAILED \(error.localizedDescription, privacy: .public)")
                    }
                } else {
                    current.allImagesExact = false
                    self.activeRun = current
                }
            }
        }
    }

    private func normalize(image: UIImage, to size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func crop(image: UIImage, around point: CGPoint, side: CGFloat) -> UIImage? {
        guard let source = image.cgImage else { return nil }
        let x = min(max(0, point.x - side * 0.5), CGFloat(source.width) - side)
        let y = min(max(0, point.y - side * 0.5), CGFloat(source.height) - side)
        guard let result = source.cropping(to: CGRect(x: x, y: y, width: side, height: side)) else { return nil }
        return UIImage(cgImage: result, scale: 1, orientation: .up)
    }

    private func handleCollisionBegan(_ event: CollisionEvents.Began) {
        guard let coin, event.entityA === coin || event.entityB === coin else { return }
        let other = event.entityA === coin ? event.entityB : event.entityA
        guard other === floorEntity || other === lipEntity else { return }
        activeRun?.contactCount += 1
        if other === lipEntity { activeRun?.lipContact = true }
        if #available(iOS 18.0, *), var run = activeRun {
            run.maximumReportedPenetration = max(
                run.maximumReportedPenetration,
                Double(max(0, event.penetrationDistance))
            )
            activeRun = run
        }
    }

    private func handleCollisionUpdated(_ event: CollisionEvents.Updated) {
        guard let coin, event.entityA === coin || event.entityB === coin else { return }
        let other = event.entityA === coin ? event.entityB : event.entityA
        guard other === floorEntity || other === lipEntity else { return }
        if other === lipEntity { activeRun?.lipContact = true }
        if #available(iOS 18.0, *), var run = activeRun {
            run.maximumReportedPenetration = max(
                run.maximumReportedPenetration,
                Double(max(0, event.penetrationDistance))
            )
            activeRun = run
        }
    }

    private func mechanicalEnergy(_ entity: ModelEntity) -> Double? {
        guard let motion = entity.components[PhysicsMotionComponent.self] else { return nil }
        let speedSquared = Double(simd_length_squared(motion.linearVelocity))
        let translational = 0.5 * Double(Constants.coinMass) * speedSquared
        let radial = Constants.coinMass * (
            3 * Constants.coinRadius * Constants.coinRadius
                + Constants.coinThickness * Constants.coinThickness
        ) / 12
        let axial = 0.5 * Constants.coinMass * Constants.coinRadius * Constants.coinRadius
        let omega = motion.angularVelocity
        let rotational = 0.5 * Double(
            radial * omega.x * omega.x + axial * omega.y * omega.y + radial * omega.z * omega.z
        )
        let height = max(0, entity.position(relativeTo: nil).y - Constants.floorTopY)
        let potential = Double(Constants.coinMass * Constants.gravity * height)
        return translational + rotational + potential
    }

    private func completeCurrentRun() {
        guard let run = activeRun, let coin else { return }
        let settledOverlap = run.spec.requiresRest
            ? max(0, -Double(cylinderSupport(
                center: coin.position(relativeTo: nil),
                orientation: coin.orientation(relativeTo: nil),
                direction: SIMD3<Float>(0, -1, 0)
            ).y - Constants.floorTopY))
            : nil
        let energyGain = run.initialEnergy > 0
            ? max(0, (run.maximumEnergy - run.initialEnergy) / run.initialEnergy)
            : 0
        var technicalFailures: [String] = []
        if run.contactCount == 0 { technicalFailures.append("kein Floor-/Lippenkontakt") }
        if run.spec.requiresLipContact, !run.lipContact { technicalFailures.append("kein Lippenkontakt") }
        if !run.remainedContained { technicalFailures.append("Containment/Tunneling-Gate verletzt") }
        if energyGain > Constants.energyGainLimit {
            technicalFailures.append(String(format: "Energiegewinn %.2f %% > 1.00 %%", energyGain * 100))
        }
        if run.spec.requiresRest, run.sustainedRest < Constants.restDuration {
            technicalFailures.append("Ruhefenster nicht erreicht")
        }
        if let settledOverlap, settledOverlap > Constants.restOverlapLimitMeters {
            technicalFailures.append(String(format: "Ruheüberlappung %.3f mm > 0.150 mm", settledOverlap * 1_000))
        }
        if run.timedOut, technicalFailures.isEmpty { technicalFailures.append("Zeitlimit erreicht") }

        var failures = technicalFailures
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(run.trace).write(
                to: run.directory.appendingPathComponent("display-frame-trace.json"),
                options: .atomic
            )
        } catch {
            failures.append("Displayframe-Spur konnte nicht geschrieben werden: \(error.localizedDescription)")
        }
        if run.maximumProjectedPenetration > Constants.visualPixelLimit {
            failures.append(String(
                format: "Kamera-projizierte Durchdringung %.2f px > 0.50 px",
                run.maximumProjectedPenetration
            ))
        }
        if !run.allImagesExact { failures.append("PNG-Ausgabegröße nicht durchgängig exakt") }
        if run.captureCount < 3 { failures.append("visuelle Laufsequenz unvollständig") }

        results.append(VisualRunResult(
            viewport: run.viewport.name,
            outputSizePixels: SizeRecord(width: run.viewport.width, height: run.viewport.height),
            caseName: run.spec.name,
            displayFramesEvaluated: run.frameCount,
            sequenceFramesCaptured: run.captureCount,
            allCapturedImagesExactSize: run.allImagesExact,
            contactCount: run.contactCount,
            lipContact: run.lipContact,
            maximumReportedPenetrationMillimeters: run.maximumReportedPenetration * 1_000,
            maximumAnalyticOverlapMillimeters: run.maximumAnalyticOverlap * 1_000,
            settledAnalyticOverlapMillimeters: settledOverlap.map { $0 * 1_000 },
            maximumCameraProjectedPenetrationPixels: run.maximumProjectedPenetration,
            maximumEnergyGainRatio: energyGain,
            remainedContained: run.remainedContained,
            sustainedRestSeconds: run.sustainedRest,
            authoredVelocityWritesAfterSpawn: 0,
            authoredTransformWritesAfterSpawn: 0,
            technicalPassed: technicalFailures.isEmpty,
            visualPixelGatePassed: run.maximumProjectedPenetration <= Constants.visualPixelLimit && run.allImagesExact,
            failures: failures,
            frameDirectory: "frames/\(run.viewport.name)/\(run.spec.name)"
        ))
        Self.log.notice("RUN_END \(run.viewport.name, privacy: .public) \(run.spec.name, privacy: .public)")
        activeRun = nil
        self.coin = nil
        coin.removeFromParent()
        runIndex += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { [weak self] in self?.startNextRun() }
    }

    private func finishReport() {
        guard !finished else { return }
        finished = true
        let technical = results.allSatisfy(\.technicalPassed) ? "GREEN" : "RED"
        let visual = results.allSatisfy(\.visualPixelGatePassed) ? "GREEN" : "RED"
        let report = VisualContractReport(
            contract: "RealityKit visual contract V3",
            runtime: UIDevice.current.systemVersion,
            physicalRestOverlapLimitMillimeters: 0.150,
            cameraProjectedPenetrationLimitPixels: 0.5,
            fixedCamera: "PerspectiveCamera FOV 52 deg; from (0, 0.200, 0.100) to (0, -0.119, -0.360); identical world transform for every viewport",
            collisionMeshSegments: 48,
            visualMeshSegments: 48,
            continuousCollisionDetection: true,
            technicalVerdict: technical,
            automatedVisualVerdict: visual,
            priorPhysicalRedPreserved: "V2 0.150-mm transient penetration RED remains authoritative and unchanged; V3 does not rename or replace it.",
            runs: results
        )
        do {
            let url = try VisualReportWriter.write(report)
            status.title = "RealityKit Visual Contract V3"
            status.verdict = "TECH \(technical) · VISUAL \(visual)"
            status.detail = "\(results.count) Läufe · \(url.lastPathComponent)"
            Self.log.notice("VISUAL_RESULT technical=\(technical, privacy: .public) visual=\(visual, privacy: .public)")
        } catch {
            failSetup(error)
        }
    }

    private func failSetup(_ error: Error) {
        finished = true
        status.verdict = "RED"
        status.detail = error.localizedDescription
        Self.log.error("SETUP_FAILED \(error.localizedDescription, privacy: .public)")
    }
}

private enum VisualSetupError: LocalizedError {
    case missingCoinMesh
    var errorDescription: String? { "48-Segment-Münzmesh konnte nicht erzeugt werden." }
}
