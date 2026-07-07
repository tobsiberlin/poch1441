import SwiftUI

/// Der eingefrorene Default-Kartenrücken (W2-Final, Tobsi-Entscheid 7.7.):
/// facettierte Siegel-Raute auf Tinten-Schwarz. PUNKTSYMMETRISCH konstruiert
/// (Facette i = Facette i+4 in der Farbe) - eine 180-Grad-gedrehte Karte ist
/// identisch, kein Orientierungs-Leak (Beweis: Pixel-Diff 0 am Print-Asset,
/// tools/gen_sichtung2_wappen.py). Farben kommen ausschließlich aus DesignTokens
/// (Engine-Branding: Code = Source of Truth der Label-Farben); das P·1441-Monogramm
/// ist Vektor-Text, nie generiert (Anti-Slop §5).
struct CardBack: View {
    var scale: CGFloat = 1

    private static let facetColors: [Color] = [
        Tokens.jewelGold, Tokens.jewelRose, Tokens.jewelSmaragd, Tokens.jewelAmethyst,
    ]
    private static let platin = Tokens.jewelPlatin.opacity(0.8)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8 * scale).fill(Color(hex: 0x14110F))
            facetLozenge
            if scale >= 1.2 { monograms }
        }
        .frame(width: 52 * scale, height: 74 * scale)
        .overlay(RoundedRectangle(cornerRadius: 8 * scale)
            .strokeBorder(.white.opacity(0.14), lineWidth: 0.5))
    }

    private var facetLozenge: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let rw = size.width * 0.40
            let rh = size.height * 0.40
            let corners = [CGPoint(x: cx, y: cy - rh), CGPoint(x: cx + rw, y: cy),
                           CGPoint(x: cx, y: cy + rh), CGPoint(x: cx - rw, y: cy)]
            var rim: [CGPoint] = []
            for i in 0..<4 {
                let a = corners[i]
                let b = corners[(i + 1) % 4]
                rim.append(a)
                rim.append(CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2))
            }
            let inner = rim.map {
                CGPoint(x: cx + ($0.x - cx) * 0.5, y: cy + ($0.y - cy) * 0.5)
            }
            let center = CGPoint(x: cx, y: cy)

            for i in 0..<8 {
                let j = (i + 1) % 8
                let color = Self.facetColors[i % 4]
                var outer = Path()
                outer.move(to: rim[i])
                outer.addLines([rim[j], inner[j], inner[i]])
                outer.closeSubpath()
                context.fill(outer, with: .color(color))

                var innerFacet = Path()
                innerFacet.move(to: inner[i])
                innerFacet.addLines([inner[j], center])
                innerFacet.closeSubpath()
                context.fill(innerFacet, with: .color(color))
                // Facetten-Tiefe: innere Felder abgedunkelt (wie im Print-Asset 0.55)
                context.fill(innerFacet, with: .color(.black.opacity(0.45)))

                var lines = Path()
                lines.move(to: rim[i]); lines.addLine(to: rim[j])
                lines.move(to: rim[i]); lines.addLine(to: inner[i])
                lines.move(to: inner[i]); lines.addLine(to: inner[j])
                context.stroke(lines, with: .color(Self.platin), lineWidth: 0.6 * scale)
            }
            // Platin-Kern (die 9. Mulde) - kleine Raute, Tinten-Fuellung
            let kr = rw * 0.16
            var core = Path()
            core.move(to: CGPoint(x: cx, y: cy - kr))
            core.addLines([CGPoint(x: cx + kr, y: cy), CGPoint(x: cx, y: cy + kr),
                           CGPoint(x: cx - kr, y: cy)])
            core.closeSubpath()
            context.fill(core, with: .color(Color(hex: 0x18151B)))
            context.stroke(core, with: .color(Self.platin), lineWidth: 0.6 * scale)
        }
        .padding(5 * scale)
    }

    /// Rotationssymmetrisches Monogramm-Paar (oben links + 180 Grad unten rechts).
    private var monograms: some View {
        VStack {
            HStack {
                monogramText
                Spacer()
            }
            Spacer()
            HStack {
                Spacer()
                monogramText.rotationEffect(.degrees(180))
            }
        }
        .padding(4 * scale)
    }

    private var monogramText: some View {
        Text(verbatim: "P · 1441")
            .font(.system(size: 4.4 * scale, weight: .medium, design: .serif))
            .foregroundStyle(Tokens.jewelPlatin.opacity(0.85))
    }
}

#Preview("CardBack Skalen") {
    ZStack {
        Color(hex: 0x0B0E14).ignoresSafeArea()
        HStack(spacing: 20) {
            CardBack(scale: 0.8)
            CardBack(scale: 1.4)
            CardBack(scale: 2.6)
        }
    }
}
