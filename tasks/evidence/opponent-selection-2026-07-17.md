# Gegner-Spur - Integrationsaudit

**Stand:** 17. Juli 2026
**Kanon:** `tasks/HANDOFF-2026-07-17.md`, `tasks/design-canon-2026.md` und
die Gegner-Gates aus `tasks/goty-2026-masterplan.md`

## Ergebnis

Die feste Tutorialbesetzung ist produktiv angebunden. Öffentliche Tendenzen sowie
die neue automatische und optionale manuelle Auswahl sind als isoliertes,
getestetes Datenmodul vorhanden, aber noch nicht als vollständiger Produktflow
integriert. Der Status `integriert` ist deshalb nur für Hana/Noah/Jonas und deren
Sitzreihenfolge korrekt.

| Anforderung | Status | Beleg |
|---|---|---|
| Geführte Partie mit Hana, Noah, Jonas | Produktiv integriert und fail-closed | `App/BotProfiles.json` definiert IDs und links/across/rechts. Der Contract pinnt die drei IDs und verwirft fehlende Sitze, unbekannte oder doppelte Personen. `GameState` hält den validierten Katalog und startet bei einem Fehler keine Tutorialrunde. |
| Sichtbare stabile Sitze | Produktiv, mit Restschuld | `GameState.name(of:)` bindet Namen an UI-Sitz 1-3; die Phasen rendern über diese UI-Sitze. Der Katalog modelliert zusätzlich `left`, `across`, `right`. `GameState` speichert produktiv jedoch nur die drei Namen, nicht `OpponentID` und `StableOpponentSeatID`. |
| First-Run-Intro zeigt dieselben drei Personen | Produktiv aus einer Quelle | Portrait und Landscape iterieren über `game.tutorialOpponentNames`; dieselbe kuratierte Katalogbesetzung wird vor dem Tutorial übernommen. |
| Öffentliche Spieltendenzen | Nur Datenmodul | `PublicTendencyBasis` erlaubt nur öffentlich beobachtbares Entscheidungstempo oder Initiative; Disclosure ist erst nach der ersten verstandenen Poch-Entscheidung. Es gibt aber keinen produktiven `Gegner lesen`-Beat, keinen Disclosure-Zustand und keine `opponent.tendency.*`-Einträge im Lokalisierungskatalog. |
| Freie Partie automatisch besetzen | Produktiv über Altpfad, neues Modul nicht integriert | Freie Tische werden derzeit automatisch gefüllt, aber `OpponentRoster.draw` nutzt `randomElement()` und `shuffled()`. Der deterministische Katalogpfad `OpponentSelection.automatic` wird außerhalb des Contract-Tests nicht aufgerufen. |
| Optionale manuelle Auswahl | Nur Modul/Platzhalter | `manualSelectionOptions` und `OpponentSelection.manual` sind implementiert und getestet. Es gibt weder einen aufrufenden App-Pfad noch eine Auswahloberfläche oder lokalisierte Copy. |
| Gemeinsame Datenquelle für sichtbares Profil und Botverhalten | Teilweise produktiv | `App/BotProfiles.json` enthält Descriptor, Tendenz und Botparameter gemeinsam. `GameState` lädt produktiv die Botparameter nach Anzeigename. Die Descriptor-/Tendenzseite erreicht die UI noch nicht. |
| Portraitzustände | Assetseitig vorhanden | Für alle 11 Profile liegen die sechs benötigten Zustände `Neutral`, `Thinking`, `Pressure`, `Surprised`, `Winning`, `Defeated` vor: 66 von 66 erwarteten PNGs. |

## Informationsgrenze

- `OpponentDescriptor` enthält nur ID, Anzeigename, Portraitpräfix und öffentliche
  Tendenz. Hand, Kartenstärke, Trumpf und nächste Aktion sind nicht Teil des
  Präsentationsmodells.
- `PublicTendencyBasis` kann ausschließlich aggregierte öffentliche Beobachtungen
  ausdrücken. Das schützt die Copy-Schnittstelle vor einer direkten Handstärke-
  Korrelation.
- Die Bot-Regeltests bestätigen zusätzlich die PochKit-Grenze: Bots entscheiden
  über `BotObservation` beziehungsweise `PlayoutBotObservation`; fremde Hände sind
  strukturell nicht verfügbar.
