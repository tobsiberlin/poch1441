#!/usr/bin/env python3
"""Build three short, physical Poch table-knock gestures from real CC0 Foley."""

from __future__ import annotations

import argparse
import hashlib
import math
import subprocess
import tempfile
import urllib.request
import wave
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from scipy.signal import butter, sosfiltfilt


ROOT = Path(__file__).resolve().parents[1]
RATE = 44_100
SOURCE_URL = "https://cdn.freesound.org/previews/425/425780_7179420-hq.mp3"
SOURCE_SHA256 = "407f38d7a7de938935f0b8cd08f187f139158a9151ad50ce9c99055caddfe85d"


@dataclass(frozen=True)
class KnockSpec:
    variant: int
    source_start: float
    duration: float
    peak: float
    high_cut: float
    body_modes: tuple[float, float, float]
    body_gain: float
    decay: float

    @property
    def name(self) -> str:
        return f"table-knock-{self.variant:02d}"


# Three separately performed knuckle contacts from the pinned recording. Tone
# variance comes from the real takes and slightly different table-body modes,
# never from playback-rate or pitch shifting.
SPECS = (
    KnockSpec(1, 2.203, 0.280, 0.64, 7_200.0,
              (116.0, 184.0, 273.0), 0.105, 0.070),
    KnockSpec(2, 5.558, 0.320, 0.69, 6_400.0,
              (123.0, 197.0, 286.0), 0.120, 0.078),
    KnockSpec(3, 9.484, 0.360, 0.66, 7_700.0,
              (109.0, 176.0, 257.0), 0.112, 0.084),
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pinned_source(cache_dir: Path) -> Path:
    cache_dir.mkdir(parents=True, exist_ok=True)
    target = cache_dir / f"{SOURCE_SHA256}.mp3"
    if not target.exists():
        request = urllib.request.Request(
            SOURCE_URL,
            headers={"User-Agent": "Poch1441TableKnockBuilder/1"},
        )
        with urllib.request.urlopen(request, timeout=120) as response:
            target.write_bytes(response.read())
    actual = sha256(target)
    if actual != SOURCE_SHA256:
        raise RuntimeError(f"Unexpected table-knock source fingerprint: {actual}")
    return target


def decode_mono(source: Path, directory: Path) -> np.ndarray:
    decoded = directory / "table-knock-source.wav"
    subprocess.run([
        "/usr/bin/afconvert", "-f", "WAVE", "-d", f"LEI16@{RATE}",
        str(source), str(decoded),
    ], check=True, capture_output=True)
    with wave.open(str(decoded), "rb") as handle:
        channels = handle.getnchannels()
        frames = np.frombuffer(
            handle.readframes(handle.getnframes()), dtype="<i2"
        ).astype(np.float64).reshape(-1, channels) / 32_768.0
    return np.mean(frames, axis=1)


def table_body(spec: KnockSpec, count: int) -> np.ndarray:
    time = np.arange(count, dtype=np.float64) / RATE
    attack = np.minimum(1.0, time / 0.0025)
    body = np.zeros(count, dtype=np.float64)
    for index, frequency in enumerate(spec.body_modes):
        amplitude = (1.0, 0.52, 0.27)[index]
        body += amplitude * np.sin(2 * math.pi * frequency * time + index * 0.37)
    body *= attack * np.exp(-time / spec.decay) * spec.body_gain
    return body


def build_knock(source: np.ndarray, spec: KnockSpec) -> np.ndarray:
    start = int(round(spec.source_start * RATE))
    count = int(round(spec.duration * RATE))
    dry = source[start:start + count].copy()
    if len(dry) != count:
        raise RuntimeError(f"Invalid source crop for {spec.name}")
    dry -= float(np.mean(dry))
    band = butter(3, [95.0, spec.high_cut], btype="bandpass",
                  fs=RATE, output="sos")
    dry = sosfiltfilt(band, dry)
    dry_peak = float(np.max(np.abs(dry)))
    if dry_peak < 0.01:
        raise RuntimeError(f"Silent knuckle crop for {spec.name}")
    dry /= dry_peak

    # Two sub-audible early reflections give the knock a small real room, not a
    # reverb tail. Their total gain stays below -24 dB relative to the dry hit.
    reflections = np.zeros(count, dtype=np.float64)
    for delay_seconds, gain in ((0.021, 0.043), (0.039, 0.022)):
        delay = int(round(delay_seconds * RATE))
        reflections[delay:] += dry[:-delay] * gain

    signal = dry * 0.70 + table_body(spec, count) + reflections
    fade_in = max(8, int(round(0.0015 * RATE)))
    fade_out = max(32, int(round(0.045 * RATE)))
    signal[:fade_in] *= np.linspace(0.0, 1.0, fade_in)
    signal[-fade_out:] *= np.linspace(1.0, 0.0, fade_out)
    signal -= float(np.mean(signal))
    maximum = float(np.max(np.abs(signal)))
    signal *= spec.peak / maximum
    signal[0] = 0
    signal[-1] = 0
    return signal


def spectral_metrics(signal: np.ndarray) -> dict[str, float]:
    windowed = signal * np.hanning(len(signal))
    spectrum = np.abs(np.fft.rfft(windowed)) ** 2 + 1e-15
    frequencies = np.fft.rfftfreq(len(signal), 1 / RATE)
    total = float(np.sum(spectrum))
    centroid = float(np.sum(frequencies * spectrum) / total)
    low_ratio = float(np.sum(spectrum[frequencies < 350.0]) / total)
    early = signal[:int(round(0.050 * RATE))]
    tail = signal[-int(round(0.050 * RATE)):]
    return {
        "duration": len(signal) / RATE,
        "peak": float(np.max(np.abs(signal))),
        "rms": float(np.sqrt(np.mean(signal * signal))),
        "centroid": centroid,
        "low_ratio": low_ratio,
        "early_rms": float(np.sqrt(np.mean(early * early))),
        "tail_rms": float(np.sqrt(np.mean(tail * tail))),
    }


def normalized_correlation(lhs: np.ndarray, rhs: np.ndarray) -> float:
    count = min(len(lhs), len(rhs))
    denominator = float(np.linalg.norm(lhs[:count]) * np.linalg.norm(rhs[:count]))
    return 0.0 if denominator == 0 else float(np.dot(lhs[:count], rhs[:count]) / denominator)


def validate(knocks: dict[str, np.ndarray]) -> None:
    metrics = {name: spectral_metrics(signal) for name, signal in knocks.items()}
    levels = [value["rms"] for value in metrics.values()]
    centroids = [value["centroid"] for value in metrics.values()]
    correlations = [
        abs(normalized_correlation(knocks[left], knocks[right]))
        for index, left in enumerate(knocks)
        for right in tuple(knocks)[index + 1:]
    ]
    for name, value in metrics.items():
        if not 0.26 <= value["duration"] <= 0.38:
            raise RuntimeError(f"{name} duration is not a short table gesture")
        if not 0.58 <= value["peak"] <= 0.74:
            raise RuntimeError(f"{name} peak is outside the phone-safe window")
        if not 0.035 <= value["rms"] <= 0.16:
            raise RuntimeError(f"{name} loudness is outside the physical window")
        if not 180.0 <= value["centroid"] <= 1_600.0:
            raise RuntimeError(f"{name} does not read as wood/knuckle contact")
        if not 0.06 <= value["low_ratio"] <= 0.90:
            raise RuntimeError(f"{name} table body is missing or exaggerated")
        if value["tail_rms"] >= value["early_rms"] * 0.35:
            raise RuntimeError(f"{name} has an oversized room tail")
        print(
            f"{name}: duration={value['duration']:.3f}s "
            f"peak={value['peak']:.3f} rms={value['rms']:.4f} "
            f"centroid={value['centroid']:.0f}Hz low={value['low_ratio']:.3f}"
        )
    if max(levels) / min(levels) < 1.08:
        raise RuntimeError("Table-knock takes need organic loudness variance")
    if max(centroids) - min(centroids) < 90.0:
        raise RuntimeError("Table-knock takes need organic spectral variance")
    if max(correlations) > 0.68:
        raise RuntimeError("Table-knock takes are too similar to avoid repetition")


def write_wav(path: Path, signal: np.ndarray) -> None:
    pcm = np.rint(np.clip(signal, -1, 1) * 32_767).astype("<i2")
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(pcm.tobytes())


def build(output_dir: Path, source_cache: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="poch-table-knock-") as temporary:
        scratch = Path(temporary)
        source = decode_mono(pinned_source(source_cache), scratch)
        knocks = {spec.name: build_knock(source, spec) for spec in SPECS}
        validate(knocks)
        for spec in SPECS:
            wav = scratch / f"{spec.name}.wav"
            output = output_dir / f"{spec.name}.caf"
            write_wav(wav, knocks[spec.name])
            subprocess.run([
                "/usr/bin/afconvert", "-f", "caff", "-d", "LEI16@44100",
                str(wav), str(output),
            ], check=True, capture_output=True)
            print(f"{output.name} {sha256(output)}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=ROOT / "App/Audio")
    parser.add_argument("--source-cache", type=Path,
                        default=ROOT / ".build/audio-source-cache")
    arguments = parser.parse_args()
    build(arguments.output_dir, arguments.source_cache)


if __name__ == "__main__":
    main()
