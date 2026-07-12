#!/usr/bin/env python3
"""Install normalized opponent portraits into the Xcode asset catalog."""

import json
import shutil
from pathlib import Path


ROOT = Path("/Users/tobsi/poch1441")
SOURCE = ROOT / "artifacts" / "opponent-expression-normalized"
DESTINATION = ROOT / "App" / "Assets.xcassets" / "Opponents"
PEOPLE = ("Liv", "Mara", "Nina", "Thomas", "Jonas", "Leon", "Noah", "Finn", "Hana", "Darius", "Samir")
STATES = ("Neutral", "Thinking", "Pressure", "Surprised", "Winning", "Defeated")


def main() -> None:
    DESTINATION.mkdir(parents=True, exist_ok=True)
    for person in PEOPLE:
        for state in STATES:
            asset_name = f"Opponent{person}{state}"
            imageset = DESTINATION / f"{asset_name}.imageset"
            imageset.mkdir(parents=True, exist_ok=True)
            filename = f"{asset_name}.png"
            shutil.copy2(SOURCE / person / f"{state}.png", imageset / filename)
            contents = {
                "images": [
                    {
                        "filename": filename,
                        "idiom": "universal",
                        "scale": "1x",
                    },
                    {"idiom": "universal", "scale": "2x"},
                    {"idiom": "universal", "scale": "3x"},
                ],
                "info": {"author": "xcode", "version": 1},
            }
            (imageset / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")

    print(f"installed {len(PEOPLE) * len(STATES)} portrait assets")


if __name__ == "__main__":
    main()
