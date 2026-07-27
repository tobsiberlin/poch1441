# First-run time-swipe audio sources

The first-run layers are built reproducibly by
`tools/build_first_run_time_swipe_audio.py`. Every audible sample comes from a
pinned CC0 field recording. There are no generated voices, musical loops,
synthetic tonal pings or radio-noise seams.

## Source receipt

| Role | CC0 source | Freesound page | Preview SHA-256 |
|---|---|---|---|
| Historical indoor room | BenDrain, `Ambience_Restaurant_01.wav` | https://freesound.org/people/BenDrain/sounds/488055/ | `3a48c64776f1cf07d70de7f3bf7b8861f7350596ed4e5ddff4db15097b84ee1d` |
| Historical cheer | BeeProductive, `Crowd cheer.wav` | https://freesound.org/people/BeeProductive/sounds/430046/ | `3d7e2d27e0d894a45969f261ae28a2423b5d86312654cc10bbad7d49f1fc2dcc` |
| Present living room | Yuval, `roomtone living room` | https://freesound.org/people/Yuval/sounds/204843/ | `846ace5f1d9decad8d4c85ef39415bf9883e2c9396e215b3a8ef6b80c35fa3fd` |
| Card handling | Kodack, `Riffle Card Shuffle` | https://freesound.org/people/Kodack/sounds/256508/ | `9b019c52519609797a7cbfe0cae79223e91e686a06bfcb726734b6edda1a4726` |
| Ceramic contact | squidge316, `putting down a mug on a table.wav` | https://freesound.org/people/squidge316/sounds/404922/ | `41e1078602f2c38eaa554ddc33f2bf73ce7c826a02158cef19a2a02af823e229` |
| Wood/chip contacts | Yuval, `coin(s) spin drop.wav` | https://freesound.org/people/Yuval/sounds/197214/ | `8b9132dca4668c13a728953e8510435799fcba06d496e4120e6705a006f2c439` |

Each linked Freesound page identifies the recording as Creative Commons 0.
The builder pins the processed preview rather than silently accepting a changed
download. It decodes with macOS `afconvert`, selects fixed crops, filters only
for phone-safe ambience, creates 20-second room loops and places real contact
events at deterministic times.

## Authored contract

- `first-run-origin-room.wav`: warm indoor crowd bed, without an embedded music
  loop. Runtime target is approximately -27 dBFS RMS.
- `first-run-origin-motif.wav`: a dry wood/chip contact at entry, a real group
  cheer after the room has opened, and sparse later physical contacts.
- `first-run-present-room.wav`: quiet closed-window living-room tone. It is a
  place, not a second crowd recording.
- `first-run-present-motif.wav`: real card handling, ceramic cup and chip Foley,
  spaced irregularly so the layer does not become a beat.
- `first-run-time-noise.wav`: a one-second digital-silence placeholder. The
  natural rooms crossfade directly; no stationary hiss or pitched seam is
  permitted. The tiny silent file preserves the existing resource contract
  while the runtime keeps this retired layer at zero gain.

The room loops are 20 seconds long. Details are sparse and non-periodic within
that window. Runtime performs an equal-power finger crossfade while a separate
master envelope fades the complete soundscape in, so immediate swipes remain
acoustically direct.

The interactive mix also uses a restrained stereo axis: the 1441 room sits
moderately left (`-0.28`) and the present room moderately right (`+0.28`).
Table contacts remain closer to the center (`-0.14` / `+0.14`). This makes the
time swipe spatially readable without hard panning or losing essential events
when a device folds the output down to mono.

## Rebuild

```sh
python3 tools/build_first_run_time_swipe_audio.py --output-dir App/Audio
```

The default source cache is `.build/audio-source-cache`. A different cache can
be passed with `--source-cache` for deterministic offline verification.
