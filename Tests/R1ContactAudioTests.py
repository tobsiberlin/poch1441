#!/usr/bin/env python3
"""Deterministic material and rebuild gate for the unified R1 Foley path."""

from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import build_r1_contact_audio as builder  # noqa: E402


def expect(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    runtime = (ROOT / "App/R1ContactAudio.swift").read_text(encoding="utf-8")
    table = (ROOT / "App/TableFoleyAudio.swift").read_text(encoding="utf-8")
    effects = (ROOT / "App/Effects.swift").read_text(encoding="utf-8")
    receipt_path = (
        ROOT / "tasks/reviews/r1-contact-audio-v2/Evidence/audio-fingerprint-receipt.json"
    )
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))

    expect(receipt["technicalVerdict"] == "GREEN",
           "The objective ceramic fingerprint gate must be green")
    expect(receipt["humanIPhoneSpeakerVerdict"]
           == "PENDING_NEW_CERAMIC_FOLEY_TESTFLIGHT",
           "Objective checks must not forge the physical-iPhone listening verdict")
    expect(all(source["recordedMaterial"] == "real clay/ceramic poker chips"
               for source in receipt["sources"]),
           "No R1 family may return to metal-coin or plastic source material")
    expect("lastContactTime" not in runtime and "systemUptime" not in runtime,
           "Distinct accepted impacts must never be suppressed by wall time")
    expect("private static let voiceCount = 6" in runtime
           and "register(eventKey)" in runtime,
           "One identity ledger and overlapping voice pool must own R1 playback")
    expect("R1ContactAudio.shared.play(" in table
           and "final class R1ContactAudio" not in effects,
           "Table transfers and root contact modifiers must use the same pipeline")

    with tempfile.TemporaryDirectory(prefix="poch-r1-audio-test-") as directory:
        scratch = Path(directory)
        rebuilt = scratch / "audio"
        rebuilt_receipt = scratch / "receipt.json"
        result = builder.build(
            rebuilt,
            rebuilt_receipt,
            ROOT / ".build/audio-source-cache",
        )
        expect(result["technicalVerdict"] == "GREEN",
               "A clean rebuild must satisfy the objective material gate")
        for family in ("outer", "center", "stack"):
            for variant in range(1, 4):
                name = f"r1-ceramic-{family}-{variant:02d}.caf"
                expect((rebuilt / name).read_bytes()
                       == (ROOT / "App/Audio" / name).read_bytes(),
                       f"{name} must rebuild byte-identically")

    print("R1ContactAudioTests: PASS")


if __name__ == "__main__":
    main()
