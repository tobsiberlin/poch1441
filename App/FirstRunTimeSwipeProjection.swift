import Foundation

enum FirstRunTimeChapter: Int, CaseIterable, Equatable, Sendable {
    case origin
    case branch
    case today

    var progress: Double {
        switch self {
        case .origin: 0
        case .branch: 0.55
        case .today: 1
        }
    }
}

/// Pure projection math for the direct-manipulation opening. It is kept free
/// of SwiftUI, game rules and persistence so gesture behavior can be tested
/// without launching the app.
enum FirstRunTimeSwipeProjection {
    static let branchProgress = 0.55
    static let handleSafeInset = 34.0

    static func clamped(_ progress: Double) -> Double {
        min(max(progress, 0), 1)
    }

    static func progress(settledProgress: Double,
                         translation: Double,
        width: Double) -> Double {
        guard width > 0 else { return clamped(settledProgress) }
        return clamped(settledProgress + translation / width)
    }

    static func target(currentProgress: Double,
                       predictedTranslation: Double,
                       width: Double) -> FirstRunTimeChapter {
        let projected = progress(settledProgress: currentProgress,
                                 translation: predictedTranslation,
                                 width: width)
        return nearestChapter(to: projected)
    }

    static func nearestChapter(to progress: Double) -> FirstRunTimeChapter {
        let candidate = clamped(progress)
        return FirstRunTimeChapter.allCases.min {
            abs($0.progress - candidate) < abs($1.progress - candidate)
        } ?? .origin
    }

    static func chapter(for progress: Double) -> FirstRunTimeChapter {
        let candidate = clamped(progress)
        if candidate < 0.30 { return .origin }
        if candidate < 0.94 { return .branch }
        return .today
    }

    static func isFinalEndpoint(_ progress: Double) -> Bool {
        clamped(progress) >= 0.995
    }

    static func handleCenterX(progress: Double, width: Double) -> Double {
        guard width > 0 else { return 0 }
        let inset = min(handleSafeInset, width / 2)
        return min(max(width * clamped(progress), inset), width - inset)
    }

    static func handleSymbolName(progress: Double) -> String {
        let candidate = clamped(progress)
        if candidate <= 0.02 { return "chevron.right" }
        if candidate >= 0.98 { return "chevron.left" }
        return "chevron.left.chevron.right"
    }

    static func opacity(_ progress: Double,
                        from lowerBound: Double,
                        to upperBound: Double) -> Double {
        guard upperBound > lowerBound else { return progress >= upperBound ? 1 : 0 }
        let linear = clamped((progress - lowerBound) / (upperBound - lowerBound))
        return linear * linear * (3 - 2 * linear)
    }
}
