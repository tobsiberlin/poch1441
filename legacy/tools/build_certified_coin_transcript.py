#!/usr/bin/env python3
"""Extract the admitted seed-1441 rest-certified transcript deterministically."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tasks/reviews/coin-motion-transcript-gate-v1/Evidence/coin-6dof-transcripts-12-seeds.json"
OUTPUT = ROOT / "App/CertifiedCoinTranscriptSeed1441.json"
EXPECTED_SOURCE_SHA256 = "76e883093a396548b07060d29d3f2149857240c1026cd1fefe35450de52d98be"
SEED = 1_441


def main() -> None:
    source_data = SOURCE.read_bytes()
    source_sha256 = hashlib.sha256(source_data).hexdigest()
    if source_sha256 != EXPECTED_SOURCE_SHA256:
        raise SystemExit(f"unexpected transcript SHA-256: {source_sha256}")

    source = json.loads(source_data)
    transcript = next(item for item in source["transcripts"] if item["seed"] == SEED)
    rest_index = next(
        index
        for index, sample in enumerate(transcript["samples"])
        if "restCertified" in sample["contacts"]
    )
    admitted = dict(transcript)
    admitted["samples"] = transcript["samples"][: rest_index + 1]

    payload = {
        "schema": "poch.certified-coin-transcript.v1",
        "stableID": "coin.track-b.queen.drop.seed-1441.v1",
        "sourceBundleSHA256": source_sha256,
        "sourceSchema": source["schema"],
        "sampleRateHertz": source["sampleRateHertz"],
        "materialFamily": "copperCent",
        "worldLightID": "track-b-lamp-left-v1",
        "surfaceID": "queen-outer-well",
        "selection": source["selection"],
        "transcript": admitted,
    }
    encoded = json.dumps(payload, ensure_ascii=True, separators=(",", ":"), sort_keys=True)
    OUTPUT.write_text(encoded + "\n", encoding="utf-8")
    print(f"wrote {OUTPUT.relative_to(ROOT)} ({len(admitted['samples'])} samples)")


if __name__ == "__main__":
    main()
