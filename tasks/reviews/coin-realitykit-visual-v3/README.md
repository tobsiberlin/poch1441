# RealityKit visual contract V3

Isolierter Simulator-Spike für die visuelle Bewertung der 48-Segment-Münze. Er ändert keine App-Datei und lässt das dokumentierte physische V2-RED von 0,150 mm unverändert.

Der Runner verwendet dieselbe feste Weltkamera für alle drei Ausgabegrößen. Jeder RealityKit-Displayframe wird vermessen. Fortlaufende native PNG-Sequenzframes und 128-x-128-Kontaktcrops liefern den visuellen Beleg. Das technische Urteil und das automatisierte visuelle Pixelurteil werden getrennt im JSON ausgegeben.

Ausführung: `./run.sh`

