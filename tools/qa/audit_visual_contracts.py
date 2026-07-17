#!/usr/bin/env python3
"""Prüft objektive Verträge der aktuellen Tisch- und First-Run-Gestaltung.

Das Skript bewertet keine Schönheit. Es findet reproduzierbar benennbare
Kanonbrüche, Vollständigkeitslücken und Risiken, die anschließend anhand echter
Screenshots menschlich abgenommen werden müssen.
"""

from __future__ import annotations

import re
import struct
import sys
from dataclasses import dataclass
from pathlib import Path


EXPECTED_POOLS = ("king", "queen", "mariage", "jack", "ten", "sequence", "poch", "ace")
READABILITY_GATES = (360, 180, 120, 64)


@dataclass(frozen=True)
class Finding:
    level: str
    identifier: str
    detail: str


def section(source: str, start: str, end: str) -> str:
    start_index = source.find(start)
    if start_index < 0:
        return ""
    end_index = source.find(end, start_index + len(start))
    return source[start_index:] if end_index < 0 else source[start_index:end_index]


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        signature = handle.read(24)
    if len(signature) != 24 or signature[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Kein lesbares PNG: {path}")
    return struct.unpack(">II", signature[16:24])


def count_terms(source: str, terms: tuple[str, ...]) -> int:
    pattern = "|".join(re.escape(term) for term in terms)
    return len(re.findall(pattern, source, flags=re.IGNORECASE))


def without_swift_comments(source: str) -> str:
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.DOTALL)
    return re.sub(r"//.*", "", source)


def typography_findings(content: str) -> list[Finding]:
    intro = section(content, "private var firstRunIntro", "private func startGuidedRound")
    learning = section(content, "private var guidedOpeningHeader", "private func advanceGuidedMeld")
    combined = intro + learning
    fixed_fonts = len(re.findall(r"\.font\(\.system\(size:", combined))
    semantic_fonts = len(
        re.findall(
            r"\.font\(\.(?:largeTitle|title|title2|title3|headline|body|callout|subheadline|footnote|caption)",
            combined,
        )
    )
    scale_factors = [float(value) for value in re.findall(r"minimumScaleFactor\((0\.\d+)\)", combined)]
    low_alpha_text = [
        float(value)
        for value in re.findall(
            r"foregroundStyle\([^\n]*?\.opacity\((0\.\d+)\)", combined
        )
        if float(value) < 0.75
    ]
    capsules = len(re.findall(r"\bCapsule\(\)", combined))

    findings = [
        Finding(
            "WARN" if fixed_fonts else "PASS",
            "TYPE-SCALING",
            f"First Run: {fixed_fonts} feste Systemgrößen, {semantic_fonts} semantische Textstile. "
            "Feste Board-Mikrolabels sind zulässig; erklärender Text braucht Screenshot-Nachweis mit Dynamic Type.",
        ),
        Finding(
            "WARN" if any(value < 0.8 for value in scale_factors) else "PASS",
            "TYPE-SHRINK",
            "MinimumScaleFactor-Werte im First Run: "
            + (", ".join(f"{value:.2f}" for value in scale_factors) if scale_factors else "keine"),
        ),
        Finding(
            "WARN" if low_alpha_text else "PASS",
            "TEXT-ALPHA",
            f"{len(low_alpha_text)} Textfarben unter 0,75 Alpha im First Run. "
            "Das ist nur ein Kontrastrisiko; der echte Kontrast muss im Screenshot gemessen werden.",
        ),
        Finding(
            "WARN" if capsules > 4 else "PASS",
            "PILL-DENSITY",
            f"{capsules} Capsule-Flächen im First-Run-/Lernbereich. Schwelle 4 löst nur menschliche Hierarchieprüfung aus.",
        ),
    ]
    return findings


