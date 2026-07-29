# TestFlight Build 19 - Tutorial- und Hardware-QA

Stand: 29.07.2026, 15:23 CEST

## Ergebnis

Poch 1441 `0.1.0 (19)` wurde erfolgreich als `Poch1441InternalQA` archiviert, zu App Store Connect hochgeladen, vollständig verarbeitet und an interne TestFlight-Tester verteilt. Der Build ist ausschließlich für interne Produkt- und Hardware-QA bestimmt und kein Produktionskandidat.

## Quellstand

- Branch: `agent/publish-poch-tutorial-hardware-qa`
- Commit: `245383833ee13aeb5d290e627a3785f56e6648d4`
- Draft-PR: `#1`
- App Store Connect App-ID: `6789242958`
- Delivery-ID: `9a8f0490-3e5b-464c-81a6-67611953cea8`

## Enthaltene Korrekturen

- filmischer Tutorial-Einstieg mit schrittweiser Brett- und Muldenführung
- klare Ursache und Wirkung bei Trumpf, Bonusfeldern, Hochzeit und Jetonauszahlung
- sichtbare Jetonquellen direkt bei den Personen statt Einflug vom Bildschirmrand
- größere, kräftigere Karten sowie stabilere Hand-, Coach- und Aktionszonen
- klickbare Melden-Aktionen und eindeutige Trumpf-Aufdeckung ohne vorzeitigen Spoiler
- verständlichere Sprache für Pochen, Ausspielen, Restkarten und Ergebnis-Hold
- stabilisierte Gegnersitze, Querformat-, Rotations-, große-Schrift- und Reduced-Motion-Zustände

## Lokale Gates vor Upload

- drei Quelltextverträge für Tutorialsprache, Kartenrendering und Materialwelt: grün
- Stringkatalog und Diff-Prüfung: grün
- vier textkritische UI-Gates einschließlich AX XXXL: grün
- vollständiger Tutorialfilm auf 390 x 844 mit normaler Bewegung: grün
- vollständiger Tutorialfilm auf 390 x 844 mit Reduced Motion: grün
- vier echte Melden-Screens nach finaler Trumpfkorrektur: grün
- acht Gates für AX XXXL, kleines iPhone, Querformat und Rotation: grün
- finale Textmatrix durch GPT und Gemini geprüft: PASS

## Archiv und Export

- Scheme: `Poch1441InternalQA`
- Konfiguration: `InternalQA`
- Export: App Store, nur internes TestFlight
- `testFlightInternalTestingOnly`: `true`
- Archiv: `build/Poch1441InternalQA.xcarchive` (95 MiB)
- IPA: `build/Poch1441InternalQA.ipa` (61 MiB)
- dSYM: `build/Poch1441InternalQA.app.dSYM.zip` (4,9 MiB)
- `get-task-allow`: `false`
- `beta-reports-active`: `true`
- `DeveloperToolsSupport`: nicht verlinkt
- Debug-Dylibs: nicht enthalten
- Metal-/AIR-Quelldateien: nicht enthalten; das kompilierte `default.metallib` ist erwarteter Laufzeitcode

Fastlane bestätigte um 15:23 Uhr die vollständige Verarbeitung von Build 19, setzte den internen Changelog und verteilte den Build erfolgreich an interne Tester.

## Prüfsummen

- IPA SHA-256: `96d4c324f35c549613c78a4854f696e55cd22e366fc52240bdca939bfdea0825`
- dSYM SHA-256: `514e2b34f7f251345532de40f13275fbe63efe6e1849c5d29bc3d86166c74aec`

## Physische Pflichtprüfung

1. vollständiger Erstlauf einschließlich Ergebnis-Hold und Abschluss
2. Human-Audio und Lautstärkeverhältnis der neuen Ambience zu Karten, R1 und Tischklopfen
3. Haptik an Karten- und Chipkontakten
4. reale Audio-/Bild-Synchronität, besonders bei schnellen Eingaben und Rotation
5. Reduced Motion und große Schrift unter realer Bedienung

NO_SECRET_VALUES_INCLUDED: true
