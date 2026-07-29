import Foundation

@main
struct FirstRunTimeSwipeAudioMixTests {
    private static let names = [
        "first-run-origin-room.m4a",
        "first-run-origin-motif.wav",
        "first-run-present-room.m4a",
        "first-run-present-motif.wav",
        "first-run-signature-contact.wav",
        "first-run-time-noise.wav"
    ]

    static func main() {
        let layers = names.map(pcm(named:))
        let renderLayers = layers.map { Array($0.prefix(20 * 44_100)) }
        keepsEraEndpointsPure()
        followsTheFingerAndMovesTheSignatureThroughCenter()
        rendersALevelMorphWithoutAnEndpointJump(renderLayers)
        keepsTheTimeSeamCenteredAndAudible(renderLayers)
        preservesOneLiteralSignatureContact(layers[4])
        sharesTheMusicalEventGrid(layers[1], layers[3])
        keepsTheRoomsSafeAndPurposefullyDifferent(layers[0], layers[2])
        keepsCompactRoomAssetsAndTwentySecondAuthoredLoops(layers)
        preloadsFileBytesAwayFromTimelineEntry()
        keepsDiscreteTimelineWiredToAudio()
        clampsOutOfRangeProgress()
        FileHandle.standardOutput.write(
            Data("FirstRunTimeSwipeAudioMixTests: PASS\n".utf8)
        )
    }

    private static func keepsEraEndpointsPure() {
        let origin = FirstRunTimeSwipeAudioMix.state(progress: 0)
        let present = FirstRunTimeSwipeAudioMix.state(progress: 1)
        expect(origin.presentRoomVolume == 0 && origin.presentMotifVolume == 0,
               "Today must be digitally silent at 1441")
        expect(present.originRoomVolume == 0 && present.originMotifVolume == 0,
               "1441 must be digitally silent today")
        expect(origin.timeNoiseVolume == 0 && present.timeNoiseVolume < 0.000_001,
               "The transition texture must not leak into either endpoint")
        expect(origin.signatureContactVolume == present.signatureContactVolume
            && origin.signatureContactVolume > 0,
               "The physical signature must survive both eras unchanged")
    }

    private static func followsTheFingerAndMovesTheSignatureThroughCenter() {
        var previous = FirstRunTimeSwipeAudioMix.state(progress: 0)
        for index in 1...100 {
            let current = FirstRunTimeSwipeAudioMix.state(progress: Double(index) / 100)
            expect(current.originRoomVolume < previous.originRoomVolume,
                   "The tavern must fade continuously with the finger")
            expect(current.presentRoomVolume > previous.presentRoomVolume,
                   "The lounge must rise continuously with the finger")
            expect(current.signatureContactPan > previous.signatureContactPan,
                   "The shared Poch contact must travel continuously through time")
            previous = current
        }
        let middle = FirstRunTimeSwipeAudioMix.state(progress: 0.5)
        let origin = FirstRunTimeSwipeAudioMix.state(progress: 0)
        let present = FirstRunTimeSwipeAudioMix.state(progress: 1)
        expect(abs(middle.signatureContactPan) < 0.000_001,
               "The shared signature contact must be centered at the seam")
        expect(middle.originRoomPan < 0 && middle.presentRoomPan > 0,
               "Both era rooms must remain spatially legible at the mashup")
        expect(abs(origin.originRoomPan + present.presentRoomPan) < 0.000_001
            && abs(origin.originMotifPan + present.presentMotifPan) < 0.000_001
            && abs(origin.signatureContactPan + present.signatureContactPan) < 0.000_001,
               "Endpoint panning must be symmetric so balance cannot skew loudness")
        expect(FirstRunTimeSwipeAudioMix.state(progress: 0.68)
            == FirstRunTimeSwipeAudioMix.state(progress: 0.68),
               "The morph must depend only on finger position")
    }

    private static func rendersALevelMorphWithoutAnEndpointJump(_ layers: [[Frame]]) {
        let covariance = covarianceMatrix(layers)
        let levels = (0...100).map { index in
            renderedRMS(progress: Double(index) / 100, covariance: covariance)
        }
        let endpointDifference = abs(decibels(levels[0] / levels[100]))
        expect(endpointDifference <= 1.0,
               "1441 and today must stay within 1 dB, measured \(endpointDifference) dB "
               + "(\(levels[0]) vs \(levels[100]))")
        let totalRange = decibels((levels.max() ?? 1) / max(0.000_001, levels.min() ?? 1))
        expect(totalRange <= 2.0,
               "The rendered morph must not contain a loudness hole or bump, measured "
               + "\(totalRange) dB")
    }

