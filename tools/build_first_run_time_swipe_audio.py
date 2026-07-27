#!/usr/bin/env python3
"""Builds the natural, reproducible first-run time-swipe soundscape.

Every audible layer is edited from pinned CC0 field recordings. The historical
side combines an indoor restaurant bed with a real cheer and physical table
contacts. The present side combines quiet living-room tone with real cards,
ceramic and coin Foley. The former synthetic radio seam is intentionally silent.
"""

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


SAMPLE_RATE = 44_100
DURATION = 20.0
FRAME_COUNT = int(SAMPLE_RATE * DURATION)
ROOM_CROSSFADE = 1.2


@dataclass(frozen=True)
class Source:
    key: str
    author: str
    title: str
    page_url: str
    preview_url: str
    preview_sha256: str


SOURCES = {
    "historical_room": Source(
        key="historical-room",
        author="BenDrain",
        title="Ambience_Restaurant_01.wav",
        page_url="https://freesound.org/people/BenDrain/sounds/488055/",
        preview_url="https://cdn.freesound.org/previews/488/488055_4763661-hq.mp3",
        preview_sha256="3a48c64776f1cf07d70de7f3bf7b8861f7350596ed4e5ddff4db15097b84ee1d",
    ),
    "cheer": Source(
        key="cheer",
        author="BeeProductive",
        title="Crowd cheer.wav",
        page_url="https://freesound.org/people/BeeProductive/sounds/430046/",
        preview_url="https://cdn.freesound.org/previews/430/430046_4298084-hq.mp3",
        preview_sha256="3d7e2d27e0d894a45969f261ae28a2423b5d86312654cc10bbad7d49f1fc2dcc",
    ),
    "present_room": Source(
        key="present-room",
        author="Yuval",
        title="roomtone living room",
        page_url="https://freesound.org/people/Yuval/sounds/204843/",
        preview_url="https://cdn.freesound.org/previews/204/204843_770707-hq.mp3",
        preview_sha256="846ace5f1d9decad8d4c85ef39415bf9883e2c9396e215b3a8ef6b80c35fa3fd",
    ),
    "cards": Source(
        key="cards",
        author="Kodack",
        title="Riffle Card Shuffle",
        page_url="https://freesound.org/people/Kodack/sounds/256508/",
        preview_url="https://cdn.freesound.org/previews/256/256508_2276808-hq.mp3",
        preview_sha256="9b019c52519609797a7cbfe0cae79223e91e686a06bfcb726734b6edda1a4726",
    ),
    "cup": Source(
        key="cup",
        author="squidge316",
        title="putting down a mug on a table.wav",
        page_url="https://freesound.org/people/squidge316/sounds/404922/",
        preview_url="https://cdn.freesound.org/previews/404/404922_1079491-hq.mp3",
        preview_sha256="41e1078602f2c38eaa554ddc33f2bf73ce7c826a02158cef19a2a02af823e229",
    ),
    "coin": Source(
        key="coin",
        author="Yuval",
        title="coin(s) spin drop.wav",
        page_url="https://freesound.org/people/Yuval/sounds/197214/",
        preview_url="https://cdn.freesound.org/previews/197/197214_770707-hq.mp3",
        preview_sha256="8b9132dca4668c13a728953e8510435799fcba06d496e4120e6705a006f2c439",
    ),
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pinned_download(source: Source, cache_dir: Path) -> Path:
    cache_dir.mkdir(parents=True, exist_ok=True)
    path = cache_dir / f"{source.preview_sha256}.mp3"
    if not path.exists():
        request = urllib.request.Request(
            source.preview_url,
            headers={"User-Agent": "Poch1441FirstRunAudioBuilder/2"},
        )
        with urllib.request.urlopen(request, timeout=120) as response:
            path.write_bytes(response.read())
    digest = sha256(path)
    if digest != source.preview_sha256:
        raise RuntimeError(f"Unexpected source fingerprint for {source.key}: {digest}")
    return path


def decode_segment(
    source_path: Path,
    decoded_dir: Path,
    start_seconds: float,
    duration: float,
) -> np.ndarray:
    decoded = decoded_dir / f"{source_path.stem}.wav"
    if not decoded.exists():
        subprocess.run(
            [
                "/usr/bin/afconvert",
                "-f", "WAVE",
                "-d", f"LEI16@{SAMPLE_RATE}",
                str(source_path), str(decoded),
            ],
            check=True,
            capture_output=True,
        )
    with wave.open(str(decoded), "rb") as handle:
        channels = handle.getnchannels()
        start = int(round(start_seconds * SAMPLE_RATE))
        count = int(round(duration * SAMPLE_RATE))
        if start + count > handle.getnframes():
            raise RuntimeError(f"Invalid crop for {source_path.name}")
        handle.setpos(start)
        pcm = np.frombuffer(handle.readframes(count), dtype="<i2")
    signal = pcm.astype(np.float64).reshape(-1, channels) / 32_768.0
    if channels == 1:
        signal = np.repeat(signal, 2, axis=1)
    elif channels > 2:
        signal = signal[:, :2]
    return signal


def filtered(signal: np.ndarray, low: float, high: float) -> np.ndarray:
    sos = butter(3, [low, high], btype="bandpass", fs=SAMPLE_RATE, output="sos")
    return sosfiltfilt(sos, signal, axis=0)


def master(
    signal: np.ndarray,
    target_rms: float,
    peak_limit: float,
    crest_limit: float | None = None,
) -> np.ndarray:
    signal = signal.copy()
    signal -= np.mean(signal, axis=0, keepdims=True)
    rms = float(np.sqrt(np.mean(signal * signal)))
    if rms > 0 and crest_limit is not None:
        # A dropped dish in a field recording must not turn the whole room down.
        # This limits only outliers before the ambience is level-calibrated.
        ceiling = rms * crest_limit
        signal = np.clip(signal, -ceiling, ceiling)
        rms = float(np.sqrt(np.mean(signal * signal)))
    if rms > 0:
        signal *= target_rms / rms
    peak = float(np.max(np.abs(signal)))
    if peak > peak_limit:
        signal *= peak_limit / peak
    return signal


def seamless_room(segment: np.ndarray, target_rms: float) -> np.ndarray:
    crossfade = int(round(ROOM_CROSSFADE * SAMPLE_RATE))
    required = FRAME_COUNT + crossfade
    if len(segment) != required:
        raise RuntimeError("Room segment does not satisfy the loop contract")
    loop = segment[:FRAME_COUNT].copy()
    phase = np.linspace(0.0, math.pi / 2.0, crossfade, endpoint=False)
    loop[:crossfade] = (
        segment[FRAME_COUNT:required] * np.cos(phase)[:, None]
        + segment[:crossfade] * np.sin(phase)[:, None]
    )
    loop[0] = loop[-1]
    return master(loop, target_rms=target_rms, peak_limit=0.68, crest_limit=6.0)


def normalize_peak(signal: np.ndarray, peak: float) -> np.ndarray:
    maximum = float(np.max(np.abs(signal)))
    if maximum > 0:
        signal = signal * (peak / maximum)
    signal[0] = 0
    signal[-1] = 0
    return signal


def event_clip(
    signal: np.ndarray,
    low: float,
    high: float,
    peak: float,
    fade_in: float = 0.012,
    fade_out: float = 0.12,
) -> np.ndarray:
    clip = filtered(signal, low, high)
    clip -= np.mean(clip, axis=0, keepdims=True)
    attack = min(len(clip), max(8, int(round(fade_in * SAMPLE_RATE))))
    release = min(len(clip), max(16, int(round(fade_out * SAMPLE_RATE))))
    clip[:attack] *= np.linspace(0.0, 1.0, attack)[:, None]
    clip[-release:] *= np.linspace(1.0, 0.0, release)[:, None]
    maximum = float(np.max(np.abs(clip)))
    if maximum < 0.000_1:
        raise RuntimeError("Natural event crop is silent")
    clip *= peak / maximum
    clip[0] = 0
    clip[-1] = 0
    return clip


def place_event(
    target: np.ndarray,
    clip: np.ndarray,
    start_seconds: float,
    pan: float,
    gain: float,
) -> None:
    start = int(round(start_seconds * SAMPLE_RATE))
    end = start + len(clip)
    if start < 0 or end > len(target):
        raise RuntimeError("Natural event lies outside the authored loop")
    mono = np.mean(clip, axis=1)
    left = math.cos(pan * math.pi / 2.0)
    right = math.sin(pan * math.pi / 2.0)
    target[start:end, 0] += mono * left * gain
    target[start:end, 1] += mono * right * gain


def historical_events(cheer: np.ndarray, coin: np.ndarray) -> np.ndarray:
    result = np.zeros((FRAME_COUNT, 2), dtype=np.float64)
    cheer_main = event_clip(cheer[:int(3.6 * SAMPLE_RATE)], 120.0, 6_800.0, peak=0.72,
                            fade_in=0.08, fade_out=0.45)
    cheer_tail = event_clip(cheer[int(7.0 * SAMPLE_RATE):int(10.0 * SAMPLE_RATE)],
                            140.0, 6_200.0,
                            peak=0.58, fade_in=0.10, fade_out=0.42)
    contact = event_clip(coin, 120.0, 7_200.0, peak=0.62,
                         fade_in=0.004, fade_out=0.09)
    # The runtime master is still rising at entry. At 440 ms this contact reads
    # clearly without becoming a launch click.
    place_event(result, contact, 0.44, 0.34, 0.70)
    place_event(result, cheer_main, 0.82, 0.50, 0.62)
    place_event(result, contact, 8.65, 0.72, 0.42)
    place_event(result, cheer_tail, 12.10, 0.42, 0.34)
    place_event(result, contact, 18.25, 0.24, 0.34)
    return normalize_peak(result, peak=0.72)


def present_events(cards: np.ndarray, cup: np.ndarray, coin: np.ndarray) -> np.ndarray:
    result = np.zeros((FRAME_COUNT, 2), dtype=np.float64)
    card_soft = event_clip(cards[:int(1.75 * SAMPLE_RATE)], 180.0, 8_600.0,
                           peak=0.58, fade_in=0.018, fade_out=0.16)
    card_riffle = event_clip(cards[int(2.85 * SAMPLE_RATE):], 180.0, 8_800.0,
                             peak=0.62, fade_in=0.018, fade_out=0.16)
    cup_down = event_clip(cup, 90.0, 7_200.0, peak=0.60,
                          fade_in=0.004, fade_out=0.18)
    chip = event_clip(coin, 130.0, 7_600.0, peak=0.56,
                      fade_in=0.004, fade_out=0.09)
    place_event(result, card_soft, 0.72, 0.68, 0.58)
    place_event(result, cup_down, 5.30, 0.28, 0.48)
    place_event(result, chip, 9.15, 0.64, 0.42)
    place_event(result, card_riffle, 12.20, 0.38, 0.48)
    place_event(result, cup_down, 17.35, 0.72, 0.30)
    return normalize_peak(result, peak=0.65)


def silent_seam() -> np.ndarray:
    """The clean room crossfade needs no radio noise or pitched transition."""
    # Keep the project file reference valid without shipping 20 seconds of
    # redundant PCM silence. AVAudioPlayer loops this inaudible placeholder.
    return np.zeros((SAMPLE_RATE, 2), dtype=np.float64)


def write_wav(path: Path, signal: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.rint(np.clip(signal, -1, 1) * 32_767).astype("<i2")
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(pcm.tobytes())


def build(output_dir: Path, source_cache: Path) -> None:
    paths = {key: pinned_download(source, source_cache)
             for key, source in SOURCES.items()}
    with tempfile.TemporaryDirectory(prefix="poch-first-run-audio-") as temporary:
        decoded = Path(temporary)
        historical_room_source = decode_segment(
            paths["historical_room"], decoded, 6.0, DURATION + ROOM_CROSSFADE
        )
        present_room_source = decode_segment(
            paths["present_room"], decoded, 40.0, DURATION + ROOM_CROSSFADE
        )
        cheer = decode_segment(paths["cheer"], decoded, 0.0, 13.0)
        historical_coin = decode_segment(paths["coin"], decoded, 50.75, 0.52)
        present_coin = decode_segment(paths["coin"], decoded, 56.45, 0.52)
        cards = decode_segment(paths["cards"], decoded, 0.0, 4.20)
        cup = decode_segment(paths["cup"], decoded, 0.0, 0.90)

        historical_room = seamless_room(
            filtered(historical_room_source, 95.0, 6_400.0), target_rms=0.09
        )
        present_room = seamless_room(
            filtered(present_room_source, 70.0, 8_200.0), target_rms=0.10
        )
        outputs = {
            "first-run-origin-room.wav": historical_room,
            "first-run-origin-motif.wav": historical_events(cheer, historical_coin),
            "first-run-present-room.wav": present_room,
            "first-run-present-motif.wav": present_events(cards, cup, present_coin),
            "first-run-time-noise.wav": silent_seam(),
        }
        for filename, signal in outputs.items():
            write_wav(output_dir / filename, signal)
            print(f"{filename} {sha256(output_dir / filename)}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--source-cache", type=Path,
                        default=Path(".build/audio-source-cache"))
    arguments = parser.parse_args()
    build(arguments.output_dir, arguments.source_cache)


if __name__ == "__main__":
    main()
