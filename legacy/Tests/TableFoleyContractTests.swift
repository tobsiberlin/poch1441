import Foundation

@main
struct TableFoleyContractTests {
    private static let root = URL(
        fileURLWithPath: FileManager.default.currentDirectoryPath
    )

    static func main() throws {
        let audio = try source("App/TableFoleyAudio.swift")
        let contactAudio = try source("App/R1ContactAudio.swift")
        let deal = try source("App/DealOverlay.swift")
        let content = try source("App/ContentView.swift")
        let phase2 = try source("App/Phase2View.swift")
        let phase3 = try source("App/Phase3View.swift")
        let builder = try source("tools/build_table_foley_audio.py")
        let receipt = try source("App/Audio/TABLE_FOLEY_SOURCES.md")

        for variant in 1...3 {
            let suffix = String(format: "%02d", variant)
            expect(audio.contains("card-deal-\(suffix)"),
                   "Runtime must include card-deal-\(suffix)")
            expect(builder.contains("CardSource(\(variant),"),
                   "Builder must pin source \(variant)")
            expect(receipt.contains("card-deal-\(suffix).caf"),
                   "The source receipt must document card-deal-\(suffix)")
        }
        try validatesThreeOrganicDealContacts()
        expect(builder.contains("validate_contacts(contacts)")
            && builder.contains("normalized_correlation")
            && builder.contains("organic dynamic variance")
            && receipt.contains("CC0 1.0 Universal"),
               "The generator must reject cloned contacts and document their CC0 sources")
        expect(audio.contains("R1ContactVariantResolver.resolve"),
               "Card contacts must vary deterministically")
        expect(!audio.contains("enableRate") && !audio.contains("player.rate"),
               "Real card Foley must not be disguised with pitch variation")
        expect(audio.contains("TableFoleySpatialModel.pan(seat: seat,")
               && audio.contains("playerCount: playerCount"),
               "Card contacts must stay spatially attached to 3-6 player seats")
        expect(audio.contains("let normalized = (index - center) / center")
               && audio.contains("normalized * 0.42"),
               "Seat panning must follow the same normalized table geometry")
        expect(audio.contains("PochAudioSession.prepareAmbientMixing()"),
               "Table Foley must establish the shared ambient audio policy")
        expect(deal.contains("playContactFoley()")
               && deal.contains("transaction.registerContact"),
               "Foley must trigger on the admitted physical contact")
        expect(deal.contains("guard reduceMotion, soundEnabled, current > previous"),
               "Reduced Motion must retain one causal contact without a flight")
        expect(audio.contains("func playCardReveal")
               && content.contains("playCardReveal("),
               "The physical trump flip must emit one causal card contact")
        expect(audio.contains("func playChipContact")
               && phase2.contains("commitBetImpact")
               && phase2.contains("commitPayoutImpact")
               && phase2.contains("playChipContact("),
               "Phase-2 bet and payout impacts must route ceramic Foley")
        expect(audio.contains("R1ContactAudio.shared.play(")
            && contactAudio.contains("struct EventKey: Hashable")
            && !audio.contains("r1-ceramic-center-01")
            && !contactAudio.contains("lastContactTime"),
               "All ceramic impacts must share one identity-based voice-pool pipeline")
        expect(audio.contains("prepareSessionIfNeeded()")
            && audio.contains("R1ContactAudio.shared.prepare()"),
               "Direct phase entry and normal dealing must both establish audio lifecycle")
        expect(audio.contains("func playPochGesture")
            && phase2.contains("TableFoleyAudio.shared.playPochGesture("),
               "Every semantic Poch shock must call its dedicated knuckle Foley")
        expect(audio.contains("func playCardPlay")
               && phase3.contains("playCardPlay("),
               "Accepted Phase-3 card landings must route table Foley")

        FileHandle.standardOutput.write(Data("TableFoleyContractTests: PASS\n".utf8))
    }

