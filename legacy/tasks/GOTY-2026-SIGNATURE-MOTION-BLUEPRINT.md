# GOTY 2026 Signature Motion Blueprint

Stand: 20.07.2026, 08:18 Uhr

## Motion Philosophy

Karten und Spielsteine sind keine Animationen. Sie sind die einzigen beweglichen Körper einer ruhigen materiellen Welt.

Jede Bewegung entsteht aus Gewicht, Material, Reibung, Licht und Kontakt. Der Spieler soll niemals über Animationen nachdenken. Er soll glauben, dass diese Objekte wirklich existieren.

Keine Animation darf Aufmerksamkeit auf sich ziehen. Aufmerksamkeit gehört ausschließlich der Spielentscheidung. Gute Motion wird nicht bemerkt, sondern geglaubt.

Jede Bewegung besitzt genau eine Ursache: geben, wählen, spielen, setzen, auszahlen oder zurücknehmen. Es existieren keine dekorativen Bewegungen. Bildschirmerschütterung, Partikel, nachträgliches Einrasten und Bewegung ohne Zustandsbedeutung bleiben ausgeschlossen.

## Materialkanon

Das Spiel besitzt feste Materialfamilien. Jede Bewegung, Lichtreaktion, Klangfarbe und Haptik muss aus ihnen ableitbar sein. Ein Materialwechsel ist eine Produktentscheidung und darf nicht als Animationsdetail geschehen.

| Welt | Körper | Kontaktflächen | Verbindlicher Charakter |
| --- | --- | --- | --- |
| Track A | R1, `36 mm x 3 mm`, gedachtes Gewicht `9-10 g`, mattes Clay-Composite oder durchgefärbte Keramik | kühler blauer Samt, graphit-nachtblauer Körper, satiniertes Aluminium | trocken, dicht, steinig, präzise gerändelt, niemals Pokerchip oder Kunststoff |
| Track B | gleichwertige echte 1-Cent-Kupfermünzen mit kontrollierter Patina und Kantenabnutzung | gealtertes rauchklares Polycarbonat der Snackbox und abgenutztes Holz | metallisch, leicht ungleichmäßig, gebraucht, niemals Goldmünze oder Spielgeld |
| Karten | steifer neutral elfenbeingrauer Karton mit trockener Druckpatina und zurückhaltendem Kantenverschleiß | Karte, Samt, Polycarbonat und Holz je nach Welt | formstabil mit kleiner gespeicherter Materialspannung, niemals Stoff, Gummi oder UI-Fläche |

Jede Tischwelt besitzt genau ein `WorldLightProfile`. Das gebackene Weltasset, Brett, Mulden, Karten, R1, Cent-Münzen und alle Schatten teilen Lichtachse, Farbtemperatur und Härte. Während einer Bewegung darf kein Objekt seine Lichtcharakteristik wechseln.

## Bewegungsidentität

- R1 berührt die Zielfläche bevorzugt zuerst über einen sehr kurzen Kanten-Face-Übergang. Die Lageänderung bleibt flach und überschreitet `20 Grad` nicht. Ein kurzer, trockener Rim-Catch vermittelt die `9-10 g` schwere Keramikscheibe, ohne einen Münzwurf zu imitieren.
- Die Track-B-Cent-Münze zeigt eine kleine materialbedingte Exzentrizität. Sie kippt nach dem Erstkontakt kurz über ihre abgenutzte Kante oder präzediert leicht, bevor sie zur Ruhe kommt. Kontaktklasse, Richtung und Dauer variieren, damit daraus kein wiederholtes Markentrickchen wird.
- Die Poch-Karte trägt `0,8-1,4 mm` gespeicherte Wölbung. Beim Erstkantenkontakt entlädt sie diese Spannung genau einmal und richtet sich auf die Tischfläche aus. Es gibt kein periodisches Atmen und keine dekorative Dauerwölbung.
- Zwei Bewegungen dürfen niemals identisch wirken, obwohl beide deterministisch reproduzierbar sind. Auswahl, Bahnklasse, Kontaktklasse, Materialantwort und Rhythmus bleiben seedbar, müssen aber definierte perzeptuelle Mindestabstände besitzen.

## Gemeinsamer Motion-Kern

- Ein fester Simulationsschritt von `1/240 s` erzeugt reproduzierbare Posen und Kontaktmarker.
- Track A und Track B besitzen je eine kalibrierte Tischprojektion, Lichtachse und semantische Landeflächen.
- Zustand, Bild, Ton und Haptik beziehen sich auf denselben Kontaktmarker.
- Maximal zwei Körper sind gleichzeitig in Bewegung.
- Direkt manipulierbare Karten starten aus der sichtbaren Präsentationspose und bleiben unterbrechbar. Ein nach Release ballistisch fliegender Körper folgt dagegen seiner expliziten Commit- und Cancel-Policy.
- Reduced Motion setzt den korrekten Endzustand ohne Raumflug und ohne unsichtbare Wartezeit.

## Signature-Münzwurf

### Modell

