# First-run time-swipe audio sources

The first-run room layers are derived from two CC0 recordings. The musical
layers are generated deterministically by
`tools/build_first_run_time_swipe_audio.py` and contain no third-party music.

- `Cafe ambiance.ogg`, Marble Toast, 7 July 2024, CC0 1.0:
  https://commons.wikimedia.org/wiki/File:Cafe_ambiance.ogg
- `Laughter(s).ogg`, sagetyrtle, 14 April 2007, CC0 1.0:
  https://commons.wikimedia.org/wiki/File:Laughter(s).ogg

The source recordings are decoded to 44.1 kHz stereo PCM before the build
script runs. Large decoded intermediates are intentionally not stored in the
repository.
