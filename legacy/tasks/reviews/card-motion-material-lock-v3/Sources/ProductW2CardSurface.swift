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
/// V3 changes only the physical print/material response around that unchanged
/// graphic: broad stock tooth that survives projection to 54.85 px, matte ink
/// coverage and a thin, dark exposed stock edge.
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
    private static let stockTooth: [(x: Double, y: Double, width: Double, height: Double, light: Bool)] = [
        (0.12, 0.10, 0.18, 0.055, true), (0.38, 0.08, 0.24, 0.070, false),
        (0.73, 0.13, 0.20, 0.060, true), (0.25, 0.22, 0.28, 0.075, false),
        (0.60, 0.25, 0.22, 0.065, true), (0.86, 0.31, 0.13, 0.080, false),
        (0.10, 0.38, 0.20, 0.070, true), (0.43, 0.40, 0.25, 0.055, false),
        (0.75, 0.46, 0.26, 0.070, true), (0.20, 0.56, 0.24, 0.080, false),
        (0.53, 0.60, 0.30, 0.060, true), (0.86, 0.65, 0.15, 0.070, false),
        (0.11, 0.73, 0.18, 0.065, true), (0.37, 0.78, 0.26, 0.075, false),
        (0.70, 0.82, 0.24, 0.060, true), (0.88, 0.91, 0.13, 0.055, false),
        (0.22, 0.92, 0.26, 0.070, true), (0.56, 0.94, 0.22, 0.060, false),
    ]
    private static let longFibres: [(x: Double, y: Double, length: Double, angle: Double)] = [
        (0.14, 0.18, 0.16, -8), (0.65, 0.18, 0.21, 5), (0.31, 0.34, 0.18, 11),
        (0.76, 0.39, 0.15, -12), (0.18, 0.51, 0.20, 7), (0.61, 0.55, 0.22, -5),
        (0.34, 0.69, 0.17, -10), (0.78, 0.74, 0.18, 8), (0.20, 0.86, 0.15, 4),
        (0.57, 0.89, 0.20, -7),
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
                lowFrequencyStockTooth
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

    /// Large enough to remain a material signal after the 312 px raster is
    /// projected down to a 54.85 px short edge. It is print coverage, not dirt.
    private var matteInkCoverage: some View {
        ZStack {
            RadialGradient(
                colors: [Color(hex: 0x82776A).opacity(0.075), Color.clear],
                center: UnitPoint(x: 0.24, y: 0.19),
                startRadius: 1,
                endRadius: size.width * 0.42
            )
            RadialGradient(
                colors: [Color.black.opacity(0.19), Color.clear],
                center: UnitPoint(x: 0.82, y: 0.72),
                startRadius: 1,
                endRadius: size.width * 0.48
            )
            LinearGradient(
                colors: [Color.clear, Color(hex: 0x756A5F).opacity(0.050), Color.black.opacity(0.11)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var lowFrequencyStockTooth: some View {
        Canvas { context, canvasSize in
            context.addFilter(.blur(radius: max(0.8, canvasSize.width * 0.006)))
            for patch in Self.stockTooth {
                let rect = CGRect(
                    x: canvasSize.width * (patch.x - patch.width / 2),
                    y: canvasSize.height * (patch.y - patch.height / 2),
                    width: canvasSize.width * patch.width,
                    height: canvasSize.height * patch.height
                )
                let tone = patch.light
                    ? Color(hex: 0xB0A392).opacity(0.060)
                    : Color.black.opacity(0.105)
                context.fill(Path(ellipseIn: rect), with: .color(tone))
            }

            for fibre in Self.longFibres {
                let center = CGPoint(x: canvasSize.width * fibre.x, y: canvasSize.height * fibre.y)
                let angle = fibre.angle * .pi / 180
                let half = canvasSize.width * fibre.length * 0.5
                let offset = CGPoint(x: cos(angle) * half, y: sin(angle) * half)
                var path = Path()
                path.move(to: CGPoint(x: center.x - offset.x, y: center.y - offset.y))
                path.addLine(to: CGPoint(x: center.x + offset.x, y: center.y + offset.y))
                context.stroke(
                    path,
                    with: .color(Color(hex: 0xB8AA98).opacity(0.080)),
                    style: StrokeStyle(
                        lineWidth: max(1.4, canvasSize.width * 0.009),
                        lineCap: .round
                    )
                )
            }
        }
        .blendMode(.plusLighter)
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
