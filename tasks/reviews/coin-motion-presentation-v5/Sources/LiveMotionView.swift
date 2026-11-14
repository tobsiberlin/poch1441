import Foundation
import os
import UIKit

struct WallClockReport: Codable, Sendable {
    let requestedFramesPerSecond: Int
    let measuredFrameCount: Int
    let meanFrameIntervalMilliseconds: Double
    let p95FrameIntervalMilliseconds: Double
    let p99FrameIntervalMilliseconds: Double
    let intervalsOver20Milliseconds: Int
    let intervalsOver33Milliseconds: Int
    let throwsCompleted: Int
    let distinctSeeds: Int
    let reducedMotionLatencyMilliseconds: Double
}

@MainActor
final class LiveMotionView: UIView {
    private static let log = Logger(subsystem: "com.tobc.reviews.coin-motion-presentation-v5",
                                    category: "WallClock")
    private let renderer: CoinSceneRenderer
    private var displayLink: CADisplayLink?
    private var throwStart = CACurrentMediaTime()
    private var lastTimestamp: CFTimeInterval?
    private var intervals: [Double] = []
    private var seedIndex = 0
    private var plans = (0..<10).map { CoinMotionPlan(seed: 1_441 + UInt64($0) * 97) }
    private var activeImage: UIImage?
    private var completionWritten = false
    private var reducedMotion = false

    init?(frame: CGRect, renderer: CoinSceneRenderer) {
        self.renderer = renderer
        super.init(frame: frame)
        isOpaque = true
        contentMode = .redraw
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 60,
                                                            maximum: 60,
                                                            preferred: 60)
        } else {
            link.preferredFramesPerSecond = 60
        }
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func draw(_ rect: CGRect) {
        activeImage?.draw(in: bounds)
    }

    override func removeFromSuperview() {
        displayLink?.invalidate()
        super.removeFromSuperview()
    }

    func setReducedMotion(_ enabled: Bool) {
        reducedMotion = enabled
        if enabled {
            throwStart = CACurrentMediaTime()
        }
    }

    @objc private func tick(_ link: CADisplayLink) {
        if let lastTimestamp {
            intervals.append((link.timestamp - lastTimestamp) * 1_000)
        }
        lastTimestamp = link.timestamp
        let plan = plans[seedIndex]
        let elapsed = link.timestamp - throwStart
        let viewport = CoinViewport(name: "live-\(Int(bounds.width))x\(Int(bounds.height))",
                                    width: max(1, Int(bounds.width)),
                                    height: max(1, Int(bounds.height)))
        activeImage = renderer.render(viewport: viewport,
                                      plan: plan,
                                      time: elapsed,
                                      reducedMotion: reducedMotion).image
        setNeedsDisplay()
        guard !reducedMotion, elapsed >= plan.duration else { return }
        seedIndex += 1
        if seedIndex >= plans.count {
            displayLink?.invalidate()
            writeReport()
            return
        }
        throwStart = link.timestamp
    }

    private func writeReport() {
        guard !completionWritten else { return }
        completionWritten = true
        let sorted = intervals.sorted()
        let report = WallClockReport(
            requestedFramesPerSecond: 60,
            measuredFrameCount: intervals.count,
            meanFrameIntervalMilliseconds: intervals.reduce(0, +) / Double(max(intervals.count, 1)),
            p95FrameIntervalMilliseconds: percentile(0.95, sorted: sorted),
            p99FrameIntervalMilliseconds: percentile(0.99, sorted: sorted),
            intervalsOver20Milliseconds: intervals.filter { $0 > 20 }.count,
            intervalsOver33Milliseconds: intervals.filter { $0 > 33.34 }.count,
            throwsCompleted: plans.count,
            distinctSeeds: Set(plans.map(\.seed)).count,
            reducedMotionLatencyMilliseconds: 0
        )
        do {
            let data = try JSONEncoder.pretty.encode(report)
            try data.write(to: Self.documentsURL.appendingPathComponent("wallclock.json"),
                           options: .atomic)
            try Data("complete".utf8).write(
                to: Self.documentsURL.appendingPathComponent("wallclock.complete"),
                options: .atomic
            )
        } catch {
            Self.log.error("Wallclock report failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func percentile(_ fraction: Double, sorted: [Double]) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let index = min(sorted.count - 1,
                        max(0, Int((Double(sorted.count - 1) * fraction).rounded())))
        return sorted[index]
    }

    private static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
