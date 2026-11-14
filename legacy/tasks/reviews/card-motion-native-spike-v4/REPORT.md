# Card Motion Native Spike V4 - Review

| Severity | Finding | Evidence | Consequence |
| --- | --- | --- | --- |
| Blocker | The card targets the lower small outer recess although the interface says `Karte auf die Mitte legen`. | `Evidence/realtime-interrupted-play-contact-sheet-402x874.png`, `Evidence/402x874-first-contact-crop-020.png` | The motion does not belong to the depicted game action and cannot be integrated into Track B. |
| Blocker | The card plane stays almost frontal while the table and snack box are strongly foreshortened. The source stack and flights therefore read as pasted-on or hovering elements. | `Evidence/realtime-interrupted-play-contact-sheet-402x874.png`, `Evidence/realtime-8-deal-overlap-sheet-402x874.png` | The card never appears physically embedded in the photographed scene. |
| Blocker | The projected contour shadow is technically present but does not read as a directed ground-contact shadow against the dark Track-B table and recess. | `Evidence/402x874-first-contact-crop-020.png`, `Evidence/first-contact-settle-sheet-402x874.png` | Height and contact remain visually ambiguous; the card appears to float. |
| High | The 86 ms settle changes position and edge pose, but the beat is too weak to read reliably as impact, restitution and rest. | `Evidence/first-contact-settle-sheet-402x874.png` | The contact lacks the weight and tactile clarity required for the game. |
| High | Deal concurrency is capped at two, yet release-angle, yaw, duration and settle variation remain too subtle in the rendered sequence. The flights still form a repeated diagonal rail. | `Evidence/realtime-8-deal-overlap-sheet-402x874.png` | The deal looks procedural and repetitive rather than hand-dealt and physical. |

## Verdict

- Technical verdict: **GREEN**
- Aesthetic verdict: **RED / BLOCKED**
- Integration verdict: **BLOCKED**

The spike proves the requested mechanics at prototype level: real wallclock sampling, same-surface retention through interrupted return, explicit layer order, a four-corner projected-shadow model, an 86 ms contact interval, deterministic seeded variation, distance-based 240-320 ms deal cadence and no more than two simultaneous deal flights. The technical test suite passes 9 of 9 tests.

It does not meet the visual bar. The wrong target recess, missing perspective match, unreadable contact shadow, weak impact beat and visibly uniform deal paths prevent integration. No V4 code or assets should be merged into the game.

## Verification

- Target viewport: `402x874` only, as requested for first review.
- Xcode tests: **9 passed, 0 failed**.
- Evidence recorder: actual controller wallclock; `syntheticProgressUsed = false`.
- Scheduled interruption: progress `0.58`.
- First-contact settle interval: `86 ms`.
- Maximum simultaneous deal flights: `2`.
- Evidence export: complete (`Evidence/export.complete`).

## Scope

V3 remained read-only. No application, status-page, cmux, Git, commit, push or integration changes were made. Work stopped after the first V4 evidence sheet and tight crop; no post-review tuning was performed.
