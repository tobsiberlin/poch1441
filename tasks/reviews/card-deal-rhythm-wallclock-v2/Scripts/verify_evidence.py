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
EVIDENCE = ROOT / "Evidence"
SOURCE_CONTRACT = ROOT.parent / "card-deal-rhythm-contract-v1" / "DealRhythmContract.swift"
VIDEO_INSPECTOR = Path(os.environ.get("VIDEO_INSPECTOR", ROOT / ".video-inspector"))
VERIFICATION = {"sequences": []}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def probe_video(path: Path) -> dict:
    result = subprocess.run(
        [str(VIDEO_INSPECTOR), str(path)],
        check=True,
        text=True,
        capture_output=True,
    )
    return json.loads(result.stdout)


def percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    rank = max(1, math.ceil(len(ordered) * fraction))
    return ordered[rank - 1]


def validate_sequence(record: dict) -> None:
    name = record["sequence"]
    frames = record["frames"]
    lifecycle = record["lifecycle"]
    require(record["captureFramesPerSecond"] == 60, f"{name}: capture is not 60 fps")
    require(record["uncut"] is True, f"{name}: sequence is not marked uncut")
    require(len(frames) > 20, f"{name}: too few capture frames")
    require(
        [frame["frameIndex"] for frame in frames] == list(range(len(frames))),
        f"{name}: frame indices are not continuous",
    )
    require(
        all(frame["activeCount"] <= 2 for frame in frames),
        f"{name}: a capture frame contains a third moving card",
    )
    require(record["maximumActiveCards"] <= 2, f"{name}: max active exceeds two")
    require(record["maximumActiveCardsAtPeel"] <= 2, f"{name}: third card appears at peel")

    captures = [frame["captureElapsedSeconds"] for frame in frames]
    require(all(b > a for a, b in zip(captures, captures[1:])), f"{name}: capture time reversed")
    intervals = [b - a for a, b in zip(captures, captures[1:])]
    require(abs(statistics.median(intervals) - 1 / 60) <= 0.004, f"{name}: median capture cadence drifted")
    require(percentile(intervals, 0.95) <= 0.026, f"{name}: p95 capture interval exceeds 26 ms")
    require(max(intervals) <= 0.050, f"{name}: uncut capture contains a gap over 50 ms")

    phases = [item["rhythmPhase"] for item in lifecycle]
    require(
        phases == [
            "tension", "tension", "acceleration", "acceleration",
            "acceleration", "acceleration", "recovery", "release",
        ],
        f"{name}: pulse arc is not readable in lifecycle",
    )
    for index, item in enumerate(lifecycle):
        required_start = item["rhythmTargetSeconds"]
        if index >= 2:
            required_start = max(required_start, lifecycle[index - 2]["restWindowStartSeconds"])
        require(
            abs(item["actualStartSeconds"] - required_start) <= 1e-8,
            f"{name}: card {index} violates V1 start gate",
        )
        require(
            item["actualStartSeconds"] < item["contactSeconds"]
            < item["settleSeconds"] < item["restWindowStartSeconds"],
            f"{name}: card {index} lifecycle order is invalid",
        )
        if index >= 2:
            routes = [lifecycle[index - offset]["routeClass"] for offset in range(3)]
            contacts = [lifecycle[index - offset]["contactClass"] for offset in range(3)]
            require(len(set(routes)) > 1, f"{name}: three identical routes")
            require(len(set(contacts)) > 1, f"{name}: three identical contacts")

    if name in {"standard", "reducedMotion"}:
        require(len(lifecycle) == 8, f"{name}: expected eight cards")
        for index, item in enumerate(lifecycle):
            for field, planned in [
                ("capturedStartSeconds", item["actualStartSeconds"]),
                ("capturedContactSeconds", item["contactSeconds"]),
                ("capturedSettleSeconds", item["settleSeconds"]),
                ("capturedRestSeconds", item["restWindowStartSeconds"]),
            ]:
                captured = item[field]
                require(captured is not None, f"{name}: card {index} missing {field}")
                require(captured + 1e-8 >= planned, f"{name}: card {index} {field} predates plan")
                require(captured - planned <= 0.034, f"{name}: card {index} {field} missed two frames")

    if name == "reducedMotion":
        require(record["invisibleWaitSeconds"] <= 1e-8, "Reduced Motion contains invisible wait")

    if name == "cancellation":
        cancel = record["cancellationSeconds"]
        clear = record["cancellationClearSeconds"]
        require(cancel is not None and clear is not None, "Cancellation timing missing")
        post_cancel_peels = [
            card
            for frame in frames
            if frame["captureElapsedSeconds"] >= cancel
            for card in frame["peeledCardIndices"]
        ]
        require(not post_cancel_peels, "A new card peeled after cancellation")
        post_clear = [frame for frame in frames if frame["captureElapsedSeconds"] >= clear]
        require(post_clear and all(frame["activeCount"] == 0 for frame in post_clear),
                "Moving cards did not clear after cancellation")

    video = EVIDENCE / record["videoFile"]
    timeline = EVIDENCE / record["timelineFile"]
    sheet = EVIDENCE / record["contactSheetFile"]
    require(video.is_file() and timeline.is_file() and sheet.is_file(), f"{name}: evidence file missing")
    probe = probe_video(video)
    require(probe["videoTrackCount"] == 1 and probe["audioTrackCount"] == 0,
            f"{name}: expected one silent video track")
    require(probe["width"] == 402 and probe["height"] == 874, f"{name}: wrong video viewport")
    require(probe["frameCount"] == len(frames), f"{name}: video frame count is cut")
    require(55 <= probe["nominalFrameRate"] <= 65, f"{name}: video is not nominally 60 fps")

    VERIFICATION["sequences"].append({
        "sequence": name,
        "capturedFrames": len(frames),
        "videoFrames": probe["frameCount"],
        "videoDurationSeconds": probe["durationSeconds"],
        "nominalFrameRate": probe["nominalFrameRate"],
        "medianCaptureIntervalMilliseconds": statistics.median(intervals) * 1_000,
        "p95CaptureIntervalMilliseconds": percentile(intervals, 0.95) * 1_000,
        "maximumCaptureIntervalMilliseconds": max(intervals) * 1_000,
        "maximumActiveCards": record["maximumActiveCards"],
        "maximumActiveCardsAtPeel": record["maximumActiveCardsAtPeel"],
        "invisibleWaitSeconds": record["invisibleWaitSeconds"],
    })


