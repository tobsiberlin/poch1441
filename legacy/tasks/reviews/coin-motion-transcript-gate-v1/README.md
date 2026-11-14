# Coin Motion Transcript Gate V1

Eng begrenzter Build-Time-Proof für genau eine Track-B-Außenmulde. Der Proof
schreibt für zwölf deterministische Seeds vollständige 6-DoF-Transkripte mit
Position, Quaternion, linearer und angularer Geschwindigkeit sowie benannten
Kontaktmarkern.

Der Proof besitzt genau einen Runtime-Bucket mit zwölf Transkripten. Seine
Auswahlprüfung schützt die letzten acht Würfe vor Wiederholung. Der Release ist
der Commit-Punkt: Vorher darf zur sichtbaren Quelle abgebrochen werden, im
Freiflug ist ausschließlich eine gemeinsame Zeitskalierung zulässig und nach
dem Erstkontakt läuft das Transkript immer bis zur zertifizierten Ruhe.

```sh
swift run -c release coin-transcript-gate
```

Ein visueller Beleg ist ausdrücklich erst nach einem vollständig grünen
Modellgate zulässig. Die Pipeline enthält weder App-Integration noch Audio,
Haptik oder ein vollständiges Auszahlungssystem.
