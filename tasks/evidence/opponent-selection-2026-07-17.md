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
| Geführte Partie mit Hana, Noah, Jonas | Produktiv integriert | `App/BotProfiles.json:93-96` definiert links/across/rechts. `App/GameState.swift:312-330` lädt diese Besetzung vor jeder Tutorialrunde. `App/ContentView.swift:833-840` erzwingt vier Tischplätze und startet anschließend die Tutorialrunde. |
| Sichtbare stabile Sitze | Produktiv, mit Restschuld | `GameState.name(of:)` bindet Namen an UI-Sitz 1-3; die Phasen rendern über diese UI-Sitze. Der Katalog modelliert zusätzlich `left`, `across`, `right`. `GameState` speichert produktiv jedoch nur die drei Namen, nicht `OpponentID` und `StableOpponentSeatID`. |
| First-Run-Intro zeigt dieselben drei Personen | Produktiv, aber doppelte Wahrheit | Portrait und Landscape nennen Hana, Noah und Jonas direkt in `App/ContentView.swift:555-558` und `:719-724`, statt die kuratierte Katalogbesetzung zu lesen. Ein Datenfehler könnte Intro und Partie auseinanderlaufen lassen. |
| Öffentliche Spieltendenzen | Nur Datenmodul | `PublicTendencyBasis` erlaubt nur öffentlich beobachtbares Entscheidungstempo oder Initiative; Disclosure ist erst nach der ersten verstandenen Poch-Entscheidung. Es gibt aber keinen produktiven `Gegner lesen`-Beat, keinen Disclosure-Zustand und keine `opponent.tendency.*`-Einträge im Lokalisierungskatalog. |
| Freie Partie automatisch besetzen | Produktiv über Altpfad, neues Modul nicht integriert | Freie Tische werden derzeit automatisch gefüllt, aber `App/GameState.swift:133-169` nutzt `randomElement()` und `shuffled()`. Der deterministische Katalogpfad `OpponentSelection.automatic` aus `App/OpponentRosterCatalog.swift:85-90,190-226` wird außerhalb des Contract-Tests nicht aufgerufen. |
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

Der Contract-Test belegt feste Tutorialreihenfolge, deterministische automatische
Auswahl, Duplikatschutz der manuellen Auswahl, stabile Sitzzuordnung und ein
präsentationssicheres Descriptor-Modell. Er belegt nicht, dass diese Pfade von der
Produkt-UI aufgerufen werden.

## Risiken

1. **Doppelte Tutorialwahrheit:** Das Intro ist hardcodiert, die Partie liest JSON.
2. **Offene Produktintegration:** Die Orchestrierung führt Tendenzen und Auswahl
   korrekt als teilintegriert; sichtbar, lokalisiert und durch einen Freigabezustand
   geschützt sind sie noch nicht.
3. **Zwei Roster-Systeme:** Der freie Tisch nutzt den alten Zufallspfad; der neue
   deterministische Resolver bleibt ungenutzt. Replays und Tests können deshalb die
   produktive Gegnerbesetzung nicht reproduzieren.
4. **Identitätsverlust:** Die zentrale Schicht reduziert `OpponentSeat` auf Namen.
   Eine spätere manuelle Auswahl oder Tendenzanzeige müsste Identität wieder über
   Strings rekonstruieren.
5. **Skip-Kante:** Das First-Run-Intro zeigt immer Hana/Noah/Jonas. `Ohne Einführung
   spielen` startet anschließend den freien Altpfad und kann unvermittelt andere
   Personen zeigen.

## Minimaler Lead-Integrationsvorschlag

1. `GameState` hält eine `OpponentLineup`-Instanz als einzige Tischidentität und
   leitet Namen, Portraitpräfix und Botprofil daraus ab. Das First-Run-Intro liest
   dieselbe kuratierte Lineup statt eigener Stringlisten.
2. Freies Spiel ruft standardmäßig
   `lineup(for: .automatic(seed: sessionSeed, excludingPrevious: previousIDs))`
   auf. Der Seed gehört zur Session-/Präsentationsebene und darf nicht aus Karten
   oder Handstärke entstehen.
3. Eine freiwillige Aktion `Mitspieler wählen` reicht exakt drei eindeutige IDs an
   `.manual`; automatische Besetzung bleibt die Primärroute. Die UI zeigt höchstens
   drei verständliche öffentliche Tendenzen, keine Werte oder Wahrscheinlichkeiten.
4. Nach dem bestätigten ersten Poch-Entscheidungsbeat darf der Presentation Director
   einmalig den optionalen Beat `Gegner lesen` freigeben. Er zeigt genau eine
   aggregierte Tendenz und den Hinweis `Neigung, kein Versprechen`.
5. Vor Sichtbarkeit werden Titel und Zusammenfassung der drei vorhandenen
   Tendenz-IDs in DE, EN, FR, IT, ES, NL und PL ergänzt und per UI-Test gegen den
   Disclosure-Zustand geprüft.

Bis Schritt 4 ist die Gegner-Spur für den aktuellen Melden-Vertical-Slice belastbar,
aber nicht für die kanonische Poch-Einführung oder freie Gegnerwahl vollständig
abgenommen.
