#!/usr/bin/env python3
"""Builds the five deterministic, loopable first-run time-swipe layers.

Every sound is synthesized locally. The crowd voices are non-verbal formant
textures, so the assets contain no samples, intelligible speech, or music.
"""

from __future__ import annotations

import argparse
import math
import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, sosfilt


SAMPLE_RATE = 44_100
DURATION = 8.0
FRAME_COUNT = int(SAMPLE_RATE * DURATION)
TIME_NOISE_SEED = 14_410_005
VOWELS = (
    (730.0, 1_090.0, 2_440.0),
    (530.0, 1_840.0, 2_480.0),
    (390.0, 1_060.0, 2_350.0),
    (300.0, 870.0, 2_240.0),
)


def bandpass(signal: np.ndarray, low: float, high: float) -> np.ndarray:
    sos = butter(3, [low, high], btype="bandpass", fs=SAMPLE_RATE, output="sos")
    return sosfilt(sos, signal)


def periodic_noise(
    rng: np.random.Generator,
    low_stop: float,
    low_pass: float,
    high_pass: float,
    high_stop: float,
    tilt: float,
) -> np.ndarray:
    frequencies = np.fft.rfftfreq(FRAME_COUNT, 1.0 / SAMPLE_RATE)
    lower = np.clip((frequencies - low_stop) / (low_pass - low_stop), 0.0, 1.0)
    upper = np.clip((high_stop - frequencies) / (high_stop - high_pass), 0.0, 1.0)
    band = np.sin(lower * math.pi / 2.0) ** 2 * np.sin(upper * math.pi / 2.0) ** 2
    colour = (np.maximum(frequencies, low_pass) / 1_000.0) ** tilt
    phases = rng.uniform(0.0, 2.0 * math.pi, len(frequencies))
    spectrum = band * colour * np.exp(1j * phases)
    spectrum[0] = 0.0
    spectrum[-1] = 0.0
    noise = np.fft.irfft(spectrum, n=FRAME_COUNT)
    rms = float(np.sqrt(np.mean(noise * noise)))
    return noise if rms == 0 else noise / rms


def add_wrapped(
    target: np.ndarray,
    signal: np.ndarray,
    start_seconds: float,
    pan: float,
    gain: float,
) -> None:
    indices = (int(start_seconds * SAMPLE_RATE) + np.arange(len(signal))) % FRAME_COUNT
    target[indices, 0] += signal * math.cos(pan * math.pi / 2.0) * gain
    target[indices, 1] += signal * math.sin(pan * math.pi / 2.0) * gain


def voice_burst(
    rng: np.random.Generator,
    seconds: float,
    fundamental: float,
    formants: tuple[float, float, float],
    glide: float = 0.0,
) -> np.ndarray:
    count = int(seconds * SAMPLE_RATE)
    position = np.arange(count) / max(count - 1, 1)
    pitch = fundamental * (
        1.0 + glide * (position - 0.5) + 0.012 * np.sin(2.0 * math.pi * 4.3 * position)
    )
    phase = 2.0 * math.pi * np.cumsum(pitch) / SAMPLE_RATE
    output = np.sin(phase) * 0.08
    for harmonic in range(2, 31):
        frequency = harmonic * fundamental
        weight = sum(
            math.exp(-0.5 * ((frequency - formant) / (115.0 + formant * 0.055)) ** 2)
            for formant in formants
        )
        output += np.sin(phase * harmonic + harmonic * 0.17) * weight / math.sqrt(harmonic)
    breath = bandpass(rng.normal(0.0, 1.0, count), 900.0, 4_800.0)
    output += breath * 0.08
    output /= max(float(np.max(np.abs(output))), 1e-9)
    envelope = np.sin(math.pi * position) ** 1.35
    return output * envelope


def transient(
    rng: np.random.Generator,
    seconds: float,
    frequency: float,
    brightness: float,
) -> np.ndarray:
    count = int(seconds * SAMPLE_RATE)
    time = np.arange(count) / SAMPLE_RATE
    attack = np.minimum(1.0, time * 380.0)
    envelope = attack * np.exp(-time / max(seconds * 0.22, 0.012))
    ring = (
        np.sin(2.0 * math.pi * frequency * time)
        + 0.46 * np.sin(2.0 * math.pi * frequency * 1.47 * time + 0.4)
        + 0.18 * np.sin(2.0 * math.pi * frequency * 2.13 * time + 1.1)
    )
    noise = bandpass(rng.normal(0.0, 1.0, count), 650.0, min(11_000.0, brightness))
    return (ring * 0.62 + noise * 0.20) * envelope


