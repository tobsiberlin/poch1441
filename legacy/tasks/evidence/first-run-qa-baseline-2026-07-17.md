# First-Run QA-Baseline

**Stand:** 18. Juli 2026
**Basis:** Worktree nach `1e2e6da`, laufende Integration
**Scope:** statischer Audit plus zentraler App-, UI-Test- und Screenshotbeleg

## Reproduzierbarer Check

```bash
python3 tools/qa/audit_first_run.py
```

Der Check endet bei einem verletzten Gate mit Exitcode `1`. Er prüft:

- iPhone-Orientierungsfreigabe;
- vier semantische Lernzustände;
- Opening-Impact-Handoff;
- VoiceOver-Ersatzaktion für die Drag-Geste;
- Reduce-Motion- und VoiceOver-Verträge;
- alle First-Run-Katalogschlüssel in DE, EN, FR, IT, ES, NL und PL;
- Bühnenzonen gegen Safe Areas und verbotene Overlaps.

Aktueller Lauf: `PASS` ohne offene statische Prüfungen. Alle 40 expliziten
First-Run-Katalogschlüssel sind in sieben Sprachen vollständig.

## Statische Geräte- und Orientierungsbelege

Die Matrix nutzt die logischen Größen und typischen Safe Areas der Zielklassen.
Sie prüft `header`, `opponents`, `decision`, `board` und `hand` gegen den aktuellen
`FirstRunStageZones.resolve`-Stand.

| Gerät | Portrait | Landscape | Safe Areas | Verbotene Zonenoverlaps |
| --- | --- | --- | --- | --- |
| iPhone SE | 375 x 667 | 667 x 375 | PASS | keine |
| iPhone Standard | 393 x 852 | 852 x 393 | PASS | keine |
| iPhone Pro Max | 430 x 932 | 932 x 430 | PASS | keine |
| iPad mini | 744 x 1133 | 1133 x 744 | PASS | keine |

Das ist nur das geometrische Gate. Intrinsische Textgrößen, Kartenfächer,
Flugobjekte und optische Schatten brauchen weiterhin Screenshots und Interaktion.

## Geschlossene frühere Stop-the-line-Funde

1. iPhone-Landscape ist jetzt in `project.yml` für beide Richtungen freigeschaltet.
2. Gegner-, Decision-, Board- und Handzonen besitzen auf den vier Zielklassen
   positive Trennabstände oder berühren sich höchstens ohne Flächenüberschneidung.
3. Der erste eigene Stein mutiert Zähler und Lernzustand erst im Completion-Block
   der Kontaktanimation.
4. Die Opening-Drag-Geste besitzt eine lokalisierte VoiceOver-Ersatzaktion.
5. Jede sichtbare Center-Beschriftung verwendet den siebenfach übersetzten
   Katalogschlüssel `board.center`.
6. Coach-Titel, Body und Primäraktion verwenden semantische Textstile ohne
   Drei-Zeilen-Limit; Accessibility XXXL ist auf dem iPhone SE in beiden
   Orientierungen interaktiv belegt.
7. Der Funding-Beat zeigt auch bei Reduce Motion eine Quelle-Ziel-Hairline und
   mutiert alle Zähler erst in der Completion zusammen mit gebündeltem R1-Impact.
8. Nach dem Opening-Impact fokussiert VoiceOver den siebenfach lokalisierten
   Ergebnissatz `Dein Stein liegt` mit dem neuen Center-Wert.

## Offene statische Stop-the-line-Funde

Keine. Der Strict-Check ist grün. Visuelle, auditive und interaktive Gates bleiben
bis zum zentralen Integrationslauf ausdrücklich offen.

## Verbindliche visuelle Integrationsmatrix

Die DEBUG-Argumente `-firstRun` und `-tutorialMeldStep=0...7` machen Intro und
alle acht Lernbeats reproduzierbar. Der vollständige Gatebeleg umfasst folgenden
Kreuztest:

| Dimension | Werte |
| --- | --- |
| Geräteklasse | iPhone SE, iPhone Standard, iPhone Pro Max |
| Orientierung | Portrait, Landscape links, Landscape rechts |
| Sprache | DE, EN, FR, IT, ES, NL, PL |
| Beat | Intro, Orientieren, Einsatz, erste Karte, Hand, Trumpf, Verbinden, Beweisen, Loslassen |
| Accessibility | Standard, Reduce Motion, VoiceOver, Accessibility XXXL, erhöhter Kontrast |

Für den ersten Integrationspunkt ist der vollständige Geräte-/Orientierungs-/
Sprach-Kreuztest für die textdichten Beats Pflicht. Alle Beats werden zusätzlich
auf SE und Pro Max in DE geprüft. iPad mini läuft als Universal-Smoke-Test in
beiden Orientierungen.

### Screenshot-Abnahme pro Beat

- Safe Areas frei, keine abgeschnittene Primäraktion und kein Text über Quelle,
  Ziel, aktiver Karte oder Hand.
