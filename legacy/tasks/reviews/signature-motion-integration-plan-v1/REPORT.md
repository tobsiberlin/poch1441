# Signature Motion Integration Plan V1

Stand: 2026-07-20

## Ergebnis

Die aktuelle App besitzt bereits sichere, generationgebundene Kontakt-Gates für
Karten und Münzen. Der Produktionsengpass liegt nicht im Regelkern, sondern in
der Präsentationsverkabelung: Startkadenz, Flugbahn, Kontaktzeitpunkt, Settle,
Audio und Haptik werden noch von mehreren Stellen mit unterschiedlichen Uhren
bestimmt.

Eine direkte Übernahme der Beweis-Renderer wäre deshalb zu riskant. Die kleinste
tragfähige Naht ist ein regelneutraler `MotionPlaybackPlan`, der eine bereits
zertifizierte Bahn samt Kontakt- und Ruhemarkern an die bestehende
`CardFlightTransaction` beziehungsweise `CoinTransferTransaction` liefert.

## Frisch gepruefter Ist-Zustand

| Bereich | Aktueller Vertrag | Konsequenz |
| --- | --- | --- |
| Deal-Start | `GameState.dealLoop()` wartet `Tokens.p1DealStep` und pollt anschließend auf maximal zwei gestartete, noch nicht gelandete Karten (`App/GameState.swift:1264`). | Das Zwei-Körper-Limit ist vorhanden, der musikalische Rhythmus kennt aber noch kein gemessenes `settle/rest` der vorvorherigen Karte. |
| Kontaktmutation | `markDealLanded(_:)` akzeptiert nur den gestarteten Presentation-Event, ordnet außer der Reihenfolge eingehende Kontakte und mutiert erst danach den sichtbaren Zähler (`App/GameState.swift:1295`). | Der bestehende State-Gate bleibt unverändert und wird weiterhin allein am zertifizierten Kontaktmarker aufgerufen. |
| Kartenflug | `FlyingBack` berechnet Dauer, Bogen und lateralen Versatz in der View und interpoliert lediglich Pose/Skalierung (`App/DealOverlay.swift:498`). | Plane-Lock, Materialspannung und Settle können derzeit nicht als ein zertifiziertes Transcript abgespielt werden. |
| Generischer Abschluss | `ImpactFlight` feuert Kontakt am SwiftUI-Abschlusskriterium `.logicallyComplete` (`App/ImpactFlight.swift:106`). | Der logische Animationsabschluss ist noch nicht derselbe Beweis wie ein expliziter physischer Kontaktframe. |
| Karten-Transaktion | `CardFlightTransaction` trennt `awaitingContact`, `contacted`, `completed` und `cancelled` und weist stale/duplicate Kontakte ab (`App/CardMaterialContract.swift:312`). | Geeignete unveränderte Ziel-API für Transcript-Playback. |
| Münzen-Transaktion | `CoinTransferTransaction` verlangt `departed -> airborne -> impacted -> settling -> completed` und besitzt einen synchronen Reduced-Motion-Pfad (`App/CoinTransferPlan.swift:119`). | Geeignete unveränderte Ziel-API für physische und barrierearme Wiedergabe. |
| Feedback | Kontakt-Haptik und -Audio reagieren auf den Impact-Trigger; das Audio besitzt bereits deterministische Varianten und `os.Logger` (`App/Effects.swift:104`). | Audio/Haptik dürfen keine eigene Timeline erhalten, sondern müssen denselben Transcript-Kontaktmarker konsumieren. |
| Materialwelt | `TableWorld` trennt R1-Keramik und 1-Cent-Kupfer, ohne Regeln oder Einsätze zu verzweigen (`App/TableWorld.swift:9`). | Material-, Licht- und Klangprofile können über die bestehende Weltwahl geroutet werden. |

## Blast Radius

Risikostufe: **L2 für reine Adapter und Tests**, **L3 für den ersten echten
Produktions-Hook**, weil Timing, Zustandsmutation, Audio, Haptik, Accessibility und
mehrere Spielphasen an derselben Kontaktkante zusammentreffen.

Betroffene Produktionsstellen beim späteren Hook:

1. `App/DealOverlay.swift`: `FlyingBack` wird zum ersten Transcript-Consumer.
2. `App/GameState.swift`: `dealLoop()` konsumiert gemessene `restWindowStart`-Marker
   statt nur eine feste Schrittweite. Regeln und `markDealLanded(_:)` bleiben
   unangetastet.
3. `App/ImpactFlight.swift`: bleibt für noch nicht migrierte Flüge erhalten;
   Transcript-Flüge erhalten einen separaten Player statt einer stillen semantischen
   Änderung des generischen Bausteins.
4. `App/Effects.swift`: nimmt denselben Kontakt-Event wie der State-Gate entgegen;
   keine Audio-Timer und keine Haptik vor dem Kontakt.
5. Phase-2-Payouts, Phase-2-Einsätze und Phase-3-Karten bleiben in der ersten
   Integrationsstufe explizit unverändert.

Wahrscheinliche Bruchstellen:

