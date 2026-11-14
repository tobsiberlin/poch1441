#!/usr/bin/env python3
import json
from pathlib import Path

import cv2
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "Evidence"


def selected_indices(sequence: dict, limit: int = 24) -> list[int]:
    frame_count = len(sequence["frames"])
    if sequence["sequence"] != "cancellation":
        return [round(index * (frame_count - 1) / (limit - 1)) for index in range(limit)]

    lifecycle = sequence["lifecycle"]
    cancel = sequence["cancellationSeconds"]
    committed = [item for item in lifecycle if item["actualStartSeconds"] < cancel]
    active = [item for item in committed if item["restWindowStartSeconds"] > cancel]
    targets = [cancel - 0.10, cancel - 0.05, cancel, cancel + 0.05, cancel + 0.10]
    for item in active:
        targets.extend([
            item["contactSeconds"] - 0.025,
            item["contactSeconds"],
            item["settleSeconds"],
            item["restWindowStartSeconds"] - 0.025,
            item["restWindowStartSeconds"],
        ])
    targets.extend([sequence["cancellationClearSeconds"] + 0.05, sequence["cancellationClearSeconds"] + 0.20])
    captures = [frame["captureElapsedSeconds"] for frame in sequence["frames"]]
    indices = {
        min(range(frame_count), key=lambda index: abs(captures[index] - target))
        for target in targets
    }
    return sorted(indices)


def decode_frames(video: Path, indices: list[int]) -> list[tuple[int, Image.Image]]:
    capture = cv2.VideoCapture(str(video))
    if not capture.isOpened():
        raise RuntimeError(f"Video konnte nicht geöffnet werden: {video}")
    wanted = set(indices)
    decoded: list[tuple[int, Image.Image]] = []
    index = 0
    while True:
        ok, frame = capture.read()
        if not ok:
            break
        if index in wanted:
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            decoded.append((index, Image.fromarray(rgb)))
        index += 1
    capture.release()
    if [index for index, _ in decoded] != indices:
        raise RuntimeError(f"Nicht alle Frames dekodiert: {video}")
    return decoded


def write_strip(sequence: dict) -> None:
    indices = selected_indices(sequence)
    decoded = decode_frames(EVIDENCE / sequence["videoFile"], indices)
    columns = 6
    cell_width = 201
    cell_height = 437
    label_height = 24
    rows = (len(decoded) + columns - 1) // columns
    strip = Image.new("RGB", (columns * cell_width, rows * (cell_height + label_height)), "black")
    draw = ImageDraw.Draw(strip)
    frames = sequence["frames"]
    for position, (frame_index, image) in enumerate(decoded):
        x = position % columns * cell_width
        y = position // columns * (cell_height + label_height)
        strip.paste(image.resize((cell_width, cell_height), Image.Resampling.LANCZOS), (x, y))
        elapsed = frames[frame_index]["captureElapsedSeconds"]
        draw.text((x + 6, y + cell_height + 5), f"f{frame_index:03d}  t={elapsed:.3f}s", fill="white")
    output = EVIDENCE / f"402x874-{sequence['sequence']}-encoded-review-strip.png"
    strip.save(output, optimize=True)
    print(output)


def main() -> None:
    manifest = json.loads((EVIDENCE / "manifest.json").read_text())
    for sequence in manifest["sequences"]:
        write_strip(sequence)


if __name__ == "__main__":
    main()
