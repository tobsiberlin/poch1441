# TestFlight Build 17 - Hardware-QA

Stand: 28.07.2026, 22:46 CEST

## Ergebnis

Poch 1441 `0.1.0 (17)` wurde erfolgreich als `Poch1441InternalQA` archiviert, zu App Store Connect hochgeladen, vollständig verarbeitet und an interne TestFlight-Tester verteilt. Der Build ist ausschließlich für interne Produkt- und Hardware-QA bestimmt und kein Produktionskandidat.

## Quellstand

- Branch: `agent/publish-poch-tutorial-hardware-qa`
- Commit: `a324d2b`
- Draft-PR: https://github.com/tobsiberlin/poch1441/pull/1
- App Store Connect App-ID: `6789242958`

## Lokale Gates vor Upload

- vollständiger Tutorialfilm auf 390 × 844 mit normaler Bewegung: grün
- vollständiger Tutorialfilm auf 390 × 844 mit Reduced Motion: grün
- Ergebnis-Hold und exklusiver 3/3-Abschluss: grün
- Accessibility XXXL, Portrait, Querformat und Rotation: grün
- Trumpf-Hero, echtes Kartenziel, R1-/Poch-Chipkontakte und Reaktions-FIFO: grün
- vier geführte SE-Ausspiel-Gates: grün
- 64 PochKit-Tests: grün
- frischer Simulator-Build und Stringkatalog in sieben Sprachen: grün

## Archiv und Export

- Scheme: `Poch1441InternalQA`
- Konfiguration: `InternalQA`
- Export: App Store, nur internes TestFlight
- `testFlightInternalTestingOnly`: `true`
- IPA: `build/Poch1441InternalQA.ipa`
- dSYM: `build/Poch1441InternalQA.app.dSYM.zip`

Das rohe Xcode-Archiv besitzt vor dem Export eine Development-Signatur. Maßgeblich für TestFlight ist die exportierte und hochgeladene IPA. Deren Payload wurde separat geprüft:

- `get-task-allow`: `false`
- `beta-reports-active`: `true`
- Provisioning Profile: `iOS Team Store Provisioning Profile: com.tobc.poch1441`
- `DeveloperToolsSupport`: nicht verlinkt
- Debug-Dylibs: nicht enthalten
- Metal-/AIR-Quelldateien: nicht enthalten
- Version und Build im exportierten Payload: `0.1.0 (17)`

## Prüfsummen

- IPA SHA-256: `731eab0f4f3ef73cc2d6d108ee4386efbe39ee7b610afb6ca75ff34e6c276fd7`
- dSYM SHA-256: `354bb354287a03c80399aa3a368cd7903f12711f8342aaaff1fdbfbb1c588da2`

## Physische Pflichtprüfung

Auf dem echten iPhone bleiben zu prüfen:

1. kompletter Erstlauf einschließlich Ergebnis-Hold und Abschluss
2. Human-Audio und Lautstärkeverhältnis von Zeitreise, Karten, R1 und Tischklopfen
3. Haptik an Karten- und Chipkontakten
4. reale Audio-/Bild-Synchronität, besonders bei schnellen Eingaben und Rotation
5. Reduced Motion und große Schrift unter realer Bedienung

NO_SECRET_VALUES_INCLUDED: true
