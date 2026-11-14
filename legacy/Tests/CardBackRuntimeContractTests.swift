import Foundation

@main
struct CardBackRuntimeContractTests {
    static func main() throws {
        let marks = W2BackPatina.marks()
        expect(!marks.isEmpty, "W2 runtime material must contain marks")
        expect(marks == W2BackPatina.marks(), "W2 runtime material must be deterministic")
        expect(marks.count.isMultiple(of: 2), "W2 runtime material must contain complete pairs")

        for index in stride(from: 0, to: marks.count, by: 2) {
            expect(
                marks[index + 1] == marks[index].rotatedByHalfTurn,
                "W2 runtime material pair \(index / 2) must be half-turn symmetric"
            )
        }

        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("App/CardBack.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        expect(
            source.contains("private static let materialMarks = W2BackPatina.marks()"),
            "CardBack must use the identity-neutral W2 material field"
        )
        expect(
            source.contains("materialPatina") && source.contains("for mark in Self.materialMarks"),
            "CardBack must render the W2 material field at runtime"
        )
        expect(
            source.contains("var materialVariant: Int? = nil"),
            "CardBack must keep a neutral default when no public material variant is supplied"
        )
        for index in 0..<10 {
            let suffix = String(format: "%02d", index)
            expect(
                source.contains("card_back_damage_\(suffix)"),
                "CardBack must declare damage overlay variant \(suffix)"
            )
        }
        for parameter in ["mark.center", "mark.radius", "mark.opacity", "mark.rotationDegrees"] {
            expect(source.contains(parameter), "CardBack runtime material must use \(parameter)")
        }

        let forbiddenIdentityInputs = [
            "assetID", "cardID", "materialSeed", ".random(", "SystemRandomNumberGenerator",
        ]
        for input in forbiddenIdentityInputs {
            expect(!source.contains(input), "CardBack must not contain identity or random input: \(input)")
        }

        guard let materialLayer = source.range(of: "            materialPatina"),
              let damageLayer = source.range(of: "            materialDamageOverlay"),
              let signetLayer = source.range(of: "            facetLozenge") else {
            fail("CardBack body must contain material, damage, and signet layers")
        }
        expect(
            materialLayer.lowerBound < damageLayer.lowerBound
                && damageLayer.lowerBound < signetLayer.lowerBound,
            "Damage must remain above W2 material and below the unchanged signet"
        )

        guard let damageSectionStart = source.range(of: "private var materialDamageOverlay"),
              let damageSectionEnd = source.range(
                of: "/// Feste, paarweise punktsymmetrische Materialfasern",
                range: damageSectionStart.upperBound..<source.endIndex
              ) else {
            fail("CardBack must keep damage rendering in an isolated material layer")
        }
        let damageSection = String(
            source[damageSectionStart.lowerBound..<damageSectionEnd.lowerBound]
        )
        for contract in [
            ".frame(width: 52 * scale, height: 74 * scale)",
            ".clipShape(RoundedRectangle(cornerRadius: 8 * scale))",
            ".allowsHitTesting(false)",
            ".accessibilityHidden(true)",
        ] {
            expect(
                damageSection.contains(contract),
                "Damage overlays must preserve stable back geometry: \(contract)"
            )
        }
        expect(
            !damageSection.contains("opacity(0)"),
            "A selected damage overlay must remain visibly rendered"
        )
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: @autoclosure () -> String
    ) {
        guard condition() else { fail(message()) }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        Foundation.exit(1)
    }
}
