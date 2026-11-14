#!/usr/bin/env python3
"""Objective contract for the semantic Poch knuckle-on-table gesture."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import build_table_knock_audio as builder  # noqa: E402


def expect(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def decode_caf(path: Path, scratch: Path) -> tuple[np.ndarray, int, int]:
    wav = scratch / f"{path.stem}.wav"
    subprocess.run([
        "/usr/bin/afconvert", "-f", "WAVE", "-d", "LEI16@44100",
        str(path), str(wav),
    ], check=True, capture_output=True)
    with wave.open(str(wav), "rb") as handle:
        channels = handle.getnchannels()
        rate = handle.getframerate()
        frames = np.frombuffer(
            handle.readframes(handle.getnframes()), dtype="<i2"
        ).astype(np.float64).reshape(-1, channels) / 32_768.0
    return np.mean(frames, axis=1), channels, rate


def main() -> None:
    audio_source = (ROOT / "App/TableFoleyAudio.swift").read_text(encoding="utf-8")
    phase_source = (ROOT / "App/Phase2View.swift").read_text(encoding="utf-8")
    receipt = (ROOT / "App/Audio/TABLE_KNOCK_SOURCES.md").read_text(encoding="utf-8")

    for variant in range(1, 4):
        expect(f'"table-knock-{variant:02d}"' in audio_source,
               f"Runtime is missing table-knock-{variant:02d}")
    expect("func playPochGesture(" in audio_source
           and 'family: "pochGesture"' in audio_source
           and "R1ContactVariantResolver.resolve" in audio_source,
           "Poch must have a dedicated, non-repeating runtime Foley family")
    expect(".sensoryFeedback(trigger: game.pochShock)" in phase_source
           and "animatableData: CGFloat(game.pochShock)" in phase_source,
           "The existing Poch haptic and physical contact marker must remain intact")
    expect(builder.SOURCE_SHA256 in receipt
           and "CC0 1.0 Universal" in receipt,
           "The pinned real-knuckle source and license must be documented")

    with tempfile.TemporaryDirectory(prefix="poch-table-knock-test-") as directory:
        scratch = Path(directory)
        knocks: dict[str, np.ndarray] = {}
        metrics: dict[str, dict[str, float]] = {}
        expected_durations = (0.280, 0.320, 0.360)

        for variant, expected_duration in enumerate(expected_durations, start=1):
            name = f"table-knock-{variant:02d}"
            signal, channels, rate = decode_caf(
                ROOT / f"App/Audio/{name}.caf", scratch
            )
            knocks[name] = signal
            metrics[name] = builder.spectral_metrics(signal)
            expect(channels == 1, f"{name} must stay mono for runtime panning")
            expect(rate == 44_100, f"{name} must stay at 44.1 kHz")
            expect(abs(metrics[name]["duration"] - expected_duration) < 0.002,
                   f"{name} duration drifted")
            expect(0.58 <= metrics[name]["peak"] <= 0.74,
                   f"{name} peak left the phone-safe window")
            expect(0.035 <= metrics[name]["rms"] <= 0.16,
                   f"{name} loudness left the physical window")
            expect(180 <= metrics[name]["centroid"] <= 1_600,
                   f"{name} lost its wood/knuckle spectrum")
            expect(0.06 <= metrics[name]["low_ratio"] <= 0.90,
                   f"{name} table body is missing or exaggerated")
            expect(metrics[name]["tail_rms"] < metrics[name]["early_rms"] * 0.35,
                   f"{name} has an oversized reverb-like tail")

        levels = [value["rms"] for value in metrics.values()]
        centroids = [value["centroid"] for value in metrics.values()]
        expect(max(levels) / min(levels) > 1.08,
               "Poch takes need organic loudness variance")
        expect(max(centroids) - min(centroids) > 90,
               "Poch takes need organic spectral variance")
        for index, left in enumerate(knocks):
            for right in tuple(knocks)[index + 1:]:
                expect(abs(builder.normalized_correlation(
                    knocks[left], knocks[right]
                )) < 0.68, "Poch takes must not be cloned repetitions")

        references = []
        for pattern in ("card-deal-*.caf", "r1-ceramic-center-*.caf"):
            for path in sorted((ROOT / "App/Audio").glob(pattern)):
                signal, _, _ = decode_caf(path, scratch)
                references.append(builder.spectral_metrics(signal))
        expect(max(centroids) + 250 < min(item["centroid"] for item in references),
               "The Poch knock must stay spectrally distinct from cards and chips")

        rebuilt = scratch / "rebuilt"
        builder.build(rebuilt, ROOT / ".build/audio-source-cache")
        for variant in range(1, 4):
            name = f"table-knock-{variant:02d}.caf"
            expect((rebuilt / name).read_bytes()
                   == (ROOT / "App/Audio" / name).read_bytes(),
                   f"{name} rebuild must be byte-identical")

    print("TableKnockAudioTests: PASS")


if __name__ == "__main__":
    main()
