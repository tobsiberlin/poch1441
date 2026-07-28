# First-run time-swipe audio sources

`tools/build_first_run_time_swipe_audio.py` builds the six synchronized layers.
The two rooms are deterministic synthesis and therefore contain no recorded
speech, language, wildlife, wind or location ambience. Short physical contacts
come only from the pinned CC0 recordings below.

| Role | CC0 source | Freesound page | Preview SHA-256 |
|---|---|---|---|
| Playing cards | Kodack, `Riffle Card Shuffle` | https://freesound.org/people/Kodack/sounds/256508/ | `9b019c52519609797a7cbfe0cae79223e91e686a06bfcb726734b6edda1a4726` |
| Historical coin | Yuval, `coin(s) spin drop.wav` | https://freesound.org/people/Yuval/sounds/197214/ | `8b9132dca4668c13a728953e8510435799fcba06d496e4120e6705a006f2c439` |
| Modern token | fartheststar, `poker_chips2.wav` - real clay/ceramic poker chips | https://freesound.org/people/fartheststar/sounds/201806/ | `420189948e68b72adf65c2f2096ca04b77e3d86606bfe7a9c776165bc5496ea7` |
| Signature Poch | thatkellytrna, `Knock on Wood.wav` | https://freesound.org/people/thatkellytrna/sounds/425780/ | `407f38d7a7de938935f0b8cd08f187f139158a9151ad50ce9c99055caddfe85d` |

Each Freesound page identifies its recording as CC0 1.0 Universal. The builder
pins every processed preview byte-for-byte before decoding it.

## Match-cut contract

- `first-run-origin-room.wav`: lively, wordless percussive tavern bustle,
  indoor fire and timber body. It contains no continuous voice-like mid band.
- `first-run-present-room.wav`: restrained HVAC and cloth-like indoor air.
  Lounge identity comes from the separate Rhodes/brush motif, not from a
  periodic room tone.
- Both motif files use the exact same 20-second note and contact grid. The
  historical side renders short plucked voices; today renders warm electric
  piano. Cards and the era-correct metal/ceramic contact share timestamps.
- `first-run-signature-contact.wav` is one invariant real knuckle-on-wood layer.
  Runtime moves it from left through center to right instead of crossfading it.
- `first-run-time-noise.wav` is true mono duplicated to stereo. It therefore
  remains centered after fold-down and has no stable pitch or radio sweep.

All layers are 20-second stereo PCM16 loops at 44.1 kHz. Runtime reads their
bytes on a utility executor and only constructs prepared players after the
off-main load completes. Endpoint and seam acceptance is render-tested rather
than inferred from gain constants.

The final physical-iPhone speaker verdict remains a mandatory human gate.

## Rebuild

```sh
python3 tools/build_first_run_time_swipe_audio.py --output-dir App/Audio
```
