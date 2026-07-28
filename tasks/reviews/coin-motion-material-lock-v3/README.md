# Coin Motion Material Lock V3

V3 prüft gealtertes Kupfer über Zeit statt anhand einer statisch lesbaren
Prägung. Es liest V1 ausschließlich als SHA-gebundenes Zertifikat und rendert
zehn reale 402x874-Frames plus zehn unvergrößerte 76px-Crops. Ein
ungeschnittener Proof bleibt bis zur menschlichen Abnahme gesperrt.

```sh
swift run -c release coin-material-time-gate
```

Nach bestandener menschlicher Materialabnahme erzeugt derselbe Renderer genau
einen ungeschnittenen 402x874-Proof vom Release bis zum V1-zertifizierten
Ruhepunkt. Das 240-Hz-Transcript wird dabei ohne Zeitlupe mit 60 fps abgetastet.

```sh
swift run -c release coin-material-time-gate --uncut-proof
```
