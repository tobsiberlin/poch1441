import AVFoundation
import Foundation

@main
struct R1MaterialContractTests {
    private static let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    static func main() throws {
        let components = try source(at: "App/PlayComponents.swift")
        let layout = try source(at: "App/R1TokenLayout.swift")
        let effects = try source(at: "App/Effects.swift")

        try r1RendererKeepsOneSharedColorway(components)
        try restingPosesAreStableAndVaried(layout)
        try contactFeedbackIsImpactBoundAndBundled(effects)
        try ceramicAudioVariantsMeetTheRuntimeContract(effects)

        FileHandle.standardOutput.write(Data("R1MaterialContractTests: PASS\n".utf8))
    }

    private static func r1RendererKeepsOneSharedColorway(_ source: String) throws {
        for colorway in ["naturalWhite", "terracotta", "sage", "slate"] {
            expect(source.contains("case \(colorway)"),
                   "R1 colorway \(colorway) is missing")
        }

        let renderer = try section(in: source,
                                   from: "struct R1Token: View",
                                   through: "typealias TableChip = R1Token")
        expect(renderer.contains("_ = tint"),
               "Legacy pool/player tint must remain explicitly ignored")
        expect(!renderer.contains("Text("),
               "R1 must not render values or currency on the token")
        expect(renderer.contains("R1BlindEmboss()"),
               "R1 must carry the tonal card-back emboss")
    }

    private static func restingPosesAreStableAndVaried(_ source: String) throws {
        expect(source.contains("static let capacity = 12"),
               "R1 requires twelve deterministic resting slots")
        expect(source.contains("guard count > 0 else { return [] }"),
               "An empty group must not synthesize a visible R1 token")
        expect(source.contains("stableSalt(for compartment: TravelCompartment)"),
               "R1 pile variation must be tied to the physical compartment")
        expect(source.contains("seed ^ stableSalt(for: compartment)"),
               "R1 pile variation must remain replay-stable")
        expect(source.contains("jitterX") && source.contains("groupAngle"),
               "R1 piles must not repeat one cloned rosette")
    }

    private static func contactFeedbackIsImpactBoundAndBundled(_ source: String) throws {
        expect(source.contains(".onChange(of: trigger)"),
               "Ceramic sound must be bound to the impact trigger")
        expect(source.contains("R1ContactDynamics.resolve(surface: surface,"),
               "Surface and group size must share one contact mapping")
        expect(source.contains("groupSize: groupSize"),
               "The bundled group size must reach audio and haptics")
        expect(source.contains("now - lastContactTime >= 0.12"),
               "Rapid subordinate contacts must remain throttled")

        let feedback = try section(in: source,
                                   from: "struct R1ContactFeedback: ViewModifier",
                                   through: "extension View")
        expect(!feedback.contains("Task.sleep"),
               "R1 feedback must not own a second timeline")
    }

    private static func ceramicAudioVariantsMeetTheRuntimeContract(_ source: String) throws {
        let expression = try NSRegularExpression(
            pattern: #"r1-ceramic-(?:outer|center)-0[1-3]"#
        )
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        let names = Set(expression.matches(in: source, range: range).compactMap { match -> String? in
            guard let swiftRange = Range(match.range, in: source) else { return nil }
            return String(source[swiftRange])
        })
        expect(names.count == 6,
               "R1 requires three outer-well and three center-well variants")

        for name in names {
            let url = root.appendingPathComponent("App/Audio/\(name).caf")
            expect(FileManager.default.fileExists(atPath: url.path),
                   "Missing bundled contact sound: \(name).caf")

            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let duration = Double(file.length) / format.sampleRate
            expect(format.channelCount == 1,
                   "R1 contact sounds must stay mono")
            expect(format.sampleRate == 44_100,
                   "R1 contact sounds must stay at 44.1 kHz")
            expect((0.14...0.30).contains(duration),
                   "R1 contact sound duration must remain short and physical")
        }
    }

    private static func source(at relativePath: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relativePath),
                   encoding: .utf8)
    }

    private static func section(in source: String,
                                from startMarker: String,
                                through endMarker: String) throws -> String {
        guard let start = source.range(of: startMarker)?.lowerBound,
              let end = source.range(of: endMarker, range: start..<source.endIndex)?.upperBound else {
            fail("Unable to locate source section \(startMarker)")
        }
        return String(source[start..<end])
    }

    private static func expect(_ condition: @autoclosure () -> Bool,
                               _ message: String) {
        if !condition() {
            fail(message)
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("R1MaterialContractTests: \(message)\n".utf8))
        Foundation.exit(EXIT_FAILURE)
    }
}
