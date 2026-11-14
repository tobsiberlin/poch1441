# Stand POCH 1441 - Neubau

Letzte Aktualisierung: 14.11.2026

## Ziel

Kompletter Neubau nach `docs/CONCEPT.md` (Konzept v0.1). Arbeitsregeln in `CLAUDE.md`. Das alte Projekt liegt unter `legacy/` und ist nur Referenz.

## Erledigt

- **Schritt 1 - Umbau (14.11.2026):** Alter Stand als Commit gesichert und mit `legacy-snapshot` getaggt. Auf dem Branch `neustart` ist das alte Projekt nach `legacy/` verschoben, `CLAUDE.md` und `docs/CONCEPT.md` sind neu angelegt. `fastlane/` bleibt im Root (Entscheidung Tobsi: Pipeline zu App Store Connect behalten).

## Als Nächstes

- **Schritt 2 - M0 Regelvertrag:** `docs/RULES.md` schreiben.
  - Klassik-Regeln aus `docs/CONCEPT.md` Kapitel 4, präzise und vollständig.
  - Modern-Layer (Siegel, Blindpochen, Zunftstrafe, Kette) als eigener Abschnitt.
  - Jeder Grenzfall als nummerierte Regel mit Beispiel.
  - Abweichungen zwischen `legacy/PochKit` und Konzept auflisten, mit Beleg `Datei:Zeile`.
  - Offene Punkte nicht entscheiden, sondern als Fragenliste am Ende sammeln.
  - Noch kein Swift-Code.

## Entscheidungen

- Branch `neustart` trägt den Neubau. `main` und der alte Branch `agent/publish-poch-tutorial-hardware-qa` bleiben unberührt. Ob `neustart` zu `main` wird, ist offen.
- Das Chrome-Profil aus einem Review-Lauf wird nicht versioniert.

## Geparkt

- `fastlane/Fastfile` verweist auf `Poch1441.xcodeproj` und die alten Schemes. Anpassen, sobald das neue App-Target existiert.
- Im Root gibt es keine `AGENTS.md` mehr (liegt in `legacy/`).
- Die Root-`.gitignore` ignoriert `*.xcodeproj`. Neu bewerten, wenn das neue Xcode-Projekt entsteht.
- Das neue `CLAUDE.md` verlangt XcodeBuildMCP. Der Server muss vor M3 eingerichtet sein.
- Arbeitsbaum `poch-material` (Branch `codex/poch-material-20260718`) ist unberührt und nicht Teil des Tags.
