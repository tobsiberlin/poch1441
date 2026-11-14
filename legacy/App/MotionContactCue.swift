import Foundation

struct MotionContactCue: Equatable, Sendable {
    let identity: CoinTransferIdentity
    let contactHostTime: UInt64
    let surfaceID: String
    let audioFingerprintID: String
    let soundEnabled: Bool
    let hapticsEnabled: Bool
}

enum MotionContactCueResult: Equatable, Sendable {
    case accepted
    case duplicate
    case stale
    case alreadyContacted
    case cancelled
}

@MainActor
protocol MotionContactCueOutput: AnyObject {
    func prepare() throws
    func schedule(_ cue: MotionContactCue) throws
    func cancel(identity: CoinTransferIdentity)
}

/// Generationgebundener Exact-once-Director für physisches Feedback. Er plant
/// ausschließlich Ausgaben; sichtbarer Zustand bleibt beim CoinTransfer-Gate.
@MainActor
final class MotionContactCueCoordinator {
    private enum State {
        case scheduled(MotionContactCue)
        case contacted(MotionContactCue)
        case cancelled(MotionContactCue)

        var cue: MotionContactCue {
            switch self {
            case .scheduled(let cue), .contacted(let cue), .cancelled(let cue): cue
            }
        }
    }

    private let output: any MotionContactCueOutput
    private var state: State?

    init(output: any MotionContactCueOutput) {
        self.output = output
    }

    func prepare() throws { try output.prepare() }

    func schedule(_ cue: MotionContactCue) throws -> MotionContactCueResult {
        if let state {
            guard state.cue.identity == cue.identity else { return .stale }
            switch state {
            case .scheduled: return .duplicate
            case .contacted: return .alreadyContacted
            case .cancelled: return .cancelled
            }
        }
        state = .scheduled(cue)
        try output.schedule(cue)
        return .accepted
    }

    func markContact(identity: CoinTransferIdentity) -> MotionContactCueResult {
        guard let state else { return .stale }
        guard state.cue.identity == identity else { return .stale }
        switch state {
        case .scheduled(let cue):
            self.state = .contacted(cue)
            return .accepted
        case .contacted:
            return .alreadyContacted
        case .cancelled:
            return .cancelled
        }
    }

    func cancelBeforeContact(identity: CoinTransferIdentity) -> MotionContactCueResult {
        guard let state else { return .stale }
        guard state.cue.identity == identity else { return .stale }
        switch state {
        case .scheduled(let cue):
            self.state = .cancelled(cue)
            output.cancel(identity: identity)
            return .accepted
        case .contacted:
            return .alreadyContacted
        case .cancelled:
            return .cancelled
        }
    }
}
