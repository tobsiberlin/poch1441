import Foundation

@main
struct FirstRunTimeSwipeProjectionTests {
    static func main() {
        clampsAndMapsOneToOne()
        snapsToThreeSemanticStops()
        projectedReleaseCanCommitOrReverse()
        chapterBoundariesStayDeterministic()
        handleRemainsVisibleAtBothEndpoints()
        FileHandle.standardOutput.write(
            Data("FirstRunTimeSwipeProjectionTests: PASS\n".utf8)
        )
    }

    private static func clampsAndMapsOneToOne() {
        expect(FirstRunTimeSwipeProjection.progress(
            settledProgress: 0.2,
            translation: 100,
            width: 400
        ) == 0.45, "Drag progress must follow the finger one-to-one")
        expect(FirstRunTimeSwipeProjection.progress(
            settledProgress: 0.9,
            translation: 200,
            width: 400
        ) == 1, "Progress must clamp at the present endpoint")
        expect(FirstRunTimeSwipeProjection.progress(
            settledProgress: 0.1,
            translation: -200,
            width: 400
        ) == 0, "Progress must clamp at the historical endpoint")
    }

    private static func snapsToThreeSemanticStops() {
        expect(FirstRunTimeSwipeProjection.nearestChapter(to: 0.18) == .origin,
               "Early releases return to 1441")
        expect(FirstRunTimeSwipeProjection.nearestChapter(to: 0.49) == .branch,
               "The historical branch must be a stable stop")
        expect(FirstRunTimeSwipeProjection.nearestChapter(to: 0.88) == .today,
               "Late releases must reach today")
    }

    private static func projectedReleaseCanCommitOrReverse() {
        expect(FirstRunTimeSwipeProjection.target(
            currentProgress: 0.38,
            predictedTranslation: 250,
            width: 390
        ) == .today, "Forward momentum must carry a partial drag to today")
        expect(FirstRunTimeSwipeProjection.target(
            currentProgress: 0.72,
            predictedTranslation: -240,
            width: 390
        ) == .origin, "Reverse momentum must be able to return to 1441")
    }

    private static func chapterBoundariesStayDeterministic() {
        expect(FirstRunTimeSwipeProjection.chapter(for: 0.1) == .origin,
               "The opening copy must remain stable near 1441")
        expect(FirstRunTimeSwipeProjection.chapter(for: 0.55) == .branch,
               "The family branch must own the middle stop")
        expect(FirstRunTimeSwipeProjection.chapter(for: 0.90) == .branch,
               "Near-end scrubbing must not reveal the final CTA early")
        expect(FirstRunTimeSwipeProjection.chapter(for: 0.94) == .today,
               "The final CTA must appear only inside the committed endpoint zone")
        expect(FirstRunTimeSwipeProjection.chapter(for: 0.96) == .today,
               "The present-day CTA must own the final stop")
        expect(!FirstRunTimeSwipeProjection.isFinalEndpoint(0.96),
               "Present-day copy must not expose actions before the visual endpoint")
        expect(FirstRunTimeSwipeProjection.isFinalEndpoint(0.995),
               "The final action zone must begin only at the committed endpoint")
    }

    private static func handleRemainsVisibleAtBothEndpoints() {
        expect(FirstRunTimeSwipeProjection.handleCenterX(progress: 0, width: 390) == 34,
               "The handle must remain fully inside the historical edge")
        expect(FirstRunTimeSwipeProjection.handleCenterX(progress: 1, width: 390) == 356,
               "The handle must remain fully inside the present-day edge")
        expect(FirstRunTimeSwipeProjection.handleSymbolName(progress: 0) == "chevron.right",
               "The left endpoint must advertise the available direction")
        expect(FirstRunTimeSwipeProjection.handleSymbolName(progress: 1) == "chevron.left",
               "The right endpoint must advertise the reverse direction")
    }

    private static func expect(_ condition: @autoclosure () -> Bool,
                               _ message: String) {
        guard condition() else {
            FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
            Foundation.exit(EXIT_FAILURE)
        }
    }
}
