# Coin Motion Transcript Gate V1 - Visual RED

## Part 1 - Findings

| Before | After | Why |
| --- | --- | --- |
| Frühere Einzelpunktkontakte konnten bei fast flacher Münze unrealistische Kippenergie erzeugen. | Ereigniszeit-Auflösung plus verteilter Flächenmanifold für nahezu parallelen Kontakt; sonst endlicher Zylinderimpuls ([CoinPhysics.swift:282](Sources/CoinTranscriptGate/CoinPhysics.swift#L282), [CoinPhysics.swift:398](Sources/CoinTranscriptGate/CoinPhysics.swift#L398)). | Ein flacher Münzkontakt ist kein mathematischer Einzelpunkt. Der Manifold verhindert künstliche Kippwinkelgeschwindigkeit, ohne Geschwindigkeitsvektoren hart auf null zu setzen. |
| Ein technisch korrekt zusammengesetzter Rasterbeleg könnte fälschlich als visuell freigegeben gelten. | Technisches Modell **GREEN**, menschliches Material-/Signature-Gate **RED**; keine Integration. | Asset-Herkunft, Schattenebene und Occlusion-Pass beweisen noch nicht, dass Metall, Relief und Kontakt im Zielbild lesbar sind. |
| Die Münzfläche wird im Erstbeleg auf nur `22.4 px` Breite und `0.61` vertikale Projektion gebracht ([EvidenceRenderer.swift:155](Sources/CoinTranscriptGate/EvidenceRenderer.swift#L155)). | Nächster isolierter Versuch muss Relief, Patina, gerändelte Kante und anisotropes Licht in der tatsächlichen Zielprojektion vor dem Gesamtscreen nachweisen. | Die aktuelle Projektion vernichtet die entscheidenden Materialfrequenzen und lässt die Kante wie eine einfarbige braune Scheibe wirken. |
| Cancel könnte als frei retargetbare Flugbahn missverstanden werden. | Release ist der Commit-Punkt: vorher Rückkehr zur sichtbaren Quelle, im Freiflug nur gemeinsame Zeitskalierung, nach Erstkontakt Transcript bis Ruhe und erst dann sichtbare Gegenbewegung ([CoinPhysics.swift:100](Sources/CoinTranscriptGate/CoinPhysics.swift#L100), [main.swift:62](Sources/CoinTranscriptGate/main.swift#L62)). | Ein gebackener Flug bleibt räumlich kausal und kann nach Kontakt nicht unsichtbar zurückgesetzt werden. |

## Part 2 - Verdict

**RED. Nicht integrieren.**

Das eng begrenzte Modellgate ist erstmals belastbar grün: zwölf deterministische
6-DoF-Transkripte bestehen alle Physik-, Ruhe-, Containment-, Commit- und
Auswahlprüfungen. Der danach einmalig erzeugte 402x874-Erstbeleg besteht jedoch
das menschliche Material-/Signature-Gate nicht. Die Münze liest sich im echten
Track-B-Gesamtbild als kleiner orangefarbener Puck. Relief, Patina, Kantenlicht
und Bodenkontakt sind in Zielauflösung nicht stark genug, um gealtertes reales
Metall eindeutig von einer generischen Coin-Demo zu unterscheiden.

Es gibt keine App-Integration, kein vollständiges Auszahlungssystem und keine
zweite visuelle Iteration.

## Technisches Modellgate

Ausgeführt mit:

```sh
swift run -c release coin-transcript-gate
```

Ergebnis: `GREEN - 106/106 checks passed`. Davon sind 102 Modell-, Policy- und
Auswahlchecks; vier weitere Checks sichern nur die technische Komposition des
Erstbelegs. Sie ersetzen ausdrücklich keine ästhetische Abnahme.

| Messwert | Beobachtung | Gate |
| --- | ---: | ---: |
| Seeds | `12 / 12` grün | `12 / 12` |
| Kontakt-Energiegewinn | maximal `0.00000 %` | `<= 0.25 %` |
| Penetration | maximal `9.2741e-12 physische Pixel` | `<= 0.5 px` |
| Ruhefenster | mindestens `1.683 s` | `>= 0.120 s` |
| finale lineare Geschwindigkeit | maximal `7.2271e-25 m/s` | `< 0.001 m/s` |
| finale angulare Geschwindigkeit | maximal `1.3848e-7 rad/s` | `< 0.002 rad/s` |
| kleinster Randabstand im Well | `7.530 mm` | `>= 0 mm` |
| harte Vektornullung | keine Zuweisung | verboten |

Die Schwellen stehen zentral in
[CoinPhysics.swift:92](Sources/CoinTranscriptGate/CoinPhysics.swift#L92). Die
Transkripte enthalten Position, Quaternion, lineare und angulare Geschwindigkeit
sowie `impactBegin`, `contactImpulse`, `supportBegin`, `restWindowBegin` und
`restCertified` ([CoinPhysics.swift:36](Sources/CoinTranscriptGate/CoinPhysics.swift#L36)).

## Commit- und Auswahlvertrag

- `prepared`: Cancel kehrt zur sichtbaren Quellpose zurück.
- `freeFlight`: committed; keine räumliche Retarget-/Cancel-Bahn, nur gemeinsame
  Zeitskalierung.
- `postContact`: Transcript läuft bis zertifizierte Ruhe; ein Rollback wäre eine
  neue sichtbare Gegenbewegung.
- Der einzige tatsächlich belegte Runtime-Bucket
  `402x874|queen|single-cent|standard|aged-copper-smoke-polycarbonate` besitzt
  zwölf Transkripte.
- 48 deterministische Auswahlzüge wurden gegen ein geschütztes Fenster von acht
  Würfen geprüft; es trat keine Wiederholung innerhalb dieses Fensters auf
  ([main.swift:149](Sources/CoinTranscriptGate/main.swift#L149)).

## Evidenz

- Vollständige Transkripte:
  [coin-6dof-transcripts-12-seeds.json](Evidence/coin-6dof-transcripts-12-seeds.json)
- Technische Zusammenfassung:
  [gate-summary.json](Evidence/gate-summary.json)
- Einmaliger 402x874-Erstbeleg:
  [402x874-track-b-queen-contact.png](Evidence/402x874-track-b-queen-contact.png)
- Kompositionsbeleg:
  [visual-evidence-receipt.json](Evidence/visual-evidence-receipt.json)

Der Erstbeleg verwendet den echten Track-B-Welthintergrund und das vorhandene
`TravelCent0`-Asset. Schatten und Frontlippe werden als getrennte Durchgänge
komponiert ([EvidenceRenderer.swift:80](Sources/CoinTranscriptGate/EvidenceRenderer.swift#L80)).
Die menschliche Sichtprüfung überstimmt den rein technischen Receipt.

## Nächster zulässiger Versuch

Nicht das Flugmodell erneut anfassen. Der nächste Spike darf ausschließlich die
Material-/Projektionsbrücke lösen: winkelabhängiges Relief oder eine echte
Mesh-/Normal-Map-Repräsentation, physikalisch an dasselbe `WorldLightProfile`
gebunden, mit einem Kontaktcrop in tatsächlicher Zielauflösung als Stop-Gate vor
einem neuen Gesamtscreen. Erst wenn die Münze dort eindeutig als altes Metall
auf altem Kunststoff lesbar ist, darf wieder ein vollständiger Beleg entstehen.

## Entscheidung nach Impact

### Origin, physicality & cohesion

Die Bewegungsursache, der Commit-Punkt und die Kontaktfolge sind jetzt kohärent.
Die visuelle Oberfläche ist es noch nicht: Relief, Kante und Schatten bilden
keine glaubwürdige gemeinsame Material- und Lichtsignatur.

**Block.** Das Modell darf als Grundlage für den nächsten isolierten
Material-Proof erhalten bleiben; die aktuelle Darstellung darf weder integriert
noch als GOTY-Evidenz geführt werden.
