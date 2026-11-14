# Card Motion Plane Lock V1 - Lead Gate

## Findings

| Before | After | Why |
| --- | --- | --- |
| V4 used a nearly frontal card rectangle and landed in the wrong small recess. | V1 projects all four card corners through one explicit Track-B homography and rests fully inside the large central compartment. | A card can only feel physical when its plane and semantic target agree with the photographed world. |
| The V4 source stack straddled the snack-box area and read as a floating UI element. | The source stack rests on exposed wood below-right of the box with a sub-pixel contact shadow from the same world-light profile. | A grounded source is part of the causal path; correcting only the destination would preserve the original illusion break. |
| Shadow direction, card edge response and background treatment were separate ad-hoc values. | `WorldLightProfile.trackB` freezes upper-left light direction, background veil, card edge response and airborne/resting shadow behavior for the whole sequence. | An object must not change its light character while moving through one world. |
| Contact was represented by a generic positional settle. | The leading edge reaches the target first while a stored `1.1 mm` card curl discharges once over the settle interval and remains at zero in stable rest. | This gives the stiff card stock one material-specific response without bounce, loop or decorative motion. |
| The earlier evidence cadence was too coarse to expose the short first-edge interval. | The uncut proof is captured at 60 fps from a real monotonic wallclock while the motion kernel advances at a fixed `1/240 s`. | Frame 47 now visibly records `firstEdgeContact`; the proof no longer skips directly from flight to settle. |

## Verdict

### Origin, physicality and cohesion

- **Technical proof: GREEN.** The card plane, correct large-middle target, grounded source deck, separate directed shadow, first-edge contact and stable rest are all present in one uncut `402x874` sequence.
- **Material continuity: GREEN for this proof.** The surface remains `cardBack` for every simulation sample. Stored curl is `1.1 mm` before contact, decreases monotonically exactly once and is `0 mm` throughout stable rest.
- **Light continuity: GREEN for this proof.** World, deck, moving card and shadows reference the unchanged `track-b-lamp-upper-left-v1` profile. The contact-shadow offset is `0.55 px`, within the `0.75 px` gate.
- **Visual product gate: REVIEW REQUIRED.** This is the first complete diagnostic proof and intentionally stops here. The lead must judge the uncut video and tight contact strip before any production port. Diagnostic polygons and labels are proof-only.
- **Integration: BLOCKED.** No App, SpriteKit scene, audio, haptics, deal scheduler or multi-card behavior was changed or approved by this spike.

## Hard-gate evidence

| Gate | Result | Evidence |
| --- | --- | --- |
| Homography RMS `<= 1 px` | `6.36e-14 px` on the four feature-locked Track-B plane corners | `Evidence/manifest.json` |
| Stable-rest corner deviation `<= 2 px` | `0 px` | `Evidence/manifest.json` |
| Correct semantic target | `Track-B large central compartment`; all four target-card corners are inside its polygon | `Tests/PlaneLockTests.swift`, `Evidence/402x874-plane-lock-054.png` |
| No surface teleport | `cardBack` before contact and after rest; all fixed-step samples keep the same surface | `Tests/PlaneLockTests.swift`, `Evidence/manifest.json` |
| First-edge contact | Frame `47` at simulation time about `0.783 s` | `Evidence/402x874-plane-lock-047.png`, `Evidence/tight-first-edge-contact-strip-402x874.png` |
| Stable rest | `28` captured frames after settle | `Evidence/manifest.json` |
| Real timing | `60 fps` capture, `240 Hz` fixed step, `syntheticProgressUsed = false` | `Evidence/wallclock-plane-lock-402x874.mp4`, `Evidence/manifest.json` |

## Verification

- Xcode unit tests: **11 passed, 0 failed**.
- Generic iOS Simulator build: passed without new Swift warnings.
- Evidence export: complete, `82` uncut frames at `402x874` plus H.264 video and tight contact strip.
- `git diff --check -- tasks/reviews/card-motion-plane-lock-v1`: passed.

## Review order

1. `Evidence/wallclock-plane-lock-402x874.mp4`
2. `Evidence/tight-first-edge-contact-strip-402x874.png`
3. `Evidence/402x874-plane-lock-047.png`
4. `Evidence/manifest.json`

No commit or push was created.
