#!/usr/bin/env python3
"""Builds the loopable first-run sound worlds from CC0 room recordings.

The human room and laughter recordings are inputs so the repository does not
need to retain large lossless source files. The two musical arrangements are
generated deterministically here and share the same four-note motif. The
time-noise transition layer is entirely synthetic and can be built alone.
"""

from __future__ import annotations

import argparse
import math
import wave
from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt


SAMPLE_RATE = 44_100
DURATION = 8.0
FRAME_COUNT = int(SAMPLE_RATE * DURATION)
RNG = np.random.default_rng(1_441)
TIME_NOISE_SEED = 14_410_005


def read_wav(path: Path) -> np.ndarray:
    sample_rate, samples = wavfile.read(path)
    if sample_rate != SAMPLE_RATE:
        raise ValueError(f"{path} must be {SAMPLE_RATE} Hz")
    if samples.dtype != np.int16:
        raise ValueError(f"{path} must be 16-bit PCM")
    if samples.ndim == 1:
        samples = samples[:, None]
    return samples.astype(np.float64) / 32_768.0


def segment(source: np.ndarray, start_seconds: float) -> np.ndarray:
    start = int(start_seconds * SAMPLE_RATE)
    stop = start + FRAME_COUNT
    if stop > len(source):
        raise ValueError("Source recording is too short for the requested segment")
    result = source[start:stop].copy()
    if result.shape[1] == 1:
        result = np.repeat(result, 2, axis=1)
    return result[:, :2]


def filtered(signal: np.ndarray, low: float, high: float) -> np.ndarray:
    sos = butter(3, [low, high], btype="bandpass", fs=SAMPLE_RATE, output="sos")
    return np.column_stack([sosfilt(sos, signal[:, channel]) for channel in range(2)])


def note_frequency(midi: int) -> float:
    return 440.0 * (2.0 ** ((midi - 69) / 12.0))


def pluck(frequency: float, seconds: float) -> np.ndarray:
    count = int(seconds * SAMPLE_RATE)
    period = max(2, int(SAMPLE_RATE / frequency))
    ring = RNG.uniform(-1.0, 1.0, period)
    output = np.zeros(count)
    for index in range(count):
        current = ring[index % period]
        next_index = (index + 1) % period
        ring[index % period] = 0.994 * 0.5 * (current + ring[next_index])
        output[index] = current
    return output


def electric_piano(frequency: float, seconds: float) -> np.ndarray:
    count = int(seconds * SAMPLE_RATE)
    time = np.arange(count) / SAMPLE_RATE
    envelope = np.exp(-time * 2.2) * np.minimum(1.0, time * 90.0)
    carrier = (
        np.sin(2 * math.pi * frequency * time)
        + 0.28 * np.sin(2 * math.pi * frequency * 2.01 * time + 0.3)
        + 0.10 * np.sin(2 * math.pi * frequency * 3.98 * time)
    )
    tremolo = 0.92 + 0.08 * np.sin(2 * math.pi * 4.2 * time)
    return carrier * envelope * tremolo


def add_motif(target: np.ndarray, modern: bool) -> None:
    notes = [62, 65, 69, 72]
    starts = [0.35, 1.38, 2.42, 3.45, 4.35, 5.38, 6.42, 7.15]
    for index, start_seconds in enumerate(starts):
        frequency = note_frequency(notes[index % len(notes)])
        voice = (electric_piano(frequency, 0.82) if modern else pluck(frequency, 0.72))
        start = int(start_seconds * SAMPLE_RATE)
        stop = min(FRAME_COUNT, start + len(voice))
        voice = voice[: stop - start]
        pan = 0.44 + 0.10 * ((index % 3) - 1)
        target[start:stop, 0] += voice * (1.0 - pan)
        target[start:stop, 1] += voice * pan

    if modern:
        time = np.arange(FRAME_COUNT) / SAMPLE_RATE
        bass = 0.10 * np.sin(2 * math.pi * note_frequency(38) * time)
        bass *= 0.62 + 0.38 * np.sin(math.pi * time / DURATION) ** 2
        target[:, 0] += bass
        target[:, 1] += bass
        brush = RNG.normal(0, 1, FRAME_COUNT)
        brush = sosfilt(butter(2, [2_800, 9_000], btype="bandpass", fs=SAMPLE_RATE, output="sos"), brush)
        pulse = np.zeros(FRAME_COUNT)
        for beat in np.arange(0.5, DURATION, 1.0):
            start = int(beat * SAMPLE_RATE)
            length = min(int(0.18 * SAMPLE_RATE), FRAME_COUNT - start)
            pulse[start:start + length] = np.exp(-np.arange(length) / (0.055 * SAMPLE_RATE))
        target[:, 0] += brush * pulse * 0.018
        target[:, 1] += np.roll(brush * pulse, 91) * 0.018
    else:
        drone_time = np.arange(FRAME_COUNT) / SAMPLE_RATE
        drone = 0.055 * (
            np.sin(2 * math.pi * note_frequency(50) * drone_time)
            + 0.35 * np.sin(2 * math.pi * note_frequency(57) * drone_time)
        )
        target[:, 0] += drone
        target[:, 1] += np.roll(drone, 133)


