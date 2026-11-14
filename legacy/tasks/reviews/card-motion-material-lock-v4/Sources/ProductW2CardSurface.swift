import CoreImage
import SwiftUI
import UIKit

private extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

/// Local, frozen reproduction of the production `App/CardBack.swift` W2.
/// V4 changes only the physical print/material response around that unchanged
/// graphic. Irregular directional fibres, sparse print dropout and compressed
/// edges must survive projection to a 54.85 px short edge without becoming a
/// repeated surface pattern.
struct ProductW2CardBack: View {
    let size: CGSize
    let materialVariant: Int

    private static let damageNames = [
        "card_back_damage_00",
        "card_back_damage_01",
        "card_back_damage_02",
    ]
    private static let facetColors = [
        Color(hex: 0xC5A059),
        Color(hex: 0x8E2A43),
        Color(hex: 0x1A5E4E),
        Color(hex: 0x4A2E65),
    ]
    private static let materialMarks = W2BackPatina.marks()
    private static let directionalFibres: [(
        x: Double, y: Double, length: Double, angle: Double,
        width: Double, opacity: Double, light: Bool
    )] = [
        (0.05, 0.08, 0.24, -7, 0.010, 0.080, true),
        (0.42, 0.06, 0.17, 5, 0.007, 0.055, false),
        (0.72, 0.11, 0.29, -4, 0.009, 0.072, true),
        (0.18, 0.16, 0.12, 8, 0.006, 0.050, false),
        (0.51, 0.20, 0.37, -9, 0.011, 0.065, false),
        (0.90, 0.19, 0.16, 6, 0.006, 0.084, true),
        (0.31, 0.27, 0.23, 3, 0.008, 0.068, true),
        (0.68, 0.31, 0.15, -13, 0.006, 0.048, false),
        (0.08, 0.35, 0.31, 7, 0.010, 0.058, false),
        (0.47, 0.38, 0.18, -5, 0.007, 0.075, true),
        (0.83, 0.41, 0.26, 4, 0.009, 0.055, true),
        (0.22, 0.47, 0.14, -11, 0.006, 0.062, false),
        (0.59, 0.52, 0.34, 6, 0.011, 0.070, false),
        (0.96, 0.55, 0.21, -8, 0.007, 0.080, true),
        (0.12, 0.61, 0.19, 2, 0.007, 0.058, true),
        (0.39, 0.66, 0.28, -6, 0.009, 0.050, false),
        (0.77, 0.69, 0.13, 10, 0.006, 0.076, true),
        (0.25, 0.75, 0.36, 5, 0.010, 0.061, true),
        (0.64, 0.79, 0.20, -12, 0.008, 0.052, false),
        (0.92, 0.83, 0.27, 3, 0.009, 0.070, false),
        (0.07, 0.89, 0.15, -5, 0.006, 0.082, true),
        (0.48, 0.93, 0.31, 8, 0.010, 0.056, true),
        (0.79, 0.97, 0.18, -7, 0.007, 0.064, false),
    ]
    private static let printDropouts: [(
        startX: Double, startY: Double, bendX: Double, bendY: Double,
        endX: Double, endY: Double, width: Double, opacity: Double
    )] = [
        (0.03, 0.13, 0.17, 0.12, 0.28, 0.15, 0.010, 0.075),
        (0.59, 0.10, 0.67, 0.13, 0.84, 0.12, 0.007, 0.058),
        (0.22, 0.31, 0.35, 0.28, 0.49, 0.30, 0.008, 0.067),
        (0.71, 0.36, 0.82, 0.34, 0.98, 0.38, 0.011, 0.064),
        (0.05, 0.50, 0.14, 0.53, 0.29, 0.51, 0.007, 0.060),
        (0.43, 0.57, 0.56, 0.54, 0.73, 0.58, 0.009, 0.072),
        (0.17, 0.70, 0.29, 0.73, 0.46, 0.69, 0.011, 0.056),
        (0.66, 0.78, 0.75, 0.75, 0.91, 0.80, 0.008, 0.069),
        (0.02, 0.91, 0.18, 0.88, 0.34, 0.92, 0.009, 0.062),
        (0.52, 0.96, 0.68, 0.93, 0.98, 0.95, 0.007, 0.052),
    ]
    private let cornerRatio = 8.0 / 52.0