SpriteKit bleibt Bühne, Layer- und Occlusion-System. Die Track-B-Cent-Münze folgt einem physikalisch geprüften 6-DoF-Transcript mit Position, Quaternion, linearer und angularer Geschwindigkeit. R1 verwendet eine eigene flachere Keramik-Transcriptfamilie und übernimmt niemals die kontinuierliche Cent-Rotation. Eine kuratierte Build-Time-Bibliothek enthält Varianten für Außenmulde, Innenmulde, Kontaktklasse und unterschiedliche Belegung. Nur Transcripts mit bestandenem Energie-, Penetrations- und Ruhevertrag gelangen in die App.

Jeder tatsächlich verwendete Runtime-Auswahlbucket enthält mindestens neun zertifizierte Transcripts. Ein Bucket ist die Kombination aus Tischwelt, Zielfläche, Belegungsklasse und Kontaktklasse. Nur so ist garantiert, dass innerhalb der letzten acht Bewegungen keine exakte Wiederholung gewählt werden muss.

### Bewegungsfolge

1. Abheben in `35-65 ms`: sofortige Trennung vom Quellstapel, Schatten bleibt auf der Tischfläche.
2. Freiflug in `210-340 ms`: Track B zeigt Ballistik mit `1,0-1,8` lesbaren Umdrehungen. R1 bleibt unter `20 Grad` Lageänderung.
3. Erstkontakt: ein eindeutiger framegenauer Kontakt für Bild, Audio, Haptik und Zustandsübergabe.
4. Rücksprung in `45-90 ms`: nur `0,8-1,8 mm`, kein dekorativer Bounce.
5. Nachlauf in `90-210 ms`: Rollen, Kippen oder kurzes Rutschen, höchstens zwei Nachkontakte.
6. Ruhefenster: mindestens `120 ms` ohne Korrektur oder Snap.

### Commit- und Cancel-Policy

1. Vor Release ist die Bewegung abbrechbar und kehrt aus ihrer sichtbaren Pose zur Quelle zurück.
2. Ab Release ist der ballistische Freiflug committed. Er besitzt keine legale beliebige Exit-Bahn und darf weder räumlich retargetet noch abgebrochen werden. Eine gemeinsame Zeitskalierung darf die Zeitbasis verändern, aber niemals nur Bild, Audio oder Haptik einzeln.
3. Nach dem Erstkontakt läuft das Transcript bis zur zertifizierten Ruhe. Ein später nötiger State-Rollback ist eine neue sichtbare Gegenbewegung mit eigener Ursache, kein Rücksprung im bestehenden Transcript.
4. Wird die App während des Freiflugs unsichtbar, setzt die Simulation auf derselben monotonen Zeitbasis fort. Beim Wiedererscheinen wird die kausal gültige Pose oder Ruhelage gezeigt, niemals eine erfundene Zwischenbahn.

### Darstellung

- eigener Bodenschatten aus Höhe, Orientierung und Weltlicht
- sichtbare gerändelte Seitenkante
- Frontlippen-Occlusion aus echter Muldengeometrie
- Bewegungsunschärfe nur bei mehr als `1,5 px` Weg pro Frame, Kontaktframe scharf
- keine Bildschirmerschütterung

### Klang und Haptik

`AVAudioEngine` und Core Haptics erhalten dieselbe vorab geplante Kontaktzeit. Jeder Materialkontakt besitzt einen eigenen Klangfingerabdruck. R1 auf Samt, R1 auf R1, Cent auf Polycarbonat, Cent auf Cent, Karte auf Samt, Karte auf Polycarbonat und Karte auf Holz müssen allein akustisch unterscheidbar sein. Der erste Kontakt trägt Transient, Körperresonanz und einen kleinen Haptikimpuls. Nachkontakte bleiben überwiegend akustisch. Zielwerte auf echtem Gerät: Audio zu Bild `p95 <= 16,7 ms`, Haptik zu Bild `p95 <= 20 ms`.

## Signature-Kartengeben

### Modell

Ein analytischer 2,5D-Kern erzeugt Position, Quaternion, Geschwindigkeit, Wölbung und vier projizierte Kartenecken. `SKWarpGeometryGrid` projiziert Karte und Schatten in dieselbe Tischperspektive. Deck, Hand, Ausspielbereich und Bewertungsfläche sind semantische Polygone, keine Viewport-Prozente.

### Bewegungsfolge

1. Peel in `45-65 ms`: oberste Karte verschiebt sich `1,5-2,5 mm`, die Vorderkante hebt `4-7 mm` ab.
2. Release in `55-80 ms`: kleiner deterministischer Winkelimpuls und `0,8-1,4 mm` Kartenbogen.
3. Glide in `250-340 ms`: Scheitelhöhe `14-28 mm`, Ausrichtung auf die Ziel-Tischebene bereits im Flug.
4. Kantenkontakt und Settle in `95-135 ms`: eine Kante oder zwei Ecken zuerst, dann `2-6 mm` Schlupf und genau eine sichtbare Rückstellung.

### Deal-Rhythmus

