# First-run time-swipe audio sources

All five first-run layers are generated deterministically by
`tools/build_first_run_time_swipe_audio.py`. They contain no recordings,
third-party samples, intelligible speech, or music.

- The 1441 room uses non-verbal formant voices, overlapping cheers and laughter,
  a broad crowd bed, and long stereo room reflections.
- The present room uses fewer, closer non-verbal voices, one restrained laugh,
  a warmer room bed, card shuffles, and quiet tableware details.
- The transition uses band-limited synthetic noise and a very quiet, continuous
  tonal texture whose perceived pitch can be coupled to swipe progress through
  playback rate. It contains no voices or radio fragments.

The complete asset set can be reproduced without source recordings:

```sh
python3 tools/build_first_run_time_swipe_audio.py --output-dir App/Audio
```

The transition layer can also be rebuilt alone:

```sh
python3 tools/build_first_run_time_swipe_audio.py \
  --time-noise-only \
  --output-dir App/Audio
```
