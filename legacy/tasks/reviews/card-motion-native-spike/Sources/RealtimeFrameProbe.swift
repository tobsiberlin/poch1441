import QuartzCore
import UIKit

struct RealtimeProbeResult: Codable, Sendable {
    let sampleCount: Int
    let durationSeconds: Double
    let p95FrameMilliseconds: Double
    let maximumFrameMilliseconds: Double
    let percentAtOrUnder16_67Milliseconds: Double
    let consecutivePairsOver33_3Milliseconds: Int
    let simulator: Bool
    let verdict: String
}

@MainActor
final class RealtimeFrameProbe: NSObject, ObservableObject {
    @Published private(set) var verdict = "NOT RUN"

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var intervals: [Double] = []
    private var startedAt: CFTimeInterval?

    func start() {
        intervals.removeAll(keepingCapacity: true)
        lastTimestamp = nil
        startedAt = CACurrentMediaTime()
        verdict = "RUNNING"
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func finishAndWrite() throws {
        displayLink?.invalidate()
        displayLink = nil
        let sorted = intervals.sorted()
        let p95Index = max(0, min(sorted.count - 1, Int(Double(sorted.count) * 0.95)))
        let p95 = sorted.isEmpty ? 0 : sorted[p95Index]
        let maximum = sorted.last ?? 0
        let withinBudget = intervals.filter { $0 <= 1.0 / 60.0 + 0.000_75 }.count
        let percent = intervals.isEmpty ? 0 : Double(withinBudget) / Double(intervals.count) * 100
        var slowPairs = 0
        if intervals.count > 1 {
            for index in 1..<intervals.count
            where intervals[index - 1] > 0.0333 && intervals[index] > 0.0333 {
                slowPairs += 1
            }
        }
        let simulator = ProcessInfo.processInfo.environment["SIMULATOR_UDID"] != nil
        let green = intervals.count >= 180 && percent >= 95 && slowPairs == 0
        verdict = green ? "GREEN" : "RED"
        let result = RealtimeProbeResult(
            sampleCount: intervals.count,
            durationSeconds: max(0, CACurrentMediaTime() - (startedAt ?? CACurrentMediaTime())),
            p95FrameMilliseconds: p95 * 1_000,
            maximumFrameMilliseconds: maximum * 1_000,
            percentAtOrUnder16_67Milliseconds: percent,
            consecutivePairsOver33_3Milliseconds: slowPairs,
            simulator: simulator,
            verdict: verdict
        )
        let data = try JSONEncoder.pretty.encode(result)
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let directory = documents.first else { throw CocoaError(.fileNoSuchFile) }
        try data.write(to: directory.appendingPathComponent("realtime-probe.json"), options: .atomic)
    }

    @objc private func tick(_ link: CADisplayLink) {
        if let lastTimestamp {
            intervals.append(link.timestamp - lastTimestamp)
        }
        lastTimestamp = link.timestamp
    }
}