def audit(root: Path) -> list[Finding]:
    app = root / "App"
    content = (app / "ContentView.swift").read_text(encoding="utf-8")
    ring = (app / "PochRing.swift").read_text(encoding="utf-8")
    theme = (app / "Theme.swift").read_text(encoding="utf-8")
    tokens = (app / "DesignTokens.swift").read_text(encoding="utf-8")
    components = (app / "PlayComponents.swift").read_text(encoding="utf-8")
    swift_files = sorted(app.glob("*.swift"))
    all_swift = "\n".join(path.read_text(encoding="utf-8") for path in swift_files)
    product_catalog = (app / "Localizable.xcstrings").read_text(encoding="utf-8")
    product_data = "\n".join(
        path.read_text(encoding="utf-8") for path in sorted(app.glob("*.json"))
    )
    asset_names = "\n".join(path.name for path in (app / "Assets.xcassets").rglob("*.imageset"))
    findings: list[Finding] = []

    anchor_block = section(ring, "static let anchors", "    ]")
    pools = tuple(re.findall(r"RingAnchor\(pool: \.(\w+)", anchor_block))
    findings.append(
        Finding(
            "PASS" if pools == EXPECTED_POOLS else "FAIL",
            "BOARD-8+1",
            f"Außenfelder: {', '.join(pools) or 'nicht gefunden'}; Mitte wird separat gerendert.",
        )
    )

    board_asset = app / "Assets.xcassets/PochDisc2026.imageset/poch-disc-2026.png"
    try:
        width, height = png_size(board_asset)
        asset_ok = width == height and width >= max(READABILITY_GATES) * 2
        asset_detail = f"Track-A-Asset {width}x{height} px; 2x-Basis für 360 px {'erfüllt' if asset_ok else 'nicht erfüllt'}."
    except (OSError, ValueError) as error:
        asset_ok = False
        asset_detail = str(error)
    findings.append(Finding("PASS" if asset_ok else "FAIL", "TRACK-A-ASSET", asset_detail))

    real_board_in_first_run = (
        'TableWorldBoardBase(world: .pochDisc' in section(content, "private var firstRunIntro", "private func startGuidedRound")
        and 'Image("PochDisc2026")' in components
        and 'accessibilityIdentifier("firstRun.intro.board")' in content
    )
    findings.append(
        Finding(
            "PASS" if real_board_in_first_run else "FAIL",
            "FIRST-RUN-REAL-DISC",
            "First Run verwendet das Track-A-Asset und identifiziert die Disc für UI-QA."
            if real_board_in_first_run
            else "First Run verwendet die echte Track-A-Disc nicht eindeutig.",
        )
    )

    historical_pm49_live = "PochRingPM49" in all_swift or "PM49Geometry" in all_swift
    findings.append(
        Finding(
            "FAIL" if historical_pm49_live else "PASS",
            "TRACK-A-NORTHSTAR",
            "Historisches PM49 ist weiterhin als Live-Renderer oder Geometrieanker aktiv."
            if historical_pm49_live
            else "Track A verwendet die kanonische 2026-Disc statt PM49 als Designanker.",
        )
    )

    overlay_labels = (
        "ForEach(PochRing.anchors)" in content
        and "TableWorldBoardGeometry.notationCenter" in content
        and 'String(localized: "board.center"' in content
    )
    findings.append(
        Finding(
            "PASS" if overlay_labels else "FAIL",
            "BOARD-LABEL-LAYER",
            "Acht Außenlabels und Mitte besitzen eine lokalisierbare UI-Ebene."
            if overlay_labels
            else "Die vollständige lokalisierbare 8+1-Beschriftung ist statisch nicht nachweisbar.",
        )
    )

    r1_ready = all(term in components for term in ("enum R1Colorway", "struct R1Token", "R1BlindEmboss", "R1TokenSlots"))
    first_run_uses_r1 = "TableTokenPile" in section(content, "private var firstRunIntro", "private func startGuidedRound")
    findings.append(
        Finding(
            "PASS" if r1_ready and first_run_uses_r1 else "FAIL",
            "TRACK-A-R1",
            "R1-Farbwelt, Blindprägung, deterministische Endlagen und First-Run-Nutzung sind vorhanden."
            if r1_ready and first_run_uses_r1
            else "R1 ist nicht vollständig als aktueller First-Run-Spielstein nachweisbar.",
        )
    )

    live_theme_source = without_swift_comments("\n".join((theme, content, tokens, ring)))
    old_theme_hits = count_terms(live_theme_source, ("premium", "neon", "vivid"))
    findings.append(
        Finding(
            "FAIL" if old_theme_hits else "PASS",
            "WORLD-CANON",
            f"{old_theme_hits} Live-Code-Vorkommen von Premium/Neon/Vivid; Ziel ist Poch Disc/Unterwegs."
            if old_theme_hits
            else "Keine alten Premium/Neon/Vivid-Weltnamen im geprüften Live-Code.",
        )
    )

    historical_terms = (
        "königliche krypta",
        "krypta",
        "gilde",
        "liga",
        "prestige",
        "pm100",
        "pm68",
        "gametokenglass",
    )
    current_product_surface = without_swift_comments(all_swift) + product_catalog + product_data
    historical_hits = count_terms(current_product_surface, historical_terms)
    findings.append(
        Finding(
            "FAIL" if historical_hits else "PASS",
            "PRESENT-DAY-CANON",
            f"{historical_hits} verworfene historische Begriffe in Live-Code, Produktdaten oder Lokalisierung."
            if historical_hits
            else "Keine verworfene Krypta-/Gilde-/Liga-/Prestige-/PM100-Richtung in den Produktquellen.",
        )
    )

    obsolete_concept_source = app / "BoardConceptView.swift"
    obsolete_concept_asset = app / "Assets.xcassets/PM100PM68Sim.imageset"
    obsolete_debug_concept = (
        obsolete_concept_source.exists()
        or obsolete_concept_asset.exists()
        or "BoardConceptView" in content
        or "-boardConcept" in content
    )
    findings.append(
        Finding(
            "FAIL" if obsolete_debug_concept else "PASS",
            "OBSOLETE-CONCEPT-PATH",
            "Die verworfene PM100-/Glas-Metall-Studie liegt noch im App-Baum oder ist erreichbar."
            if obsolete_debug_concept
            else "Keine verworfene Boardstudie im App-Baum oder erreichbaren Debug-Pfad.",
        )
    )

    executable_swift = without_swift_comments(all_swift)
    travel_path = app / "TravelTableComponents.swift"
    non_travel_swift = "\n".join(
        path.read_text(encoding="utf-8")
        for path in swift_files
        if path != travel_path
    )
    world_domain = re.search(
        r"enum\s+(?:TableWorld|TableEnvironment|TableStyle)[\s\S]{0,1000}",
        executable_swift,
        flags=re.IGNORECASE,
    )
    world_block = world_domain.group(0).lower() if world_domain else ""
    track_b_domain = "pochdisc" in world_block and any(
        term in world_block for term in ("unterwegs", "travel")
    )
    track_b_board = bool(re.search(r"struct\s+(?:TravelSnackTray|Unterwegs\w*)\s*:\s*View", all_swift))
    track_b_coin = bool(re.search(r"struct\s+(?:TravelCentCoin|OneCentCoin|CentCoin)\s*:\s*View", all_swift))
    track_b_integrated = "TravelSnackTray" in non_travel_swift
    track_b_assets = bool(re.search(r"(?:unterwegs|snack|tray|centcoin|onecent)", asset_names, flags=re.IGNORECASE))
    track_b_complete = track_b_domain and track_b_board and track_b_coin and track_b_integrated
    findings.append(
        Finding(
            "PASS" if track_b_complete else "FAIL",
            "TRACK-B-COMPLETE",
            "Unterwegs-Domäne={}, Board-Renderer={}, 1-Cent-Renderer={}, zentral integriert={}, eigene Raster-Assets={} (code-native ist zulässig).".format(
                "ja" if track_b_domain else "nein",
                "ja" if track_b_board else "nein",
                "ja" if track_b_coin else "nein",
                "ja" if track_b_integrated else "nein",
                "ja" if track_b_assets else "nein",
            ),
        )
    )

    glass_asset = "GameTokenGlass.imageset" in asset_names
    glass_live_reference = "GameTokenGlass" in all_swift
    findings.append(
        Finding(
            "FAIL" if glass_asset or glass_live_reference else "PASS",
            "LEGACY-MATERIAL-ASSET",
            "Das verworfene GameTokenGlass-Material liegt noch im App-Baum oder wird referenziert."
            if glass_asset or glass_live_reference
            else "Das verworfene GameTokenGlass-Material ist aus App-Baum und Live-Code entfernt.",
        )
    )

    findings.extend(typography_findings(content))
    findings.append(
        Finding(
            "WARN",
            "READABILITY-SCREENSHOTS",
            "Statisch vorbereitet: 360/180/120/64 px. Tatsächliche Label-, Material- und Belegungslesbarkeit braucht die menschliche Screenshot-Matrix.",
        )
    )
    return findings


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    findings = audit(root)
    print("Poch 1441 - visueller Vertragscheck (keine automatische Ästhetiknote)")
    print(f"Board-Lesegates: {', '.join(f'{gate} px' for gate in READABILITY_GATES)}")
    for finding in findings:
        print(f"[{finding.level}] {finding.identifier}: {finding.detail}")
    counts = {level: sum(item.level == level for item in findings) for level in ("PASS", "WARN", "FAIL")}
    print(f"Ergebnis: {counts['PASS']} PASS, {counts['WARN']} WARN, {counts['FAIL']} FAIL")
    return 1 if counts["FAIL"] else 0


if __name__ == "__main__":
    sys.exit(main())
