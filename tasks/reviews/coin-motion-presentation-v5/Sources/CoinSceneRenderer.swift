import Foundation
import UIKit

struct CoinViewport: Codable, Equatable, Sendable {
    let name: String
    let width: Int
    let height: Int

    static let required = [
        Self(name: "390x844", width: 390, height: 844),
        Self(name: "402x874", width: 402, height: 874),
        Self(name: "667x375", width: 667, height: 375),
    ]
}

@MainActor
final class CoinSceneRenderer {
    struct RenderResult {
        let image: UIImage
        let coinCenter: CGPoint
        let shadowCenter: CGPoint
        let coinBounds: CGRect
        let targetCenter: CGPoint
        let drawCount: Int
    }

    private let worldImage: UIImage
    private let coinImages: [UIImage]

    init?() {
        guard let worldURL = Bundle.main.url(forResource: "world-master", withExtension: "png"),
              let world = UIImage(contentsOfFile: worldURL.path) else {
            return nil
        }
        let coins = (0..<6).compactMap { index -> UIImage? in
            guard let url = Bundle.main.url(forResource: "travel-cent-\(index)",
                                            withExtension: "png") else { return nil }
            return UIImage(contentsOfFile: url.path)
        }
        guard coins.count == 6 else { return nil }
        worldImage = world
        coinImages = coins
    }

    func render(viewport: CoinViewport,
                plan: CoinMotionPlan,
                time: Double,
                reducedMotion: Bool = false) -> RenderResult {
        let size = CGSize(width: viewport.width, height: viewport.height)
        let state = plan.state(at: time, reducedMotion: reducedMotion)
        var coinCenter = CGPoint.zero
        var shadowCenter = CGPoint.zero
        var coinBounds = CGRect.zero
        var targetCenter = CGPoint.zero
        var drawCount = 0
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { output in
            let context = output.cgContext
            drawBackground(in: context, size: size, viewport: viewport)
            drawHUD(in: context, size: size, landscape: viewport.width > viewport.height)

            let geometry = sceneGeometry(size: size, viewport: viewport)
            targetCenter = geometry.targetCenter
            let ground = CGPoint(
                x: geometry.targetCenter.x + CGFloat(state.position.x) * geometry.meterScale,
                y: geometry.targetCenter.y + CGFloat(state.position.y) * geometry.meterScale
            )
            let lift = CGFloat(state.bottomGap) * geometry.meterScale * geometry.heightProjection
            coinCenter = CGPoint(x: ground.x, y: ground.y - lift)
            shadowCenter = ground

            let shadowGap = min(1, max(0, CGFloat(state.bottomGap) / 0.10))
            let shadowWidth = geometry.coinDiameter * (0.94 + shadowGap * 0.12)
            let shadowHeight = geometry.coinDiameter * (0.32 + shadowGap * 0.10)
            let shadowRect = CGRect(x: ground.x - shadowWidth * 0.5,
                                    y: ground.y - shadowHeight * 0.10,
                                    width: shadowWidth,
                                    height: shadowHeight)
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: 1.2),
                              blur: 3.0 + 5.0 * shadowGap,
                              color: UIColor.black.withAlphaComponent(0.48 - 0.20 * shadowGap).cgColor)
            context.setFillColor(UIColor.black.withAlphaComponent(0.28 - 0.12 * shadowGap).cgColor)
            context.fillEllipse(in: shadowRect)
            context.restoreGState()