def add_laughter(target: np.ndarray, laughter: np.ndarray) -> None:
    source = segment(laughter, 10.0)
    start = int(1.15 * SAMPLE_RATE)
    length = min(len(source), FRAME_COUNT - start)
    envelope = np.ones(length)
    fade = min(int(0.5 * SAMPLE_RATE), length // 2)
    envelope[:fade] = np.linspace(0, 1, fade)
    envelope[-fade:] = np.linspace(1, 0, fade)
    target[start:start + length] += source[:length] * envelope[:, None] * 0.17


def soften_loop_edges(signal: np.ndarray) -> np.ndarray:
    fade = int(0.35 * SAMPLE_RATE)
    ramp = np.linspace(0, 1, fade)
    signal[:fade] *= ramp[:, None]
    signal[-fade:] *= ramp[::-1, None]
    return signal


def normalize(signal: np.ndarray, peak: float = 0.82) -> np.ndarray:
    maximum = float(np.max(np.abs(signal)))
    return signal if maximum == 0 else signal * (peak / maximum)


def periodic_band_noise(rng: np.random.Generator) -> np.ndarray:
    """Returns spectrally shaped noise whose final sample wraps to the first."""
    frequencies = np.fft.rfftfreq(FRAME_COUNT, 1.0 / SAMPLE_RATE)
    lower = np.clip((frequencies - 180.0) / (520.0 - 180.0), 0.0, 1.0)
    upper = np.clip((6_200.0 - frequencies) / (6_200.0 - 3_600.0), 0.0, 1.0)
    band = np.sin(lower * math.pi / 2.0) ** 2 * np.sin(upper * math.pi / 2.0) ** 2
    colour = (np.maximum(frequencies, 520.0) / 1_000.0) ** -0.32
    phases = rng.uniform(0.0, 2.0 * math.pi, len(frequencies))
    spectrum = band * colour * np.exp(1j * phases)
    spectrum[0] = 0.0
    spectrum[-1] = 0.0
    noise = np.fft.irfft(spectrum, n=FRAME_COUNT)
    rms = float(np.sqrt(np.mean(noise * noise)))
    return noise if rms == 0 else noise / rms


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
    pcm = (pcm * 32_767).astype("<i2")
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(pcm.tobytes())


def build(cafe_path: Path, laughter_path: Path, output_dir: Path) -> None:
    cafe = read_wav(cafe_path)
    laughter = read_wav(laughter_path)

    historical_room = filtered(segment(cafe, 38.0), 120, 4_800) * 0.36
    delayed = np.roll(historical_room, int(0.11 * SAMPLE_RATE), axis=0) * 0.16
    delayed[: int(0.11 * SAMPLE_RATE)] = 0
    historical_room += delayed
    add_laughter(historical_room, laughter)
    historical_motif = np.zeros((FRAME_COUNT, 2))
    add_motif(historical_motif, modern=False)

    present_room = filtered(segment(cafe, 112.0), 90, 12_000) * 0.30
    present_motif = np.zeros((FRAME_COUNT, 2))
    add_motif(present_motif, modern=True)

    outputs = {
        "first-run-origin-room.wav": historical_room,
        "first-run-origin-motif.wav": historical_motif * 0.52,
        "first-run-present-room.wav": present_room,
        "first-run-present-motif.wav": present_motif * 0.42,
    }
    for filename, signal in outputs.items():
        write_wav(output_dir / filename, normalize(soften_loop_edges(signal)))
    build_time_noise(output_dir)


def build_time_noise(output_dir: Path) -> None:
    write_wav(output_dir / "first-run-time-noise.wav", time_noise())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cafe-wav", type=Path)
    parser.add_argument("--laughter-wav", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--time-noise-only", action="store_true")
    arguments = parser.parse_args()
    if arguments.time_noise_only:
        build_time_noise(arguments.output_dir)
        return
    if arguments.cafe_wav is None or arguments.laughter_wav is None:
        parser.error(
            "--cafe-wav and --laughter-wav are required unless --time-noise-only is set"
        )
    build(arguments.cafe_wav, arguments.laughter_wav, arguments.output_dir)


if __name__ == "__main__":
    main()
