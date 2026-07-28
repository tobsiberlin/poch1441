# Table Foley Sources

The three card contacts are deterministic crops of three separate, real
card-dealing performances by Freesound user `el_boss`. Each source is licensed
under CC0 1.0 Universal. The build script verifies every downloaded preview
fingerprint before processing; there is no synthesized or pitch-shifted clone.

| Asset | Source | Preview SHA-256 |
| --- | --- | --- |
| `card-deal-01.caf` | [Playing Card Deal Variation 1](https://freesound.org/people/el_boss/sounds/571577/) | `d50fa67b0bdc84e241ceb543ca334e61afe62445ca68552dcaf0f63fa2283f58` |
| `card-deal-02.caf` | [Playing Card Deal Variation 2](https://freesound.org/people/el_boss/sounds/571576/) | `58de0a11f0801215d2c1dab615885f28319114746ade35f21919c86e8fd15b9a` |
| `card-deal-03.caf` | [Playing Card Deal Variation 3](https://freesound.org/people/el_boss/sounds/571575/) | `024eea9ea74466dd14f1110923d0d6b0535d8de269409296a2537a0a7b2f0949` |

License: [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/)

## Authored contact differences

| Asset | Crop | Paper/table band | Peak ceiling | Physical role |
| --- | ---: | ---: | ---: | --- |
| `card-deal-01.caf` | 300 ms | 240-9,800 Hz | 0.56 | light paper flick |
| `card-deal-02.caf` | 360 ms | 135-6,400 Hz | 0.64 | medium card landing |
| `card-deal-03.caf` | 440 ms | 85-4,600 Hz | 0.70 | fuller card/table contact |

Before any CAF is written, the generator rejects a set whose durations are too
similar, RMS dynamics are too flat, zero-crossing tone is too uniform, or any
pair is highly correlated. This preserves organic take-to-take variation while
the runtime chooses among the three real performances deterministically.

Rebuild with:

```sh
python3 tools/build_table_foley_audio.py
```
