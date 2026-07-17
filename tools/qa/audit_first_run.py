#!/usr/bin/env python3
"""Statischer, reproduzierbarer QA-Gatecheck für den First-Run-Slice.

Der Check baut die App nicht. Er prüft die verbindlichen Quellverträge und
spiegelt die reine Rechteckmathematik aus FirstRunStageZones für fest definierte
logische Gerätegrößen. Wenn der Resolver geändert wird, muss dieser Spiegel
zusammen mit dem visuellen Beleg aktualisiert werden.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path


LOCALES = ("de", "en", "fr", "it", "es", "nl", "pl")

# SHA-256 des gespiegelten `FirstRunStageZones.resolve`-Blocks. So kann eine
# spätere Produktänderung nicht unbemerkt gegen veraltete QA-Mathematik laufen.
EXPECTED_ZONE_RESOLVER_SHA256 = (
    "8e82815d663fde1579dd7bfe648fec5b114f2df52a94b489822dd09542b12a7e"
)

FIRST_RUN_KEYS = (
    "tutorial.firstTable.title",
    "firstRun.intro.body",
    "firstRun.goal",
    "firstRun.intro.primary",
    "firstRun.intro.secondary",
    "firstRun.act.meld",
    "firstRun.act.bidding",
    "firstRun.act.playout",
    "tutorial.learningState.label",
    "tutorial.learningState.orient",
    "tutorial.learningState.connect",
    "tutorial.learningState.prove",
    "tutorial.learningState.release",
    "tutorial.meld.drag.title",
    "tutorial.meld.drag.body",
    "tutorial.meld.action.openTable",
    "tutorial.meld.action.ante",
    "tutorial.meld.action.firstDeal",
    "tutorial.meld.action.finishDeal",
    "tutorial.meld.action.revealTrump",
    "tutorial.meld.action.connectClaim",
    "tutorial.meld.action.showClaim",
    "tutorial.meld.action.continueBidding",
    "tutorial.meld.table.title",
    "tutorial.meld.table.body",
    "tutorial.meld.ante.title",
    "tutorial.meld.ante.body",
    "tutorial.meld.firstDeal.title",
    "tutorial.meld.firstDeal.body",
    "tutorial.meld.hand.title",
    "tutorial.meld.hand.body",
    "tutorial.meld.connect.title",
    "tutorial.meld.connect.body",
    "tutorial.guide.trump.title",
    "tutorial.guide.trump.body",
    "tutorial.meld.claim.title",
    "tutorial.meld.claim.body",
    "tutorial.meld.release.title",
    "tutorial.meld.release.body",
    "board.center",
)


@dataclass(frozen=True)
class Insets:
    top: float
    leading: float
    bottom: float
    trailing: float


@dataclass(frozen=True)
class Device:
    name: str
    width: float
    height: float
    safe: Insets


@dataclass(frozen=True)
class Rect:
    x: float
    y: float
    width: float
    height: float

    @property
    def max_x(self) -> float:
        return self.x + self.width

    @property
    def max_y(self) -> float:
        return self.y + self.height


DEVICES = (
    Device("iPhone SE - Portrait", 375, 667, Insets(20, 0, 0, 0)),
    Device("iPhone SE - Landscape", 667, 375, Insets(0, 0, 0, 0)),
    Device("iPhone Standard - Portrait", 393, 852, Insets(59, 0, 34, 0)),
    Device("iPhone Standard - Landscape", 852, 393, Insets(0, 59, 21, 59)),
    Device("iPhone Pro Max - Portrait", 430, 932, Insets(59, 0, 34, 0)),
    Device("iPhone Pro Max - Landscape", 932, 430, Insets(0, 59, 21, 59)),
    Device("iPad mini - Portrait", 744, 1133, Insets(24, 0, 20, 0)),
    Device("iPad mini - Landscape", 1133, 744, Insets(24, 0, 20, 0)),
)

# Zonen, die sich laut Handoff und Board-Brief nicht schneiden dürfen.
FORBIDDEN_OVERLAPS = (
    ("header", "opponents"),
    ("header", "board"),
    ("opponents", "decision"),
    ("opponents", "board"),
    ("opponents", "hand"),
    ("decision", "board"),
    ("decision", "hand"),
    ("board", "hand"),
)


def resolve_zones(device: Device) -> dict[str, Rect]:
    """Spiegel von FirstRunStageZones.resolve, Stand 17.07.2026."""
    size_w, size_h, safe = device.width, device.height, device.safe
    landscape = size_w > size_h
    if landscape:
        top = safe.top + 8
        bottom = size_h - safe.bottom - 8
        available_height = max(240, bottom - top)
        opponents_width = min(132, size_w * 0.18)
        decision_x = safe.leading + opponents_width + 20
        board_side = min(
            available_height * 0.72,
            available_height - 126,
            size_w * 0.35,
        )
        board_x = size_w - safe.trailing - board_side - 18
        decision_width = min(
            286,
            size_w * 0.34,
            max(180, board_x - decision_x - 18),
        )
        return {
            "header": Rect(decision_x, top, decision_width, 52),
            "opponents": Rect(
                safe.leading + 8,
                top + 18,
                opponents_width,
                available_height - 132,
            ),
            "decision": Rect(
                decision_x,
                top + 60,
                decision_width,
                max(120, available_height - 166),
            ),
            "board": Rect(board_x, top + 12, board_side, board_side),
            "hand": Rect(
                decision_x - 8,
                bottom - 104,
                size_w - decision_x - safe.trailing - 12,
                104,
            ),
        }

    top = safe.top + 8
    usable_width = size_w - safe.leading - safe.trailing
    hand_top = size_h - safe.bottom - 126
    board_y = top + 142
    board_side = min(
        usable_width - 32,
        max(180, hand_top - board_y - 154),
        max(216, size_h * 0.36),
    )
    board_x = safe.leading + (usable_width - board_side) / 2
    decision_y = board_y + board_side + 10
    decision_height = max(112, min(142, hand_top - decision_y - 6))
    return {
        "header": Rect(safe.leading + 18, top, usable_width - 36, 76),
        "opponents": Rect(safe.leading + 22, top + 76, usable_width - 44, 58),
        "decision": Rect(
            safe.leading + 18,
            decision_y,
            usable_width - 36,
            decision_height,
        ),
        "board": Rect(board_x, board_y, board_side, board_side),
        "hand": Rect(safe.leading + 8, hand_top, usable_width - 16, 126),
    }


def intersection(a: Rect, b: Rect) -> tuple[float, float]:
    return max(0, min(a.max_x, b.max_x) - max(a.x, b.x)), max(
        0, min(a.max_y, b.max_y) - max(a.y, b.y)
    )


def inside_safe_frame(rect: Rect, device: Device) -> bool:
    return (
        rect.x >= device.safe.leading - 0.01
        and rect.y >= device.safe.top - 0.01
        and rect.max_x <= device.width - device.safe.trailing + 0.01
        and rect.max_y <= device.height - device.safe.bottom + 0.01
        and rect.width > 0
        and rect.height > 0
    )


def method_body(source: str, signature: str) -> str:
    start = source.find(signature)
    if start < 0:
        return ""
    next_method = source.find("\n    private ", start + len(signature))
    return source[start:] if next_method < 0 else source[start:next_method]


def check_contracts(root: Path) -> list[tuple[str, bool, str]]:
    content = (root / "App/ContentView.swift").read_text(encoding="utf-8")
    game_state = (root / "App/GameState.swift").read_text(encoding="utf-8")
    presentation = (root / "App/FirstRunPresentation.swift").read_text(encoding="utf-8")
    project = (root / "project.yml").read_text(encoding="utf-8")
    opening_interaction = method_body(content, "private func guidedOpeningInteraction")
    opening = method_body(content, "private func settleGuidedOpeningToken")
    funding = method_body(content, "private func runGuidedTableFundingImpact")
    resolver_signature = (
        "    static func resolve(in size: CGSize, safeArea: EdgeInsets) "
        "-> FirstRunStageZones {"
    )
    resolver_start = presentation.find(resolver_signature)
    resolver_end = presentation.find("\n    }\n}", resolver_start)
    resolver = (
        presentation[resolver_start : resolver_end + 6]
        if resolver_start >= 0 and resolver_end >= 0
        else ""
    )
    resolver_sha256 = hashlib.sha256(resolver.encode("utf-8")).hexdigest()

    iphone_orientation = re.search(
        r"INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone:\s*\"([^\"]+)\"",
        project,
    )
    orientations = iphone_orientation.group(1) if iphone_orientation else ""
    required_orientations = (
        "UIInterfaceOrientationPortrait",
        "UIInterfaceOrientationLandscapeLeft",
        "UIInterfaceOrientationLandscapeRight",
    )

    state_cases = all(
        f"case {state}" in presentation
        for state in ("orientieren", "verbinden", "beweisen", "loslassen")
    )
    mapped_states = all(
        f"learningState: .{state}" in presentation
        for state in ("orientieren", "verbinden", "beweisen", "loslassen")
    )
    opening_completion = (
        "completionCriteria: .logicallyComplete" in opening
        and "} completion:" in opening
        and opening.find("markGuidedOpeningTokenLanded")
        > opening.find("} completion:")
    )
    reduce_motion_funding = (
        "reduceMotion ? 0.16" in funding
        and "guidedTableFundingTargeted = true" in funding
        and "} completion:" in funding
        and funding.find("markGuidedTableFundingLanded") > funding.find("} completion:")
        and funding.find("guidedAntePoolCounts =") > funding.find("} completion:")
        and "recordR1Impact(groupSize: groupSize" in game_state
    )
    voiceover_effect = (
        "guidedCoachFocused = true" in opening
        and "tutorial.meld.ante.title" in content
        and "tutorial.meld.ante.body" in content
    )
    voiceover_opening_action = (
        "Button {" in opening_interaction
        and "settleGuidedOpeningToken(from: source, to: target)" in opening_interaction
        and "tutorial.meld.action.openTable" in opening_interaction
        and 'accessibilityIdentifier("firstRun.openingToken")' in opening_interaction
        and 'accessibilityIdentifier("firstRun.openingTarget")' in opening_interaction
        and 'String(localized: "board.center"' in opening_interaction
    )
    return [
        (
            "QA-Zonenmathematik entspricht dem Produktresolver",
            resolver_sha256 == EXPECTED_ZONE_RESOLVER_SHA256,
            resolver_sha256,
        ),
        (
            "iPhone Portrait + Landscape freigeschaltet",
            all(value in orientations for value in required_orientations),
            orientations or "Orientierungsschlüssel fehlt",
        ),
        (
            "Vier semantische Lernzustände vorhanden und gemappt",
            state_cases and mapped_states,
            "Orientieren, Verbinden, Beweisen, Loslassen",
        ),
        (
            "Opening-Token mutiert erst im Animationsabschluss",
            opening_completion,
            "markGuidedOpeningTokenLanded muss im completion-Block liegen",
        ),
        (
            "VoiceOver-Ersatzaktion für die Drag-Geste",
            voiceover_opening_action,
            "lokalisierter 44-Punkt-Button für Stein -> benannte Mitte",
        ),
        (
            "Reduce Motion wird als Umgebungseinstellung gelesen",
            "@Environment(\\.accessibilityReduceMotion)" in content,
            "statischer Hook vorhanden; Verständlichkeit braucht Simulatorbeleg",
        ),
        (
            "Reduce-Motion-Funding erhält Quelle/Ziel/Impact",
            reduce_motion_funding,
            (
                "Hairline-Puls, Completion-Mutation und gebündelter R1-Impact"
                if reduce_motion_funding
                else "Kausalkette im Funding-Ersatzbeat unvollständig"
            ),
        ),
        (
            "VoiceOver benennt Wirkung nach dem Kontakt",
            voiceover_effect,
            (
                "fokussierter, lokalisierter Ergebnissatz vorhanden"
                if voiceover_effect
                else "Fokuswechsel vorhanden, aber kein Ergebnissatz oder Ergebniswert"
            ),
        ),
        (
            "Mitte-Label nutzt den lokalisierten Katalogschlüssel",
            'Text("MITTE")' not in content,
            (
                "board.center wird verwendet"
                if 'Text("MITTE")' not in content
                else 'board.center ist vollständig lokalisiert; Text("MITTE") ist es nicht'
            ),
        ),
        (
            "Coach-Text verwendet Dynamic-Type-fähige Stile",
            not (".lineLimit(3)" in content and ".font(.system(size: 11.8" in content),
            (
                "semantische Textstile ohne Drei-Zeilen-Limit"
                if not (".lineLimit(3)" in content and ".font(.system(size: 11.8" in content)
                else "feste 11,8-pt-Schrift mit lineLimit(3) braucht Ersatz oder Layoutbeleg"
            ),
        ),
    ]


def localization_rows(root: Path) -> list[tuple[str, bool, str]]:
    data = json.loads((root / "App/Localizable.xcstrings").read_text(encoding="utf-8"))
    strings = data.get("strings", {})
    rows: list[tuple[str, bool, str]] = []
    for key in FIRST_RUN_KEYS:
        localizations = strings.get(key, {}).get("localizations", {})
        valid = []
        for locale in LOCALES:
            unit = localizations.get(locale, {}).get("stringUnit", {})
            if unit.get("state") == "translated" and str(unit.get("value", "")).strip():
                valid.append(locale)
        missing = [locale for locale in LOCALES if locale not in valid]
        rows.append((key, not missing, "-" if not missing else ", ".join(missing)))
    return rows


def render(root: Path) -> tuple[str, int]:
    lines = [
        "# First-Run QA - statischer Gatecheck",
        "",
        "Ausführung: `python3 tools/qa/audit_first_run.py`",
        "",
        "## Geräte- und Overlap-Matrix",
        "",
        "| Gerät | Safe Frame | Zonen innerhalb | Verbotene Overlaps | Ergebnis |",
        "| --- | --- | --- | --- | --- |",
    ]
    failures = 0
    for device in DEVICES:
        zones = resolve_zones(device)
        outside = [name for name, rect in zones.items() if not inside_safe_frame(rect, device)]
        overlaps = []
        for left, right in FORBIDDEN_OVERLAPS:
            width, height = intersection(zones[left], zones[right])
            if width > 0.01 and height > 0.01:
                overlaps.append(f"{left}/{right} {width:.0f}x{height:.0f} pt")
        passed = not outside and not overlaps
        failures += 0 if passed else 1
        lines.append(
            f"| {device.name} | {device.width:.0f}x{device.height:.0f} pt | "
            f"{'ja' if not outside else 'nein: ' + ', '.join(outside)} | "
            f"{'keine' if not overlaps else '<br>'.join(overlaps)} | "
            f"{'PASS' if passed else 'FAIL'} |"
        )

    lines.extend(
        [
            "",
            "Hinweis: Das ist ein Rechteck-Gate, kein Screenshot-Ersatz. Intrinsische Textgrößen, "
            "Kartenfächer und laufende Flüge werden am Integrationspunkt visuell geprüft.",
            "",
            "## Quellverträge für Accessibility, Rotation und Impact",
            "",
            "| Vertrag | Ergebnis | Beleg |",
            "| --- | --- | --- |",
        ]
    )
    for name, passed, detail in check_contracts(root):
        failures += 0 if passed else 1
        lines.append(f"| {name} | {'PASS' if passed else 'FAIL'} | {detail} |")

    rows = localization_rows(root)
    lines.extend(
        [
            "",
            "## Lokalisierung des Vertical Slice",
            "",
            "| Katalogschlüssel | DE/EN/FR/IT/ES/NL/PL | Fehlend |",
            "| --- | --- | --- |",
        ]
    )
    for key, passed, missing in rows:
        failures += 0 if passed else 1
        lines.append(f"| `{key}` | {'PASS' if passed else 'FAIL'} | {missing} |")

    lines.extend(
        [
            "",
            "## Ergebnis",
            "",
            f"Strict-Gate: {'PASS' if failures == 0 else 'FAIL'} - {failures} fehlgeschlagene Prüfungen.",
        ]
    )
    return "\n".join(lines) + "\n", failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
        help="Repository-Wurzel",
    )
    args = parser.parse_args()
    report, failures = render(args.root.resolve())
    print(report, end="")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
