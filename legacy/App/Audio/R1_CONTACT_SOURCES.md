# R1 ceramic contact sources

All nine R1 contacts are edited from the CC0 `Poker Chips` pack by Freesound
user `fartheststar`. The pack description explicitly identifies the recorded
objects as real clay/ceramic poker chips rather than plastic chips or coins.

Source pages:

- `poker_chips1.wav`: https://freesound.org/people/fartheststar/sounds/201807/
- `poker_chips2.wav`: https://freesound.org/people/fartheststar/sounds/201806/
- `poker_chips3.wav`: https://freesound.org/people/fartheststar/sounds/201805/
- `poker_chips4.wav`: https://freesound.org/people/fartheststar/sounds/201804/
- `poker_chips5.wav`: https://freesound.org/people/fartheststar/sounds/201809/
- `poker_chips6.wav`: https://freesound.org/people/fartheststar/sounds/201808/

License: CC0 1.0 Universal.

`tools/build_r1_contact_audio.py` pins all six HQ previews, trims real attacks,
applies only phone-safe band limiting and mild saturation, and generates three
mono variants for outer well, center well and player stack. It adds no pitch
shift, synthesized body, casino sweetener or metal coin recording.

Runtime uses one `R1ContactAudio` voice-pool pipeline for every R1 surface and
for Phase-2 bet/payout contacts. Event identity prevents duplicates; distinct
accepted contacts are never dropped by a wall-clock throttle.

The generated receipt remains at
`tasks/reviews/r1-contact-audio-v2/Evidence/audio-fingerprint-receipt.json`.
Its technical verdict must be green. The physical-iPhone speaker verdict stays
pending until the new ceramic Foley passes a human TestFlight listening gate.

## Rebuild

```sh
python3 tools/build_r1_contact_audio.py
```
