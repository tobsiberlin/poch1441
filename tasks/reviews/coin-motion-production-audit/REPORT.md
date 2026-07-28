# Produktionsaudit: Münzbewegung

Stand: 20.07.2026, 01:24 Uhr  
Urteil: **P0 BLOCK - visuell und physikalisch nicht freigegeben**

## Beobachteter Produktionspfad

- `ImpactFlight` besitzt nur einen skalaren Fortschritt und übersetzt seinen Inhalt zweidimensional (`App/ImpactFlight.swift:106-159`, `183-205`). Münzlage, Neigung, Eigenrotation und Winkelgeschwindigkeit sind nicht Teil des Modells.
- Der Pfad ist eine quadratische Bildschirmraumkurve (`App/Effects.swift:10-46`). Das hält den Fortschritt linear, bildet aber weder reale Brettprojektion noch Kontakte mit Boden, Rand oder anderen Münzen ab.
- Der Schatten ist direkt an der fliegenden Münzansicht befestigt und bleibt mit festen Werten unverändert (`App/Phase2View.swift:1465-1472`, `App/DealOverlay.swift:472-479`). Es gibt keinen separaten, auf den Tisch projizierten Schatten.
- Beim logisch abgeschlossenen Flug ruft `ImpactFlight` sofort `onImpact` auf (`App/ImpactFlight.swift:153-169`). Ein sichtbarer Erstkontakt, Rückprall, Rutschen/Rollen und eine kurze Setzphase fehlen.
- Mehrere Zielpositionen werden über feste Bildschirmraum-Offsets komponiert (`App/Phase2View.swift:1443-1459`, `App/DealOverlay.swift:484-491`). Die Offsets sind keine aus einer geschlossenen Muldengeometrie berechneten Ruheposen.

## Warum der Wurf unglaubwürdig wirkt

1. Eine flache Textur wandert, statt dass ein schwerer Körper rotiert.
2. Der Schatten bewegt sich wie ein Teil der Münze, statt als Kontaktinformation auf dem Tisch zu bleiben.
3. Der Materialmoment fehlt: Flug und gesetzter Zustand wechseln ohne lesbaren Impuls.
4. Rand, Boden und Nachbarmünzen können die Bewegung nicht beeinflussen.
5. Wiederholungen unterscheiden sich überwiegend durch kleine feste Offsets und wirken deshalb choreografiert.

## Produktionsgate für einen Ersatz

- Gesamter echter Spielscreen bei `390x844`, `402x874` und `667x375`, nicht nur ein isolierter Miniatur-Crop.
- 3D-Lage oder eine nachweislich äquivalente Projektion mit kontinuierlicher Winkel- und Translationsgeschwindigkeit.
- Getrennter Tischschatten, dessen Kontur, Versatz und Schärfe von Höhe, Lage und Licht abhängen.
- Expliziter Erstkontakt mit messbarem Geschwindigkeitswechsel, danach höchstens zwei kurze Nachkontakte und eine ruhige Restlage.
- Keine nachträgliche Zielplatzierung, kein hartes Velocity-Zeroing, kein Doppelbild und kein Schweben.
- Ruhepose vollständig innerhalb der berechneten Mulden-Safe-Zone.
- 8-12 aufeinanderfolgende Würfe mit unterschiedlichen deterministischen Seeds, um Rhythmus und Wiederholungsmüdigkeit sichtbar zu prüfen.
- Reduced Motion setzt den gültigen Endzustand sofort und wartet keine unsichtbare Flugzeit ab.

## Integrationsentscheidung

Die vorhandene Präsentationslogik bleibt bis zu einem bestandenen Ersatzbeleg ein bekannter P0-Qualitätsmangel. Keiner der bisherigen Laborprototypen V1-V4, RealityKit V1-V3 oder Jolt erfüllt das Produktionsgate. Es wird nichts aus diesen Spikes integriert.
