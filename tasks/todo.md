# Stand POCH 1441 - Neubau

Letzte Aktualisierung: 14.11.2026

## Ziel

Kompletter Neubau nach `docs/CONCEPT.md` (Konzept v0.1). Arbeitsregeln in `CLAUDE.md`. Das alte Projekt liegt unter `legacy/` und ist nur Referenz.

## Erledigt

- **Schritt 1 - Umbau (14.11.2026):** Alter Stand als Commit gesichert und mit `legacy-snapshot` getaggt. Auf dem Branch `neustart` ist das alte Projekt nach `legacy/` verschoben, `CLAUDE.md` und `docs/CONCEPT.md` sind neu angelegt. `fastlane/` bleibt im Root (Entscheidung Tobsi: Pipeline zu App Store Connect behalten).
- **Schritt 2 - M0 Entwurf (14.11.2026):** `docs/RULES.md` geschrieben. Enthält Klassik-Regeln (`K-…`), Modern-Layer (`M-…`), Abweichungen zum alten Code mit Belegen und die Fragenliste. Kein Swift-Code.

## Als Nächstes

- **Tobsi entscheidet die Fragenliste** in `docs/RULES.md`, Abschnitt 10: 18 offene Punkte (F-01 bis F-18) und 6 von Pagat übernommene Regeln (Abschnitt 10.5).
  - Zuerst klären, weil der Rest daran hängt: F-04 (Einsatzregeln im Pochen), F-10 (gilt der Modern-Layer für KI-Sitze), F-15 (Zählweise der Kette), F-17 (Bank und Chip-Erhaltung).
- Danach die Entscheidungen in `docs/RULES.md` einarbeiten, Status auf "final" setzen. Damit ist M0 abgenommen.
- Erst dann M1: PochCore Klassik, test-first, jeder Test nennt seine Regel-ID.

## Entscheidungen

- Branch `neustart` trägt den Neubau. `main` und der alte Branch `agent/publish-poch-tutorial-hardware-qa` bleiben unberührt. Ob `neustart` zu `main` wird, ist offen.
- Das Chrome-Profil aus einem Review-Lauf wird nicht versioniert.
- Herkunft jeder Regel ist in `docs/RULES.md` gekennzeichnet: `[K]` Konzept, `[P]` Pagat, `[A]` abgeleitet, `[OFFEN]`.

## Geparkt

- `fastlane/Fastfile` verweist auf `Poch1441.xcodeproj` und die alten Schemes. Anpassen, sobald das neue App-Target existiert.
- Im Root gibt es keine `AGENTS.md` mehr (liegt in `legacy/`).
- Die Root-`.gitignore` ignoriert `*.xcodeproj`. Neu bewerten, wenn das neue Xcode-Projekt entsteht.
- Das neue `CLAUDE.md` verlangt XcodeBuildMCP. Der Server muss vor M3 eingerichtet sein.
- Arbeitsbaum `poch-material` (Branch `codex/poch-material-20260718`) ist unberührt und nicht Teil des Tags.
- Vorgemerkt für den Run-Layer (M2): R-01 bis R-04 in `docs/RULES.md`, Abschnitt 10.4.
