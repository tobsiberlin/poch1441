#!/usr/bin/env python3
import json
import math
from pathlib import Path

import cv2
import numpy as np


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "Evidence"
SELECTION_LIMIT = 24
MAXIMUM_UPRIGHT_MAE = 5.0
MINIMUM_WINNING_MARGIN = 2.0
ORIENTATIONS = ("upright", "verticalFlip", "horizontalFlip", "rotate180")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def selected_indices(frame_count: int) -> list[int]:
    require(frame_count >= SELECTION_LIMIT, "Zu wenige Frames für den Orientierungsvergleich")
    return [
        math.floor(index * (frame_count - 1) / (SELECTION_LIMIT - 1) + 0.5)
        for index in range(SELECTION_LIMIT)
    ]


def decode_selected(video: Path, indices: list[int]) -> dict[int, np.ndarray]:
    capture = cv2.VideoCapture(str(video))
    require(capture.isOpened(), f"Video konnte nicht dekodiert werden: {video.name}")
    wanted = set(indices)
    decoded: dict[int, np.ndarray] = {}
    frame_index = 0
    while True:
        available, frame = capture.read()
        if not available:
            break
        if frame_index in wanted:
            decoded[frame_index] = frame
        frame_index += 1
    capture.release()
    require(sorted(decoded) == indices, f"Nicht alle Vergleichsframes dekodiert: {video.name}")
    return decoded


def oriented(frame: np.ndarray) -> dict[str, np.ndarray]:
    return {
        "upright": frame,
        "verticalFlip": cv2.flip(frame, 0),
        "horizontalFlip": cv2.flip(frame, 1),
        "rotate180": cv2.flip(frame, -1),
    }


def compare_sequence(sequence: dict) -> dict:
    frames = sequence["frames"]
    indices = selected_indices(len(frames))
    video_path = EVIDENCE / sequence["videoFile"]
    sheet_path = EVIDENCE / sequence["contactSheetFile"]
    decoded = decode_selected(video_path, indices)
    sheet = cv2.imread(str(sheet_path), cv2.IMREAD_COLOR)
    require(sheet is not None, f"Kontaktbogen konnte nicht gelesen werden: {sheet_path.name}")
    require(sheet.shape[1] == 804 and sheet.shape[0] == 1166,
            f"Unerwartete Kontaktbogen-Größe: {sheet_path.name}")

    scores: dict[str, list[float]] = {name: [] for name in ORIENTATIONS}
    for position, frame_index in enumerate(indices):
        row, column = divmod(position, 6)
        x0 = column * 134
        x1 = (column + 1) * 134
        y0 = round(row * sheet.shape[0] / 4)
        y1 = round((row + 1) * sheet.shape[0] / 4)
        reference = cv2.cvtColor(sheet[y0:y1, x0:x1], cv2.COLOR_BGR2GRAY).astype(np.float32)
        downscaled = cv2.resize(
            decoded[frame_index],
            (x1 - x0, y1 - y0),
            interpolation=cv2.INTER_AREA,
        )
        for name, candidate in oriented(downscaled).items():
            grayscale = cv2.cvtColor(candidate, cv2.COLOR_BGR2GRAY).astype(np.float32)
            scores[name].append(float(np.mean(np.abs(reference - grayscale))))

    summary = {
        name: {
            "meanAbsoluteError": float(np.mean(values)),
            "p95AbsoluteError": float(np.percentile(values, 95)),
            "maximumAbsoluteError": float(np.max(values)),
        }
        for name, values in scores.items()
    }
    ordered = sorted(ORIENTATIONS, key=lambda name: summary[name]["meanAbsoluteError"])
    winner = ordered[0]
    margin = summary[ordered[1]]["meanAbsoluteError"] - summary[winner]["meanAbsoluteError"]
    require(winner == "upright", f"{sequence['sequence']}: dekodiertes Video ist {winner}")
    require(summary["upright"]["meanAbsoluteError"] <= MAXIMUM_UPRIGHT_MAE,
            f"{sequence['sequence']}: aufrechter Pixelvergleich ist zu unähnlich")
    require(margin >= MINIMUM_WINNING_MARGIN,
            f"{sequence['sequence']}: Orientierungsabstand ist nicht eindeutig")
    return {
        "sequence": sequence["sequence"],
        "videoFile": sequence["videoFile"],
        "referenceContactSheetFile": sequence["contactSheetFile"],
        "sampledFrameIndices": indices,
        "decodedOrientation": winner,
        "winningMargin": margin,
        "scores": summary,
        "result": "PASS",
    }


def main() -> None:
    manifest = json.loads((EVIDENCE / "manifest.json").read_text())
    sequence_results = [compare_sequence(sequence) for sequence in manifest["sequences"]]
    receipt = {
        "schemaVersion": 1,
        "result": "PASS",
        "comparison": "decoded H.264 frames versus pre-encode rendered contact-sheet cells",
        "sampleCountPerSequence": SELECTION_LIMIT,
        "maximumUprightMeanAbsoluteError": MAXIMUM_UPRIGHT_MAE,
        "minimumWinningMargin": MINIMUM_WINNING_MARGIN,
        "sequences": sequence_results,
    }
    (EVIDENCE / "orientation-verification.json").write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n"
    )
    print("CardDealRhythmEvidenceV4 orientation: PASS")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"CardDealRhythmEvidenceV4 orientation: FAIL - {error}")
        raise
