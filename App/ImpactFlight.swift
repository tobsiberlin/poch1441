import Observation
import SwiftUI
import os

enum PresentationEventKind: String, Sendable {
    case tableToken
    case dealCard
    case meldToken
    case pochToken
    case playedCard
    case penaltyToken
}

struct PresentationEvent: Identifiable, Equatable, Sendable {
    enum Phase: String, Sendable {
        case started
        case impacted
        case completed
        case cancelled
    }

    let id: String
    let kind: PresentationEventKind
    let source: String
    let target: String
    let startedAt: ContinuousClock.Instant
    var phase: Phase
}

@Observable @MainActor
final class PresentationDirector {
    private static let log = Logger(subsystem: "com.tobc.poch1441",
                                    category: "Presentation")
    private(set) var events: [String: PresentationEvent] = [:]
    private(set) var firstRunBeat: FirstRunBeat = .orientTable

    var firstRunStep: FirstRunStep {
        FirstRunScript.step(for: firstRunBeat)
    }

    var discLearningState: DiscLearningState {
        firstRunStep.learningState
    }

    func startFirstRun() {
        setFirstRunBeat(.orientTable)
    }

    func advanceFirstRun() {
        guard let next = FirstRunScript.next(after: firstRunBeat) else { return }
        setFirstRunBeat(next)
    }

    func setFirstRunBeat(_ beat: FirstRunBeat) {
        guard firstRunBeat != beat else { return }
        let previous = firstRunBeat
        firstRunBeat = beat
        Self.log.debug("first-run \(String(describing: previous), privacy: .public) -> \(String(describing: beat), privacy: .public)")
    }

    func begin(id: String,
               kind: PresentationEventKind,
               source: String,
               target: String) {
        guard events[id] == nil else { return }
        events[id] = PresentationEvent(id: id,
                                       kind: kind,
                                       source: source,
                                       target: target,
                                       startedAt: .now,
                                       phase: .started)
        Self.log.debug("start \(id, privacy: .public) \(source, privacy: .public) -> \(target, privacy: .public)")
    }

    @discardableResult
    func impact(id: String) -> Bool {
        guard var event = events[id], event.phase == .started else { return false }
        event.phase = .impacted
        events[id] = event
        Self.log.debug("impact \(id, privacy: .public)")
        return true
    }

    func complete(id: String) {
        guard var event = events[id], event.phase == .impacted else { return }
        event.phase = .completed
        events[id] = event
        Self.log.debug("complete \(id, privacy: .public)")
    }

    func cancelAll() {
        for (id, var event) in events where event.phase != .completed {
            event.phase = .cancelled
            events[id] = event
        }
    }

    func reset() {
        events.removeAll(keepingCapacity: true)
    }
}

/// A single source-to-target transaction. The target state is committed only by
/// `onImpact`, which is guarded against duplicate animation completions.
struct ImpactFlight<Content: View>: View {
    let from: CGPoint
    let to: CGPoint
    let duration: Double
    let delay: Double
    let arcHeight: CGFloat
    let lateralBias: CGFloat
    private let content: (CGFloat) -> Content
    private let onImpact: () -> Void

    @State private var progress: CGFloat = 0
    @State private var impacted = false

    init(from: CGPoint,
         to: CGPoint,
         duration: Double,
         delay: Double = 0,
         arcHeight: CGFloat = 0,
         lateralBias: CGFloat = 0,
         onImpact: @escaping () -> Void,
         @ViewBuilder content: @escaping (CGFloat) -> Content) {
        self.from = from
        self.to = to
        self.duration = duration
        self.delay = delay
        self.arcHeight = arcHeight
        self.lateralBias = lateralBias
        self.onImpact = onImpact
        self.content = content
    }

    var body: some View {
        content(progress)
            .position(PhysicalMotion.quadraticPoint(progress: progress,
                                                    from: from,
                                                    to: to,
                                                    arcHeight: arcHeight,
                                                    lateralBias: lateralBias))
            .onAppear {
                withAnimation(PhysicalMotion.travel(duration: duration).delay(delay),
                              completionCriteria: .logicallyComplete) {
                    progress = 1
                } completion: {
                    impactOnce()
                }
            }
    }

    private func impactOnce() {
        guard !impacted else { return }
        impacted = true
        onImpact()
    }
}
