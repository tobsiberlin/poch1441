#!/usr/bin/env python3
import json
import math
import sys
from pathlib import Path

import cv2
import numpy as np


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "Evidence"
SAMPLE_COUNT = 18
MAXIMUM_UPRIGHT_MAE = 5.0
MINIMUM_WINNING_MARGIN = 2.0
ORIENTATIONS = ("upright", "verticalFlip", "horizontalFlip", "rotate180")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def selected_indices(frame_count: int) -> list[int]:
    require(frame_count >= SAMPLE_COUNT, "Zu wenige Frames für den Orientierungsvergleich")
    return [
        math.floor(index * (frame_count - 1) / (SAMPLE_COUNT - 1) + 0.5)
        for index in range(SAMPLE_COUNT)
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
    require(sorted(decoded) == indices, "Nicht alle Vergleichsframes wurden dekodiert")
    return decoded


def oriented(frame: np.ndarray) -> dict[str, np.ndarray]:
    return {
        "upright": frame,
        "verticalFlip": cv2.flip(frame, 0),
        "horizontalFlip": cv2.flip(frame, 1),
        "rotate180": cv2.flip(frame, -1),
    }


def main() -> None:
    manifest = json.loads((EVIDENCE / "manifest.json").read_text())
    frames = manifest["wallclock"]["frames"]
    indices = selected_indices(len(frames))
    decoded = decode_selected(EVIDENCE / manifest["videoFile"], indices)
    sheet_path = EVIDENCE / manifest["contactSheetFile"]
    sheet = cv2.imread(str(sheet_path), cv2.IMREAD_COLOR)
    require(sheet is not None, "Contact Sheet konnte nicht gelesen werden")
    require(sheet.shape[1] == 804 and sheet.shape[0] == 873,
            f"Unerwartete Contact-Sheet-Größe: {sheet.shape[1]}x{sheet.shape[0]}")

    scores: dict[str, list[float]] = {name: [] for name in ORIENTATIONS}
    cell_width = 134
    cell_height = 291
    for position, frame_index in enumerate(indices):
        row, column = divmod(position, 6)
        reference = cv2.cvtColor(
            sheet[
                row * cell_height:(row + 1) * cell_height,
                column * cell_width:(column + 1) * cell_width,
            ],
            cv2.COLOR_BGR2GRAY,
        ).astype(np.float32)
        downscaled = cv2.resize(
            decoded[frame_index],
            (cell_width, cell_height),
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
    require(winner == "upright", f"Dekodiertes Video ist {winner}")
    require(summary["upright"]["meanAbsoluteError"] <= MAXIMUM_UPRIGHT_MAE,
            "Aufrechter Pixelvergleich ist zu unähnlich")
    require(margin >= MINIMUM_WINNING_MARGIN, "Orientierungsabstand ist nicht eindeutig")

    receipt = {
        "schemaVersion": 1,
        "result": "PASS",
        "comparison": "18 decoded H.264 frames versus frame-matched pre-encode contact-sheet cells",
        "sampledFrameIndices": indices,
        "decodedOrientation": winner,
        "winningMargin": margin,
        "maximumUprightMeanAbsoluteError": MAXIMUM_UPRIGHT_MAE,
        "minimumWinningMargin": MINIMUM_WINNING_MARGIN,
        "scores": summary,
    }
    (EVIDENCE / "orientation-verification.json").write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n"
    )
    print("TranscriptMotionPlayerV1 orientation: PASS")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"TranscriptMotionPlayerV1 orientation: FAIL - {error}", file=sys.stderr)
        raise
