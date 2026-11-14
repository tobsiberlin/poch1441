# Coin Motion Material Lock V3 - GREEN

## Verdict

**GREEN für den isolierten Material-Lock. Keine Produktionsintegration.**

V3 löst den in V2 dokumentierten Materialblocker knapp, aber belastbar. Bei der
realen Projektion von `19.8 px` liest die Münze über die Zeit nicht mehr als
flacher orangefarbener Puck. Dünner Metallrand, wechselnde Glanzlage,
stumpfere Kupferinseln, eigenes Relief und der separate Bodenschatten bleiben
während Orientierung, Kontakt und Auslauf als ein zusammenhängender
Metallkörper erkennbar.

Die Ziffer `1` ist weiterhin kein zuverlässiges Einzelbildsignal. Das ist kein
verdeckter Erfolgskompromiss, sondern die explizite V3-Hypothese: Bei dieser
physischen Größe muss Materialidentität durch zeitlich gekoppelte Kante,
Specular, Normal und Roughness entstehen. Der menschliche Gate-Receipt liegt in
[human-material-verdict.json](Evidence/human-material-verdict.json). Der
technische Receipt bleibt unverändert
`TECHNICAL_GREEN_HUMAN_PENDING`, damit die zeitliche Reihenfolge von technischem
und menschlichem Urteil nachvollziehbar bleibt.

## Geprüfte Evidence

- Der ungeschnittene Clip
  [uncut-material-proof-402x874.mp4](Evidence/uncut-material-proof-402x874.mp4)
  enthält `98` Frames bei `60 fps`, `402 x 874 px`, ohne Audiospur und endet am
  V1-zertifizierten `restCertified`-Punkt bei `1.6125 s`.
- Der frühe Kontaktstreifen
  [orientation-contact-strip-10x-402x874.png](Evidence/orientation-contact-strip-10x-402x874.png)
  zeigt die echte Weltprojektion vor, während und nach dem ersten Kontakt.
- Der unvergrößerte Zielcrop
  [orientation-contact-crop-strip-10x-76.png](Evidence/orientation-contact-crop-strip-10x-76.png)
  prüft genau die Information, die in der produktnahen Abtastung übrig bleibt.
- Eine zusätzliche Lead-Prüfung extrahierte mit AVFoundation `18` gleichmäßig
  verteilte Bilder direkt aus demselben MP4. Sie wurde nur zur zeitlichen
  Sichtprüfung verwendet und veränderte den Evidence-Satz nicht.

SHA-256 der abgenommenen Dateien:

| Datei | SHA-256 |
| --- | --- |
| `orientation-contact-strip-10x-402x874.png` | `4e6292ef7d4bb5c7904b332abb2639e41b2761b1db5fdbdec368edb8aa830397` |
| `orientation-contact-crop-strip-10x-76.png` | `c16886ca615728d8532206f23c8a48e6f115cb9c5049155b6c27f8bd9721cd6f` |
| `technical-receipt.json` | `f3ab172b6e8d527f006ab28cf21dac7e2cf7038529581cc11ee66287321dac79` |
| `uncut-material-proof-402x874.mp4` | `87d7e206901a3ca7dd7fe4c0ba754468201ba118ed7795c96bb06d6b6dc11cb7` |

## Menschliche Sichtprüfung

### Bestanden

- Der Rand bleibt dünn, geschlossen und klar vom dunkleren Kunststoff-Well
  getrennt.
- Glanz und Reliefantwort ändern sich mit der Orientierung, statt als
  bildschirmfeste Textur auf der Münze zu kleben.
- Größere dunkle Kupferinseln bleiben münzlokal stabil und zerfallen beim
  Downsampling nicht zu zufälligem Pixelrauschen.
- Das warme Kupfer bleibt trotz Lampenlicht von Gold, Kunststoff und dem
  braunen Well unterscheidbar.
- Bodenschatten, Kante und Frontlippen-Occlusion ergeben einen glaubwürdigen
  Kontakt ohne sichtbares Schweben oder Durchdringen.
- Im Ruhefenster stoppt nicht nur die Position. Auch die Materialantwort wird
  ruhig und erzeugt keinen dekorativen Rest-Shimmer.

### Bewusste Grenze

- Die eingeprägte `1` ist bei `19.8 px` nicht sicher lesbar und darf weder in
  Tests noch in Statusaussagen als Identitätsbeweis dienen.
- Das Green bestätigt eine alte Kupfermünze im etablierten Track-B-Licht. Es
  bestätigt noch keinen vollständigen Auszahlungseffekt, keine Audio-
  Synchronität, keine Haptik und keine Produktionskorrespondenz.
- Der ungeschnittene Proof wurde vor der menschlichen Abnahme erzeugt, obwohl
  die README ihn erst danach vorsieht. Diese Sequenzabweichung bleibt offen
  dokumentiert. Der Dateibestand allein war deshalb kein Freigabesignal.

## Unveränderte technische Grundlage

V3 bindet die grüne V1-Grundlage weiterhin über die im technischen Receipt
aufgeführten SHA-256-Werte. Der Renderer hält `402 x 874 px`, `19.8 px`
Münzdurchmesser und sechsfaches Supersampling fest
([MaterialTimeRenderer.swift:82](Sources/CoinMaterialTimeGate/MaterialTimeRenderer.swift#L82),
[MaterialTimeRenderer.swift:94](Sources/CoinMaterialTimeGate/MaterialTimeRenderer.swift#L94)).
Die getrennten Materialkanäle und der Weltlichtvertrag werden im Receipt aus
dem Renderer geschrieben
([MaterialTimeRenderer.swift:203](Sources/CoinMaterialTimeGate/MaterialTimeRenderer.swift#L203)).
Der ungeschnittene Clip endet ausschließlich am ersten `restCertified`-Sample
([MaterialTimeRenderer.swift:173](Sources/CoinMaterialTimeGate/MaterialTimeRenderer.swift#L173)).

Es wurden keine App-Dateien, keine V1-Transkripte, kein Solver und keine
Produktionsansicht geändert.

## Zulässiger nächster Schritt

Coin V3 darf als isolierter Materialbaustein erhalten bleiben. Eine Integration
ist erst zulässig, wenn Card Material und Deal Wallclock ebenfalls ihre
menschlichen Produktgates bestehen. Danach muss ein DEBUG-Transcript-Player
den exakt gemeinsamen Kontaktmarker für Bild, Zustand, Audio und Haptik
nachweisen, bevor irgendein produktiver Auszahlungspfad umgestellt wird.