    private static func keepsTheTimeSeamCenteredAndAudible(_ layers: [[Frame]]) {
        let seam = layers[5]
        let middleRMS = rms(seam.map { ($0.left + $0.right) * 0.5 })
        let sideRMS = rms(seam.map { ($0.left - $0.right) * 0.5 })
        let sideToMid = decibels(max(0.000_000_001, sideRMS) / middleRMS)
        expect(sideToMid <= -12,
               "The time seam must stay centered, measured Side/Mid \(sideToMid) dB")

        let covariance = covarianceMatrix(layers)
        let fullMix = renderedRMS(progress: 0.5, covariance: covariance)
        let state = FirstRunTimeSwipeAudioMix.state(progress: 0.5)
        let seamContribution = rms(seam) * Double(state.timeNoiseVolume)
        let contributionDB = decibels(seamContribution / fullMix)
        expect((-12.5 ... -8.0).contains(contributionDB),
               "The centered grain must be audible but subordinate, measured \(contributionDB) dB")

        let reduced = FirstRunTimeSwipeAudioMix.state(progress: 0.5,
                                                      reduceMotion: true)
        expect(reduced.timeNoiseVolume < state.timeNoiseVolume
            && reduced.timeNoiseRate == 1,
               "Reduce Motion must soften the seam without pitching it")

        let quarter = FirstRunTimeSwipeAudioMix.state(progress: 0.25)
        let threeQuarter = FirstRunTimeSwipeAudioMix.state(progress: 0.75)
        expect(quarter.timeNoiseVolume >= state.timeNoiseVolume * 0.49,
               "The time seam must remain audible before the exact midpoint")
        expect(abs(quarter.timeNoiseVolume - threeQuarter.timeNoiseVolume) < 0.000_001,
               "The time seam must stay symmetric in both scrub directions")
    }

    private static func preservesOneLiteralSignatureContact(_ signature: [Frame]) {
        let starts = [1.25, 6.25, 11.25, 16.25].map {
            Int(round($0 * 44_100))
        }
        let count = Int(round(0.30 * 44_100))
        let reference = Array(signature[starts[0]..<(starts[0] + count)])
        for start in starts.dropFirst() {
            expect(reference == Array(signature[start..<(start + count)]),
                   "Every era must preserve the same sample-exact Poch match cut")
        }
        expect(rms(reference) > 0.025,
               "The real knuckle signature must remain physically audible")
    }

    private static func sharesTheMusicalEventGrid(_ origin: [Frame],
                                                   _ present: [Frame]) {
        let window = 1_102
        let originEnvelope = windowedRMS(origin, window: window)
        let presentEnvelope = windowedRMS(present, window: window)
        let correlation = normalizedCorrelation(originEnvelope, presentEnvelope)
        expect(correlation >= 0.50,
               "Both timbres must share one rhythmic event grid, measured \(correlation)")
        expect(abs(normalizedCorrelation(origin.map(\.left), present.map(\.left))) < 0.95,
               "The two eras must morph timbre rather than duplicate one recording")
    }

    private static func keepsTheRoomsSafeAndPurposefullyDifferent(_ origin: [Frame],
                                                                   _ present: [Frame]) {
        expect(rms(origin) > 0.005 && rms(present) > 0.005,
               "Both supplied room ambiences must remain audibly non-silent")
        expect(abs(normalizedCorrelation(origin.map(\.left), present.map(\.left))) < 0.95,
               "The supplied room beds must remain genuinely different recordings")

        let generator = source("tools/build_first_run_time_swipe_audio.py")
        let documentation = source("App/Audio/FIRST_RUN_AUDIO_SOURCES.md")
        expect(!generator.contains("\"first-run-origin-room.wav\"")
            && !generator.contains("\"first-run-present-room.wav\"")
            && documentation.contains("73165bd306950e47d9d5d9947e6b21ce94e49fada32e2d352165ccbfa9c29211")
            && documentation.contains("0b88207b551d2145ec6ce799c9091edb9951c25b94a2b4121a5bbae21018922c"),
               "The interaction-layer builder must preserve the supplied, fingerprinted rooms")
    }

