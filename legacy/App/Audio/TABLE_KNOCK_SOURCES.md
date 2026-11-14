# Poch table-knock source

The semantic Poch gesture uses three separately performed knuckle contacts from
`Knock on Wood.wav` by Freesound user `thatkellytrna`. The source is licensed
under CC0 1.0 Universal.

- Source page: https://freesound.org/people/thatkellytrna/sounds/425780/
- Processed preview: `425780_7179420-hq.mp3`
- Preview SHA-256: `407f38d7a7de938935f0b8cd08f187f139158a9151ad50ce9c99055caddfe85d`
- License: https://creativecommons.org/publicdomain/zero/1.0/

`tools/build_table_knock_audio.py` selects three different physical knocks. It
adds a short, low-level modal response for a massive wood table and two minimal
early reflections below -24 dB. It does not pitch-shift a take, synthesize a
casino impact, add a bass drop, or use an algorithmic reverb tail.

The generator rejects output outside its duration, peak, RMS loudness, spectral
centroid, low-frequency body and tail-decay limits. It also rejects insufficient
take-to-take level or spectral variation and pair correlations above 0.68.

Rebuild with:

```sh
python3 tools/build_table_knock_audio.py
```
