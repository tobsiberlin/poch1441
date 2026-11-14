# Card Motion Material Lock V3 - Lead Review

## Verdict

**BLOCK - motion contract passes; material contract fails.** The first uncut
402 x 874 product evidence preserves the complete V2 motion contract, improves
the dark exposed edge and makes the directional shadow easier to read. The new
low-frequency stock signal, however, resolves as a row of soft oval patches.
That reads as a designed surface pattern rather than compressed cardstock or
uneven matte ink. The card therefore still separates from the photographed
Track-B world as a digital black rectangle.

Per brief, V3 stopped at the first uncut evidence. No second material iteration,
deal sequence, App integration, audio or haptics was attempted.

## Before / After / Why

| Before | After | Why |
| --- | --- | --- |
| V2 bright ivory-gray perimeter | 1.05% dark warm-gray exposed stock edge | Removes the white UI-outline reading and keeps only a thin physical edge |
| V2 nearly uniform ink-black field | Broad deterministic stock-tooth and matte-coverage layers | Attempts to retain a material signal after projection to a 54.85 px short edge |
| V2 subtle public damage overlay | Same W2 damage, slightly integrated into the matte print response | Keeps the W2 identity and restrained camping history without redesigning the back |
| V2 technically separate but weak shadow | Same frozen shadow quad plus a tighter umbra on that quad | Makes airborne lift and first contact legible without changing light direction or trajectory |
| V2 mechanically aligned source stack | Two frozen source cards offset by 0.8-1.9 px | Removes perfect UI registration while preserving the same source position |
| V2 unrecorded motion-source relationship | SHA-256 locks for model, controller and W2 material contract | Proves geometry, homography, timing, target, WorldLight and 1.1 mm response stayed byte-identical |

## Hard Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| V2 motion model byte-identical | **PASS** | `57898a7157ca5e8c987021f4b412ca20d6daa402d84be066d732ffc07b59c32e` |
| V2 controller byte-identical | **PASS** | `018504e26ab18f5605be1221d6d1022fcaf348ad943fa5d66c7ce7dbf9f075c6` |
| Production W2 contract byte-identical | **PASS** | `8d44945cd1b304442f331cd328bc34d94cf3ae5d907a457c8148e9e628a83573` |
| Plane lock unchanged | **PASS** | Homography RMS `6.355e-14 px`; stable-rest deviation `0 px` |
| Real-time evidence | **PASS** | 60 fps wallclock capture, 240 Hz fixed step, 82 frames; no synthetic progress |
| First-edge contact and 1.1 mm response | **PASS** | Contact frame 47; 28 rest frames; curl remains the frozen one-time `1.1 mm -> 0 mm` |
| WorldLight unchanged | **PASS** | Frozen `track-b-lamp-upper-left-v1` profile and direction |
| W2 recognizability | **PASS** | Original lozenge, palette, monograms and deterministic W2 patina remain intact |
| Thin dark physical edge | **PASS** | Bright V2 outline is gone; silhouette remains readable without an ivory halo |
| Separate directional shadow | **PASS** | Lift shadow and contact umbra are visibly separated and keep the frozen upper-left key direction |
| Imperfect source registration | **PASS** | 0.8-1.9 px offsets break exact stacking without changing source geometry |
| No diagnostic chrome | **PASS** | Product frames contain no debug labels, plane lines or diagnostic overlays |
| Stock tooth survives 54.85 px | **FAIL** | Signal survives, but as discrete soft ovals rather than fibrous cardstock |
| Uneven matte ink looks physical | **FAIL** | Coverage variation is too regular and graphic; it reads designed rather than accumulated |
| Not a black UI rectangle | **FAIL** | Darker edge helps, but the face still reads as a digital black panel against the aged world |

## Motion Review

- **Origin:** improved. The 1-2 px registration variation makes the lower-right
  source stack less mechanically perfect while keeping a clear spatial source.
- **Physicality:** trajectory, scale, projection, shadow direction and first-edge
  contact remain credible. The surface itself breaks the illusion because its
  texture language is graphic rather than fibrous.
- **Cohesion:** the dark edge and stronger umbra better inherit the table light;
  the oval tooth pattern does not belong to the tray, wood or worn playing-card
  references.

## Evidence

- `Evidence/wallclock-material-lock-v3-402x874.mp4` - first uncut 60 fps capture
- `Evidence/uncut-material-lock-v3-sequence-402x874.png` - all 82 frames
- `Evidence/tight-first-edge-contact-v3-strip-402x874.png` - contact strip
- `Evidence/402x874-material-lock-v3-000.png` - registered source stack
- `Evidence/402x874-material-lock-v3-024.png` - apex and shadow separation
- `Evidence/402x874-material-lock-v3-047.png` - first-edge contact
- `Evidence/402x874-material-lock-v3-054.png` - stable rest
- `Evidence/manifest.json` - measurements and frozen-source hashes

## Lead Decision Requested

Do not integrate V3. If another isolated material pass is approved, retain the
dark edge and shadow transfer but replace the ellipse-based tooth completely.
Use an irregular directional fiber field plus sparse edge-compression and
low-amplitude print dropout, and validate the raster itself at exactly 54.85 px
before running another flight. The next pass should fail fast on a static
source/rest pair before spending a full uncut capture.

## Explicit Decision

**Block.** Plane lock, timing and contact are approved. Material is not.