- Echte Track-A-Disc bleibt exakt 8+1 und räumlich stabil.
- Gegnerplätze behalten Name, Sitz und Reihenfolge über Rotation und Beatwechsel.
- Portrait und Landscape zeigen denselben `FirstRunBeat`, Lernzustand, Zähler,
  Trumpf und dieselbe gelandete Karte.
- Flug- und Zielobjekt existieren am Impact niemals doppelt.
- Nach dem Impact folgt ein ruhiger Endzustand ohne Springen oder Verschwinden.

### Interaktionsabnahme

1. First Run starten und den Stein per Drag in die Mitte legen.
2. Dasselbe mit VoiceOver über die benannte Ersatzaktion ausführen.
3. Während Token- und Kartenflug rotieren; der neue Aufbau darf erst nach Impact
   denselben bestätigten Zustand übernehmen.
4. In jedem Beat schnell doppelt tippen, pausieren, fortsetzen und zurückkehren.
5. Reduce Motion aktivieren und Ursache, Ziel, Kontakt und Wirkung ohne Flug prüfen.
6. VoiceOver-Reihenfolge prüfen: Lernzustand -> Coach-Satz -> Primäraktion ->
   räumliches Ziel -> Ergebnis.

## Ausgeführte Integrationsbelege

- App-Build auf iOS Simulator erfolgreich; einzige Meldung ist der erwartete
  AppIntents-Metadatenhinweis ohne AppIntents-Abhängigkeit.
- `FirstRunUITests`: First-Run-Einstieg, zugängliche Scheibenaktivierung,
  kontaktabhängige Folgeaktion, alle vier Lernzustände und sieben erhaltene
  Screenshots erfolgreich.
- Echte XCTest-Rotation mit bestätigter Window-Geometrie auf iPhone SE
  (375 x 667 / 667 x 375), Standard (402 x 874 / 874 x 402) und Pro Max
  (440 x 956 / 956 x 440).
- Feste Plätze Hana, Noah und Jonas liegen in jedem geprüften Beat mit mindestens
  44 x 44 Punkten im sichtbaren App-Fenster.
- Der Intro-Screenshot bei Accessibility XXXL trennt Gegnerreihe, Disc, Lernziel
  und beide Aktionen vollständig. Der UI-Test verlangt in Portrait komplette
  Fensteraufnahme und verbietet in beiden Orientierungen jede Überschneidung
  zwischen Disc, Gegnern, Ziel und Aktionen.
- Der frühere grüne Status des alten Lernbühnen-Gates ist widerrufen. Im abgelehnten
  Beleg `artifacts/qa/ax-xxxl-landscape-20260717-223905-4565/` meldete XCTest zwar
  ein `667 x 375`-Window, der einzige Screenshot war jedoch ein
  `750 x 1334`-Portrait-PNG. Die AX-Aktion war `311,5 pt` statt `48 pt` hoch. Das
  alte Gate hatte weder eine Maximalhöhe noch Viewport-Containment und fotografierte
  erst nach einem Scroll; `exists`, `isHittable` und paarweise Nichtüberlappung
  konnten diesen geclippten Zustand deshalb nicht ablehnen.
- Der gehärtete Gate `tools/qa/run_ax_xxxl_landscape_gate.sh <SE-UDID>` hängt nun
  zwingend einen initialen Gesamtframe vor jeder
  Interaktion sowie einen Bottom-Reveal an. Er verlangt, dass kein einzelner
  Lernframe größer als der sichtbare Scroll-Viewport ist, dass Gegner und initialer
  Disc-Anker im Viewport liegen und dass Gegner, Disc, Aktion und Hand jeweils
  vollständig ohne Clipping revealbar sind. Der bestätigte Lauf verwendet ein
  echtes `667 x 375`-App-Fenster; die Coach-Aktion wächst kontrolliert von `48 pt`
  auf `68 pt`, die initiale `130 pt`-Disc und alle drei Gegner sind vollständig
  sichtbar, Coach und Hand vollständig scrollbar. Während der App-Zustand aktiv
  bleibt, nimmt der Runner den Simulator-Framebuffer direkt auf und normalisiert
  nur dessen bekannte Metadrehung auf `1334 x 750 px`.
- Erste sichtbare Karte, volle Hand, Trumpf, Verbinden, Beweisen und Loslassen
  wurden als Simulator-Screenshots visuell geprüft; keine Overlay-Kollision.
- Accessibility-Baum benennt Lernzustand, 44-Punkt-Scheibe, Mitte, Ergebnis und
  Folgeaktion eindeutig. Reduce Motion behält den statisch geprüften
  Quelle-Ziel-Impact-Vertrag.

## Noch offene Hardware-/Langzeitbelege

- Gesprochene VoiceOver-Reihenfolge und Accessibility XXXL auf echter Hardware;
- Taptic-Charakter und Keramik-Audio über Gerätelautsprecher;
- 60-/120-Hz-Profiling sowie Rotation genau während eines laufenden Flugs.
