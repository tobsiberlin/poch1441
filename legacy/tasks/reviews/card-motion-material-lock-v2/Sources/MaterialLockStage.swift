import SwiftUI

private struct MaterialQuadShape: Shape {
    let quad: PlaneQuad

    func path(in _: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: quad.topLeft.x, y: quad.topLeft.y))
        path.addLine(to: CGPoint(x: quad.topRight.x, y: quad.topRight.y))
        path.addLine(to: CGPoint(x: quad.bottomRight.x, y: quad.bottomRight.y))
        path.addLine(to: CGPoint(x: quad.bottomLeft.x, y: quad.bottomLeft.y))
        path.closeSubpath()
        return path
    }
}

struct MaterialLockStage: View {
    let snapshot: PlaneLockSnapshot

    private let calibration = PlaneLockCalibration()
    private let lightProfile = WorldLightProfile.trackB
    private let viewport = CGSize(
        width: PlaneLockCalibration.viewportWidth,
        height: PlaneLockCalibration.viewportHeight
    )

    var body: some View {
        ZStack {
            Image("TrackBWorld")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: viewport.width, height: viewport.height)
                .clipped()

            Color.black.opacity(lightProfile.backgroundVeilOpacity)

            sourceDeckShadow
            sourceDeck

            MaterialQuadShape(quad: snapshot.pose.shadowQuad)
                .fill(.black.opacity(shadowOpacity))
                .blur(radius: shadowBlur)

            WarpedProductW2Card(
                quad: snapshot.pose.cardQuad,
                viewport: viewport,
                materialVariant: 0
            )
        }
        .frame(width: viewport.width, height: viewport.height)
        .clipped()
        .accessibilityIdentifier("card-material-lock-v2-stage")
    }

    private var sourceDeck: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { index in
                WarpedProductW2Card(
                    quad: calibration.sourceQuad.translated(
                        by: PlanePoint(x: Double(index) * -1.2, y: Double(index) * 1.5)
                    ),
                    viewport: viewport,
                    materialVariant: index + 1
                )
            }
        }
    }

    private var sourceDeckShadow: some View {
        MaterialQuadShape(
            quad: calibration.sourceQuad.translated(
                by: lightProfile.keyDirection * -lightProfile.restingShadowOffset
            )
        )
        .fill(.black.opacity(lightProfile.restingShadowOpacity))
        .blur(radius: lightProfile.restingShadowBlur)
    }

    private var shadowOpacity: Double {
        let progress = min(max(snapshot.pose.height / 34, 0), 1)
        return lightProfile.restingShadowOpacity
            + (lightProfile.airborneShadowOpacity - lightProfile.restingShadowOpacity) * progress
    }

    private var shadowBlur: Double {
        let progress = min(max(snapshot.pose.height / 34, 0), 1)
        return lightProfile.restingShadowBlur
            + (lightProfile.airborneShadowBlur - lightProfile.restingShadowBlur) * progress
    }
}
