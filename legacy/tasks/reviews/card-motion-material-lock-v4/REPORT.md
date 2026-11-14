# Card Motion Material Lock V4 - RED

## Verdict

**STATIC MATERIAL HYPOTHESIS PASS. HUMAN EVIDENCE GATE RED. PRODUCTION
INTEGRATION BLOCKED.** V4 removes the visually red V3 oval/polka layer completely.
At the real 402 x 874 viewport and 54.85065 px target-card short edge, the new
signal resolves as irregular directional fibres, sparse bent print dropout and
a compressed perimeter rather than repeated spots. Geometry, timing, contact,
motion, source registration, shadow transfer and the W2 graphic contract did
not change.

The upright static source/rest pair narrowly approves the isolated one-card
material hypothesis. The required wallclock MP4 is vertically mirrored in
QuickTime although the pre-encode strips are upright, so the complete material
lock remains red and may not be ported into `App/**`. No product integration,
multi-card deal, audio, haptics or production performance gate was attempted.

## Material-only hypothesis

At phone scale, matte printed stock should read through directional continuity
and edge behavior, not large local patches. Replacing V3's blurred ovals with
an irregular fibre field, sparse non-repeating print dropout and narrow edge
compression should retain a physical stock signal without a designed pattern.

The hypothesis passes the static source/rest gate. The uncut motion gate does
not pass because its encoded playback orientation is wrong.

## Before / After / Why

| Before | After | Why |
| --- | --- | --- |
| V3's 18 blurred light/dark ellipses formed visible rows of soft oval patches | No ellipse or radial-spot primitive remains; 23 irregular fibres and 10 bent dropout paths carry the surface variation | Directional discontinuities read as print/stock behavior instead of a designed polka texture |
| V3 broad local coverage changes competed with the W2 lozenge | One low-amplitude diagonal ink drift stays beneath the W2 graphic | Material variation remains legible without becoming a second graphic layer |
| V3 material change had no static fail-fast gate | Exact 402 x 874 source/rest frames and card crops are exported before the flight | A bad raster can be rejected before spending a full wallclock capture |
| V3 only locked the V2 model, controller and W2 contract | V1, V2 and V3 model/controller/stage sources are hash-bound; V4 Model, Controller, Stage and W2 contract are byte-identical to V3 | The review can attribute every visible difference to `ProductW2CardSurface.swift` |

## Hard gates

| Gate | Result | Evidence |
| --- | --- | --- |
| V1 geometry/timing/contact/motion hash lock | **PASS** | Model `1b4afc9f...`, controller `018504e2...`, stage `c8b44118...` |
| V2 geometry/timing/contact/motion hash lock | **PASS** | Model `57898a71...`, controller `018504e2...`, stage `5e91af4a...` |
| V3 geometry/timing/contact/motion hash lock | **PASS** | Model `57898a71...`, controller `018504e2...`, stage `d6885cd3...` |
| V4 frozen runtime sources byte-identical to V3 | **PASS** | `cmp` passes for Model, Controller, Stage and W2 contract |
| Production W2 contract unchanged | **PASS** | `8d44945cd1b304442f331cd328bc34d94cf3ae5d907a457c8148e9e628a83573` |
| V3 oval/polka layer absent | **PASS** | No `ellipseIn:`, old tooth identifier or radial spot gradient in the V4 surface source |
| Static real-scale material gate | **PASS** | Two exact 402 x 874 frames; target short edge `54.85065110795071 px`; `motionAdvanced = false` |
| Irregular stock signal survives projection | **PASS, narrowly** | Fibres and edge compression remain visible at native scale without resolving into dots or rows |
| Uneven matte ink looks physical | **PASS, narrowly** | Variation reads as subdued press drift and abrasion; the enlarged crop overstates it, so the native 402 x 874 pair is authoritative |
| Not a black UI rectangle | **PASS, narrowly** | Warm exposed edge, non-uniform ink, damage and stable world shadow give the dark W2 field a material boundary; its intentionally near-black identity remains high contrast |
| Plane lock unchanged | **PASS** | Homography RMS `6.355e-14 px`; stable-rest deviation `0 px` |
| Real-time evidence | **PASS** | 82 frames, 60 fps capture, 240 Hz fixed step, monotonic wallclock/fixed-step/simulation records, no synthetic progress |
| Encoded video orientation | **RED** | QuickTime displays the MP4 vertically mirrored while the pre-encode frame strips are upright |
| First-edge contact and response | **PASS** | Contact frame `47`; 28 stable-rest frames; frozen one-time `1.1 mm -> 0 mm` curl |
| No diagnostic chrome | **PASS** | Manifest is false; frozen V3 Stage contains no diagnostic overlay |
| Product integration | **PENDING/BLOCKED** | Out of scope; no `App/**` file changed |

## Visual judgment

- **Origin:** unchanged and credible. The V3 source registration and grounded
  shadow remain byte-identical.
- **Physicality:** improved. The card no longer advertises a repeated surface
  pattern. Fine directional interruptions and the compressed edge read as
  printing/card wear at the actual target scale. The result is intentionally
  restrained and only narrowly clears the material gate.
- **Cohesion:** improved. The warm edge and low-amplitude surface response sit
  closer to the photographed wood and worn tray without recoloring the W2
  identity. The inherited damage remains more visible after removing the oval
  veil, but does not form a new repeating pattern.
- **Motion:** no new material-motion judgment can be approved from the encoded
  video. The complete V3 Stage, Model and Controller are byte-identical and the
  upright pre-encode strip shows no obvious material pop, but QuickTime displays
  the mandatory MP4 vertically mirrored.

## Verification

- Xcode iOS Simulator test run: **16 passed, 0 failed, 0 skipped** on iPhone 17
  Pro, iOS 26.2. One build was used for both evidence stages.
- Static fail-fast export: complete at exact 402 x 874.
- Full wallclock export: complete, 82 frames; manifest hard gates and monotonic
  wallclock/fixed-step/simulation checks pass.
- Whitespace/diff hygiene check across all V4 text sources: passed.
- Evidence SHA-256 values are recorded in `Evidence/SHA256SUMS` and verify with
  `shasum -a 256 -c Evidence/SHA256SUMS` from the V4 root.
- Independent `ffprobe` inspection was unavailable because the local binary is
  broken against a missing `libx265.215.dylib`. A freshly compiled native
  AVFoundation inspector independently confirms one silent 402 x 874 video
  track, 82 frames, 60 fps and 1.3667 s duration. QuickTime visual inspection
  independently rejects its vertical mirroring.

The binding human verdict is recorded in
`Evidence/human-material-verdict.json`.

## Evidence review order

1. `Evidence/Static/static-source-rest-pair-v4-402x874.png`
2. `Evidence/Static/static-material-crops-v4.png` - enlarged, not authoritative
   for signal strength
3. `Evidence/wallclock-material-lock-v4-402x874.mp4`
4. `Evidence/tight-first-edge-contact-v4-strip-402x874.png`
5. `Evidence/uncut-material-lock-v4-sequence-402x874.png`
6. `Evidence/manifest.json`
7. `Evidence/SHA256SUMS`

## Scope

All changes are under `tasks/reviews/card-motion-material-lock-v4/**`. No older
review subtree or `App/**` file was modified. No commit or push was created.
