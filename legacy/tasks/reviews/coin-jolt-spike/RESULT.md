# Jolt 5.6.0 Headless-Spike - SOLVER RED / iOS LINK GREEN / PRODUCTION RED

**Ausgeführt:** 19. Juli 2026  
**Host:** macOS arm64, Apple clang 17.0.0  
**Ziel:** iOS 17, unverändertes maximales Transientengate `0,150 mm`

## Urteil

**Der Jolt-Solverpfad ist für den unveränderten Münzvertrag RED.**

Alle sechs vor dem ersten Lauf fixierten Parameterkombinationen überschreiten
das `0,150-mm`-Gate in den geneigten und dynamischen Pflichtfällen deutlich.
Die beste vorab deklarierte Kombination, `S5-zero-slop`, erreicht zwar exakt
aufliegende ruhende Kontrollkörper, aber noch:

- `2,204678 mm` bei der 12-Punkt-Münze mit 3° Neigung,
- `2,292945 mm` bei der 48-Punkt-Münze mit 3° Neigung,
- `1,702590-2,790138 mm` in den dynamischen zentralen Zylinderfällen,
- `0,993371 mm` im Lippenfall.

Der Lippenfall erreicht in keiner Kombination den geforderten echten Kontakt
mit dem Front-Lip. Damit wäre er selbst ohne Penetrationsfehler RED.

**Der iOS-17-arm64-Compile/Link ist GREEN.** Der gleiche Harness und die gleiche
statische Jolt-Distribution wurden als Mach-O-arm64-Executable mit
`LC_BUILD_VERSION platform IOS`, `minos 17.0`, `sdk 26.2` gelinkt. Das ist kein
Gerätelauf und keine App-Integration.

**Die Produktionsfreigabe bleibt RED.** Es fehlen ein echter iOS-17-Gerätelauf,
neun gleichzeitig aktive Münzen bei 60 FPS, Geräte-Energiemessung sowie die
SwiftUI-/RealityKit-Integration. Diese fehlenden Gates würden das bereits rote
Solvergate ohnehin nicht retten.

## Unveränderte Messregeln

- Faktor `50`: `22 mm × 2,2 mm` werden zu Radius `0,55` und Halbdicke `0,055`
  in Jolt-Einheiten.
- Fester Schritt `1/120 s`, ein Collision Step pro Update.
- `JPH_CROSS_PLATFORM_DETERMINISTIC`, präzises Floating-Point und
  `-ffp-contract=off`.
- Keine Teleports, keine Renderkorrektur, kein manuelles Velocity-Zeroing. Der
  einzige Velocity-Setter setzt den dokumentierten Anfangszustand vor Step 1.
- Der analytische Bodengap wird aus Körpertransform und Nominalshape bestimmt.
  Zusätzlich wird die positive `ContactManifold.mPenetrationDepth` erfasst; das
  Gate verwendet konservativ das Maximum beider Werte.
- Mechanische Energie umfasst Potential-, lineare und rotatorische Energie.
  Grenzwert für positives Wachstum: `1 %`.
- Ruhe: lineare Geschwindigkeit `< 0,015 m/s`, Winkelgeschwindigkeit
  `< 0,8 rad/s`, ununterbrochen mindestens `0,750 s` innerhalb des jeweiligen
  Zeitbudgets.
- Lippenkontakt stammt ausschließlich aus dem Jolt-ContactListener gegen den
  statischen Front-Lip.

## Vorab fixierte Solvermatrix

| Konfiguration | Slop intern / Produkt | Speculative Distance | Velocity / Position Steps | GREEN-Fälle | maximales Pflichtfall-Ergebnis | Urteil |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| S1-limit-slop | `0,00750` / `0,150 mm` | `0,02000` | `10 / 4` | `3 / 9` | `3,093412 mm` | RED |
| S2-half-slop | `0,00375` / `0,075 mm` | `0,01500` | `12 / 6` | `3 / 9` | `2,939894 mm` | RED |
| S3-fifth-slop | `0,00150` / `0,030 mm` | `0,01000` | `16 / 8` | `3 / 9` | `2,850041 mm` | RED |
| S4-tenth-slop | `0,00075` / `0,015 mm` | `0,00750` | `20 / 10` | `3 / 9` | `2,820092 mm` | RED |
| S5-zero-slop | `0,00000` / `0,000 mm` | `0,00500` | `24 / 12` | `3 / 9` | `2,790138 mm` | RED |
| S6-balanced | `0,00375` / `0,075 mm` | `0,00750` | `24 / 12` | `3 / 9` | `2,939884 mm` | RED |

Die drei GREEN-Fälle jeder Kombination sind nur die flachen V2-Kontrollen:
12-Punkt-Hull, 48-Punkt-Hull und Box. Alle geneigten/dynamischen Münzfälle
bleiben RED. Slop null und mehr Iterationen reduzieren die Erstaufprall-
Überlappung, eliminieren sie aber nicht. Nachträgliche siebte Kombinationen
oder fallbezogene Kalibrierungen wurden nicht ergänzt.

