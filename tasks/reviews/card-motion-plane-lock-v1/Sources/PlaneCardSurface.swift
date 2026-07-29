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

struct ProofCardBack: View {
    let size: CGSize

    private let facetColors = [
        Color(hex: 0xC5A059),
        Color(hex: 0x8E2A43),
        Color(hex: 0x1A5E4E),
        Color(hex: 0x4A2E65),
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.width * 0.154)
                .fill(Color(hex: 0x14110F))
            Image("W2Damage")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: size.width * 0.154))
            facetLozenge
        }
        .frame(width: size.width, height: size.height)
        .overlay {
            RoundedRectangle(cornerRadius: size.width * 0.154)
                .strokeBorder(
                    Color.white.opacity(WorldLightProfile.trackB.cardEdgeHighlightOpacity),
                    lineWidth: 2.2
                )
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
                context.fill(outer, with: .color(facetColors[index % 4]))

                var innerFacet = Path()
                innerFacet.move(to: inner[index])
                innerFacet.addLines([inner[next], center])
                innerFacet.closeSubpath()
                context.fill(innerFacet, with: .color(facetColors[index % 4]))
                context.fill(innerFacet, with: .color(.black.opacity(0.45)))
                context.stroke(outer, with: .color(.white.opacity(0.42)), lineWidth: 1.3)
            }
        }
        .padding(size.width * 0.096)
    }
}

@MainActor
enum PlaneCardSurface {
    static let rasterSize = CGSize(width: 156, height: 222)

    static let back: UIImage = {
        let renderer = ImageRenderer(content: ProofCardBack(size: rasterSize))
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: rasterSize.width, height: rasterSize.height)
        return renderer.uiImage ?? UIImage()
    }()
}

@MainActor
enum PerspectiveCardRenderer {
    private static let context = CIContext(options: [
        .cacheIntermediates: true,
        .useSoftwareRenderer: false,
    ])

    static func render(image: UIImage, quad: PlaneQuad, viewport: CGSize) -> UIImage? {
        guard let input = CIImage(image: image),
              let filter = CIFilter(name: "CIPerspectiveTransform") else {
            return nil
        }
        func ciVector(_ point: PlanePoint) -> CIVector {
            CIVector(x: point.x, y: Double(viewport.height) - point.y)
        }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(ciVector(quad.topLeft), forKey: "inputTopLeft")
        filter.setValue(ciVector(quad.topRight), forKey: "inputTopRight")
        filter.setValue(ciVector(quad.bottomRight), forKey: "inputBottomRight")
        filter.setValue(ciVector(quad.bottomLeft), forKey: "inputBottomLeft")
        guard let output = filter.outputImage,
              let cgImage = context.createCGImage(
                output,
                from: CGRect(origin: .zero, size: viewport)
              ) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

struct WarpedProofCard: View {
    let quad: PlaneQuad
    let viewport: CGSize

    var body: some View {
        if let image = PerspectiveCardRenderer.render(
            image: PlaneCardSurface.back,
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
