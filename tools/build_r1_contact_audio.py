#!/usr/bin/env python3
"""Build short, phone-safe R1 contact sounds from real CC0 Foley."""

from __future__ import annotations

import hashlib
import json
import subprocess
import tempfile
import urllib.request
import wave
from dataclasses import dataclass
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "App/Audio"
RECEIPT = ROOT / "tasks/reviews/r1-contact-audio-v2/Evidence/audio-fingerprint-receipt.json"
RATE = 44_100
SOURCE_RATE = 48_000


@dataclass(frozen=True)
class FoleySource:
    family: str
    author: str
    title: str
    page_url: str
    preview_url: str
    preview_sha256: str
    original_format: str


@dataclass(frozen=True)
class ContactSpec:
    family: str
    variant: int
    source_offset: float
    duration: float
    peak: float

    @property
    def name(self) -> str:
        return f"r1-ceramic-{self.family}-{self.variant:02d}"


SOURCES = {
    "outer": FoleySource(
        family="outer",
        author="Yuval",
        title="coin(s) spin drop.wav",
        page_url="https://freesound.org/people/Yuval/sounds/197214/",
        preview_url="https://cdn.freesound.org/previews/197/197214_770707-hq.mp3",
        preview_sha256="8b9132dca4668c13a728953e8510435799fcba06d496e4120e6705a006f2c439",
        original_format="48 kHz / 24-bit stereo WAV",
    ),
    "center": FoleySource(
        family="center",
        author="kbnevel",
        title="Coindrop_porcelain.aif",
        page_url="https://freesound.org/people/kbnevel/sounds/119831/",
        preview_url="https://cdn.freesound.org/previews/119/119831_1990690-hq.mp3",
        preview_sha256="66eb667342844b9fcb4c929aae3468843ac916c44b9958cfd61a4d334fcf534d",
        original_format="48 kHz / 24-bit mono AIFF",
    ),
    "stack": FoleySource(
        family="stack",
        author="kinglseyzissou",
        title="coin drop into coins",
        page_url="https://freesound.org/people/kinglseyzissou/sounds/435780/",
        preview_url="https://cdn.freesound.org/previews/435/435780_4379588-hq.mp3",
        preview_sha256="634ecba8d297a8be75af0ac8d123cc276ca783674f20deae3d4a9ef84f9f6de1",
        original_format="48 kHz / 32-bit mono WAV",
    ),
}