    private static func keepsCompactRoomAssetsAndTwentySecondAuthoredLoops(_ layers: [[Frame]]) {
        expect(layers[0].count >= 20 * 44_100,
               "The historical room must cover the full interaction loop")
        expect(layers[2].count >= 20 * 44_100,
               "The present room must cover the full interaction loop")
        for index in [1, 3, 4, 5] {
            let layer = layers[index]
            expect(layer.count == 20 * 44_100,
                   "\(names[index]) must remain a 20-second stereo loop")
        }
        let roomBytes = [names[0], names[2]].reduce(0) { total, name in
            let attributes = try? FileManager.default.attributesOfItem(
                atPath: "App/Audio/\(name)"
            )
            let size = (attributes?[.size] as? NSNumber)?.intValue ?? Int.max
            return total + size
        }
        expect(roomBytes < 1_100_000,
               "The two supplied rooms must stay compact enough for the app bundle")
    }

    private static func preloadsFileBytesAwayFromTimelineEntry() {
        let runtime = source("App/FirstRunTimeSwipeAudio.swift")
        let start = section(runtime, from: "func startIfEnabled", to: "func update")
        expect(runtime.contains("Task.detached(priority: .utility)")
            && runtime.contains("options: [.mappedIfSafe]")
            && !start.contains("Data(contentsOf:")
            && !start.contains("AVAudioPlayer(contentsOf:")
            && !start.contains("prepareIfNeeded"),
               "Timeline entry must never synchronously read or decode long PCM assets")
        expect(runtime.contains("fadeDuration: 0.008")
            && runtime.contains("let frameCount = 12"),
               "Finger gain and startup feedback must settle within the short direct-manipulation budget")
    }

    private static func keepsDiscreteTimelineWiredToAudio() {
        let opening = source("App/FirstRunTimeSwipeOpening.swift")
        expect(opening.contains(".onChange(of: settledProgress)")
            && opening.contains("audioDirector.update(progress: progress)")
            && opening.contains("audioDirector.update(progress: snappedProgress)"),
               "Discrete VoiceOver and Reduce Motion chapters must update audio")
    }

    private static func clampsOutOfRangeProgress() {
        expect(FirstRunTimeSwipeAudioMix.state(progress: -1)
            == FirstRunTimeSwipeAudioMix.state(progress: 0),
               "Negative progress must clamp to 1441")
        expect(FirstRunTimeSwipeAudioMix.state(progress: 2)
            == FirstRunTimeSwipeAudioMix.state(progress: 1),
               "Excess progress must clamp to today")
    }

    private static func gains(progress: Double) -> [Double] {
        let state = FirstRunTimeSwipeAudioMix.state(progress: progress)
        return [Double(state.originRoomVolume), Double(state.originMotifVolume),
                Double(state.presentRoomVolume), Double(state.presentMotifVolume),
                Double(state.signatureContactVolume), Double(state.timeNoiseVolume)]
    }

    private static func covarianceMatrix(_ layers: [[Frame]]) -> [[Double]] {
        layers.map { left in
            layers.map { right in
                let count = min(left.count, right.count)
                var sum = 0.0
                for index in 0..<count {
                    sum += left[index].left * right[index].left
                    sum += left[index].right * right[index].right
                }
                return sum / Double(count * 2)
            }
        }
    }

    private static func renderedRMS(progress: Double,
                                    covariance: [[Double]]) -> Double {
        let level = gains(progress: progress)
        var energy = 0.0
        for left in level.indices {
            for right in level.indices {
                energy += level[left] * level[right] * covariance[left][right]
            }
        }
        return sqrt(max(0, energy))
    }

    private static func windowedRMS(_ frames: [Frame], window: Int) -> [Double] {
        stride(from: 0, to: frames.count - window, by: window).map { start in
            rms(Array(frames[start..<(start + window)]))
        }
    }