- Nicht belegt ist bislang die produktive Messung einer Tendenz aus mehreren
  öffentlichen Entscheidungen. Die Daten benennen nur die erlaubte Evidenzklasse.

## Ausgeführte Checks

```text
swiftc App/OpponentRosterCatalog.swift Tests/OpponentRosterContractTests.swift
OpponentRosterContractTests: PASS

swift test --package-path PochKit --filter BotBrainTests
8 Tests, 0 Fehler

Assetprüfung aus den 11 portraitAssetPrefix-Werten:
66 von 66 erwarteten Zustands-PNGs vorhanden

rg '"opponent\.tendency\.' App/Localizable.xcstrings
0 Treffer
```

Der Contract-Test belegt feste Tutorial-IDs und -Reihenfolge, Fail-closed-Verhalten
des Katalogs bei fehlenden Sitzen, unbekannten oder doppelten Personen,
deterministische automatische Auswahl, Duplikatschutz der manuellen Auswahl,
stabile Sitzzuordnung und ein präsentationssicheres Descriptor-Modell. Der Katalog
verwirft außerdem doppelte Anzeigenamen und Portraitpräfixe sowie weniger als drei
automatisch verfügbare Personen. Er belegt nicht, dass diese Pfade von der
Produkt-UI aufgerufen werden.

## Risiken

1. **Offene Produktintegration:** Die Orchestrierung führt Tendenzen und Auswahl
   korrekt als teilintegriert; sichtbar, lokalisiert und durch einen Freigabezustand
   geschützt sind sie noch nicht.
2. **Zwei Roster-Systeme:** Der freie Tisch nutzt den alten Zufallspfad; der neue
   deterministische Resolver bleibt ungenutzt. Replays und Tests können deshalb die
   produktive Gegnerbesetzung nicht reproduzieren.
3. **Identitätsverlust:** Die zentrale Schicht reduziert `OpponentSeat` auf Namen.
   Eine spätere manuelle Auswahl oder Tendenzanzeige müsste Identität wieder über
   Strings rekonstruieren.
4. **Skip-Kante:** Das First-Run-Intro zeigt immer Hana/Noah/Jonas. `Ohne Einführung
   spielen` startet anschließend den freien Altpfad und kann unvermittelt andere
   Personen zeigen.
5. **Doppelte Decoder:** `GameState.loadBotProfiles` decodiert die Datei neben dem
   validierten Rosterpfad separat und erzeugt ein Dictionary über Anzeigenamen.
   Doppelte Namen würden dort vor der Katalogvalidierung abbrechen. Der Lead-Hook
   muss daher zuerst den Katalog validieren und die Botprofil-Zuordnung anschließend
   duplikatsicher aus derselben Datei erzeugen; mittelfristig gehört beides in einen
   gemeinsamen Loader.

## Minimaler Lead-Integrationsvorschlag

1. Freies Spiel ruft standardmäßig
   `lineup(for: .automatic(seed: sessionSeed, excludingPrevious: previousIDs))`
   auf. Der Seed gehört zur Session-/Präsentationsebene und darf nicht aus Karten
   oder Handstärke entstehen.
2. Eine freiwillige Aktion `Mitspieler wählen` reicht exakt drei eindeutige IDs an
   `.manual`; automatische Besetzung bleibt die Primärroute. Die UI zeigt höchstens
   drei verständliche öffentliche Tendenzen, keine Werte oder Wahrscheinlichkeiten.
3. Nach dem bestätigten ersten Poch-Entscheidungsbeat darf der Presentation Director
   einmalig den optionalen Beat `Gegner lesen` freigeben. Er zeigt genau eine
   aggregierte Tendenz und den Hinweis `Neigung, kein Versprechen`.
4. Vor Sichtbarkeit werden Titel und Zusammenfassung der drei vorhandenen
   Tendenz-IDs in DE, EN, FR, IT, ES, NL und PL ergänzt und per UI-Test gegen den
   Disclosure-Zustand geprüft.

Bis Schritt 4 ist die Gegner-Spur für den aktuellen Melden-Vertical-Slice belastbar,
aber nicht für die kanonische Poch-Einführung oder freie Gegnerwahl vollständig
abgenommen.
