# Changelog

Änderungen am Neubau von POCH 1441. Die Historie des alten Projekts steht in `legacy/CHANGELOG.md`.

## [Neustart] - 2026-11-14

### Hinzugefügt
- `CLAUDE.md` mit den Arbeits- und Architekturregeln des Neubaus.
- `docs/CONCEPT.md`, Konzept v0.1.
- `legacy/README.md` mit Hinweis auf Sicherung und Rückweg.

### Geändert
- Das bisherige Projekt liegt vollständig unter `legacy/` und wird nicht mehr gebaut. Der Stand davor ist mit dem Tag `legacy-snapshot` gesichert.
- `fastlane/` bleibt im Root, damit die bestehende Pipeline zu App Store Connect weiterverwendet werden kann. Das `Fastfile` ist noch unverändert und verweist auf das alte Xcode-Projekt.
- `.gitignore` schließt Browser-Profile aus Review-Läufen aus (`chrome-profile/`).
