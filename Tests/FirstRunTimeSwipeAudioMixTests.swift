import Foundation

@main
struct FirstRunTimeSwipeAudioMixTests {
    static func main() {
        keepsBothErasClean()
        crossfadesRoomsContinuouslyWithoutALoudnessHole()
        keepsMaterialDetailsBehindTheRooms()
        keepsTheSyntheticSeamSilent()
        followsTheFingerReversibly()
        reducesMotionOfTheSeam()
        keepsTheNaturalCrossfadeCalibrated()
        placesTheErasOnARestrainedStereoAxis()
        keepsFingerProgressLiveDuringTheMasterFade()
        keepsTheTwentySecondAssetContract()
        keepsTheDiscreteTimelineWiredToAudio()
        clampsOutOfRangeProgress()
        FileHandle.standardOutput.write(
            Data("FirstRunTimeSwipeAudioMixTests: PASS\n".utf8)
        )
    }

    private static func crossfadesRoomsContinuouslyWithoutALoudnessHole() {
        let states = (0...100).map {
            FirstRunTimeSwipeAudioMix.state(progress: Double($0) / 100)
        }

        for index in 1..<states.count {
            expect(states[index].originRoomVolume < states[index - 1].originRoomVolume,
                   "The historical room must become continuously quieter to the right")
            expect(states[index].presentRoomVolume > states[index - 1].presentRoomVolume,
                   "The present room must become continuously louder to the right")
        }

        let middle = states[50]
        expect(middle.originRoomVolume > 0.35 && middle.presentRoomVolume > 0.31,
               "Both rooms must remain audible at the time seam")
        expect(states.first?.originRoomVolume == 0.50,
               "The lively historical tavern must own the first endpoint")
        expect(states.last?.presentRoomVolume == 0.45,
               "The relaxed present room must remain clear at its endpoint")
    }

    private static func keepsMaterialDetailsBehindTheRooms() {
        let origin = FirstRunTimeSwipeAudioMix.state(progress: 0)
        let present = FirstRunTimeSwipeAudioMix.state(progress: 1)

        expect(origin.originMotifVolume < origin.originRoomVolume * 0.38,
               "Historical table details must not dominate the tavern room")
        expect(present.presentMotifVolume < present.presentRoomVolume * 0.37,
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

    private static func keepsTheSyntheticSeamSilent() {
        let quarter = FirstRunTimeSwipeAudioMix.state(progress: 0.25)
        let middle = FirstRunTimeSwipeAudioMix.state(progress: 0.5)
        let threeQuarter = FirstRunTimeSwipeAudioMix.state(progress: 0.75)

        expect(middle.timeNoiseVolume == 0,
               "The clean room transition must not reintroduce radio noise")
        expect(abs(quarter.timeNoiseVolume - threeQuarter.timeNoiseVolume) < 0.000_001,
               "The seam envelope must be symmetric in both swipe directions")
        expect(quarter.timeNoiseVolume == 0 && threeQuarter.timeNoiseVolume == 0,
               "The transition must stay free of synthetic seam effects")
    }

    private static func followsTheFingerReversibly() {
        let forward = FirstRunTimeSwipeAudioMix.state(progress: 0.68)
        let reverse = FirstRunTimeSwipeAudioMix.state(progress: 0.68)
        let earlier = FirstRunTimeSwipeAudioMix.state(progress: 0.32)

        expect(forward == reverse,
               "Mix state must depend on finger position, not wall-clock direction")
        expect(forward.originRoomVolume < earlier.originRoomVolume
            && forward.presentRoomVolume > earlier.presentRoomVolume,
               "The natural rooms must follow the finger reversibly")
    }

    private static func reducesMotionOfTheSeam() {
        let standard = FirstRunTimeSwipeAudioMix.state(progress: 0.5)
        let reduced = FirstRunTimeSwipeAudioMix.state(progress: 0.5,
                                                      reduceMotion: true)

        expect(reduced.timeNoiseRate == 1,
               "The natural crossfade must never pitch a seam texture")
        expect(reduced.timeNoiseVolume == 0 && standard.timeNoiseVolume == 0,
               "Neither motion mode may restore the rejected radio seam")
        expect(reduced.originRoomVolume == standard.originRoomVolume
            && reduced.presentRoomVolume == standard.presentRoomVolume,
               "Reduce Motion must preserve the understandable era crossfade")
    }

    private static func keepsTheNaturalCrossfadeCalibrated() {
        let origin = FirstRunTimeSwipeAudioMix.state(progress: 0)
        let middle = FirstRunTimeSwipeAudioMix.state(progress: 0.5)
        let present = FirstRunTimeSwipeAudioMix.state(progress: 1)

        expect(origin.originRoomVolume == 0.50 && present.presentRoomVolume == 0.45,
               "Room endpoints must retain the measured -27 dBFS calibration")
        expect(middle.originRoomVolume > middle.presentRoomVolume,
               "The source-level compensation must survive the equal-power seam")
        expect(origin.originMotifVolume == 0.18 && present.presentMotifVolume == 0.16,
               "Natural contact beds must be audible without becoming music")
    }

    private static func placesTheErasOnARestrainedStereoAxis() {
        let origin = FirstRunTimeSwipeAudioMix.state(progress: 0)
        let middle = FirstRunTimeSwipeAudioMix.state(progress: 0.5)
        let present = FirstRunTimeSwipeAudioMix.state(progress: 1)

        expect(origin.originRoomPan < 0 && present.presentRoomPan > 0,
               "1441 must sit left and today right on the audible time axis")
        expect(abs(origin.originRoomPan) <= 0.30
            && abs(present.presentRoomPan) <= 0.30,
               "Phone playback must use restrained rather than hard stereo pans")
        expect(abs(origin.originMotifPan) < abs(origin.originRoomPan)
            && abs(present.presentMotifPan) < abs(present.presentRoomPan),
               "Important table contacts must stay closer to the center")
        expect(middle.originRoomVolume > 0 && middle.presentRoomVolume > 0,
               "Both spatially distinct rooms must overlap in the middle")
    }

    private static func keepsFingerProgressLiveDuringTheMasterFade() {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let source = try? String(
            contentsOf: root.appendingPathComponent("App/FirstRunTimeSwipeAudio.swift"),
            encoding: .utf8
        )
        expect(source?.contains("masterGain") == true
            && source?.contains("currentMix = mixState(progress: progress)") == true
            && source?.contains("pendingProgress") == false,
               "The start fade must multiply the live finger mix instead of queuing it")
    }

    private static func keepsTheTwentySecondAssetContract() {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let audio = root.appendingPathComponent("App/Audio")
        let twentySecondNames = [
            "first-run-origin-room.wav",
            "first-run-origin-motif.wav",
            "first-run-present-room.wav",
            "first-run-present-motif.wav"
        ]
        let expectedByteCount = 44 + 20 * 44_100 * 2 * 2

        for name in twentySecondNames {
            let data = try? Data(contentsOf: audio.appendingPathComponent(name))
            expect(data?.count == expectedByteCount,
                   "\(name) must remain 20-second stereo PCM16")
        }

        let seam = try? Data(contentsOf: audio.appendingPathComponent(
            "first-run-time-noise.wav"
        ))
        expect(seam?.count == 44 + 44_100 * 2 * 2
            && seam?.dropFirst(44).allSatisfy { $0 == 0 } == true,
               "The retired radio seam asset must contain digital silence")
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