            let coinImage = coinImages[Int(plan.seed % UInt64(coinImages.count))]
            coinBounds = drawCoin(image: coinImage,
                                  state: state,
                                  center: coinCenter,
                                  diameter: geometry.coinDiameter,
                                  context: context)
            drawCount += 1
            drawContactOcclusion(in: context,
                                 state: state,
                                 center: coinCenter,
                                 diameter: geometry.coinDiameter,
                                 target: geometry.targetCenter)
            drawSegmentBadge(in: context,
                             state: state,
                             size: size,
                             landscape: viewport.width > viewport.height,
                             reducedMotion: reducedMotion)
        }
        return RenderResult(image: image,
                            coinCenter: coinCenter,
                            shadowCenter: shadowCenter,
                            coinBounds: coinBounds,
                            targetCenter: targetCenter,
                            drawCount: drawCount)
    }

    private func drawBackground(in context: CGContext,
                                size: CGSize,
                                viewport: CoinViewport) {
        let sourceSize = worldImage.size
        let scale: CGFloat
        let focalSource: CGPoint
        if viewport.width > viewport.height {
            scale = max(size.width / sourceSize.width, size.height / (sourceSize.height * 0.46))
            focalSource = CGPoint(x: 470, y: 835)
        } else {
            scale = max(size.width / sourceSize.width, size.height / sourceSize.height)
            focalSource = CGPoint(x: 470, y: 835)
        }
        let drawSize = CGSize(width: sourceSize.width * scale,
                              height: sourceSize.height * scale)
        let origin = CGPoint(x: size.width * 0.5 - focalSource.x * scale,
                             y: size.height * 0.52 - focalSource.y * scale)
        worldImage.draw(in: CGRect(origin: origin, size: drawSize))

        let colors = [
            UIColor.black.withAlphaComponent(0.76).cgColor,
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.54).cgColor,
        ] as CFArray
        let locations: [CGFloat] = [0, 0.42, 1]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors,
                                     locations: locations) {
            context.drawLinearGradient(gradient,
                                       start: CGPoint(x: 0, y: 0),
                                       end: CGPoint(x: 0, y: size.height),
                                       options: [])
        }
    }

    private func drawHUD(in context: CGContext, size: CGSize, landscape: Bool) {
        let headerHeight: CGFloat = landscape ? 46 : 112
        context.setFillColor(UIColor(red: 0.025, green: 0.020, blue: 0.018, alpha: 0.78).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: size.width, height: headerHeight))

        drawText("POCH", at: CGPoint(x: landscape ? 22 : 24, y: landscape ? 13 : 48),
                 font: .systemFont(ofSize: landscape ? 17 : 25, weight: .bold),
                 color: .white)
        drawText("1441", at: CGPoint(x: landscape ? 78 : 92, y: landscape ? 13 : 48),
                 font: .systemFont(ofSize: landscape ? 17 : 25, weight: .light),
                 color: UIColor(red: 0.84, green: 0.68, blue: 0.35, alpha: 1))

        if landscape {
            drawText("POCHEN · EINSATZ 1", at: CGPoint(x: 172, y: 15),
                     font: .systemFont(ofSize: 13, weight: .semibold),
                     color: UIColor.white.withAlphaComponent(0.72))
        } else {
            drawText("PHASE 2 · POCHEN", at: CGPoint(x: 24, y: 83),
                     font: .systemFont(ofSize: 11, weight: .semibold),
                     color: UIColor.white.withAlphaComponent(0.62))
        }

        let panel = landscape
            ? CGRect(x: 18, y: size.height - 74, width: 222, height: 56)
            : CGRect(x: 22, y: size.height - 118, width: size.width - 44, height: 86)
        context.setFillColor(UIColor(red: 0.055, green: 0.045, blue: 0.040, alpha: 0.90).cgColor)
        let path = UIBezierPath(roundedRect: panel, cornerRadius: landscape ? 18 : 24)
        context.addPath(path.cgPath)
        context.fillPath()
        context.setStrokeColor(UIColor(red: 0.62, green: 0.47, blue: 0.25, alpha: 0.52).cgColor)
        context.setLineWidth(1)
        context.addPath(path.cgPath)
        context.strokePath()
        drawText("MÜNZE SETZEN", at: CGPoint(x: panel.minX + 18, y: panel.minY + 14),
                 font: .systemFont(ofSize: landscape ? 13 : 16, weight: .bold),
                 color: UIColor(red: 0.92, green: 0.79, blue: 0.52, alpha: 1))
        drawText("Kontakt entscheidet · kein Slotting", at: CGPoint(x: panel.minX + 18,
                                                                     y: panel.minY + (landscape ? 34 : 48)),
                 font: .systemFont(ofSize: landscape ? 10 : 12, weight: .regular),
                 color: UIColor.white.withAlphaComponent(0.62))
    }

    private func drawCoin(image: UIImage,
                          state: CoinState,
                          center: CGPoint,
                          diameter: CGFloat,
                          context: CGContext) -> CGRect {
        let normal = state.orientation.rotated(.up)
        let axisU = state.orientation.rotated(V3(x: 1, y: 0, z: 0))
        let axisV = state.orientation.rotated(V3(x: 0, y: 1, z: 0))
        let half = diameter * 0.5
        let ux = CGFloat(axisU.x) * half
        let uy = CGFloat(axisU.y - axisU.z * 0.30) * half
        var vx = CGFloat(axisV.x) * half
        var vy = CGFloat(axisV.y - axisV.z * 0.30) * half
        let determinant = abs(ux * vy - uy * vx)
        let minimumArea = half * half * 0.12
        if determinant < minimumArea {
            let factor = minimumArea / max(determinant, 0.001)
            vx *= factor
            vy *= factor
        }

        let edgeOffset = max(1.0, diameter * 0.065)
        context.saveGState()
        context.translateBy(x: center.x, y: center.y + edgeOffset)
        context.concatenate(CGAffineTransform(a: ux, b: uy, c: vx, d: vy, tx: 0, ty: 0))
        context.setFillColor(UIColor(red: 0.28, green: 0.105, blue: 0.045, alpha: 0.96).cgColor)
        context.fillEllipse(in: CGRect(x: -1, y: -1, width: 2, height: 2))
        context.restoreGState()

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.concatenate(CGAffineTransform(a: ux, b: uy, c: vx, d: vy, tx: 0, ty: 0))
        context.addEllipse(in: CGRect(x: -1, y: -1, width: 2, height: 2))
        context.clip()
        image.draw(in: CGRect(x: -1, y: -1, width: 2, height: 2))
        context.restoreGState()

        let points = [
            CGPoint(x: center.x + ux + vx, y: center.y + uy + vy),
            CGPoint(x: center.x + ux - vx, y: center.y + uy - vy),
            CGPoint(x: center.x - ux + vx, y: center.y - uy + vy),
            CGPoint(x: center.x - ux - vx, y: center.y - uy - vy),
        ]
        let bounds = points.reduce(CGRect.null) { partial, point in
            partial.union(CGRect(x: point.x, y: point.y, width: 0, height: 0))
        }
        _ = normal
        return bounds.insetBy(dx: -edgeOffset, dy: -edgeOffset)
    }

    private func drawContactOcclusion(in context: CGContext,
                                      state: CoinState,
                                      center: CGPoint,
                                      diameter: CGFloat,
                                      target: CGPoint) {
        guard state.bottomGap < 0.0015,
              abs(center.x - target.x) < diameter * 1.4,
              abs(center.y - target.y) < diameter * 1.4 else { return }
        let lip = CGRect(x: target.x - diameter * 1.42,
                         y: target.y + diameter * 0.58,
                         width: diameter * 2.84,
                         height: diameter * 0.18)
        context.saveGState()
        context.setStrokeColor(UIColor(red: 0.13, green: 0.10, blue: 0.08, alpha: 0.72).cgColor)
        context.setLineWidth(diameter * 0.10)
        context.addArc(center: CGPoint(x: lip.midX, y: lip.minY),
                       radius: lip.width * 0.49,
                       startAngle: 0.14,
                       endAngle: .pi - 0.14,
                       clockwise: false)
        context.strokePath()
        context.restoreGState()
    }

    private func drawSegmentBadge(in context: CGContext,
                                  state: CoinState,
                                  size: CGSize,
                                  landscape: Bool,
                                  reducedMotion: Bool) {
        let label = reducedMotion ? "REDUCED · RUHE" : state.segment.rawValue.uppercased()
        let point = CGPoint(x: landscape ? size.width - 170 : 24,
                            y: landscape ? 16 : 16)
        drawText(label, at: point,
                 font: .monospacedSystemFont(ofSize: landscape ? 9 : 10, weight: .semibold),
                 color: UIColor.white.withAlphaComponent(0.48))
    }

    private func sceneGeometry(size: CGSize, viewport: CoinViewport) -> (
        targetCenter: CGPoint,
        meterScale: CGFloat,
        heightProjection: CGFloat,
        coinDiameter: CGFloat
    ) {
        let source = worldImage.size
        let scale: CGFloat
        let focal = CGPoint(x: 470, y: 835)
        if viewport.width > viewport.height {
            scale = max(size.width / source.width, size.height / (source.height * 0.46))
        } else {
            scale = max(size.width / source.width, size.height / source.height)
        }
        let origin = CGPoint(x: size.width * 0.5 - focal.x * scale,
                             y: size.height * 0.52 - focal.y * scale)
        let sourceWell = CGPoint(x: 648, y: 704)
        let target = CGPoint(x: origin.x + sourceWell.x * scale,
                             y: origin.y + sourceWell.y * scale)
        // Production currently uses a roughly 31-pt R1 token. Track B's real
        // 1-cent diameter stays materially legible at 28 pt in portrait and
        // 24 pt in compact landscape instead of becoming a diagnostic speck.
        let coinDiameter = min(viewport.width > viewport.height ? 24 : 28,
                               max(21, size.width * 0.072))
        return (target,
                coinDiameter / CGFloat(CoinMotionPlan.radius * 2),
                viewport.width > viewport.height ? 0.36 : 0.46,
                coinDiameter)
    }

    private func drawText(_ text: String,
                          at point: CGPoint,
                          font: UIFont,
                          color: UIColor) {
        text.draw(at: point, withAttributes: [
            .font: font,
            .foregroundColor: color,
        ])
    }
}
