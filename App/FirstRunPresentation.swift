import SwiftUI

enum DiscLearningState: String, CaseIterable, Sendable {
    case orientieren
    case verbinden
    case beweisen
    case loslassen
}

enum FirstRunBeat: Int, CaseIterable, Comparable, Sendable {
    case orientTable
    case fundTable
    case firstCard
    case completeHand
    case revealTrump
    case connectMeld
    case proveMeld
    case release

    static func < (lhs: FirstRunBeat, rhs: FirstRunBeat) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct FirstRunStep: Identifiable, Sendable {
    enum Focus: Sendable {
        case discCenter
        case fullDisc
        case seatsAndDeck
        case hand
        case trump
        case meldConnection
        case settledTable
    }

    let beat: FirstRunBeat
    let learningState: DiscLearningState
    let focus: Focus
    let allowsPrimaryAction: Bool
    var id: FirstRunBeat { beat }
}

enum FirstRunScript {
    static let steps: [FirstRunStep] = [
        FirstRunStep(beat: .orientTable,
                     learningState: .orientieren,
                     focus: .discCenter,
                     allowsPrimaryAction: true),
        FirstRunStep(beat: .fundTable,
                     learningState: .orientieren,
                     focus: .fullDisc,
                     allowsPrimaryAction: true),
        FirstRunStep(beat: .firstCard,
                     learningState: .verbinden,
                     focus: .seatsAndDeck,
                     allowsPrimaryAction: true),
        FirstRunStep(beat: .completeHand,
                     learningState: .verbinden,
                     focus: .hand,
                     allowsPrimaryAction: true),
        FirstRunStep(beat: .revealTrump,
                     learningState: .verbinden,
                     focus: .trump,
                     allowsPrimaryAction: true),
        FirstRunStep(beat: .connectMeld,
                     learningState: .verbinden,
                     focus: .meldConnection,
                     allowsPrimaryAction: true),
        FirstRunStep(beat: .proveMeld,
                     learningState: .beweisen,
                     focus: .meldConnection,
                     allowsPrimaryAction: true),
        FirstRunStep(beat: .release,
                     learningState: .loslassen,
                     focus: .settledTable,
                     allowsPrimaryAction: true)
    ]

    static func step(for beat: FirstRunBeat) -> FirstRunStep {
        steps.first(where: { $0.beat == beat }) ?? steps[0]
    }

    static func next(after beat: FirstRunBeat) -> FirstRunBeat? {
        guard let index = steps.firstIndex(where: { $0.beat == beat }),
              steps.indices.contains(index + 1) else { return nil }
        return steps[index + 1].beat
    }
}

struct FirstRunStageZones: Equatable {
    let header: CGRect
    let opponents: CGRect
    let decision: CGRect
    let board: CGRect
    let hand: CGRect
    let isLandscape: Bool

    static func resolve(in size: CGSize, safeArea: EdgeInsets) -> FirstRunStageZones {
        let landscape = size.width > size.height
        if landscape {
            let top = safeArea.top + 8
            let bottom = size.height - safeArea.bottom - 8
            let availableHeight = max(240, bottom - top)
            let opponentsWidth = min(132, size.width * 0.18)
            let decisionX = safeArea.leading + opponentsWidth + 20
            let boardSide = min(availableHeight * 0.72,
                                availableHeight - 126,
                                size.width * 0.35)
            let boardX = size.width - safeArea.trailing - boardSide - 18
            let decisionWidth = min(286,
                                    size.width * 0.34,
                                    max(180, boardX - decisionX - 18))
            return FirstRunStageZones(
                header: CGRect(x: decisionX,
                               y: top,
                               width: decisionWidth,
                               height: 52),
                opponents: CGRect(x: safeArea.leading + 8,
                                  y: top + 18,
                                  width: opponentsWidth,
                                  height: availableHeight - 132),
                decision: CGRect(x: decisionX,
                                 y: top + 60,
                                 width: decisionWidth,
                                 height: max(120, availableHeight - 166)),
                board: CGRect(x: boardX,
                              y: top + 12,
                              width: boardSide,
                              height: boardSide),
                hand: CGRect(x: decisionX - 8,
                             y: bottom - 104,
                             width: size.width - decisionX - safeArea.trailing - 12,
                             height: 104),
                isLandscape: true
            )
        }

        let top = safeArea.top + 8
        let usableWidth = size.width - safeArea.leading - safeArea.trailing
        let handTop = size.height - safeArea.bottom - 126
        let boardY = top + 142
        let boardSide = min(usableWidth - 32,
                            max(180, handTop - boardY - 154),
                            max(216, size.height * 0.36))
        let boardX = safeArea.leading + (usableWidth - boardSide) / 2
        let decisionY = boardY + boardSide + 10
        let decisionHeight = max(112, min(142, handTop - decisionY - 6))
        return FirstRunStageZones(
            header: CGRect(x: safeArea.leading + 18,
                           y: top,
                           width: usableWidth - 36,
                           height: 76),
            opponents: CGRect(x: safeArea.leading + 22,
                              y: top + 76,
                              width: usableWidth - 44,
                              height: 58),
            decision: CGRect(x: safeArea.leading + 18,
                             y: decisionY,
                             width: usableWidth - 36,
                             height: decisionHeight),
            board: CGRect(x: boardX,
                          y: boardY,
                          width: boardSide,
                          height: boardSide),
            hand: CGRect(x: safeArea.leading + 8,
                         y: handTop,
                         width: usableWidth - 16,
                         height: 126),
            isLandscape: false
        )
    }
}