def master(
    signal: np.ndarray,
    target_rms: float,
    peak_limit: float,
    saturation: float = 0.0,
) -> np.ndarray:
    signal -= np.mean(signal, axis=0, keepdims=True)
    if saturation > 0:
        raw_peak = max(float(np.max(np.abs(signal))), 1e-9)
        signal = np.tanh(signal * (saturation / raw_peak))
        signal -= np.mean(signal, axis=0, keepdims=True)
    rms = float(np.sqrt(np.mean(signal * signal)))
    if rms > 0:
        signal *= target_rms / rms
    peak = float(np.max(np.abs(signal)))
    if peak > peak_limit:
        signal *= peak_limit / peak
    return signal


def historical_room() -> np.ndarray:
    rng = np.random.default_rng(14_410_101)
    centre = periodic_noise(rng, 55.0, 120.0, 4_200.0, 5_600.0, -0.48)
    side = periodic_noise(rng, 90.0, 220.0, 3_600.0, 5_000.0, -0.22)
    room = np.column_stack([centre * 0.94 + side * 0.25, centre * 0.94 - side * 0.25]) * 0.038
    crowd = np.zeros((FRAME_COUNT, 2))

    for _ in range(42):
        start = rng.uniform(0.0, DURATION)
        duration = rng.uniform(0.22, 0.72)
        voice = voice_burst(
            rng,
            duration,
            rng.uniform(92.0, 215.0),
            VOWELS[int(rng.integers(0, len(VOWELS)))],
            rng.uniform(-0.12, 0.12),
        )
        add_wrapped(crowd, voice, start, rng.uniform(0.04, 0.96), rng.uniform(0.045, 0.10))

    for cheer_start in (0.85, 4.72):
        for _ in range(7):
            voice = voice_burst(
                rng,
                rng.uniform(0.72, 1.28),
                rng.uniform(105.0, 195.0),
                VOWELS[int(rng.integers(0, 2))],
                rng.uniform(0.28, 0.58),
            )
            add_wrapped(
                crowd,
                voice,
                cheer_start + rng.uniform(-0.16, 0.20),
                rng.uniform(0.06, 0.94),
                rng.uniform(0.095, 0.16),
            )

    for laugh_start in (2.28, 6.15):
        for person in range(4):
            base = laugh_start + rng.uniform(-0.12, 0.16)
            for pulse in range(int(rng.integers(3, 6))):
                voice = voice_burst(
                    rng,
                    rng.uniform(0.11, 0.18),
                    rng.uniform(125.0, 235.0),
                    VOWELS[0],
                    rng.uniform(-0.08, 0.16),
                )
                add_wrapped(
                    crowd,
                    voice,
                    base + pulse * rng.uniform(0.15, 0.22),
                    0.18 + person * 0.20,
                    rng.uniform(0.07, 0.12),
                )

    room += crowd
    room += np.roll(crowd, int(0.073 * SAMPLE_RATE), axis=0) * 0.22
    room += np.roll(crowd[:, ::-1], int(0.137 * SAMPLE_RATE), axis=0) * 0.14
    return master(room, target_rms=0.14, peak_limit=0.78, saturation=1.45)


def present_room() -> np.ndarray:
    rng = np.random.default_rng(14_410_202)
    centre = periodic_noise(rng, 45.0, 90.0, 5_800.0, 7_800.0, -0.62)
    side = periodic_noise(rng, 140.0, 300.0, 6_200.0, 8_400.0, -0.28)
    room = np.column_stack([centre * 0.96 + side * 0.12, centre * 0.96 - side * 0.12]) * 0.022
    group = np.zeros((FRAME_COUNT, 2))

    for _ in range(18):
        voice = voice_burst(
            rng,
            rng.uniform(0.25, 0.64),
            rng.uniform(105.0, 205.0),
            VOWELS[int(rng.integers(0, len(VOWELS)))],
            rng.uniform(-0.08, 0.08),
        )
        add_wrapped(
            group,
            voice,
            rng.uniform(0.0, DURATION),
            rng.uniform(0.12, 0.88),
            rng.uniform(0.025, 0.055),
        )

    for pulse in range(4):
        voice = voice_burst(rng, 0.15, 165.0 + pulse * 8.0, VOWELS[0], -0.04)
        add_wrapped(group, voice, 5.05 + pulse * 0.19, 0.72, 0.044)

    room += group
    room += np.roll(group[:, ::-1], int(0.031 * SAMPLE_RATE), axis=0) * 0.10
    return master(room, target_rms=0.10, peak_limit=0.72)


