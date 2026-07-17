#!/usr/bin/env python3
"""Generiert das gegenwartsbezogene Poch-1441-Statuscockpit.

Der Designkanon und der aktuelle Handoff sind verbindlich. Das Cockpit ist kein
Archiv: verworfene Richtungen, alte Sichtungen und historische Todo-Stände werden
nicht übernommen.
"""

from __future__ import annotations

import html
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
TEMPLATE = ROOT / "tools" / "cockpit_template.html"
OUTPUT = ROOT / "artifacts" / "poch-1441-cockpit.html"
TEMP = Path(
    "/Users/tobsi/Library/Mobile Documents/com~apple~CloudDocs/TEMP/"
    "poch-1441-cockpit.html"
)


def current_revision() -> str:
    result = subprocess.run(
        ["git", "rev-parse", "--short", "HEAD"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def cards(rows: list[tuple[str, str, str]]) -> str:
    return "".join(
        '<article class="card">'
        f'<span class="tag {html.escape(state)}">{html.escape(state)}</span>'
        f"<h3>{html.escape(title)}</h3>"
        f"<p>{html.escape(body)}</p>"
        "</article>"
        for state, title, body in rows
    )


def list_items(rows: list[str]) -> str:
    return "".join(f"<li>{html.escape(row)}</li>" for row in rows)


revision = current_revision()

tracks = [
    (
        "grün",
        "Lead",
        "Acht First-Run-Beats, adaptive Bühne und zentrale Integration stehen.",
    ),
    (
        "grün",
        "Material",
        "R1-Keramik, natürliche Endlagen sowie gemeinsamer Sound-/Haptik-Impact stehen.",
    ),
    (
        "grün",
        "Gegner",
        "Hana, Noah und Jonas besitzen feste Tutorialsitze; Tendenzen bleiben öffentlich.",
    ),
    (
        "grün",
        "Regel",
        "Seed 19, erste Meldung und Bot-Informationsgrenzen sind durch PochKit belegt.",
    ),
    (
        "arbeit",
        "QA",
        "Geräte und Rotation sind grün; Accessibility XXXL und Hardwaregefühl werden vertieft.",
    ),
]

evidence = [
    f"Revision {revision} ist die aktuelle Cockpit-Basis.",
    "51 PochKit-XCTest-Tests und 6 Swift-Testing-Tests bestehen.",
    "102 explizite Lokalisierungsschlüssel sind in DE, EN, FR, IT, ES, NL und PL vollständig.",
    "First-Run-UI-Tests belegen Kontakt, erste Karte, Trumpf, Meldung und alle vier Lernzustände.",
    "SE, Standard und Pro Max bestehen Portrait und Landscape mit stabilen Gegnerplätzen.",
    "Der Simulator-Build besteht ohne Swift-Warnung; AppIntents meldet nur den erwarteten Metadatenhinweis.",
]

next_steps = [
    "Accessibility XXXL auf SE in Portrait und Landscape kollisionsfrei abschließen.",
    "Reduce Motion und gesprochene VoiceOver-Reihenfolge im echten Flow prüfen.",
    "Rotation während eines laufenden Impacts auf Zustandsduplikate testen.",
    "Keramikklang, Taptic-Charakter und 60-/120-Hz-Verhalten auf Hardware abnehmen.",
]

canon = [
    "Poch 1441 wird gestaltet, als wäre es 2026 erstmals erfunden worden.",
    "Präzision, Lesbarkeit und souveräne Interaktion stehen vor Dekoration und Spektakel.",
    "Die echte Poch Disc ist Regelobjekt und Tutorialbühne; es gibt keine alternative Lernscheibe.",
    "Portrait und Landscape sind gleichwertige Kompositionen mit identischem semantischem Zustand.",
    "Die Produkthülle ist warm-editorial; der Spieltisch behält seine dunkle Juwelen- und Materialsprache.",
    "Keine historische Themenwelt, keine royale Meta-Erzählung und keine Luxusinszenierung.",
]

sources = [
    "tasks/HANDOFF-2026-07-17.md",
    "tasks/design-canon-2026.md",
    "tasks/board-art-direction.md",
    "tasks/parallel-orchestration.md",
    "tasks/evidence/first-run-qa-baseline-2026-07-17.md",
]

document = TEMPLATE.read_text(encoding="utf-8")
document = (
    document.replace("__REVISION__", html.escape(revision))
    .replace("<!--TRACKS-->", cards(tracks))
    .replace("<!--EVIDENCE-->", list_items(evidence))
    .replace("<!--NEXT-->", list_items(next_steps))
    .replace("<!--CANON-->", list_items(canon))
    .replace("<!--SOURCES-->", list_items(sources))
)

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
TEMP.parent.mkdir(parents=True, exist_ok=True)
OUTPUT.write_text(document, encoding="utf-8")
TEMP.write_text(document, encoding="utf-8")

size_kb = round(len(document.encode("utf-8")) / 1024)
print(f"Gegenwarts-Cockpit aktualisiert: {size_kb} KB")
