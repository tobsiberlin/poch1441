# Changelog

Änderungen am Neubau von POCH 1441. Die Historie des alten Projekts steht in `legacy/CHANGELOG.md`.

## [M0 Entwurf] - 2026-11-14

### Hinzugefügt
- `docs/RULES.md`: Regelvertrag für PochCore als Entwurf. Klassik-Regeln mit stabilen IDs (`K-…`), Modern-Layer als eigener Abschnitt (`M-…`), jeder Grenzfall mit Beispiel.
- Abweichungen zwischen `legacy/PochKit` und Konzept, jeweils mit Beleg `Datei:Zeile`.
- Fragenliste mit 18 offenen Punkten (F-01 bis F-18) und 6 aus Pagat übernommenen Regeln zur Bestätigung. Nichts davon ist entschieden.

## [Neustart] - 2026-11-14

### Hinzugefügt
- `CLAUDE.md` mit den Arbeits- und Architekturregeln des Neubaus.
- `docs/CONCEPT.md`, Konzept v0.1.
- `legacy/README.md` mit Hinweis auf Sicherung und Rückweg.

### Geändert
- Das bisherige Projekt liegt vollständig unter `legacy/` und wird nicht mehr gebaut. Der Stand davor ist mit dem Tag `legacy-snapshot` gesichert.
- `fastlane/` bleibt im Root, damit die bestehende Pipeline zu App Store Connect weiterverwendet werden kann. Das `Fastfile` ist noch unverändert und verweist auf das alte Xcode-Projekt.
- `.gitignore` schließt Browser-Profile aus Review-Läufen aus (`chrome-profile/`).