    private static func validatesThreeOrganicDealContacts() throws {
        let expectedDurations = [0.30, 0.36, 0.44]
        var contacts: [[Double]] = []

        for variant in 1...3 {
            let suffix = String(format: "%02d", variant)
            let samples = try decodedPCM(
                root.appendingPathComponent("App/Audio/card-deal-\(suffix).caf")
            )
            contacts.append(samples)
            let duration = Double(samples.count / 2) / 44_100
            expect(abs(duration - expectedDurations[variant - 1]) < 0.002,
                   "Deal contact \(suffix) must retain its authored organic tail")
        }

        let levels = contacts.map(rms)
        let crossings = contacts.map(zeroCrossingRate)
        expect((levels.max() ?? 0) / max(0.000_001, levels.min() ?? 0) > 1.30,
               "Deal contacts must preserve real dynamic variation")
        expect((crossings.max() ?? 0) - (crossings.min() ?? 0) > 0.015,
               "Deal contacts must preserve distinct paper/table tone")

        for left in 0..<contacts.count {
            for right in (left + 1)..<contacts.count {
                expect(abs(normalizedCorrelation(contacts[left], contacts[right])) < 0.72,
                       "Deal contacts must be separate performances, not repeated clones")
            }
        }
    }

    private static func decodedPCM(_ cafURL: URL) throws -> [Double] {
        let wavURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("poch-table-foley-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: wavURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        process.arguments = ["-f", "WAVE", "-d", "LEI16@44100",
                             cafURL.path, wavURL.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ContractError.decodeFailed(cafURL.lastPathComponent)
        }

        let data = try Data(contentsOf: wavURL)
        let bytes = [UInt8](data)
        guard let marker = bytes.firstRange(of: Array("data".utf8)),
              marker.upperBound + 4 <= bytes.count else {
            throw ContractError.invalidWAV(cafURL.lastPathComponent)
        }
        let start = marker.upperBound + 4
        var samples: [Double] = []
        samples.reserveCapacity((bytes.count - start) / 2)
        for index in stride(from: start, to: bytes.count - 1, by: 2) {
            let word = UInt16(bytes[index]) | (UInt16(bytes[index + 1]) << 8)
            samples.append(Double(Int16(bitPattern: word)) / 32_768)
        }
        return samples
    }

    private static func rms(_ samples: [Double]) -> Double {
        sqrt(samples.reduce(0) { $0 + $1 * $1 } / Double(samples.count))
    }

    private static func zeroCrossingRate(_ interleaved: [Double]) -> Double {
        var crossings = 0
        var frames = 0
        for index in stride(from: 2, to: interleaved.count - 1, by: 2) {
            crossings += (interleaved[index] < 0) != (interleaved[index - 2] < 0) ? 1 : 0
            frames += 1
        }
        return Double(crossings) / Double(frames)
    }

    private static func normalizedCorrelation(_ lhs: [Double], _ rhs: [Double]) -> Double {
        let count = min(lhs.count, rhs.count)
        var dot = 0.0
        var leftEnergy = 0.0
        var rightEnergy = 0.0
        for index in 0..<count {
            dot += lhs[index] * rhs[index]
            leftEnergy += lhs[index] * lhs[index]
            rightEnergy += rhs[index] * rhs[index]
        }
        return dot / max(0.000_000_001, sqrt(leftEnergy * rightEnergy))
    }

    private enum ContractError: Error {
        case decodeFailed(String)
        case invalidWAV(String)
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    private static func expect(_ condition: @autoclosure () -> Bool,
                               _ message: String) {
        guard condition() else {
            FileHandle.standardError.write(Data("TableFoleyContractTests: \(message)\n".utf8))
            Foundation.exit(EXIT_FAILURE)
        }
    }
}

private extension Array where Element: Equatable {
    func firstRange(of pattern: [Element]) -> Range<Int>? {
        guard !pattern.isEmpty, pattern.count <= count else { return nil }
        for start in 0...(count - pattern.count) {
            let end = start + pattern.count
            if Array(self[start..<end]) == pattern { return start..<end }
        }
        return nil
    }
}