# Offsets select discrete physical contacts, not synthesized pitch variants.
# Stack 02/03 retain a second real contact so larger transfers sound denser.
SPECS = (
    ContactSpec("outer", 1, 50.858, 0.180, 0.68),
    ContactSpec("outer", 2, 56.552, 0.200, 0.69),
    ContactSpec("outer", 3, 68.732, 0.200, 0.70),
    ContactSpec("center", 1, 0.164, 0.280, 0.72),
    ContactSpec("center", 2, 0.318, 0.240, 0.69),
    ContactSpec("center", 3, 2.148, 0.280, 0.71),
    ContactSpec("stack", 1, 1.252, 0.180, 0.65),
    ContactSpec("stack", 2, 0.168, 0.220, 0.67),
    ContactSpec("stack", 3, 3.578, 0.280, 0.69),
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def download_source(source: FoleySource, directory: Path) -> Path:
    target = directory / f"{source.family}-source.mp3"
    request = urllib.request.Request(
        source.preview_url,
        headers={"User-Agent": "Poch1441FoleyBuilder/3"},
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        target.write_bytes(response.read())
    actual_sha = sha256(target)
    if actual_sha != source.preview_sha256:
        raise RuntimeError(
            f"Unexpected {source.family} source fingerprint: {actual_sha}"
        )
    return target


def decode_source(source: Path, directory: Path) -> tuple[np.ndarray, int]:
    decoded = directory / f"{source.stem}.wav"
    subprocess.run([
        "/usr/bin/afconvert", "-f", "WAVE", "-d", f"LEI16@{SOURCE_RATE}",
        str(source), str(decoded),
    ], check=True, capture_output=True)
    with wave.open(str(decoded), "rb") as input_file:
        channels = input_file.getnchannels()
        sample_rate = input_file.getframerate()
        frames = np.frombuffer(
            input_file.readframes(input_file.getnframes()),
            dtype="<i2",
        ).astype(np.float64) / 32_768
    if channels > 1:
        frames = frames.reshape(-1, channels).mean(axis=1)
    return frames, sample_rate


def extract_contact(source: np.ndarray,
                    sample_rate: int,
                    spec: ContactSpec) -> np.ndarray:
    start = int(round(spec.source_offset * sample_rate))
    end = start + int(round(spec.duration * sample_rate))
    if start < 0 or end > len(source):
        raise RuntimeError(f"Invalid source window for {spec.name}")
    clip = source[start:end].copy()

    output_count = int(round(spec.duration * RATE))
    source_positions = np.arange(len(clip), dtype=np.float64)
    output_positions = np.linspace(0, len(clip) - 1, output_count)
    clip = np.interp(output_positions, source_positions, clip)
    clip -= float(np.mean(clip))

    # Two gentle one-pole passes keep real metal detail while removing the
    # brittle ultrasonic emphasis that small phone speakers exaggerate.
    cutoff_hertz = 6_800
    tap_count = 63
    positions = np.arange(tap_count) - (tap_count - 1) / 2
    normalized_cutoff = cutoff_hertz / RATE
    kernel = 2 * normalized_cutoff * np.sinc(2 * normalized_cutoff * positions)
    kernel *= np.hamming(tap_count)
    kernel /= float(np.sum(kernel))
    clip = np.convolve(clip, kernel, mode="same")

    # Real coin peaks stay transient, but no single sample dominates the body.
    drive = 1.8
    pre_drive_peak = max(float(np.max(np.abs(clip))), 0.0001)
    clip = np.tanh((clip / pre_drive_peak) * drive) / np.tanh(drive)

    fade_in = max(8, int(RATE * 0.0015))
    fade_out = max(16, int(RATE * 0.020))
    clip[:fade_in] *= np.linspace(0, 1, fade_in)
    clip[-fade_out:] *= np.linspace(1, 0, fade_out)
    clip -= float(np.mean(clip))
    clip[0] = 0
    clip[-1] = 0

    maximum = float(np.max(np.abs(clip)))
    if maximum < 0.0001:
        raise RuntimeError(f"Silent source window for {spec.name}")
    clip *= spec.peak / maximum
    return clip


def write_wav(path: Path, signal: np.ndarray) -> None:
    pcm = np.round(np.clip(signal, -1, 1) * 32_767).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())


def metrics(signal: np.ndarray,
            spec: ContactSpec,
            output: Path) -> dict[str, object]:
    absolute = np.abs(signal)
    rms = float(np.sqrt(np.mean(signal * signal)))
    window = signal * np.hanning(len(signal))
    spectrum = np.abs(np.fft.rfft(window)) ** 2 + 1e-12
    frequencies = np.fft.rfftfreq(len(signal), 1 / RATE)
    centroid = float(np.sum(frequencies * spectrum) / np.sum(spectrum))
    early = float(np.sqrt(np.mean(signal[: int(RATE * 0.035)] ** 2)))
    tail = float(np.sqrt(np.mean(signal[-int(RATE * 0.035):] ** 2)))
    return {
        "asset": str(output.relative_to(ROOT)),
        "family": spec.family,
        "variant": spec.variant,
        "sourceOffsetSeconds": spec.source_offset,
        "sha256": sha256(output),
        "durationSeconds": len(signal) / RATE,
        "peakAmplitude": float(np.max(absolute)),
        "rmsAmplitude": rms,
        "crestFactor": float(np.max(absolute) / max(rms, 1e-12)),
        "dcOffset": float(np.mean(signal)),
        "spectralCentroidHertz": centroid,
        "earlyRMS0To35ms": early,
        "tailRMSLast35ms": tail,
        "clippedSampleCount": int(np.count_nonzero(absolute >= 0.999)),
    }


def source_receipt(source: FoleySource) -> dict[str, object]:
    return {
        "family": source.family,
        "author": source.author,
        "title": source.title,
        "pageURL": source.page_url,
        "processedPreviewURL": source.preview_url,
        "processedPreviewSHA256": source.preview_sha256,
        "originalFormat": source.original_format,
        "license": "CC0 1.0 Universal",
        "licenseURL": "https://creativecommons.org/publicdomain/zero/1.0/",
        "retrievedDate": "2026-07-22",
    }


def main() -> None:
    AUDIO.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, object]] = []
    with tempfile.TemporaryDirectory(prefix="poch-r1-foley-") as directory:
        temporary = Path(directory)
        decoded = {
            family: decode_source(download_source(source, temporary), temporary)
            for family, source in SOURCES.items()
        }
        for spec in SPECS:
            source_frames, source_rate = decoded[spec.family]
            signal = extract_contact(source_frames, source_rate, spec)
            wav = temporary / f"{spec.name}.wav"
            output = AUDIO / f"{spec.name}.caf"
            write_wav(wav, signal)
            subprocess.run([
                "/usr/bin/afconvert", "-f", "caff", "-d", "LEI16@44100",
                str(wav), str(output),
            ], check=True, capture_output=True)
            records.append(metrics(signal, spec, output))

    checks = []
    for record in records:
        checks.append(
            0.14 <= float(record["durationSeconds"]) <= 0.30
            and 0.60 <= float(record["peakAmplitude"]) <= 0.82
            and 2.5 <= float(record["crestFactor"]) <= 25.0
            and abs(float(record["dcOffset"])) < 0.0001
            and 450 <= float(record["spectralCentroidHertz"]) <= 9_000
            and int(record["clippedSampleCount"]) == 0
            and float(record["tailRMSLast35ms"])
                < float(record["earlyRMS0To35ms"]) * 0.85
        )

    receipt = {
        "schema": "poch.r1-contact-audio.v3",
        "provenance": "edited excerpts from real CC0 field recordings; no additive synthesis",
        "format": {"sampleRateHertz": RATE, "channels": 1, "pcmBits": 16},
        "surfaces": ["outerWell", "centerWell", "playerStack"],
        "sources": [source_receipt(source) for source in SOURCES.values()],
        "assets": records,
        "technicalVerdict": "GREEN" if all(checks) else "RED",
        "humanIPhoneSpeakerVerdict": "PENDING_NEW_FOLEY_TESTFLIGHT",
    }
    RECEIPT.parent.mkdir(parents=True, exist_ok=True)
    RECEIPT.write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(receipt, indent=2, sort_keys=True))
    if receipt["technicalVerdict"] != "GREEN":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