## Beste Ergebnisse je Pflichtfall

| Pflichtfall | beste transiente Überlappung | Ruhe | Lippe | Urteil |
| --- | ---: | ---: | --- | --- |
| coin-convex12-face | `0,000000 mm` | `0,750 s` | n/a | GREEN |
| coin-convex48-face | `0,000000 mm` | `0,750 s` | n/a | GREEN |
| box-control-face | `0,000000 mm` | `0,750 s` | n/a | GREEN |
| coin-convex12-tilt3 | `2,204678 mm` | `0,750 s` | n/a | RED |
| coin-convex48-tilt3 | `2,292945 mm` | `0,750 s` | n/a | RED |
| central-face-0deg | `2,287722 mm` | `0,750 s` | n/a | RED |
| central-face-minus3deg | `2,790138 mm` | `0,750 s` | n/a | RED |
| central-face-plus3deg | `1,702590 mm` | `0,750 s` | n/a | RED |
| edge-lip-78deg | `0,993371 mm` | nicht gefordert | nein | RED |

Bei den roten Bodenkontakten stimmen analytisches Transformmaximum und
Manifoldmaximum bis auf wenige Millionstel Millimeter überein. Die Werte sind
daher keine bloße Kontaktcallback-Anomalie.

## Determinismus, Energie und Laufzeit

- `6 × 9 × 100 = 5.400` vollständige Läufe.
- Jede Config-/Case-Gruppe hat genau **einen** eindeutigen State-Sequence-Hash;
  erster Mismatch überall `-1`.
- Kein Lauf erzeugte NaN/Infinity oder verließ den definierten Tray-Bereich.
- Das im JSON mit sechs Dezimalstellen gespeicherte maximale positive
  mechanische Energiewachstum ist in allen Fällen `0,000000` und damit GREEN.
- Headless Single-Body-Step auf dem Mac:
  `p50 1,167 µs`, `p95 4,417 µs`, `p99 6,250 µs`, Maximum `125,666 µs`.
- Gesamte 5.400-Lauf-Matrix: `1,366 s` Wall Time, `1,351 s` User CPU,
  `0,008 s` System CPU.

Diese Laufzeit ist nur ein Architekturbeleg für einen einzelnen Körper. Sie
belegt weder 60 FPS im integrierten Renderer noch Energieeffizienz auf iOS.

## Upstream-Pin und Lizenz

- Offizieller Tag: `v5.6.0`
- Commit: `e77f175595e64cb44218cc9d9d56fc365ad0e36a`
- Lizenz: MIT
- `LICENSE` SHA-256:
  `800abe35d64ad9defd636ff1ee8c961e06f0ebca3ef8d10083e8aa0e8ef86ac3`
- Quelle: <https://github.com/jrouwe/JoltPhysics/tree/v5.6.0>

Der vollständige unveränderte Lizenztext liegt in `UPSTREAM-LICENSE.txt`.
Jolt-Quellcode und Buildobjekte wurden ausschließlich in einem
`/private/tmp/poch-jolt-spike-*`-Verzeichnis verwendet und nach Build und Lauf
entfernt. Im Repository ist kein Drittquellcode oder Binary enthalten.

## Reproduktion

```sh
cd tasks/reviews/coin-jolt-spike
./run.sh
```

`run.sh` klont ausschließlich den gepinnten Tag in ein neues explizites
Temp-Verzeichnis, verifiziert Commit und Lizenzhash, baut macOS-arm64, führt die
Matrix aus, versucht den iOS-17-arm64-Link und entfernt das gesamte Temp-
Verzeichnis per Trap. Ein Solver-RED führt absichtlich zu Exitstatus `1`, auch
wenn Build und iOS-Link erfolgreich waren.

Maschinenlesbare und prüfbare Belege:

- `runtime-result.json` - vollständige sechs Konfigurationen, 54 Fallresultate,
  Hash-, Geometrie-, Energie-, Ruhe- und Performancewerte.
- `build-metadata.txt` - Pin, Compiler und Buildstatus.
- `build-macos.log` - macOS-Build-/Laufzusammenfassung.
- `build-ios.log` - iOS-Link und Mach-O-Deploymenttarget.
- `Sources/main.cpp` - eingefrorene Matrix und Messimplementierung.

## Architekturfolge

Jolt 5.6.0 wird für den unveränderten `0,150-mm`-Transientenvertrag nicht in die
App integriert. Der Spike falsifiziert die Annahme, dass Faktor 50 plus enger
Slop und bis zu `24/12` Iterationen allein genügen. Gemäß der vorherigen
Entscheidung ist der nächste technische Kandidat ein eng begrenzter eigener
Persistent-Manifold-Solver. Eine Änderung auf einen visuellen statt transienten
Vertrag bleibt eine separate Produktentscheidung und darf dieses RED nicht
umdeuten.