    private static func normalizedCorrelation(_ left: [Double],
                                              _ right: [Double]) -> Double {
        let count = min(left.count, right.count)
        let leftMean = left.prefix(count).reduce(0, +) / Double(count)
        let rightMean = right.prefix(count).reduce(0, +) / Double(count)
        var dot = 0.0
        var leftEnergy = 0.0
        var rightEnergy = 0.0
        for index in 0..<count {
            let lhs = left[index] - leftMean
            let rhs = right[index] - rightMean
            dot += lhs * rhs
            leftEnergy += lhs * lhs
            rightEnergy += rhs * rhs
        }
        return dot / max(0.000_000_001, sqrt(leftEnergy * rightEnergy))
    }

    private static func rms(_ frames: [Frame]) -> Double {
        sqrt(frames.reduce(0) { $0 + $1.left * $1.left + $1.right * $1.right }
            / Double(frames.count * 2))
    }

    private static func rms(_ samples: [Double]) -> Double {
        sqrt(samples.reduce(0) { $0 + $1 * $1 } / Double(samples.count))
    }

    private static func decibels(_ ratio: Double) -> Double {
        20 * log10(max(0.000_000_001, ratio))
    }

    private static func pcm(named name: String) -> [Frame] {
        let sourceURL = URL(fileURLWithPath: "App/Audio/\(name)")
        var decodedURL: URL?
        let wavURL: URL
        if sourceURL.pathExtension == "m4a" {
            let temporary = FileManager.default.temporaryDirectory
                .appendingPathComponent("poch-\(UUID().uuidString).wav")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
            process.arguments = [sourceURL.path, temporary.path,
                                 "-f", "WAVE", "-d", "LEI16@44100", "-c", "2"]
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                fail("Could not decode \(name): \(error)")
            }
            expect(process.terminationStatus == 0, "Could not decode \(name)")
            decodedURL = temporary
            wavURL = temporary
        } else {
            wavURL = sourceURL
        }
        defer {
            if let decodedURL { try? FileManager.default.removeItem(at: decodedURL) }
        }
        guard let data = try? Data(contentsOf: wavURL), data.count >= 44,
              let payload = waveData(in: data) else {
            fail("Missing PCM asset \(name)")
        }
        let bytes = [UInt8](payload)
        var result: [Frame] = []
        result.reserveCapacity(bytes.count / 4)
        for index in stride(from: 0, to: bytes.count - 3, by: 4) {
            let left = Int16(bitPattern: UInt16(bytes[index])
                             | UInt16(bytes[index + 1]) << 8)
            let right = Int16(bitPattern: UInt16(bytes[index + 2])
                              | UInt16(bytes[index + 3]) << 8)
            result.append(Frame(left: Double(left) / 32_768,
                                right: Double(right) / 32_768))
        }
        return result
    }

    private static func waveData(in data: Data) -> Data? {
        guard data.prefix(4) == Data("RIFF".utf8),
              data.dropFirst(8).prefix(4) == Data("WAVE".utf8) else { return nil }
        var offset = 12
        while offset + 8 <= data.count {
            let identifier = data[offset..<(offset + 4)]
            let sizeBytes = data[(offset + 4)..<(offset + 8)]
            let size = sizeBytes.enumerated().reduce(0) {
                $0 | Int($1.element) << ($1.offset * 8)
            }
            let start = offset + 8
            let end = start + size
            guard end <= data.count else { return nil }
            if identifier == Data("data".utf8) { return data[start..<end] }
            offset = end + (size % 2)
        }
        return nil
    }

    private static func source(_ path: String) -> String {
        guard let value = try? String(contentsOfFile: path, encoding: .utf8) else {
            fail("Missing source \(path)")
        }
        return value
    }

    private static func section(_ source: String, from start: String, to end: String) -> String {
        guard let lower = source.range(of: start)?.lowerBound,
              let upper = source.range(of: end, range: lower..<source.endIndex)?.lowerBound else {
            fail("Missing source section \(start)")
        }
        return String(source[lower..<upper])
    }

    private static func expect(_ condition: @autoclosure () -> Bool,
                               _ message: String) {
        guard condition() else { fail(message) }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(
            Data("FirstRunTimeSwipeAudioMixTests: \(message)\n".utf8)
        )
        Foundation.exit(EXIT_FAILURE)
    }
}

private struct Frame: Equatable {
    let left: Double
    let right: Double
}
