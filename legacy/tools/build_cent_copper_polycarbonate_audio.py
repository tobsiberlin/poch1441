#!/usr/bin/env python3
"""Build and audit the deterministic 96 kHz cent/polycarbonate contact PCM."""

from __future__ import annotations

import hashlib
import json
import math
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "App/Audio/cent-copper-polycarbonate-01.wav"
RECEIPT = ROOT / "tasks/reviews/transcript-coin-feedback-stage4/Evidence/audio-fingerprint-receipt.json"
RATE = 96_000
DURATION = 0.18


def envelope(time: np.ndarray, attack: float, decay: float) -> np.ndarray:
    return np.minimum(time / attack, 1.0) * np.exp(-time / decay)


def synthesize() -> np.ndarray:
    count = int(RATE * DURATION)
    time = np.arange(count, dtype=np.float64) / RATE
    rng = np.random.default_rng(1_441)

    polycarbonate = (
        0.34 * np.sin(2 * np.pi * 1_180 * time + 0.15)
        + 0.22 * np.sin(2 * np.pi * 2_060 * time + 1.10)
    ) * envelope(time, 0.00018, 0.018)
    copper = (
        0.30 * np.sin(2 * np.pi * 4_760 * time + 0.40)
        + 0.21 * np.sin(2 * np.pi * 7_320 * time + 1.85)
        + 0.12 * np.sin(2 * np.pi * 11_240 * time + 0.70)
    ) * envelope(time, 0.00012, 0.052)

    noise = rng.normal(0, 1, count)
    high_passed = np.empty_like(noise)
    previous = 0.0
    for index, value in enumerate(noise):
        high_passed[index] = value - previous * 0.94
        previous = value
    texture = 0.025 * high_passed * envelope(time, 0.00008, 0.009)

    signal = polycarbonate + copper + texture
    signal -= float(np.mean(signal))
    signal *= 0.86 / float(np.max(np.abs(signal)))
    fade_start = int(RATE * 0.155)
    signal[fade_start:] *= np.linspace(1, 0, count - fade_start)
    return signal


def write_pcm(signal: np.ndarray) -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.round(np.clip(signal, -1, 1) * 32_767).astype("<i2")
    with wave.open(str(OUTPUT), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())


def read_wave(path: Path) -> tuple[int, np.ndarray]:
    with wave.open(str(path), "rb") as source:
        rate = source.getframerate()
        channels = source.getnchannels()
        width = source.getsampwidth()
        frames = source.readframes(source.getnframes())
    if width != 2:
        raise RuntimeError(f"unsupported PCM width for {path}: {width}")
    samples = np.frombuffer(frames, dtype="<i2").astype(np.float64) / 32_768
    if channels > 1:
        samples = samples.reshape(-1, channels).mean(axis=1)
    return rate, samples


def spectral_signature(rate: int, signal: np.ndarray) -> np.ndarray:
    window_count = min(len(signal), int(rate * 0.12))
    window = signal[:window_count] * np.hanning(window_count)
    spectrum = np.abs(np.fft.rfft(window)) + 1e-12
    frequencies = np.fft.rfftfreq(window_count, 1 / rate)
    edges = np.geomspace(180, min(rate / 2, 20_000), 25)
    bands = []
    for lower, upper in zip(edges[:-1], edges[1:]):
        mask = (frequencies >= lower) & (frequencies < upper)
        bands.append(float(np.mean(spectrum[mask])) if np.any(mask) else 1e-12)
    signature = 20 * np.log10(np.asarray(bands) / max(bands))
    return signature


def ceramic_distances(target_rate: int, target: np.ndarray) -> dict[str, float]:
    target_signature = spectral_signature(target_rate, target)
    distances: dict[str, float] = {}
    with tempfile.TemporaryDirectory(prefix="poch-cent-audio-") as directory:
        temporary = Path(directory)
        for source in sorted((ROOT / "App/Audio").glob("r1-ceramic-*.caf")):
            converted = temporary / f"{source.stem}.wav"
            subprocess.run([
                "/usr/bin/afconvert", "-f", "WAVE", "-d", "LEI16@96000",
                str(source), str(converted),
            ], check=True, capture_output=True)
            rate, samples = read_wave(converted)
            signature = spectral_signature(rate, samples)
            distances[source.name] = float(np.sqrt(np.mean((target_signature - signature) ** 2)))
    return distances


def main() -> None:
    signal = synthesize()
    write_pcm(signal)
    rate, decoded = read_wave(OUTPUT)
    absolute = np.abs(decoded)
    peak_index = int(np.argmax(absolute))
    peak = float(absolute[peak_index])
    rms = float(np.sqrt(np.mean(decoded * decoded)))
    dc = float(np.mean(decoded))
    onset_candidates = np.flatnonzero(absolute >= peak * 0.10)
    onset_index = int(onset_candidates[0]) if len(onset_candidates) else -1
    early_rms = float(np.sqrt(np.mean(decoded[: int(rate * 0.030)] ** 2)))
    tail_rms = float(np.sqrt(np.mean(decoded[int(rate * 0.120):] ** 2)))
    distances = ceramic_distances(rate, decoded)

    receipt = {
        "schema": "poch.contact-audio-fingerprint.v1",
        "asset": str(OUTPUT.relative_to(ROOT)),
        "sha256": hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
        "provenance": "deterministic additive modal synthesis; seed 1441",
        "format": {"sampleRateHertz": rate, "channels": 1, "pcmBits": 16},
        "durationSeconds": len(decoded) / rate,
        "peakAmplitude": peak,
        "peakIndex": peak_index,
        "rmsAmplitude": rms,
        "dcOffset": dc,
        "onsetSecondsAt10PercentPeak": onset_index / rate,
        "earlyRMS0To30ms": early_rms,
        "tailRMS120To180ms": tail_rms,
        "clippedSampleCount": int(np.count_nonzero(absolute >= 0.999)),
        "spectralRMSEDifferenceDecibelsVsCeramic": distances,
        "minimumSpectralRMSEDifferenceDecibels": min(distances.values()),
        "technicalVerdict": "GREEN" if (
            rate == RATE
            and peak <= 0.90
            and abs(dc) < 0.0001
            and onset_index / rate <= 0.0005
            and tail_rms < early_rms * 0.2
            and not np.any(absolute >= 0.999)
            and min(distances.values()) >= 5.0
        ) else "RED",
        "humanSpeakerVerdict": "PENDING",
    }
    RECEIPT.parent.mkdir(parents=True, exist_ok=True)
    RECEIPT.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(receipt, indent=2, sort_keys=True))
    if receipt["technicalVerdict"] != "GREEN":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
