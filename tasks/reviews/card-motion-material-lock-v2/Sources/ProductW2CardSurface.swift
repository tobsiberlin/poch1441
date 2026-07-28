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

/// Local, frozen reproduction of the production `App/CardBack.swift` W2
/// material. The only added layer is the neutral card-stock perimeter that the
/// product sprite normally receives from physical edge rendering.
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
    private let cornerRatio = 8.0 / 52.0

    var body: some View {
        let edgeInset = size.width * 0.018
        ZStack {
            RoundedRectangle(cornerRadius: size.width * cornerRatio)
                .fill(cardStock)

            ZStack {
                RoundedRectangle(cornerRadius: size.width * cornerRatio * 0.92)
                    .fill(Color(hex: 0x14110F))
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
                .strokeBorder(Color(hex: 0x6B655E).opacity(0.78), lineWidth: size.width * 0.0045)
        }
    }

    private var cardStock: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0xD7D0C3), Color(hex: 0xA69C8D)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Baked once into the raster and therefore invariant throughout flight.
    /// Its axis is identical to `WorldLightProfile.trackB.keyDirection`.
    private var fixedWorldLightResponse: some View {
        LinearGradient(
            colors: [Color.white.opacity(0.055), Color.clear, Color.black.opacity(0.11)],
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
