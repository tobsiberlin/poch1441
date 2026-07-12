#!/usr/bin/env python3
"""Prüft explizite Swift-String-Keys gegen den Poch-1441-String-Katalog."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "App"
CATALOG = APP / "Localizable.xcstrings"
REQUIRED_LANGUAGES = {"de", "en", "es", "fr", "it", "nl", "pl"}
KEY_PATTERN = re.compile(r'String\(localized:\s*"([^"]+)"')


def main() -> int:
    strings = json.loads(CATALOG.read_text(encoding="utf-8"))["strings"]
    references: dict[str, list[str]] = {}

    for source in sorted(APP.glob("*.swift")):
        text = source.read_text(encoding="utf-8")
        for match in KEY_PATTERN.finditer(text):
            line = text.count("\n", 0, match.start()) + 1
            references.setdefault(match.group(1), []).append(f"{source.relative_to(ROOT)}:{line}")

    failures: list[str] = []
    for key, locations in sorted(references.items()):
        entry = strings.get(key)
        if entry is None:
            failures.append(f"FEHLT: {key} ({', '.join(locations)})")
            continue
        available = set(entry.get("localizations", {}))
        missing = sorted(REQUIRED_LANGUAGES - available)
        if missing:
            failures.append(
                f"UNVOLLSTÄNDIG: {key} - {', '.join(missing)} ({', '.join(locations)})"
            )

    if failures:
        print("\n".join(failures))
        return 1

    print(
        f"OK: {len(references)} explizite Keys, "
        f"alle in {len(REQUIRED_LANGUAGES)} Zielsprachen vorhanden."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