def historical_details() -> np.ndarray:
    rng = np.random.default_rng(14_410_303)
    details = np.zeros((FRAME_COUNT, 2))
    for start, pan, frequency in (
        (0.46, 0.18, 1_480.0),
        (1.92, 0.74, 920.0),
        (3.34, 0.42, 1_210.0),
        (5.54, 0.82, 1_670.0),
        (7.18, 0.28, 1_030.0),
    ):
        add_wrapped(details, transient(rng, 0.34, frequency, 7_200.0), start, pan, 0.38)
    add_wrapped(details, transient(rng, 0.48, 118.0, 2_200.0), 4.08, 0.52, 0.45)
    return master(details, target_rms=0.028, peak_limit=0.72)


def present_details() -> np.ndarray:
    rng = np.random.default_rng(14_410_404)
    details = np.zeros((FRAME_COUNT, 2))
    for start, pan in ((0.72, 0.68), (2.55, 0.24), (4.40, 0.58), (6.72, 0.38)):
        count = int(0.24 * SAMPLE_RATE)
        time = np.arange(count) / SAMPLE_RATE
        envelope = np.sin(math.pi * np.arange(count) / max(count - 1, 1)) ** 2
        shuffle = bandpass(rng.normal(0.0, 1.0, count), 1_100.0, 8_200.0)
        add_wrapped(details, shuffle * envelope, start, pan, 0.07)
    for start, pan, frequency in ((1.48, 0.80, 760.0), (5.76, 0.31, 680.0)):
        add_wrapped(details, transient(rng, 0.28, frequency, 6_400.0), start, pan, 0.24)
    return master(details, target_rms=0.023, peak_limit=0.64)


def normalize(signal: np.ndarray, peak: float = 0.82) -> np.ndarray:
    maximum = float(np.max(np.abs(signal)))
    return signal if maximum == 0 else signal * (peak / maximum)


def periodic_band_noise(rng: np.random.Generator) -> np.ndarray:
    """Returns spectrally shaped noise whose final sample wraps to the first."""
    return periodic_noise(rng, 180.0, 520.0, 3_600.0, 6_200.0, -0.32)


def periodic_tonal_texture(rng: np.random.Generator) -> np.ndarray:
    """Returns a quiet, pitchable resonance without a wall-clock gesture."""
    frequencies = np.fft.rfftfreq(FRAME_COUNT, 1.0 / SAMPLE_RATE)
    profile = np.exp(-0.5 * ((frequencies - 760.0) / 18.0) ** 2)
    profile[np.abs(frequencies - 760.0) > 54.0] = 0.0
    phases = rng.uniform(0.0, 2.0 * math.pi, len(frequencies))
    spectrum = profile * np.exp(1j * phases)
    spectrum[0] = 0.0
    spectrum[-1] = 0.0
    texture = np.fft.irfft(spectrum, n=FRAME_COUNT)
    rms = float(np.sqrt(np.mean(texture * texture)))
    return texture if rms == 0 else texture / rms


def time_noise() -> np.ndarray:
    """Builds subtle noise plus a continuous rate-pitchable tonal texture."""
    rng = np.random.default_rng(TIME_NOISE_SEED)
    centre = periodic_band_noise(rng)
    side = periodic_band_noise(rng)
    result = np.column_stack(
        [centre * 0.93 + side * 0.20, centre * 0.93 - side * 0.20]
    ) * 0.045

    resonance = periodic_tonal_texture(rng) * 0.007
    result[:, 0] += resonance * 0.72
    result[:, 1] += np.roll(resonance, 17) * 0.69
    result -= np.mean(result, axis=0, keepdims=True)
    return normalize(result, peak=0.32)


def write_wav(path: Path, signal: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.clip(signal, -1, 1)
    pcm = np.rint(pcm * 32_767).astype("<i2")
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(pcm.tobytes())


def build(output_dir: Path) -> None:
    outputs = {
        "first-run-origin-room.wav": historical_room(),
        "first-run-origin-motif.wav": historical_details(),
        "first-run-present-room.wav": present_room(),
        "first-run-present-motif.wav": present_details(),
        "first-run-time-noise.wav": time_noise(),
    }
    for filename, signal in outputs.items():
        write_wav(output_dir / filename, signal)


def build_time_noise(output_dir: Path) -> None:
    write_wav(output_dir / "first-run-time-noise.wav", time_noise())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--time-noise-only", action="store_true")
    arguments = parser.parse_args()
    if arguments.time_noise_only:
        build_time_noise(arguments.output_dir)
        return
    build(arguments.output_dir)


if __name__ == "__main__":
    main()
