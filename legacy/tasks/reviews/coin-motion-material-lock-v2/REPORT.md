# Coin Motion Material Lock V2 - RED

## Verdict

**RED. Kein ungeschnittener Proof, keine Integration.**

V2 übernimmt V1 vollständig unverändert und prüft ausschließlich die visuelle
Materialbrücke. Der technische Crop-Renderer ist grün, aber der menschliche
Material-Lock scheitert: In der realen 402x874-Projektion mit `19.8 px`
Münzdurchmesser bleiben Kupfersilhouette, dünne Kante und Bodenkontakt erkennbar.
Die 1-Cent-Prägung, Patina und orientierungsabhängige Reliefantwort überleben die
Zielabtastung dagegen nicht überzeugend. Die rekonstruierte große `1` reduziert
sich auf ein 2-3-Pixel-Kontrastsignal und liest sich eher wie eine Kerbe oder
Farbmarke als wie geprägtes Metall.

Die Freigabebedingung für `--uncut` ist damit nicht erfüllt. Die Datei
`402x874-uncut-material-proof.png` wurde bewusst nicht erzeugt.

## Unveränderte V1-Grundlage

V2 liest die V1-Ergebnisse ausschließlich aus deren Evidence-Ordner und prüft
vor jedem Materiallauf:

- V1-Verdict `GREEN`
- `106` bestandene Checks ohne Fehler
- `12` Transkripte
- Commit-Punkt `release`
- Freiflug `committedTimeScaleOnly`
- nach Kontakt `finishTranscriptThenVisibleCountermove`
- Auswahlpool `12`, Schutzfenster `8`, keine Wiederholung im Audit

Die Prüfung steht in [main.swift:17](Sources/CoinMaterialLock/main.swift#L17).
Zusätzlich bindet V2 die unveränderten V1-Dateien über SHA-256:

- Gate-Summary:
  `8ee7ce5321d7a42556c6bc64ba5ba5da46e2df2d3deab788c6385d4fcf649737`
- 12-Seed-Transkripte:
  `76e883093a396548b07060d29d3f2149857240c1026cd1fefe35450de52d98be`

Es wurde kein Solver-, Transcript-, Cancel- oder Selection-Code kopiert oder
verändert.

## Materialversuch

Der neue Renderer:

- beschneidet den 512er Quell-Asset auf seinen echten Alpha-Rand
  (`310 x 309 px`) statt die transparenten Außenränder mitzuskalieren
  ([MaterialRenderer.swift:124](Sources/CoinMaterialLock/MaterialRenderer.swift#L124));
- hält den physischen Durchmesser bei `19.8 px`, statt die Münze für bessere
  Lesbarkeit unrealistisch zu vergrößern
  ([MaterialRenderer.swift:34](Sources/CoinMaterialLock/MaterialRenderer.swift#L34));
- rendert sechsfach supersampled und reduziert erst abschließend auf 402x874
  ([MaterialRenderer.swift:56](Sources/CoinMaterialLock/MaterialRenderer.swift#L56));
- verwendet das echte `TravelCent0`-Kupferbild mit gedämpfter Albedo,
  Relief-Faltung und wiederhergestellter Alpha-Silhouette
  ([MaterialRenderer.swift:148](Sources/CoinMaterialLock/MaterialRenderer.swift#L148));
- setzt abgenutzte Kante, geringe Patina und eine ausschließlich über
  Licht-/Schattenkanten rekonstruierte `1` ohne Druckfarbe
  ([MaterialRenderer.swift:226](Sources/CoinMaterialLock/MaterialRenderer.swift#L226),
  [MaterialRenderer.swift:272](Sources/CoinMaterialLock/MaterialRenderer.swift#L272));
- behält `track-b-lamp-left-v1`, separaten Bodenschatten und die neu aufgelegte
  Frontlippe
  ([MaterialRenderer.swift:5](Sources/CoinMaterialLock/MaterialRenderer.swift#L5),
  [MaterialRenderer.swift:208](Sources/CoinMaterialLock/MaterialRenderer.swift#L208),
  [MaterialRenderer.swift:314](Sources/CoinMaterialLock/MaterialRenderer.swift#L314)).

## Sichtprüfung

Geprüft wurde ausschließlich der Crop aus dem echten 402x874-Downsample:

[material-crop-gate-actual-76x76.png](Evidence/material-crop-gate-actual-76x76.png)

### Bestanden

- Münze liegt innerhalb der zertifizierten V1-Endpose.
- Physische Größe blieb unverändert.
- Kupferfarbe ist von Gold unterscheidbar.
- Elliptische Projektion und dünne Seitenkante lesen sich räumlicher als V1.
- Schatten ist eine eigene Bodenebene.
- Frontlippenpass bleibt von Münze und Schatten getrennt.

### Blocker

- Die reale Foto-Prägung fällt beim Downsampling fast vollständig aus.
- Die ergänzte gleichfarbige Relief-`1` ist in Zielpixeln noch kein eindeutig
  metallischer Prägeschlag.
- Patina wird zu diffuser Farbvariation statt zu gealterter Kupferoberfläche.
- Die sehr kleine Oberseite trägt zu wenig winkelabhängige Information, um den
  Materialwechsel unter demselben Weltlicht während einer Rotation glaubwürdig
  zu zeigen.
- Im normalen Gesamtscreen wäre die Verbesserung gegenüber einem generischen
  orangefarbenen Puck noch nicht presse- oder GOTY-tauglich.

Der technische Receipt ist deshalb nur
`TECHNICAL_GREEN_HUMAN_PENDING`; die menschliche Entscheidung in
[human-material-verdict.json](Evidence/human-material-verdict.json) ist bindend
und lautet `RED`.

## Nächster zulässiger Ansatz

Kein weiteres Nachschärfen dieses einzelnen Rasterfotos. Die physische
20-Pixel-Projektion braucht eine vorab für kleine Bildschirmgrößen entwickelte
mehrkanalige Repräsentation:

1. echte hochauflösende Kupfer-Albedo ohne eingebackenes Licht;
2. separate Height-/Normal-Map der realen 1-Cent-Prägung und Randrändelung;
3. Roughness-/Oxidationsmaske mit großskaligen, im Downsample stabilen
   Materialinseln;
4. mindestens neun vorgerenderte Orientierungs-/Licht-Buckets pro verwendeter
   Runtime-Kombination oder ein kleiner Metal-Renderer mit demselben
   `WorldLightProfile`;
5. Material-Lock erneut zuerst am unvergrößerten Zielcrop, bevor ein
   ungeschnittener Beleg zulässig wird.

Der V1-Transcript-Player bleibt dabei unangetastet.
