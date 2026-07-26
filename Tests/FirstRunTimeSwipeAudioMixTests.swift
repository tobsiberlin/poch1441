import Foundation

@main
struct FirstRunTimeSwipeAudioMixTests {
    static func main() {
        keepsBothErasClean()
        crossfadesRoomsContinuouslyAndAtEqualPower()
        keepsMaterialDetailsBehindTheRooms()
        peaksOnlyAtTheTimeSeam()
        followsTheFingerReversibly()
        reducesMotionOfTheSeam()
        keepsTheDiscreteTimelineWiredToAudio()
        clampsOutOfRangeProgress()
        FileHandle.standardOutput.write(
            Data("FirstRunTimeSwipeAudioMixTests: PASS\n".utf8)
        )
    }

    private static func crossfadesRoomsContinuouslyAndAtEqualPower() {
        let states = (0...100).map {
            FirstRunTimeSwipeAudioMix.state(progress: Double($0) / 100)
        }

        for index in 1..<states.count {
            expect(states[index].originRoomVolume < states[index - 1].originRoomVolume,
                   "The historical room must become continuously quieter to the right")
            expect(states[index].presentRoomVolume > states[index - 1].presentRoomVolume,
                   "The present room must become continuously louder to the right")
        }

        for index in states.indices {
            let reverse = states[states.count - 1 - index]
            expect(abs(states[index].originRoomVolume - reverse.presentRoomVolume) < 0.000_001,
                   "Forward and reverse room crossfades must be exact mirrors")
            let normalizedOrigin = states[index].originRoomVolume / 0.78
            let normalizedPresent = states[index].presentRoomVolume / 0.78
            let power = normalizedOrigin * normalizedOrigin
                + normalizedPresent * normalizedPresent
            expect(abs(power - 1) < 0.000_001,
                   "The room crossfade must not create a loudness hole at the seam")
        }
    }

    private static func keepsMaterialDetailsBehindTheRooms() {
        let origin = FirstRunTimeSwipeAudioMix.state(progress: 0)
        let present = FirstRunTimeSwipeAudioMix.state(progress: 1)

        expect(origin.originMotifVolume < origin.originRoomVolume * 0.16,
               "Historical table details must not dominate the tavern room")
        expect(present.presentMotifVolume < present.presentRoomVolume * 0.14,
               "Present table details must not dominate the cozy room")
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

        expect(abs(middle.timeNoiseVolume - 0.28) < 0.000_001,
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
               "The tonal seam texture must move monotonically with the finger")
    }

    private static func reducesMotionOfTheSeam() {
        let standard = FirstRunTimeSwipeAudioMix.state(progress: 0.5)
        let reduced = FirstRunTimeSwipeAudioMix.state(progress: 0.5,
                                                      reduceMotion: true)

        expect(reduced.timeNoiseRate == 1,
               "Reduce Motion must disable the seam's pitch travel")
        expect(reduced.timeNoiseVolume < standard.timeNoiseVolume * 0.36,
               "Reduce Motion must substantially soften the acoustic seam")
        expect(reduced.originRoomVolume == standard.originRoomVolume
            && reduced.presentRoomVolume == standard.presentRoomVolume,
               "Reduce Motion must preserve the understandable era crossfade")
    }

    private static func clampsOutOfRangeProgress() {
        expect(FirstRunTimeSwipeAudioMix.state(progress: -1)
            == FirstRunTimeSwipeAudioMix.state(progress: 0),
               "Negative progress must clamp to 1441")
        expect(FirstRunTimeSwipeAudioMix.state(progress: 2)
            == FirstRunTimeSwipeAudioMix.state(progress: 1),
               "Excess progress must clamp to today")
    }

    private static func keepsTheDiscreteTimelineWiredToAudio() {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let source = try? String(
            contentsOf: root.appendingPathComponent("App/FirstRunTimeSwipeOpening.swift"),
            encoding: .utf8
        )
        expect(source?.contains(".onChange(of: settledProgress)") == true
            && source?.contains("audioDirector.update(progress: progress)") == true
            && source?.contains("audioDirector.update(progress: snappedProgress)") == true,
               "Discrete VoiceOver and Reduce Motion chapters must update the era mix")
    }

    private static func expect(_ condition: @autoclosure () -> Bool,
                               _ message: String) {
        guard condition() else {
            FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
            Foundation.exit(EXIT_FAILURE)
        }
    }
}