Der Deal besitzt einen hörbaren, aber nicht metronomischen Puls aus Anspannung, Beschleunigung und kurzer Erholung. `DealRhythmProfile` bestimmt die gewünschte Startzeit jeder Karte deterministisch aus Runde, Sitz und Sequenz. Das Klangbild muss den Deal auch ohne Blick auf den Bildschirm verständlich machen.

Settle zählt vollständig als Bewegung. Der Start einer Karte `i` erfüllt deshalb zwingend:

`start(i) >= max(rhythmTarget(i), restWindowStart(i - 2))`

Damit kann Karte 3 erst beginnen, wenn Karte 1 ihr Settle beendet und ihr Ruhefenster erreicht hat. Maximal zwei Karten sind dadurch nicht nur nominell, sondern in jedem Frame in Bewegung. Keine drei aufeinanderfolgenden Karten verwenden dieselbe Bahn- oder Kontaktklasse. Die statische Hand übernimmt erst nach zwei pixelidentischen Frames.

## Kartenbewertung als materielles Ritual

- Relevante Karten heben sich `4-6 mm` aus dem bestehenden Fächer.
- Paar, Sequenz und Kunststück bilden jeweils eine eigene physische Leseschiene.
- Die letzte Karte erzeugt einen leichten gemeinsamen Kantenkontakt.
- Erst dieser Kontakt gibt Bewertung und Auszahlung frei.
- Eine verworfene Auswahl kehrt aus der aktuellen sichtbaren Pose zurück. Kein Shake und kein Teleport.

## Der besondere Eindruck

Der Press-Moment ist kein einmaliger Effekt. Er entsteht in einer ungeschnittenen Folge: Karte löst sich sichtbar vom Stapel, richtet sich korrekt auf die reale Tischfläche aus, berührt zuerst mit einer Kante, setzt sich mit kurzem Faserton und passender Haptik, und die nächste Karte übernimmt den Rhythmus ohne Förderbandgefühl. Beim späteren Einsatz fliegt eine schwere Münze mit sichtbarer Kante, ihr Schatten bleibt auf dem Brett, die Muldenlippe verdeckt sie korrekt, und der Kontakt klingt exakt in dem Frame, in dem der Körper aufsetzt.

Diese Kohärenz muss auch beim zwölften Durchlauf tragen. Variation ist deterministisch und materiell, nicht zufällig dekorativ.

## Harte Gates

### Plane Lock

- Homografie-RMS höchstens `1 px`
- maximale Eckabweichung `2 px`
- kein falsches Fach, kein falscher Tischwinkel, kein schwebender Quellstapel

### Contact and Mass

- Schattenprojektionsfehler höchstens `1 px`
- Kontaktschatten-Lücke höchstens `0,75 px`
- Münzpenetration höchstens `0,5` physische Pixel
- kein Energiegewinn über `0,25 %`
- Münzruhe erst unter `1 mm/s` und `0,002 rad/s` für mindestens `120 ms`

### Full Ritual

- ungeschnittenes Austeilen, Spielen, Abbrechen, Bewerten und Auszahlen
- Track A und Track B
- `375x667`, `390x844`, `402x874` und `667x375`
- 60 und 120 Hz, Standard und Reduced Motion
- p99 Framezeit unter `8,33 ms` bei aktivem 120-Hz-Takt
- p99 Framezeit unter `12,50 ms` bei aktivem 80-Hz-Takt
- p99 Framezeit unter `16,67 ms` bei aktivem 60-Hz-Takt
- aktiven Takt aus `CADisplayLink` beziehungsweise den tatsächlichen Frameintervallen messen; Thermik-, Low-Power- und ProMotion-Wechsel werden als eigene Segmente ausgewertet
- kein Teleport, kein Ziel-Snap, kein Förderband, keine exakte Wiederholung innerhalb acht Bewegungen desselben Auswahlbuckets

### Physischer Sync-Beleg

- zweites iPhone im 240-fps-Slo-Mo-Modus, starr montiert und auf Kontaktzone plus Display ausgerichtet
- 96-kHz-Zweikanalaufnahme mit akustischem Signal auf Kanal 1 und Kontaktmikrofon auf Kanal 2
- sicht- und hörbarer Sync-Slate vor jedem Run verbindet Videoframes und Audiowellenform
- mindestens 30 vollständige Kontakte je Gerät, Körper, Materialpaar und Motion-Variante
- keine Ausreißerbereinigung; absolute p95-Werte werden aus der vollständigen Messreihe gebildet

## Kleinster nächster Beweis

1. Eine Karte in Track B: korrekte Tischprojektion, Erstkantenkontakt und Ruhe. Noch kein vollständiger Deal.
2. Eine Cent-Münze in einer echten Track-B-Außenmulde: mindestens neun zertifizierte Transcripts im verwendeten Auswahlbucket und zwölf ungeschnittene Läufe im vollständigen `402x874`-Spielscreen.
3. Bild, Ton und Haptik auf einem echten iPhone mit 240-fps-Messbeleg synchronisieren.
4. Erst nach drei grünen Gates auf vollständigen Deal, Auszahlung und beide Materialwelten erweitern.

Card V4 und Coin V5.1 bleiben Referenzen für gescheiterte Modelle. Sie werden nicht integriert.
