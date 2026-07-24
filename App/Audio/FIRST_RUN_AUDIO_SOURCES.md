# First-run time-swipe audio sources

The first-run room layers are derived from two CC0 recordings. The musical
layers and the band-limited `first-run-time-noise.wav` transition layer are
generated deterministically by `tools/build_first_run_time_swipe_audio.py` and
contain no third-party music or samples. The transition layer uses synthetic
noise and a very quiet, continuous tonal texture whose perceived pitch can be
coupled to swipe progress through playback rate. It contains no voices or radio
fragments.

- `Cafe ambiance.ogg`, Marble Toast, 7 July 2024, CC0 1.0:
  https://commons.wikimedia.org/wiki/File:Cafe_ambiance.ogg
- `Laughter(s).ogg`, sagetyrtle, 14 April 2007, CC0 1.0:
  https://commons.wikimedia.org/wiki/File:Laughter(s).ogg

The source recordings are decoded to 44.1 kHz stereo PCM before the build
script runs. Large decoded intermediates are intentionally not stored in the
repository.

The synthetic transition layer can be reproduced without source recordings:

```sh
python3 tools/build_first_run_time_swipe_audio.py \
  --time-noise-only \
  --output-dir App/Audio
```
