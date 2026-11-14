# TestFlight Build 18 - Feedback- und Hardware-QA

Stand: 29.07.2026, 02:11 CEST

## Ergebnis

Poch 1441 `0.1.0 (18)` wurde erfolgreich als `Poch1441InternalQA` archiviert, zu App Store Connect hochgeladen, vollständig verarbeitet und an interne TestFlight-Tester verteilt. Der Build ist ausschließlich für interne Produkt- und Hardware-QA bestimmt und kein Produktionskandidat.

## Quellstand

- Branch: `agent/publish-poch-tutorial-hardware-qa`
- Commit: `4b7b0077acae60b13545e2cd2107ff60a0f31f52`
- App Store Connect App-ID: `6789242958`
- Delivery-ID: `98d22e61-812c-428e-be33-893215de1ff1`

## Enthaltene Korrekturen

- nur noch ein App-eigener Schriftzug vor der Einführung
- neue historische und heutige Ambience als platzsparende M4A-Ressourcen
- sichtbarer Trumpf-König und größere eigene Karten im Melden-Schritt
- eindeutige Erklärung, dass jede Person nur ihre eigenen Bonuschips erhält
- stabile Aktionszonen in Phase 2 sowie feste Gegnersitze und unverdeckte Karten in Phase 3
- kräftigere Kartenfarben
- Ergebnis-Hold mit Mitte, Restkarten, Gesamt und Fortsetzungsaktion nach der letzten Handkarte

## Lokale Gates vor Upload

- vollständiger Tutorialfilm auf 390 x 844 mit normaler Bewegung: grün
- vollständiger Tutorialfilm auf 390 x 844 mit Reduced Motion: grün
- Ergebnis-Hold nach leerer Hand mit Punkten und Aktion: grün
- Accessibility XXXL, Portrait, Querformat und Rotation: grün
- drei echte Melden-Screens auf 390 x 844: visuell grün
- Phase-2- und Phase-3-Zonen auf 375 x 667 sowie 667 x 375: grün
- kompakter Einstieg in Hoch- und Querformat: grün
- frischer Simulator-Build, Stringkatalog und Audio-Mix-Vertrag: grün

## Archiv und Export

- Scheme: `Poch1441InternalQA`
- Konfiguration: `InternalQA`
- Export: App Store, nur internes TestFlight
- `testFlightInternalTestingOnly`: `true`
- IPA: `build/Poch1441InternalQA.ipa`
- dSYM: `build/Poch1441InternalQA.app.dSYM.zip`
- `get-task-allow`: `false`
- `beta-reports-active`: `true`
- Provisioning Profile: `iOS Team Store Provisioning Profile: com.tobc.poch1441`
- `DeveloperToolsSupport`: nicht verlinkt
- Debug-Dylibs: nicht enthalten
- Metal-/AIR-Quelldateien: nicht enthalten

Der mehrteilige Upload meldete vorübergehende Netzwerkabbrüche, schloss die Übertragung aber ausdrücklich erfolgreich ab. Die Delivery-ID wurde angenommen; der separate Distributionslauf bestätigte anschließend Verarbeitung und interne Verteilung von Build 18.

## Prüfsummen

- IPA SHA-256: `4d5068edc556a73a99f945db37f9167af65ab85cca6113177528ba8df01f00f6`
- dSYM SHA-256: `d81372ac055804f46e55a65baeba7a4f93c26ffaa79b19cfdb9a1e768271471a`

## Physische Pflichtprüfung

1. vollständiger Erstlauf einschließlich Ergebnis-Hold und Abschluss
2. Human-Audio und Lautstärkeverhältnis der neuen Ambience zu Karten, R1 und Tischklopfen
3. Haptik an Karten- und Chipkontakten
4. reale Audio-/Bild-Synchronität, besonders bei schnellen Eingaben und Rotation
5. Reduced Motion und große Schrift unter realer Bedienung

NO_SECRET_VALUES_INCLUDED: true