- Kontakt wird doppelt gemeldet, wenn alter SwiftUI-Completion-Callback und neuer
  Marker gleichzeitig aktiv sind.
- Karte drei startet, bevor Karte eins ihr Ruhefenster erreicht.
- `skipDeal()` oder ein Generationwechsel lässt einen veralteten Marker nachlaufen.
- Reduced Motion behaelt unbemerkt die normale Wartezeit.
- Ein visuelles Settle wird nicht mehr als bewegter Körper gezählt.
- Audio/Haptik wird an `started` statt `impacted` gekoppelt.

## Integrationsfolge

### Stufe 1 - Reine Datennaht

Neue regelneutrale Typen, noch ohne View- oder Game-State-Änderung:

- `MotionSample`: normalisierte Zeit, Position, Tiefe, Rotation, Curl und Schatten.
- `MotionContactMarker`: Sample-Index, physische Kontaktzeit und Surface-ID.
- `MotionRestWindow`: erster zulässiger Ruhezeitpunkt und Mindestdauer.
- `MotionPlaybackPlan`: stabile ID, Materialfamilie, World-Light-ID, Samples,
  Kontaktmarker, Ruhefenster und Cancel-Policy.
- `DealRhythmSchedule`: `actualStart(i) = max(rhythmTarget(i), restWindowStart(i-2))`.

Done-Kriterien:

- `Sendable`, deterministisch serialisierbar, keine PochKit- oder Regeltypen.
- Mindestens neun Varianten pro Auswahl-Bucket.
- Derselbe Seed erzeugt bytegleich dieselbe Auswahl, ohne exakte Wiederholung in
  acht aufeinanderfolgenden Transfers.
- Keine Produktions-Views veraendert.

### Stufe 2 - DEBUG-Wiedergabe

Ein isolierter `TranscriptMotionPlayer` rendert genau einen zertifizierten Plan bei
402 x 874 und publiziert drei Callbacks: `onContact`, `onRest`, `onCancelBeforeRelease`.

Done-Kriterien:

- State, Audio und Haptik reagieren ausschließlich auf `onContact`.
- Standard-, 60-, 80- und 120-Hz-Segmente erfassen reale Wallclock-Intervalle.
- Settle zaehlt bis `onRest` als Bewegung.
- Im Freiflug ist nur Zeitskalierung zulässig; kein Teleport-Cancel.
- Reduced Motion erreicht denselben Endzustand ohne versteckte Normalzeit-Wartefrist.

### Stufe 3 - Ein Karten-Hook hinter Schalter

Nur `FlyingBack` wird für einen DEBUG-Seed auf Transcript-Playback umgestellt. Der
alte `ImpactFlight`-Pfad bleibt als sofortiger Rückfall erhalten. `GameState`,
PochKit, Kartenidentitaet und Zielstapel werden nicht umgebaut.

Done-Kriterien:

- `markDealLanded(_:)` wird exakt einmal am Transcript-Kontaktmarker aufgerufen.
- Generationwechsel und Skip erzeugen keinen späten State-Write.
- Die Startkadenz wartet auf das Ruhefenster der vorvorherigen Karte.
- 8-Karten-Wallclock-Beleg: maximal zwei bewegte Körper einschließlich Settle.
- UI-Test für Standard und Reduced Motion.

### Stufe 4 - Münzen und Feedback

Erst nach bestandenem Karten-Hook wird derselbe Player an einen einzigen
Track-B-1-Cent-Transfer gekoppelt. Danach folgen Audiofingerabdruck und Haptik aus
dem gemeinsamen Kontaktmarker.

Done-Kriterien:

- Kein Energiegewinn und keine Penetration gegen die jeweilige Muldengeometrie.
- Kein Cancel im Freiflug; sichtbare Gegenbewegung nach bereits erfolgtem Kontakt.
- Kontaktbild, Audio-Waveform und Haptikmarker liegen im 240-fps/96-kHz-Beleg auf
  derselben zertifizierten Kante.

## Nicht Teil dieses Schritts

- Keine Änderung am deterministischen PochKit-Regelkern.
- Keine neue Economy, Botlogik oder Kartenbewertung.
- Keine breite Migration von Phase 2 oder Phase 3.
- Kein Austausch von Assets, solange Karten- und Münzenmaterial im nativen
  Zielmassstab nicht separat gruen sind.
- Kein Commit oder Push ohne erneute ausdrueckliche Nutzeranweisung.

## Kleinster naechster Beweis

Die drei laufenden V3-Stränge müssen zuerst folgende harte Reihenfolge erfüllen:

1. Kartenmaterial ist bei echter 54,85-px-Breite lesbar, ohne Geometrie- oder
   Timingdrift.
2. 1-Cent-Material ist bei echter 19,8-px-Breite über eine kurze
   Orientierungssequenz lesbar, ohne Solverdrift.
3. Die 8-Karten-Wallclock-Wiedergabe beweist den Ruhefenster-gesteuerten Rhythmus
   bei Standard und Reduced Motion.

Erst wenn diese drei Belege gruen sind, beginnt Stufe 1 als Produktionscode.
