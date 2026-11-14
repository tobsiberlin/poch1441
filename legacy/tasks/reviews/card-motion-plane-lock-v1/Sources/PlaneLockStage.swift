import SwiftUI

private struct AbsoluteQuadShape: Shape {
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

struct PlaneLockStage: View {
    let snapshot: PlaneLockSnapshot
    var showDiagnostics = true

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

            deckGroundShadow
            sourceDeck

            AbsoluteQuadShape(quad: snapshot.pose.shadowQuad)
                .fill(.black.opacity(shadowOpacity))
                .blur(radius: shadowBlur)

            WarpedProofCard(quad: snapshot.pose.cardQuad, viewport: viewport)

            if showDiagnostics {
                diagnostics
            }
        }
        .frame(width: viewport.width, height: viewport.height)
        .clipped()
        .accessibilityIdentifier("card-plane-lock-v1-stage")
    }

    private var sourceDeck: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { index in
                let offset = PlanePoint(x: Double(index) * -1.2, y: Double(index) * 1.5)
                WarpedProofCard(
                    quad: calibration.sourceQuad.translated(by: offset),
                    viewport: viewport
                )
            }
        }
    }

    private var deckGroundShadow: some View {
        AbsoluteQuadShape(
            quad: calibration.sourceQuad.translated(
                by: lightProfile.keyDirection * -lightProfile.restingShadowOffset
            )
        )
        .fill(.black.opacity(lightProfile.restingShadowOpacity))
        .blur(radius: lightProfile.restingShadowBlur)
    }

    private var diagnostics: some View {
        ZStack {
            AbsoluteQuadShape(quad: calibration.semanticMiddleRegion)
                .stroke(
                    Color.cyan.opacity(0.58),
                    style: StrokeStyle(lineWidth: 0.85, dash: [4, 4])
                )
            diagnosticQuad(calibration.sourceQuad, color: .yellow)
            diagnosticQuad(calibration.targetQuad, color: .green)

            Text("DECK")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.yellow.opacity(0.9))
                .position(x: calibration.sourceQuad.center.x, y: calibration.sourceQuad.topLeft.y - 8)
            Text("MITTE")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.green.opacity(0.9))
                .position(x: calibration.targetQuad.center.x, y: calibration.targetQuad.bottomLeft.y + 9)

            VStack {
                HStack {
                    Text("PLANE LOCK · \(snapshot.pose.phase.rawValue.uppercased())")
                    Spacer()
                    Text(String(
                        format: "t %.3f · z %.1f · c %.2f mm",
                        snapshot.simulationTime,
                        snapshot.pose.height,
                        snapshot.pose.storedMaterialCurlMillimeters
                    ))
                }
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.76))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.black.opacity(0.62))
                Spacer()
            }
        }
        .allowsHitTesting(false)
    }

    private func diagnosticQuad(_ quad: PlaneQuad, color: Color) -> some View {
        AbsoluteQuadShape(quad: quad)
            .stroke(color.opacity(0.9), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
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
