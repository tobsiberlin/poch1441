import Foundation

@main
struct FirstRunTimeSwipeAudioMixTests {
    static func main() {
        keepsBothErasClean()
        peaksOnlyAtTheTimeSeam()
        followsTheFingerReversibly()
        clampsOutOfRangeProgress()
        FileHandle.standardOutput.write(
            Data("FirstRunTimeSwipeAudioMixTests: PASS\n".utf8)
        )
    }

    private static func keepsBothErasClean() {
        let origin = FirstRunTimeSwipeAudioMix.state(progress: 0)
        let present = FirstRunTimeSwipeAudioMix.state(progress: 1)

        expect(origin.timeNoiseVolume == 0,
               "The historical endpoint must contain no transition noise")
        expect(present.timeNoiseVolume < 0.000_001,
               "The present endpoint must contain no transition noise")
        expect(origin.presentRoomVolume == 0 && origin.presentMotifVolume == 0,
               "The present scene must be silent at 1441")
        expect(present.originRoomVolume == 0 && present.originMotifVolume == 0,
               "The historical scene must be silent today")
    }

    private static func peaksOnlyAtTheTimeSeam() {
        let quarter = FirstRunTimeSwipeAudioMix.state(progress: 0.25)
        let middle = FirstRunTimeSwipeAudioMix.state(progress: 0.5)
        let threeQuarter = FirstRunTimeSwipeAudioMix.state(progress: 0.75)

        expect(abs(middle.timeNoiseVolume - 0.15) < 0.000_001,
               "The seam must reach its authored peak at the midpoint")
        expect(abs(quarter.timeNoiseVolume - threeQuarter.timeNoiseVolume) < 0.000_001,
               "The seam envelope must be symmetric in both swipe directions")
        expect(quarter.timeNoiseVolume < middle.timeNoiseVolume * 0.26,
               "The transition must not contaminate the era soundscapes")
    }

    private static func followsTheFingerReversibly() {
        let forward = FirstRunTimeSwipeAudioMix.state(progress: 0.68)
        let reverse = FirstRunTimeSwipeAudioMix.state(progress: 0.68)
        let earlier = FirstRunTimeSwipeAudioMix.state(progress: 0.32)

        expect(forward == reverse,
               "Mix state must depend on finger position, not wall-clock direction")
        expect(forward.timeNoiseRate > earlier.timeNoiseRate,
               "The tonal search impulse must move monotonically with the finger")
    }

    private static func clampsOutOfRangeProgress() {
        expect(FirstRunTimeSwipeAudioMix.state(progress: -1)
            == FirstRunTimeSwipeAudioMix.state(progress: 0),
               "Negative progress must clamp to 1441")
        expect(FirstRunTimeSwipeAudioMix.state(progress: 2)
            == FirstRunTimeSwipeAudioMix.state(progress: 1),
               "Excess progress must clamp to today")
    }

    private static func expect(_ condition: @autoclosure () -> Bool,
                               _ message: String) {
        guard condition() else {
            FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
            Foundation.exit(EXIT_FAILURE)
        }
    }
}
