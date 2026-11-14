# Poch 1441 - interner TestFlight-Build 9

Status: **INTERN VERTEILT**  
Produktion: **GESPERRT**

## Was dieser Build behebt

- neue dreiteilige Tutorial-Premiere mit klarer Handlung, Skip und echtem 3/3-Abschluss
- sichtbare Einstellungen und Pause in allen geprüften Phasen
- vollständige, fortlaufende Kartenfächer im 3-Spieler-Deal
- größeres, klar getrenntes Pochbrett in Phase 2
- kräftigere rote Karten und besser lesbare inaktive Hand
- weniger mechanisches Timing mit begrenzter Montage und sicherer Rückgabe der Kontrolle
- stabiler InternalQA-Start sowie simulator-sichere Audioinitialisierung

## Liefernachweis

- App Store Connect: Version `0.1.0`, Build `9`
- Zustand: `VALID`, `IN_BETA_TESTING`
- nur internes TestFlight: `testFlightInternalTestingOnly: true`
- IPA: `build/Poch1441InternalQA.ipa`
- IPA-SHA-256: `143d1ee4feaecdee7e02ab4f54edb22e0337c104e016f5610b57627694c70bc2`
- Signatur: `get-task-allow = false`, `beta-reports-active = true`
- Artefakt: kein `DeveloperToolsSupport`, keine `*debug*.dylib`, keine Metal-Quellpfade

Der erste Transportlauf wurde durch wiederholte Netzwerkabbrüche formal mit Exit 1 beendet, obwohl Apples Uploader `UPLOAD SUCCEEDED` meldete. App Store Connect bestätigte den Upload anschließend als vollständig und `VALID`. Der Recovery-Pfad setzte Export-Compliance auf `false` und verteilte exakt Build 9 intern, ohne einen zweiten Build zu erzeugen.

## Software- und Produktgate

- PochKit: 64/64 PASS
- Product-Wayfinding: 4/4 PASS auf 390 x 844 und 402 x 874
- kompletter Tutorial-Pfad: PASS in Standard und Reduced Motion
- InternalCoinQA: 3/3 PASS nach dem Audio-/Intro-Startfix
- neun normale InternalQA-Starts: 9/9 PASS
- unabhängiger visueller Gegencheck: keine P0/P1-Findings, GO für internen TestFlight

## Bewusst weiterhin offen

- physischer Start von Build 9 auf dem iPhone: **PENDING**
- Human-Audio auf dem iPhone: **PENDING**
- Haptik inklusive deaktivierter Systemhaptik: **PENDING**
- 240-fps-/96-kHz-Kontaktmessung und Offset: **PENDING**
- vollständige Lokalisierung aller noch hart codierten deutschen Produkttexte: **P2 / Produktionsblocker**
- Stage-4-Produktgate: **BLOCKED_PENDING_HARDWARE**
- Produktionsintegration und normaler Release-Pfad: **BLOCKED**

Build 7 bleibt als historischer Startcrash rot. Build 8 ist technisch überholt und wird für die aktuelle Produktprüfung durch Build 9 ersetzt. Historische rote Material- und Motion-Gates werden durch diese TestFlight-Lieferung nicht umetikettiert.

