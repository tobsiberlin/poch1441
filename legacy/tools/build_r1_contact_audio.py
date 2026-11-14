#!/usr/bin/env python3
"""Build tactile R1 contacts from pinned CC0 clay/ceramic poker-chip Foley."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import tempfile
import urllib.request
import wave
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from scipy.signal import butter, sosfiltfilt


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_AUDIO = ROOT / "App/Audio"
DEFAULT_RECEIPT = (
    ROOT / "tasks/reviews/r1-contact-audio-v2/Evidence/audio-fingerprint-receipt.json"
)
RATE = 44_100


@dataclass(frozen=True)
class FoleySource:
    source_number: int
    freesound_id: int
    preview_sha256: str

    @property
    def title(self) -> str:
        return f"poker_chips{self.source_number}.wav"

    @property
    def page_url(self) -> str:
        return f"https://freesound.org/people/fartheststar/sounds/{self.freesound_id}/"

    @property
    def preview_url(self) -> str:
        return (
            "https://cdn.freesound.org/previews/201/"
            f"{self.freesound_id}_3745836-hq.mp3"
        )


@dataclass(frozen=True)
class ContactSpec:
    family: str
    variant: int
    source_number: int
    duration: float
    peak: float
    low_cut: float
    high_cut: float

    @property
    def name(self) -> str:
        return f"r1-ceramic-{self.family}-{self.variant:02d}"


# This complete CC0 pack was recorded from real clay/ceramic poker chips.
# Singles remain light; larger real groups are reserved for pot and stack tails.
SOURCES = {
    1: FoleySource(1, 201807,
                   "feed53fa32b22a04110ed9d4b9d09f296a53806d4e616dd8c1bdc0852afd053d"),
    2: FoleySource(2, 201806,
                   "420189948e68b72adf65c2f2096ca04b77e3d86606bfe7a9c776165bc5496ea7"),
    3: FoleySource(3, 201805,
                   "ade4480527d9fe7442b4ef6bef6ec1616ed546e81e0d07837fedea74e4b63de5"),
    4: FoleySource(4, 201804,
                   "241ca8b13c1cc72c3aabb5b14718e871a18323e67492aaf310c218af0561e318"),
    5: FoleySource(5, 201809,
                   "7a956be36079c9524a15efbaf9d7d6abcdbc840e110f50474cc98e9d2e76698a"),
    6: FoleySource(6, 201808,
                   "f7f9c003686c8a57ca95e7ba7ea77f0455ca80051862fb8df88bcbece4de2fb4"),
}

SPECS = (
    ContactSpec("outer", 1, 2, 0.180, 0.62, 150.0, 3_800.0),
    ContactSpec("outer", 2, 3, 0.200, 0.65, 140.0, 4_000.0),
    ContactSpec("outer", 3, 4, 0.220, 0.67, 130.0, 4_200.0),
    ContactSpec("center", 1, 3, 0.220, 0.67, 95.0, 3_600.0),
    ContactSpec("center", 2, 4, 0.240, 0.70, 90.0, 3_800.0),
    ContactSpec("center", 3, 6, 0.240, 0.68, 95.0, 4_200.0),
    ContactSpec("stack", 1, 6, 0.210, 0.64, 170.0, 4_200.0),
    ContactSpec("stack", 2, 5, 0.280, 0.68, 150.0, 4_400.0),
    ContactSpec("stack", 3, 1, 0.300, 0.70, 130.0, 4_200.0),
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pinned_source(source: FoleySource, cache_dir: Path) -> Path:
    cache_dir.mkdir(parents=True, exist_ok=True)
    target = cache_dir / f"{source.preview_sha256}.mp3"
    if not target.exists():
        request = urllib.request.Request(
            source.preview_url,
            headers={"User-Agent": "Poch1441CeramicFoleyBuilder/4"},
        )
        with urllib.request.urlopen(request, timeout=120) as response:
            target.write_bytes(response.read())
    actual = sha256(target)
    if actual != source.preview_sha256:
        raise RuntimeError(
            f"Unexpected source fingerprint for {source.title}: {actual}"
        )
    return target


def decode_mono(source: Path, directory: Path) -> np.ndarray:
    decoded = directory / f"{source.stem}.wav"
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


def extract_contact(source: np.ndarray, spec: ContactSpec) -> np.ndarray:
    absolute = np.abs(source)
    threshold = max(0.004, float(np.max(absolute)) * 0.045)
    active = np.flatnonzero(absolute >= threshold)
    if len(active) == 0:
        raise RuntimeError(f"Silent clay-chip source for {spec.name}")
    pre_roll = int(round(0.003 * RATE))
    start = max(0, int(active[0]) - pre_roll)
    count = int(round(spec.duration * RATE))
    clip = np.zeros(count, dtype=np.float64)
    available = source[start:min(len(source), start + count)]
    clip[:len(available)] = available
    clip -= float(np.mean(clip))

    band = butter(3, [spec.low_cut, spec.high_cut], btype="bandpass",
                  fs=RATE, output="sos")
    clip = sosfiltfilt(band, clip)
    # Mild tape-like saturation controls MP3 preview spikes while preserving
    # the recorded clay/ceramic spectrum. No tone, pitch shift or synthesis is added.
    drive = 1.22
    input_peak = max(float(np.max(np.abs(clip))), 0.0001)
    clip = np.tanh((clip / input_peak) * drive) / np.tanh(drive)

    fade_in = max(8, int(round(0.0012 * RATE)))
    fade_out = max(32, int(round(0.036 * RATE)))
    clip[:fade_in] *= np.linspace(0.0, 1.0, fade_in)
    clip[-fade_out:] *= np.linspace(1.0, 0.0, fade_out)
    clip -= float(np.mean(clip))
    maximum = float(np.max(np.abs(clip)))
    clip *= spec.peak / max(maximum, 0.0001)
    clip[0] = 0
    clip[-1] = 0
    return clip


def write_wav(path: Path, signal: np.ndarray) -> None:
    pcm = np.rint(np.clip(signal, -1, 1) * 32_767).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())


def metrics(signal: np.ndarray, spec: ContactSpec, output: Path) -> dict[str, object]:
    windowed = signal * np.hanning(len(signal))
    spectrum = np.abs(np.fft.rfft(windowed)) ** 2 + 1e-15
    frequencies = np.fft.rfftfreq(len(signal), 1 / RATE)
    total = float(np.sum(spectrum))
    early = signal[:int(round(0.035 * RATE))]
    tail = signal[-int(round(0.035 * RATE)):]
    rms = float(np.sqrt(np.mean(signal * signal)))
    return {
        "asset": f"App/Audio/{output.name}",
        "family": spec.family,
        "variant": spec.variant,
        "sourceTitle": SOURCES[spec.source_number].title,
        "sha256": sha256(output),
        "durationSeconds": len(signal) / RATE,
        "peakAmplitude": float(np.max(np.abs(signal))),
        "rmsAmplitude": rms,
        "crestFactor": float(np.max(np.abs(signal)) / max(rms, 1e-12)),
        "dcOffset": float(np.mean(signal)),
        "spectralCentroidHertz": float(np.sum(frequencies * spectrum) / total),
        "lowMidPowerRatio": float(
            np.sum(spectrum[(frequencies >= 140) & (frequencies < 1_800)]) / total
        ),
        "earlyRMS0To35ms": float(np.sqrt(np.mean(early * early))),
        "tailRMSLast35ms": float(np.sqrt(np.mean(tail * tail))),
        "clippedSampleCount": int(np.count_nonzero(np.abs(signal) >= 0.999)),
    }


def source_receipt(source: FoleySource) -> dict[str, object]:
    return {
        "author": "fartheststar",
        "title": source.title,
        "pageURL": source.page_url,
        "processedPreviewURL": source.preview_url,
        "processedPreviewSHA256": source.preview_sha256,
        "recordedMaterial": "real clay/ceramic poker chips",
        "license": "CC0 1.0 Universal",
        "licenseURL": "https://creativecommons.org/publicdomain/zero/1.0/",
        "retrievedDate": "2026-07-28",
    }


def build(audio_dir: Path, receipt_path: Path, cache_dir: Path) -> dict[str, object]:
    audio_dir.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, object]] = []
    with tempfile.TemporaryDirectory(prefix="poch-r1-ceramic-") as directory:
        scratch = Path(directory)
        decoded = {
            number: decode_mono(pinned_source(source, cache_dir), scratch)
            for number, source in SOURCES.items()
        }
        for spec in SPECS:
            signal = extract_contact(decoded[spec.source_number], spec)
            wav = scratch / f"{spec.name}.wav"
            output = audio_dir / f"{spec.name}.caf"
            write_wav(wav, signal)
            subprocess.run([
                "/usr/bin/afconvert", "-f", "caff", "-d", "LEI16@44100",
                str(wav), str(output),
            ], check=True, capture_output=True)
            records.append(metrics(signal, spec, output))

    checks = [
        0.17 <= float(item["durationSeconds"]) <= 0.31
        and 0.58 <= float(item["peakAmplitude"]) <= 0.74
        and 2.0 <= float(item["crestFactor"]) <= 22.0
        and abs(float(item["dcOffset"])) < 0.0001
        and 650 <= float(item["spectralCentroidHertz"]) <= 4_800
        and 0.008 <= float(item["lowMidPowerRatio"]) <= 0.95
        and int(item["clippedSampleCount"]) == 0
        and float(item["tailRMSLast35ms"])
            < float(item["earlyRMS0To35ms"]) * 0.90
        for item in records
    ]
    receipt = {
        "schema": "poch.r1-contact-audio.v4",
        "provenance": "edited excerpts from real CC0 clay/ceramic poker-chip recordings",
        "format": {"sampleRateHertz": RATE, "channels": 1, "pcmBits": 16},
        "surfaces": ["outerWell", "centerWell", "playerStack"],
        "sources": [source_receipt(source) for source in SOURCES.values()],
        "assets": records,
        "technicalVerdict": "GREEN" if all(checks) else "RED",
        "humanIPhoneSpeakerVerdict": "PENDING_NEW_CERAMIC_FOLEY_TESTFLIGHT",
    }
    receipt_path.parent.mkdir(parents=True, exist_ok=True)
    receipt_path.write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    if receipt["technicalVerdict"] != "GREEN":
        raise RuntimeError("Generated ceramic Foley did not satisfy the objective gate")
    return receipt


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_AUDIO)
    parser.add_argument("--receipt", type=Path, default=DEFAULT_RECEIPT)
    parser.add_argument("--source-cache", type=Path,
                        default=ROOT / ".build/audio-source-cache")
    arguments = parser.parse_args()
    receipt = build(arguments.output_dir, arguments.receipt, arguments.source_cache)
    print(json.dumps(receipt, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
