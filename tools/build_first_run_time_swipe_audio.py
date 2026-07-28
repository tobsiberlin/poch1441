#!/usr/bin/env python3
"""Build the deterministic, finger-morphed first-run soundscape.

The two eras share a musical event grid and one real knuckle-on-wood signature
layer. Rooms and timbres change around that invariant match cut. Generated room
beds contain no captured speech, wildlife or language.
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
    recorded_material: str


SOURCES = {
    "cards": Source(
        "cards", "Kodack", "Riffle Card Shuffle",
        "https://freesound.org/people/Kodack/sounds/256508/",
        "https://cdn.freesound.org/previews/256/256508_2276808-hq.mp3",
        "9b019c52519609797a7cbfe0cae79223e91e686a06bfcb726734b6edda1a4726",
        "real playing cards",
    ),
    "coin": Source(
        "coin", "Yuval", "coin(s) spin drop.wav",
        "https://freesound.org/people/Yuval/sounds/197214/",
        "https://cdn.freesound.org/previews/197/197214_770707-hq.mp3",
        "8b9132dca4668c13a728953e8510435799fcba06d496e4120e6705a006f2c439",
        "real historical metal coin contact",
    ),
    "ceramic": Source(
        "ceramic", "fartheststar", "poker_chips2.wav",
        "https://freesound.org/people/fartheststar/sounds/201806/",
        "https://cdn.freesound.org/previews/201/201806_3745836-hq.mp3",
        "420189948e68b72adf65c2f2096ca04b77e3d86606bfe7a9c776165bc5496ea7",
        "real clay/ceramic poker chips",
    ),
    "knock": Source(
        "knock", "thatkellytrna", "Knock on Wood.wav",
        "https://freesound.org/people/thatkellytrna/sounds/425780/",
        "https://cdn.freesound.org/previews/425/425780_7179420-hq.mp3",
        "407f38d7a7de938935f0b8cd08f187f139158a9151ad50ce9c99055caddfe85d",
        "real knuckle on wood",
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
            headers={"User-Agent": "Poch1441FirstRunAudioBuilder/3"},
        )
        with urllib.request.urlopen(request, timeout=120) as response:
            path.write_bytes(response.read())
    actual = sha256(path)
    if actual != source.preview_sha256:
        raise RuntimeError(f"Unexpected source fingerprint for {source.key}: {actual}")
    return path


def decode_segment(source_path: Path, decoded_dir: Path,
                   start_seconds: float, duration: float) -> np.ndarray:
    decoded = decoded_dir / f"{source_path.stem}.wav"
    if not decoded.exists():
        subprocess.run([
            "/usr/bin/afconvert", "-f", "WAVE", "-d", f"LEI16@{SAMPLE_RATE}",
            str(source_path), str(decoded),
        ], check=True, capture_output=True)
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
    return signal[:, :2]


def filtered(signal: np.ndarray, low: float, high: float) -> np.ndarray:
    band = butter(3, [low, high], btype="bandpass",
                  fs=SAMPLE_RATE, output="sos")
    return sosfiltfilt(band, signal, axis=0)


def master(signal: np.ndarray, target_rms: float, peak_limit: float) -> np.ndarray:
    result = signal.copy()
    result -= np.mean(result, axis=0, keepdims=True)
    level = float(np.sqrt(np.mean(result * result)))
    if level > 0:
        result *= target_rms / level
    peak = float(np.max(np.abs(result)))
    if peak > peak_limit:
        result *= peak_limit / peak
    result[0] = result[-1]
    return result


def seamless_room(signal: np.ndarray, target_rms: float) -> np.ndarray:
    crossfade = int(round(ROOM_CROSSFADE * SAMPLE_RATE))
    if len(signal) != FRAME_COUNT + crossfade:
        raise RuntimeError("Room source does not satisfy the loop contract")
    loop = signal[:FRAME_COUNT].copy()
    phase = np.linspace(0.0, math.pi / 2, crossfade, endpoint=False)
    loop[:crossfade] = (
        signal[FRAME_COUNT:] * np.cos(phase)[:, None]
        + signal[:crossfade] * np.sin(phase)[:, None]
    )
    return master(loop, target_rms, 0.66)


def narrow_stereo(signal: np.ndarray, side_gain: float) -> np.ndarray:
    middle = np.mean(signal, axis=1)
    side = (signal[:, 0] - signal[:, 1]) * 0.5 * side_gain
    return np.column_stack((middle + side, middle - side))


def event_clip(signal: np.ndarray, low: float, high: float,
               peak: float, duration: float | None = None) -> np.ndarray:
    clip = filtered(signal, low, high)
    if duration is not None:
        clip = clip[:int(round(duration * SAMPLE_RATE))]
    clip -= np.mean(clip, axis=0, keepdims=True)
    fade_in = min(len(clip), max(8, int(round(0.002 * SAMPLE_RATE))))
    fade_out = min(len(clip), max(32, int(round(0.045 * SAMPLE_RATE))))
    clip[:fade_in] *= np.linspace(0, 1, fade_in)[:, None]
    clip[-fade_out:] *= np.linspace(1, 0, fade_out)[:, None]
    maximum = float(np.max(np.abs(clip)))
    if maximum < 0.0001:
        raise RuntimeError("Physical source crop is silent")
    clip *= peak / maximum
    clip[0] = 0
    clip[-1] = 0
    return clip


def place_event(target: np.ndarray, clip: np.ndarray,
                start_seconds: float, pan: float, gain: float) -> None:
    start = int(round(start_seconds * SAMPLE_RATE))
    end = start + len(clip)
    if start < 0 or end > len(target):
        raise RuntimeError("Event lies outside the authored loop")
    mono = np.mean(clip, axis=1)
    angle = (pan + 1.0) * math.pi / 4.0
    target[start:end, 0] += mono * math.cos(angle) * gain
    target[start:end, 1] += mono * math.sin(angle) * gain


def historical_tavern_room() -> np.ndarray:
    count = FRAME_COUNT + int(round(ROOM_CROSSFADE * SAMPLE_RATE))
    rng = np.random.default_rng(1_441_77)
    fire = filtered(rng.standard_normal((count, 2)), 1_300, 9_500) * 0.023
    room_body = filtered(rng.standard_normal((count, 2)), 80, 420) * 0.030
    timber_rustle = filtered(rng.standard_normal((count, 2)), 1_700, 6_600) * 0.032
    pops = np.zeros((count, 2), dtype=np.float64)
    for event in rng.uniform(0.15, DURATION + 0.9, 126):
        start = int(round(event * SAMPLE_RATE))
        length = min(int(round(0.022 * SAMPLE_RATE)), count - start)
        if length <= 0:
            continue
        pop = rng.standard_normal(length) * np.exp(-np.linspace(0, 9, length))
        pops[start:start + length, 0] += pop * rng.uniform(0.010, 0.027)
        pops[start:start + length, 1] += np.roll(pop, 7) * rng.uniform(0.009, 0.025)

    # Irregular clap/bench clusters make the room busy and social without any
    # speech-like continuous mid band. Era identity comes from this percussive
    # bustle plus the lute, metal coin, cards and shared table knock layers.
    bustle = np.zeros((count, 2), dtype=np.float64)
    for cluster in (0.82, 3.46, 6.24, 9.12, 12.58, 15.21, 18.05):
        for pulse_index in range(rng.integers(3, 7)):
            event = cluster + pulse_index * rng.uniform(0.055, 0.13)
            start = int(round(event * SAMPLE_RATE))
            length = min(int(round(rng.uniform(0.025, 0.062) * SAMPLE_RATE)),
                         count - start)
            if length <= 0:
                continue
            local_time = np.arange(length, dtype=np.float64) / SAMPLE_RATE
            contact = filtered(rng.standard_normal((length, 2)), 720, 6_800)
            envelope = np.exp(-rng.uniform(35, 62) * local_time)
            bustle[start:start + length] += contact * envelope[:, None] * rng.uniform(0.012, 0.027)
    signal = narrow_stereo(fire + room_body + timber_rustle + pops + bustle,
                           side_gain=0.18)
    return seamless_room(signal, target_rms=0.082)


def present_lounge_room() -> np.ndarray:
    count = FRAME_COUNT + int(round(ROOM_CROSSFADE * SAMPLE_RATE))
    rng = np.random.default_rng(2_026_77)
    # Neutral indoor air only. The lounge is identified by Rhodes, brushes,
    # ceramic chips and cards - never by periodic breathing or outdoor bands.
    cloth = filtered(rng.standard_normal((count, 2)), 1_900, 5_800) * 0.14
    hvac = filtered(rng.standard_normal((count, 2)), 55, 220) * 0.30
    signal = narrow_stereo(cloth + hvac, side_gain=0.12)
    return seamless_room(signal, target_rms=0.048)


def midi_frequency(note: int) -> float:
    return 440.0 * 2 ** ((note - 69) / 12)


def add_voice(target: np.ndarray, start: float, duration: float,
              note: int, gain: float, pan: float, historical: bool) -> None:
    first = int(round(start * SAMPLE_RATE))
    count = min(int(round(duration * SAMPLE_RATE)), len(target) - first)
    if count <= 0:
        return
    time = np.arange(count, dtype=np.float64) / SAMPLE_RATE
    frequency = midi_frequency(note)
    attack = np.minimum(1.0, time / (0.006 if historical else 0.028))
    release = np.minimum(1.0, (duration - time) / (0.12 if historical else 0.34))
    if historical:
        envelope = attack * np.maximum(0.0, release) * np.exp(-2.8 * time)
        voice = (
            np.sin(2 * math.pi * frequency * time)
            + 0.42 * np.sin(2 * math.pi * frequency * 2.01 * time + 0.2)
            + 0.18 * np.sin(2 * math.pi * frequency * 3.02 * time + 0.7)
        ) * envelope
    else:
        envelope = attack * np.maximum(0.0, release) * (0.60 + 0.40 * np.exp(-2.2 * time))
        voice = (
            np.sin(2 * math.pi * frequency * time)
            + 0.22 * np.sin(2 * math.pi * frequency * 2 * time + 0.18)
            + 0.06 * np.sin(2 * math.pi * frequency * 3 * time + 0.47)
        ) * envelope
    angle = (pan + 1) * math.pi / 4
    target[first:first + count, 0] += voice * gain * math.cos(angle)
    target[first:first + count, 1] += voice * gain * math.sin(angle)


def add_rhodes(target: np.ndarray, start: float, duration: float,
               note: int, gain: float, pan: float) -> None:
    """Warm electric-piano voice without a long bird-like sine sustain."""
    first = int(round(start * SAMPLE_RATE))
    count = min(int(round(duration * SAMPLE_RATE)), len(target) - first)
    if count <= 0:
        return
    time = np.arange(count, dtype=np.float64) / SAMPLE_RATE
    frequency = midi_frequency(note)
    attack = np.minimum(1.0, time / 0.014)
    release = np.minimum(1.0, (duration - time) / 0.24)
    decay = 0.20 + 0.80 * np.exp(-2.15 * time)
    tremolo = 0.96 + 0.04 * np.sin(2 * math.pi * 4.7 * time)
    envelope = attack * np.maximum(0.0, release) * decay * tremolo
    voice = (
        np.sin(2 * math.pi * frequency * time)
        + 0.34 * np.sin(2 * math.pi * frequency * 2.003 * time + 0.42)
        + 0.10 * np.sin(2 * math.pi * frequency * 3.998 * time + 1.12)
    ) * envelope
    angle = (pan + 1) * math.pi / 4
    target[first:first + count, 0] += voice * gain * math.cos(angle)
    target[first:first + count, 1] += voice * gain * math.sin(angle)


def add_brush(target: np.ndarray, start: float, gain: float,
              rng: np.random.Generator, pan: float) -> None:
    duration = 0.12
    first = int(round(start * SAMPLE_RATE))
    count = min(int(round(duration * SAMPLE_RATE)), len(target) - first)
    if count <= 0:
        return
    time = np.arange(count, dtype=np.float64) / SAMPLE_RATE
    noise = filtered(rng.standard_normal((count, 2)), 1_500, 7_200)
    envelope = np.minimum(1.0, time / 0.008) * np.exp(-24 * time)
    mono = np.mean(noise, axis=1) * envelope * gain
    angle = (pan + 1) * math.pi / 4
    target[first:first + count, 0] += mono * math.cos(angle)
    target[first:first + count, 1] += mono * math.sin(angle)


def aligned_signature_music(historical: bool) -> np.ndarray:
    result = np.zeros((FRAME_COUNT, 2), dtype=np.float64)
    beat = 0.625
    historical_chords = (
        (50, 57, 60, 64), (46, 53, 57, 62),
        (41, 48, 52, 57), (48, 55, 62, 64),
    )
    # Seventh/ninth voicings make today unmistakably a restrained lounge,
    # while keeping the exact same bar and contact grid as 1441.
    present_chords = (
        (50, 57, 60, 64, 69), (46, 53, 57, 60, 65),
        (41, 48, 52, 55, 59), (48, 55, 58, 62, 67),
    )
    historical_motif = (69, 72, 76, 72, 67, 69, 65, 64)
    present_motif = (64, 67, 69, 67, 62, 64, 60, 62)
    brush_rng = np.random.default_rng(2_026_1_441)
    for bar_index in range(8):
        start = bar_index * beat * 4
        chord = (historical_chords if historical else present_chords)[bar_index // 2]
        for voice_index, note in enumerate(chord):
            pan = -0.30 + voice_index * (0.15 if historical else 0.12)
            if historical:
                add_voice(result, start, beat * 1.45, note, 0.026,
                          pan, historical=True)
            else:
                add_rhodes(result, start, beat * 2.85, note, 0.0165, pan)
        motif = historical_motif if historical else present_motif
        if historical:
            add_voice(result, start + beat * 2, beat * 0.78,
                      motif[bar_index], 0.022, 0.18, historical=True)
        else:
            add_rhodes(result, start + beat * 2, beat * 1.05,
                       motif[bar_index], 0.015, 0.20)
            # Soft bass and brushes establish an unmistakable indoor lounge
            # groove without turning the introduction into a music bed.
            add_rhodes(result, start, beat * 1.2, chord[0] - 12, 0.020, -0.20)
            for step in range(8):
                add_brush(result, start + step * beat * 0.5,
                          0.010 if step % 2 == 0 else 0.006,
                          brush_rng, 0.24)
    return master(result, target_rms=0.052 if historical else 0.056,
                  peak_limit=0.48)


def era_motif(historical: bool, cards: np.ndarray,
              coin: np.ndarray, ceramic: np.ndarray) -> np.ndarray:
    result = aligned_signature_music(historical)
    card = event_clip(cards, 180, 7_600, 0.54, duration=0.34)
    if historical:
        token = event_clip(coin, 130, 5_400, 0.54, duration=0.25)
        events = ((3.10, card, -0.28, 0.30), (8.65, token, 0.18, 0.36),
                  (13.10, card, -0.08, 0.24), (18.25, token, 0.24, 0.28))
    else:
        token = event_clip(ceramic, 120, 4_200, 0.58, duration=0.24)
        events = ((3.10, card, -0.18, 0.25), (8.65, token, 0.18, 0.32),
                  (13.10, card, 0.08, 0.22), (18.25, token, 0.28, 0.27))
    for start, clip, pan, gain in events:
        place_event(result, clip, start, pan, gain)
    return master(result, target_rms=0.060, peak_limit=0.60)


def signature_contact(knock_source: np.ndarray) -> np.ndarray:
    result = np.zeros((FRAME_COUNT, 2), dtype=np.float64)
    knock = event_clip(knock_source, 95, 6_200, 0.66, duration=0.30)
    for start in (1.25, 6.25, 11.25, 16.25):
        place_event(result, knock, start, 0, 0.82)
    return result


def broadband_time_grain() -> np.ndarray:
    count = FRAME_COUNT + int(round(ROOM_CROSSFADE * SAMPLE_RATE))
    rng = np.random.default_rng(1_999)
    mono = filtered(rng.standard_normal((count, 1)), 280, 9_200)[:, 0]
    shimmer = filtered(rng.standard_normal((count, 1)), 3_800, 11_500)[:, 0]
    signal = mono * 0.82 + shimmer * 0.12
    centered = np.column_stack((signal, signal))
    return seamless_room(centered, target_rms=0.060)


def write_wav(path: Path, signal: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.rint(np.clip(signal, -1, 1) * 32_767).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm.tobytes())


def build(output_dir: Path, source_cache: Path) -> None:
    paths = {key: pinned_download(source, source_cache)
             for key, source in SOURCES.items()}
    with tempfile.TemporaryDirectory(prefix="poch-first-run-audio-") as directory:
        scratch = Path(directory)
        cards = decode_segment(paths["cards"], scratch, 0, 0.50)
        coin = decode_segment(paths["coin"], scratch, 50.75, 0.52)
        ceramic = decode_segment(paths["ceramic"], scratch, 0, 0.32)
        knock = decode_segment(paths["knock"], scratch, 2.203, 0.32)
        outputs = {
            "first-run-origin-room.wav": historical_tavern_room(),
            "first-run-origin-motif.wav": era_motif(True, cards, coin, ceramic),
            "first-run-present-room.wav": present_lounge_room(),
            "first-run-present-motif.wav": era_motif(False, cards, coin, ceramic),
            "first-run-signature-contact.wav": signature_contact(knock),
            "first-run-time-noise.wav": broadband_time_grain(),
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
