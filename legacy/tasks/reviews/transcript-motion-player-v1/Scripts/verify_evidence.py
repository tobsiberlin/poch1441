#!/usr/bin/env python3
import hashlib
import json
import math
import os
import statistics
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = ROOT.parents[2]
EVIDENCE = ROOT / "Evidence"
SOURCE = PROJECT_ROOT / "App" / "MotionPlaybackPlan.swift"
VIDEO_INSPECTOR = Path(os.environ.get("VIDEO_INSPECTOR", "/tmp/poch1441-transcript-player-video-inspector"))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    return ordered[max(0, math.ceil(len(ordered) * fraction) - 1)]


def near_point(lhs: dict, rhs: dict, tolerance: float = 1e-9) -> bool:
    return abs(lhs["x"] - rhs["x"]) <= tolerance and abs(lhs["y"] - rhs["y"]) <= tolerance


def probe_video(path: Path) -> dict:
    result = subprocess.run(
        [str(VIDEO_INSPECTOR), str(path)],
        check=True,
        text=True,
        capture_output=True,
    )
    return json.loads(result.stdout)


def main() -> None:
    manifest_path = EVIDENCE / "manifest.json"
    require(manifest_path.is_file(), "manifest.json fehlt")
    manifest = json.loads(manifest_path.read_text())

    source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    require(source_hash == manifest["productContractSHA256"], "Produktvertrag-SHA driftete")
    require(manifest["schemaVersion"] == 1, "falsche Evidence-Schemaversion")
    require(manifest["viewport"] == "402x874", "falscher Viewport")
    require(manifest["productContractCompiledDirectly"] is True, "Produktvertrag wurde nicht direkt kompiliert")
    require(manifest["planValid"] is True, "zertifizierter Plan ist ungültig")
    require(manifest["instantiatedPlanCount"] == 1, "Harness muss genau einen Plan instanziieren")
    require(manifest["rendererNeutralPlayer"] is True, "Player ist nicht renderer-neutral deklariert")
    require(manifest["productHooksIncluded"] is False, "Produktions-Hook ist außerhalb des Scopes")
    require(manifest["audioIncluded"] is False and manifest["hapticsIncluded"] is False,
            "Audio/Haptik sind außerhalb des Scopes")

    test_receipt_path = EVIDENCE / "test-verification.json"
    require(test_receipt_path.is_file(), "XCTest-Receipt fehlt")
    test_receipt = json.loads(test_receipt_path.read_text())
    require(test_receipt["result"] == "Passed", "XCTest-Suite ist nicht grün")
    require(test_receipt["totalTestCount"] == 7, "unerwartete XCTest-Anzahl")
    require(test_receipt["passedTests"] == 7 and test_receipt["failedTests"] == 0,
            "nicht alle sieben XCTest-Fälle sind grün")
    require(test_receipt["productContractSHA256"] == source_hash, "XCTest-Produktvertrag driftete")

    source_occurrences = sum(
        path.read_text().count("MotionPlaybackPlan(")
        for path in (ROOT / "Sources").glob("*.swift")
    )
    require(source_occurrences == 1, "Sources müssen genau eine MotionPlaybackPlan-Instanz enthalten")
    require(not (ROOT / "Sources" / "MotionPlaybackPlan.swift").exists(), "Produktvertrag darf nicht kopiert werden")
    project_spec = (ROOT / "project.yml").read_text()
    require("../../../App/MotionPlaybackPlan.swift" in project_spec, "externe Build-Quelle fehlt")

    wallclock = manifest["wallclock"]
    frames = wallclock["frames"]
    require(wallclock["requestedFramesPerSecond"] == 60, "Standard-Capture ist nicht 60 Hz")
    require(len(frames) >= 55, "Standard-Capture ist zu kurz")
    require([frame["frameIndex"] for frame in frames] == list(range(len(frames))),
            "Standard-Frameindizes sind nicht lückenlos")
    captures = [frame["captureElapsedSeconds"] for frame in frames]
    require(all(b > a for a, b in zip(captures, captures[1:])), "Wallclock lief rückwärts")
    intervals = [b - a for a, b in zip(captures, captures[1:])]
    require(abs(statistics.median(intervals) - 1 / 60) <= 0.004, "60-Hz-Median driftete")
    require(percentile(intervals, 0.95) <= 0.030, "60-Hz-p95 überschreitet 30 ms")
    require(max(intervals) <= 0.060, "Wallclock-Capture hat eine Lücke über 60 ms")
    require([event["name"] for event in wallclock["callbacks"]] == ["onContact", "onRest"],
            "Standard-Callbacks sind nicht exakt contact -> rest")

    release = wallclock["releaseElapsedSeconds"]
    contact_event, rest_event = wallclock["callbacks"]
    require(contact_event["elapsedSeconds"] + 1e-8 >= release + 0.54, "onContact kam vor Planmarker")
    require(contact_event["elapsedSeconds"] - (release + 0.54) <= 0.035, "onContact verpasste zwei Frames")
    require(rest_event["elapsedSeconds"] + 1e-8 >= release + 0.72, "onRest kam vor Ruhemarker")
    require(rest_event["elapsedSeconds"] - (release + 0.72) <= 0.035, "onRest verpasste zwei Frames")
    settling = [frame for frame in frames if frame["phase"] == "settling"]
    require(settling and all(frame["moving"] for frame in settling), "Settle zählt nicht vollständig als Bewegung")
    rested = [frame for frame in frames if frame["phase"] == "resting"]
    require(rested and all(not frame["moving"] for frame in rested), "Restzustand meldet Bewegung")

    rate_summary = []
    expected_final = manifest["reducedMotion"]["finalPosition"]
    segments = manifest["rateSegments"]
    require([segment["requestedFramesPerSecond"] for segment in segments] == [60, 80, 120],
            "60/80/120-Hz-Messsegmente fehlen")
    for segment in segments:
        hz = segment["requestedFramesPerSecond"]
        values = segment["measuredIntervalsSeconds"]
        require(len(values) >= int(hz * 0.70), f"{hz} Hz: Messsegment ist zu kurz")
        require(all(value > 0 for value in values), f"{hz} Hz: nicht-monotones Intervall")
        median = statistics.median(values)
        require(abs(median - 1 / hz) <= 0.004, f"{hz} Hz: Median driftete mehr als 4 ms")
        require(percentile(values, 0.95) <= 1 / hz + 0.012, f"{hz} Hz: p95 ist instabil")
        require(segment["callbackNames"] == ["onContact", "onRest"], f"{hz} Hz: Callbackvertrag verletzt")
        require(segment["finalPhase"] == "resting", f"{hz} Hz: kein Endzustand")
        require(near_point(segment["finalPosition"], expected_final), f"{hz} Hz: anderer Endpunkt")
        rate_summary.append({
            "requestedFramesPerSecond": hz,
            "samples": len(values),
            "medianIntervalMilliseconds": median * 1000,
            "p95IntervalMilliseconds": percentile(values, 0.95) * 1000,
            "maximumIntervalMilliseconds": max(values) * 1000,
        })

    cancellation = manifest["cancellation"]
    require(cancellation["beforeReleaseCallbackCount"] == 1, "Cancel vor Release ist nicht genau einmal")
    require(cancellation["beforeReleaseContactCount"] == 0, "Cancel vor Release lieferte Kontakt")
    require(cancellation["beforeReleaseRestCount"] == 0, "Cancel vor Release lieferte Rest")
    require(cancellation["committedCancelIgnored"] is True, "Committed Cancel wurde nicht ignoriert")
    require(cancellation["committedCallbackNames"] == ["onContact", "onRest"],
            "Committed Cancel führte den Pfad nicht vollständig fort")
    require(cancellation["committedFinalPhase"] == "resting", "Committed Cancel endet nicht in Rest")
    require(near_point(cancellation["committedFinalPosition"], expected_final), "Committed Cancel endet am falschen Ziel")

    reduced = manifest["reducedMotion"]
    require(reduced["releaseLatencySeconds"] <= 0.010, "Reduced Motion enthält versteckte Normalzeit-Wartefrist")
    require(reduced["callbackNames"] == ["onContact", "onRest"], "Reduced-Motion-Callbacks verletzt")
    require(reduced["finalPhase"] == "resting", "Reduced Motion erreicht Rest nicht synchron")

    video_path = EVIDENCE / manifest["videoFile"]
    sheet_path = EVIDENCE / manifest["contactSheetFile"]
    require(video_path.is_file() and sheet_path.is_file(), "visuelle Evidence fehlt")
    video = probe_video(video_path)
    require(video["videoTrackCount"] == 1 and video["audioTrackCount"] == 0,
            "Video muss genau eine lautlose Spur enthalten")
    require(video["width"] == 402 and video["height"] == 874, "Video hat falsche Abmessungen")
    require(video["frameCount"] == len(frames), "Video ist gegenüber Wallclock-Frames geschnitten")
    require(55 <= video["nominalFrameRate"] <= 65, "Video ist nicht nominell 60 fps")
    orientation_path = EVIDENCE / "orientation-verification.json"
    require(orientation_path.is_file(), "Dekodierter Pixel-Orientierungsbeleg fehlt")
    orientation = json.loads(orientation_path.read_text())
    require(orientation["result"] == "PASS", "Dekodierte Videoorientierung ist nicht grün")
    require(orientation["decodedOrientation"] == "upright", "Dekodiertes Video ist nicht aufrecht")

    verification = {
        "result": "PASS",
        "status": "TECHNICAL_GREEN_HUMAN_PENDING",
        "productContractSHA256": source_hash,
        "xctest": test_receipt,
        "planStableID": manifest["planStableID"],
        "instantiatedPlanCount": manifest["instantiatedPlanCount"],
        "viewport": manifest["viewport"],
        "standardWallclock": {
            "capturedFrames": len(frames),
            "medianIntervalMilliseconds": statistics.median(intervals) * 1000,
            "p95IntervalMilliseconds": percentile(intervals, 0.95) * 1000,
            "maximumIntervalMilliseconds": max(intervals) * 1000,
            "callbackNames": [event["name"] for event in wallclock["callbacks"]],
            "settleFramesCountedMoving": len(settling),
        },
        "rateSegments": rate_summary,
        "cancellation": cancellation,
        "reducedMotion": reduced,
        "video": video,
        "decodedPixelOrientation": orientation,
        "visualVerdict": "PENDING",
    }
    (EVIDENCE / "verification.json").write_text(json.dumps(verification, indent=2) + "\n")
    (EVIDENCE / "technical-verdict.json").write_text(json.dumps({
        "status": "TECHNICAL_GREEN_HUMAN_PENDING",
        "technicalResult": "GREEN",
        "humanVisualResult": "PENDING",
        "productionIntegrationAllowed": False,
    }, indent=2) + "\n")
    (EVIDENCE / "verified.complete").write_text("verified\n")
    print("TranscriptMotionPlayerV1: TECHNICAL_GREEN_HUMAN_PENDING")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"TranscriptMotionPlayerV1: FAIL - {error}", file=sys.stderr)
        raise
