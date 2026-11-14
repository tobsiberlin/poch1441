# Coin Motion Material Lock V2

V2 liest die 106/106-grüne V1-Physik, Commit-Policy und Transcript-Auswahl nur
als signiertes Zertifikat. Der Solver wird weder kopiert noch verändert.

Zuerst wird ausschließlich der enge Crop in echten Zielpixeln erzeugt:

```sh
swift run -c release coin-material-lock --crop-gate
```

Nur nach bestandener menschlicher Materialabnahme darf der einzelne
ungeschnittene Proof entstehen:

```sh
swift run -c release coin-material-lock --uncut
```