def main() -> None:
    manifest_path = EVIDENCE / "manifest.json"
    require(manifest_path.is_file(), "manifest.json missing")
    manifest = json.loads(manifest_path.read_text())
    source_hash = hashlib.sha256(SOURCE_CONTRACT.read_bytes()).hexdigest()
    require(manifest["sourceContractSHA256"] == source_hash, "V1 source provenance mismatch")
    require(manifest["viewport"] == "402x874", "manifest viewport mismatch")
    require(manifest["syntheticProgressUsed"] is False, "synthetic progress is forbidden")
    require(manifest["productAudioIncluded"] is False, "product audio is out of scope")
    require(manifest["materialApprovalClaimed"] is False, "W2 body must not imply material approval")
    sequences = manifest["sequences"]
    require([item["sequence"] for item in sequences] == ["standard", "reducedMotion", "cancellation"],
            "standard, Reduced Motion and cancellation evidence must be separate")
    for sequence in sequences:
        validate_sequence(sequence)
    VERIFICATION.update({
        "result": "PASS",
        "sourceContractSHA256": source_hash,
        "viewport": manifest["viewport"],
        "syntheticProgressUsed": manifest["syntheticProgressUsed"],
        "productAudioIncluded": manifest["productAudioIncluded"],
        "materialApprovalClaimed": manifest["materialApprovalClaimed"],
    })
    (EVIDENCE / "verification.json").write_text(json.dumps(VERIFICATION, indent=2) + "\n")
    (EVIDENCE / "verified.complete").write_text("verified\n")
    print("CardDealRhythmEvidenceV2: PASS")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"CardDealRhythmEvidenceV2: FAIL - {error}", file=sys.stderr)
        raise