    var body: some View {
        let edgeInset = size.width * 0.0105
        ZStack {
            RoundedRectangle(cornerRadius: size.width * cornerRatio)
                .fill(cardStock)

            ZStack {
                RoundedRectangle(cornerRadius: size.width * cornerRatio * 0.92)
                    .fill(Color(hex: 0x14110F))
                matteInkCoverage
                directionalFibreField
                sparsePrintDropout
                edgeCompression
                fixedWorldLightResponse
                materialPatina
                materialDamage
                facetLozenge
                monograms
            }
            .clipShape(RoundedRectangle(cornerRadius: size.width * cornerRatio * 0.92))
            .padding(edgeInset)
        }
        .frame(width: size.width, height: size.height)
        .overlay {
            RoundedRectangle(cornerRadius: size.width * cornerRatio)
                .strokeBorder(
                    Color(hex: 0x3F3B36).opacity(0.86),
                    lineWidth: max(0.55, size.width * 0.0024)
                )
        }
    }

    private var cardStock: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0x8B8376), Color(hex: 0x5E5951)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// One quiet press-direction drift replaces V3's discrete coverage patches.
    /// It stays subordinate to the W2 graphic and has no repeated local shapes.
    private var matteInkCoverage: some View {
        LinearGradient(
            stops: [
                .init(color: Color(hex: 0xA59683).opacity(0.025), location: 0),
                .init(color: Color.black.opacity(0.018), location: 0.28),
                .init(color: Color(hex: 0x756A5F).opacity(0.014), location: 0.57),
                .init(color: Color.black.opacity(0.055), location: 1),
            ],
            startPoint: UnitPoint(x: 0.04, y: 0.02),
            endPoint: UnitPoint(x: 0.93, y: 0.98)
        )
    }

    /// The raster is 312 px wide, so these 1.9-3.4 px strokes resolve as
    /// sub-pixel, directionally coherent fibres at the 54.85 px target width.
    private var directionalFibreField: some View {
        Canvas { context, canvasSize in
            for fibre in Self.directionalFibres {
                let center = CGPoint(x: canvasSize.width * fibre.x, y: canvasSize.height * fibre.y)
                let angle = fibre.angle * .pi / 180
                let half = canvasSize.width * fibre.length * 0.5
                let offset = CGPoint(x: cos(angle) * half, y: sin(angle) * half)
                var path = Path()
                path.move(to: CGPoint(x: center.x - offset.x, y: center.y - offset.y))
                path.addLine(to: CGPoint(x: center.x + offset.x, y: center.y + offset.y))
                context.stroke(
                    path,
                    with: .color(
                        fibre.light
                            ? Color(hex: 0xB8AA98).opacity(fibre.opacity)
                            : Color.black.opacity(fibre.opacity)
                    ),
                    style: StrokeStyle(
                        lineWidth: max(1.0, canvasSize.width * fibre.width),
                        lineCap: .round
                    )
                )
            }
        }
        .blendMode(.softLight)
    }

    /// Sparse, bent interruptions emulate incomplete matte-ink transfer. Their
    /// varied spans and offsets avoid any row, cell or dot cadence.
    private var sparsePrintDropout: some View {
        Canvas { context, canvasSize in
            for dropout in Self.printDropouts {
                var path = Path()
                path.move(to: CGPoint(
                    x: canvasSize.width * dropout.startX,
                    y: canvasSize.height * dropout.startY
                ))
                path.addQuadCurve(
                    to: CGPoint(
                        x: canvasSize.width * dropout.endX,
                        y: canvasSize.height * dropout.endY
                    ),
                    control: CGPoint(
                        x: canvasSize.width * dropout.bendX,
                        y: canvasSize.height * dropout.bendY
                    )
                )
                context.stroke(
                    path,
                    with: .color(Color(hex: 0x9D8F7D).opacity(dropout.opacity)),
                    style: StrokeStyle(
                        lineWidth: max(1.0, canvasSize.width * dropout.width),
                        lineCap: .butt,
                        lineJoin: .round
                    )
                )
            }
        }
        .blendMode(.screen)
    }

    /// Pressed ink accumulates at the perimeter while sparse upper-left breaks
    /// expose the warm stock. Both strokes remain inside the unchanged V3 edge.
    private var edgeCompression: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.width * cornerRatio * 0.92)
                .strokeBorder(
                    Color.black.opacity(0.18),
                    lineWidth: max(1.2, size.width * 0.012)
                )
            RoundedRectangle(cornerRadius: size.width * cornerRatio * 0.92)
                .trim(from: 0.58, to: 0.89)
                .stroke(
                    Color(hex: 0x9D8F7D).opacity(0.095),
                    style: StrokeStyle(
                        lineWidth: max(0.8, size.width * 0.005),
                        lineCap: .butt,
                        dash: [size.width * 0.046, size.width * 0.024]
                    )
                )
                .padding(size.width * 0.004)
        }
    }

    /// Baked once into the raster and therefore invariant throughout flight.
    /// Its axis is identical to `WorldLightProfile.trackB.keyDirection`.
    private var fixedWorldLightResponse: some View {
        LinearGradient(
            colors: [Color.white.opacity(0.028), Color.clear, Color.black.opacity(0.15)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var materialPatina: some View {
        Canvas { context, canvasSize in
            let longEdge = max(canvasSize.width, canvasSize.height)
            for mark in Self.materialMarks {
                let center = CGPoint(
                    x: canvasSize.width * mark.center.x,
                    y: canvasSize.height * mark.center.y
                )
                let angle = mark.rotationDegrees * .pi / 180
                let halfLength = max(0.4, longEdge * mark.radius * 1.8)
                let offset = CGPoint(
                    x: cos(angle) * halfLength,
                    y: sin(angle) * halfLength
                )
                var fibre = Path()
                fibre.move(to: CGPoint(x: center.x - offset.x, y: center.y - offset.y))
                fibre.addLine(to: CGPoint(x: center.x + offset.x, y: center.y + offset.y))
                context.stroke(
                    fibre,
                    with: .color(Color(hex: 0x8B7C70).opacity(mark.opacity * 0.62)),
                    style: StrokeStyle(
                        lineWidth: max(0.2, longEdge * mark.radius * 0.22),
                        lineCap: .round
                    )
                )
            }
        }
    }

    @ViewBuilder
    private var materialDamage: some View {
        if Self.damageNames.indices.contains(materialVariant) {
            Image(Self.damageNames[materialVariant])
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .opacity(0.68)
                .blendMode(.screen)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var facetLozenge: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radiusX = canvasSize.width * 0.40
            let radiusY = canvasSize.height * 0.40
            let corners = [
                CGPoint(x: center.x, y: center.y - radiusY),
                CGPoint(x: center.x + radiusX, y: center.y),
                CGPoint(x: center.x, y: center.y + radiusY),
                CGPoint(x: center.x - radiusX, y: center.y),
            ]
            var rim: [CGPoint] = []
            for index in 0..<4 {
                let first = corners[index]
                let second = corners[(index + 1) % 4]
                rim.append(first)
                rim.append(CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2))
            }
            let inner = rim.map {
                CGPoint(
                    x: center.x + ($0.x - center.x) * 0.64,
                    y: center.y + ($0.y - center.y) * 0.64
                )
            }
            for index in 0..<8 {
                let next = (index + 1) % 8
                var outer = Path()
                outer.move(to: rim[index])
                outer.addLines([rim[next], inner[next], inner[index]])
                outer.closeSubpath()
                context.fill(outer, with: .color(Self.facetColors[index % 4]))

                var innerFacet = Path()
                innerFacet.move(to: inner[index])
                innerFacet.addLines([inner[next], center])
                innerFacet.closeSubpath()
                context.fill(innerFacet, with: .color(Self.facetColors[index % 4]))
                context.fill(innerFacet, with: .color(.black.opacity(0.45)))

                var lines = Path()
                lines.move(to: rim[index])
                lines.addLine(to: rim[next])
                lines.move(to: rim[index])
                lines.addLine(to: inner[index])
                lines.move(to: inner[index])
                lines.addLine(to: inner[next])
                context.stroke(lines, with: .color(Color(hex: 0xE2E8F0).opacity(0.8)), lineWidth: 1.7)
            }

            let coreRadius = radiusX * 0.16
            var core = Path()
            core.move(to: CGPoint(x: center.x, y: center.y - coreRadius))
            core.addLines([
                CGPoint(x: center.x + coreRadius, y: center.y),
                CGPoint(x: center.x, y: center.y + coreRadius),
                CGPoint(x: center.x - coreRadius, y: center.y),
            ])
            core.closeSubpath()
            context.fill(core, with: .color(Color(hex: 0x18151B)))
            context.stroke(core, with: .color(Color(hex: 0xE2E8F0).opacity(0.8)), lineWidth: 1.7)
        }
        .padding(size.width * 5 / 52)
    }

    private var monograms: some View {
        VStack {
            HStack {
                monogram
                Spacer()
            }
            Spacer()
            HStack {
                Spacer()
                monogram.rotationEffect(.degrees(180))
            }
        }
        .padding(size.width * 4 / 52)
    }

    private var monogram: some View {
        Text(verbatim: "1441")
            .font(.system(size: size.width * 4.4 / 52, weight: .medium, design: .serif))
            .foregroundStyle(Color(hex: 0xE2E8F0).opacity(0.8))
    }
}

@MainActor
enum ProductW2SurfaceRaster {
    static let size = CGSize(width: 312, height: 444)

    private static let variants: [UIImage] = (0..<3).map { variant in
        let renderer = ImageRenderer(
            content: ProductW2CardBack(size: size, materialVariant: variant)
        )
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        return renderer.uiImage ?? UIImage()
    }

    static func image(variant: Int) -> UIImage {
        variants[min(max(variant, 0), variants.count - 1)]
    }
}

@MainActor
enum MaterialPerspectiveRenderer {
    private static let context = CIContext(options: [
        .cacheIntermediates: true,
        .useSoftwareRenderer: false,
    ])

    static func render(image: UIImage, quad: PlaneQuad, viewport: CGSize) -> UIImage? {
        guard let input = CIImage(image: image),
              let filter = CIFilter(name: "CIPerspectiveTransform") else {
            return nil
        }
        func vector(_ point: PlanePoint) -> CIVector {
            CIVector(x: point.x, y: Double(viewport.height) - point.y)
        }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(vector(quad.topLeft), forKey: "inputTopLeft")
        filter.setValue(vector(quad.topRight), forKey: "inputTopRight")
        filter.setValue(vector(quad.bottomRight), forKey: "inputBottomRight")
        filter.setValue(vector(quad.bottomLeft), forKey: "inputBottomLeft")
        guard let output = filter.outputImage,
              let cgImage = context.createCGImage(output, from: CGRect(origin: .zero, size: viewport)) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

struct WarpedProductW2Card: View {
    let quad: PlaneQuad
    let viewport: CGSize
    let materialVariant: Int

    var body: some View {
        if let image = MaterialPerspectiveRenderer.render(
            image: ProductW2SurfaceRaster.image(variant: materialVariant),
            quad: quad,
            viewport: viewport
        ) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: viewport.width, height: viewport.height)
        }
    }
}
