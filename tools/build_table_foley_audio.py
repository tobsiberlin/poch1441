#!/usr/bin/env python3
"""Build short, phone-safe card contacts from real CC0 table Foley."""

from __future__ import annotations

import hashlib
import subprocess
import tempfile
import urllib.request
import wave
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from scipy.signal import butter, sosfiltfilt


ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "App/Audio"
RATE = 44_100


@dataclass(frozen=True)
class CardSource:
    variant: int
    freesound_id: int
    preview_sha256: str
    crop_start: float
    duration: float
    low_cut: float
    high_cut: float
    peak: float

    @property
    def name(self) -> str:
        return f"card-deal-{self.variant:02d}"

    @property
    def preview_url(self) -> str:
        return (
            "https://cdn.freesound.org/previews/571/"
            f"{self.freesound_id}_9129912-hq.mp3"
        )


SOURCES = (
    CardSource(1, 571577,
               "d50fa67b0bdc84e241ceb543ca334e61afe62445ca68552dcaf0f63fa2283f58",
               0.235, 0.30, 240.0, 9_800.0, 0.56),
    CardSource(2, 571576,
               "58de0a11f0801215d2c1dab615885f28319114746ade35f21919c86e8fd15b9a",
               0.240, 0.36, 135.0, 6_400.0, 0.64),
    CardSource(3, 571575,
               "024eea9ea74466dd14f1110923d0d6b0535d8de269409296a2537a0a7b2f0949",
               0.238, 0.44, 85.0, 4_600.0, 0.70),
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def download(source: CardSource, directory: Path) -> Path:
    target = directory / f"{source.name}.mp3"
    request = urllib.request.Request(
        source.preview_url,
        headers={"User-Agent": "Poch1441TableFoleyBuilder/1"},
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        target.write_bytes(response.read())
    actual = sha256(target)
    if actual != source.preview_sha256:
        raise RuntimeError(f"Unexpected source fingerprint for {source.name}: {actual}")
    return target


def decode(source: Path, directory: Path) -> tuple[np.ndarray, int]:
    decoded = directory / f"{source.stem}.wav"
    subprocess.run([
        "/usr/bin/afconvert", "-f", "WAVE", "-d", f"LEI16@{RATE}",
        str(source), str(decoded),
    ], check=True, capture_output=True)
    with wave.open(str(decoded), "rb") as input_file:
        channels = input_file.getnchannels()
        sample_rate = input_file.getframerate()
        frames = np.frombuffer(
            input_file.readframes(input_file.getnframes()),
            dtype="<i2",
        ).astype(np.float64) / 32_768
    return frames.reshape(-1, channels), sample_rate


def build_contact(frames: np.ndarray,
                  sample_rate: int,
                  source: CardSource) -> np.ndarray:
    start = int(round(source.crop_start * sample_rate))
    end = start + int(round(source.duration * sample_rate))
    if end > len(frames):
        raise RuntimeError(f"Invalid crop for {source.name}")
    clip = frames[start:end].copy()
    clip -= np.mean(clip, axis=0, keepdims=True)
    band = butter(2, [source.low_cut, source.high_cut], btype="bandpass",
                  fs=sample_rate, output="sos")
    clip = sosfiltfilt(band, clip, axis=0)

    fade_in = max(8, int(sample_rate * 0.006))
    fade_out = max(16, int(sample_rate * 0.050))
    clip[:fade_in] *= np.linspace(0, 1, fade_in)[:, None]
    clip[-fade_out:] *= np.linspace(1, 0, fade_out)[:, None]

    maximum = float(np.max(np.abs(clip)))
    if maximum < 0.0001:
        raise RuntimeError(f"Silent crop for {source.name}")
    clip *= source.peak / maximum
    clip[0] = 0
    clip[-1] = 0
    return clip


def contact_metrics(signal: np.ndarray) -> tuple[float, float, float]:
    mono = np.mean(signal, axis=1)
    level = float(np.sqrt(np.mean(signal * signal)))
    crossings = float(np.mean(np.signbit(mono[1:]) != np.signbit(mono[:-1])))
    duration = len(signal) / RATE
    return duration, level, crossings


def normalized_correlation(lhs: np.ndarray, rhs: np.ndarray) -> float:
    count = min(len(lhs), len(rhs))
    left = np.mean(lhs[:count], axis=1)
    right = np.mean(rhs[:count], axis=1)
    denominator = float(np.linalg.norm(left) * np.linalg.norm(right))
    return 0.0 if denominator == 0 else float(np.dot(left, right) / denominator)


def validate_contacts(contacts: dict[str, np.ndarray]) -> None:
    """Rejects normalized clones before they can reach the runtime bundle."""
    metrics = {name: contact_metrics(signal) for name, signal in contacts.items()}
    durations = sorted(value[0] for value in metrics.values())
    levels = [value[1] for value in metrics.values()]
    crossings = [value[2] for value in metrics.values()]
    correlations = [
        abs(normalized_correlation(contacts[left], contacts[right]))
        for index, left in enumerate(contacts)
        for right in tuple(contacts)[index + 1:]
    ]

    if any(duration < 0.26 or duration > 0.46 for duration in durations):
        raise RuntimeError("Card contacts must remain short physical events")
    if min(b - a for a, b in zip(durations, durations[1:])) < 0.045:
        raise RuntimeError("Card contacts need perceptibly different tail lengths")
    if max(levels) / min(levels) < 1.30:
        raise RuntimeError("Card contacts need organic dynamic variance")
    if max(crossings) - min(crossings) < 0.015:
        raise RuntimeError("Card contacts need distinct paper/table tone")
    if max(correlations) > 0.72:
        raise RuntimeError("Card contacts are too correlated to sound organic")

    for name, (duration, level, crossings) in metrics.items():
        print(f"{name}: duration={duration:.3f}s rms={level:.4f} zcr={crossings:.4f}")


def write_wav(path: Path, signal: np.ndarray) -> None:
    pcm = np.round(np.clip(signal, -1, 1) * 32_767).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(signal.shape[1])
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())


def main() -> None:
    AUDIO.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="poch-card-foley-") as directory:
        temporary = Path(directory)
        contacts: dict[str, np.ndarray] = {}
        for source in SOURCES:
            frames, sample_rate = decode(download(source, temporary), temporary)
            contacts[source.name] = build_contact(frames, sample_rate, source)

        validate_contacts(contacts)

        for source in SOURCES:
            signal = contacts[source.name]
            wav = temporary / f"{source.name}.wav"
            output = AUDIO / f"{source.name}.caf"
            write_wav(wav, signal)
            subprocess.run([
                "/usr/bin/afconvert", "-f", "caff", "-d", "LEI16@44100",
                str(wav), str(output),
            ], check=True, capture_output=True)
            if float(np.max(np.abs(signal))) >= 0.999:
                raise RuntimeError(f"Clipping detected in {source.name}")
            print(f"{output.relative_to(ROOT)} {sha256(output)}")


if __name__ == "__main__":
    main()
