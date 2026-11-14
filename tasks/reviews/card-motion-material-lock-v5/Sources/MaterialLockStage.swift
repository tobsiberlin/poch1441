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
    private let sourceRegistration = [
        PlanePoint(x: -1.7, y: 1.4),
        PlanePoint(x: 0.8, y: 1.9),
    ]

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
            MaterialQuadShape(quad: snapshot.pose.shadowQuad)
                .fill(.black.opacity(shadowCoreOpacity))
                .blur(radius: shadowCoreBlur)

            WarpedProductW2Card(
                quad: snapshot.pose.cardQuad,
                viewport: viewport,
                materialVariant: 0
            )
        }
        .frame(width: viewport.width, height: viewport.height)
        .clipped()
        .accessibilityIdentifier("card-material-lock-v3-stage")
    }

    private var sourceDeck: some View {
        ZStack {
            ForEach(sourceRegistration.indices, id: \.self) { index in
                WarpedProductW2Card(
                    quad: calibration.sourceQuad.translated(by: sourceRegistration[index]),
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

    /// A tighter umbra makes the already-directed model shadow legible at the
    /// true phone scale. Its quad and direction remain the frozen V2 values.
    private var shadowCoreOpacity: Double {
        let progress = min(max(snapshot.pose.height / 34, 0), 1)
        return 0.19 - 0.055 * progress
    }

    private var shadowCoreBlur: Double {
        let progress = min(max(snapshot.pose.height / 34, 0), 1)
        return 0.45 + 0.75 * progress
    }
}
