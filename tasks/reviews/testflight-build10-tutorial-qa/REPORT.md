# TestFlight Build 10 - Tutorial-Premiere

## Ergebnis

Poch 1441 `0.1.0 (10)` ist ausschließlich für interne TestFlight-Tester verteilt. Der Kandidat ist für den kabellosen iPhone-Test freigegeben. Er ist ausdrücklich kein Produktionskandidat.

## Was sich geändert hat

- Das Tutorial führt durch echte Spielaktionen und erklärt Ziel, Einsatz und Gewinn in verständlicher Kartensprache.
- Die markierte Gewinnkarte ist tatsächlich antippbar; der Hinweis führt nicht mehr ins Leere.
- Verteilte Karten kommen sichtbar bei den Mitspielern an, ergänzen deren Hand und bleiben vollständig deckend liegen.
- Text, Abschlusskarte, Aktionen und Handkarten überlagern sich nicht mehr in den geprüften Größen.
- Das Pochbrett ist in Phase 2 größer, sauber zentriert und als Spielfläche klarer lesbar.
- Der Münzkontakt verwendet neun differenzierte Keramikvarianten statt des vorherigen plumpen Einheitsklangs.

## Automatische Freigaben

- PochKit: 64/64 Tests bestanden.
- Tutorial-Premiere: 8/8 echte UI-Flows bestanden.
- Phase 2 bei Accessibility XXXL: 402 x 874, iPhone SE Portrait und 667 x 375 Landscape bestanden.
- Produktgrößen: 390 x 844 und 402 x 874 bestanden.
- Interner Starttest: 9/9 normale Starts bestanden.
- Internal Coin QA: 3/3 bestanden.
- Strikter arm64-InternalQA-Build mit Swift- und Clang-Warnungen als Fehler: bestanden.
- Externer visueller Review: keine bestätigte Text- oder Elementüberlagerung im freigegebenen Kandidaten.

## Ausgeliefertes Artefakt

- Datei: `build/Poch1441InternalQA.ipa`
- Größe: 53.432.988 Bytes
- SHA-256: `0c8dded02344e3e3ba8e65423821aec53ab5a3bcc15345845d40593211f053fe`
- Signatur: `get-task-allow=false`, `beta-reports-active=true`
- Kein `DeveloperToolsSupport`, keine Debug-Dylib und keine Metal-Quellpfade im Export.
- App Store Connect: verarbeitet und intern verteilt; externe Tests und App-Store-Veröffentlichung sind ausgeschlossen.

## Noch offen - Produktion bleibt gesperrt

- Physischer Start von Build 10 auf dem iPhone.
- Menschliche Beurteilung des Münzklangs über den iPhone-Lautsprecher.
- Haptik auf dem Gerät, einschließlich ausgeschalteter Haptik in den Einstellungen.
- 240-fps-/96-kHz-Messung des sichtbaren und hörbaren Kontaktversatzes.
- Vollständige Produktlokalisierung.

Alle historischen roten Gates bleiben erhalten. Erst reales Gerätefeedback darf die Hardware-Gates ändern.
