#!/usr/bin/env python3
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "Evidence"
V3_ROOT = ROOT.parent / "card-deal-rhythm-wallclock-v3"
FROZEN_FILES = {
    "Sources/DealRhythmContract.swift": "2294f03d7fa1079b737ff6274aad36555d1a3acad018b8f0f0659a3251e8487c",
    "Sources/RhythmHarnessModel.swift": "37760e68efee123be56c6f9ae8e3a6ed06ed4ca2b16087c856082367544aacfe",
    "Sources/RhythmHarnessStage.swift": "48bc7fc8646b24b3ae847dbd660994ad2f0347950729d447843fe34b1916db85",
    "Sources/W2CardBody.swift": "b5c745e86aae6c3cab7ebb7cd43589885067db60612dc95b4ea38b7e6ad53aac",
    "Scripts/verify_evidence.py": "ef11bdb73f3212f1f14a7ab6549515bf6e62e567a4950cbb252453d9f52dd15b",
    "Scripts/VideoInspector.swift": "a86915e6ad6e207af688c98b34a78756fa844cbb5c58bb9a2dd80a1d572ca4bf",
    "Scripts/make_encoded_review_strips.py": "15dead7b50ea94d4c9b25833c14bb9c4e138ab7aef5d81db4855b64b3c903ee0",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    frozen_receipt = {}
    for relative, expected_hash in FROZEN_FILES.items():
        local = ROOT / relative
        v3 = V3_ROOT / relative
        require(local.is_file() and v3.is_file(), f"Frozen source missing: {relative}")
        local_hash = sha256(local)
        require(local_hash == expected_hash, f"V4 frozen source drift: {relative}")
        require(local.read_bytes() == v3.read_bytes(), f"V4/V3 byte mismatch: {relative}")
        frozen_receipt[relative] = local_hash

    subprocess.run(
        [sys.executable, str(ROOT / "Scripts/verify_evidence.py")],
        check=True,
        env=os.environ.copy(),
    )
    subprocess.run(
        [sys.executable, str(ROOT / "Scripts/verify_orientation.py")],
        check=True,
    )

    base_receipt = EVIDENCE / "verification.json"
    orientation_receipt = EVIDENCE / "orientation-verification.json"
    require(json.loads(base_receipt.read_text())["result"] == "PASS", "Timing verifier failed")
    require(json.loads(orientation_receipt.read_text())["result"] == "PASS", "Orientation verifier failed")
    aggregate = {
        "schemaVersion": 1,
        "result": "PASS",
        "humanReviewStatus": "HUMAN_PENDING",
        "productionIntegrationAllowed": False,
        "baseTimingReceipt": {
            "file": base_receipt.name,
            "sha256": sha256(base_receipt),
        },
        "decodedOrientationReceipt": {
            "file": orientation_receipt.name,
            "sha256": sha256(orientation_receipt),
        },
        "frozenV3Files": frozen_receipt,
    }
    (EVIDENCE / "v4-verification.json").write_text(
        json.dumps(aggregate, indent=2, sort_keys=True) + "\n"
    )
    human_pending = {
        "schemaVersion": 1,
        "technicalGate": "GREEN",
        "humanWallclockGate": "HUMAN_PENDING",
        "productGate": "PENDING",
        "productionIntegrationAllowed": False,
        "requiredHumanChecks": [
            "QuickTime playback is upright for Standard, Reduced Motion, and Cancellation",
            "motion cadence and physical continuity remain visually coherent",
            "committed cancellation cards visibly complete travel, contact, settle, and rest",
        ],
    }
    (EVIDENCE / "human-wallclock-verdict.json").write_text(
        json.dumps(human_pending, indent=2, sort_keys=True) + "\n"
    )
    (EVIDENCE / "v4-verified.complete").write_text("verified; human pending\n")
    print("CardDealRhythmEvidenceV4: TECHNICAL PASS; HUMAN_PENDING")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"CardDealRhythmEvidenceV4: FAIL - {error}", file=sys.stderr)
        raise
