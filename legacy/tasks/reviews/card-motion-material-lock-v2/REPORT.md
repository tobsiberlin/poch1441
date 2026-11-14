# Card Motion Material Lock V2 - Lead Review

## Verdict

**REVIEW REQUIRED - V2 is not product-locked.** The inherited plane lock remains technically intact, but the first uncut 402 x 874 product evidence does not clear the material-readability gate. At phone scale the moving object still reads primarily as a clean black UI rectangle. Cardstock, restrained camping patina, edge thickness and the detached directional shadow are not yet strong enough to sell a physical playing card.

Per the brief, work stopped at this first uncut evidence. No cosmetic follow-up pass, app integration, deal series, audio or haptics was attempted.

## Before / After / Why

| Before | After | Why |
|---|---|---|
| V1 diagnostic plane card | Exact production W2 back geometry with existing W2 patina and public damage variant 0 | Test the real visual language instead of a diagnostic surrogate |
| Small V1 projected card | 54.85 px target short edge in the 402 x 874 evidence | Restore a physically plausible, readable Track-B scale |
| Diagnostic geometry and labels | Product-only evidence without overlays, labels or plane strokes | Judge the card as a player would see it |
| Flat proof surface | Neutral cardstock perimeter plus fixed upper-left material light | Attempt to expose edge thickness and keep light direction stable |
| V1 source point | Grounded source stack on exposed lower-right wood | Preserve a credible origin and prevent teleport-like entry |
| V1 rigid contact | 1.1 mm stored curl released once after first-edge contact | Add one restrained material response without decorative bounce |

## Hard Gates

| Gate | Result | Evidence |
|---|---|---|
| Plane lock unchanged | **PASS** | Homography RMS `6.355e-14 px`; stable-rest corner deviation `0 px` |
| Correct Track-B target | **PASS** | Large central compartment; all target corners remain inside the semantic region |
| Real-time evidence | **PASS** | 60 fps wallclock capture, 240 Hz fixed step, 82 frames; no synthetic progress |
| First-edge contact | **PASS** | First contact frame 47; 28 stable-rest frames |
| One-time tension release | **PASS** | Stored curl `1.1 mm -> 0 mm`, monotonic after first contact |
| Fixed light character | **PASS** | `track-b-lamp-upper-left-v1` stays constant through source, flight and rest |
| No diagnostic graphics | **PASS** | Product evidence contains no labels, vectors, plane outlines or debug chrome |
| Physically plausible phone scale | **PASS** | Target short edge `54.85 px` in a 402 x 874 viewport |
| Material readable at phone scale | **FAIL** | Paper fiber and restrained damage disappear at target size; face reads mostly flat-black |
| Not a black UI rectangle | **FAIL** | Bright perimeter separates silhouette, but the body remains visually too clean and uniformly black |
| Separate directional shadow | **REVIEW** | Shadow is technically separate and follows the upper-left key, but is too weak to establish lift/contact decisively in the product frames |
| Grounded source stack | **PASS / REVIEW** | Source exists on exposed wood and has contact shadow, but its uniform alignment still feels arranged rather than handled |

## Motion Review

- **Origin:** grounded and spatially understandable. The card starts at a visible lower-right stack rather than entering from off-screen.
- **Physicality:** trajectory, plane mapping and contact continuity are credible; the material response is not yet visually legible enough to make the object feel like cardstock.
- **Cohesion:** the fixed upper-left light belongs to the Track-B world, but the card's clean black field and bright outline separate it from the aged tray and table.

## Evidence

- `Evidence/wallclock-material-lock-402x874.mp4` - uncut 60 fps wallclock capture
- `Evidence/uncut-material-lock-sequence-402x874.png` - all 82 frames, uncut
- `Evidence/tight-first-edge-contact-strip-402x874.png` - frames around first contact
- `Evidence/402x874-material-lock-000.png` - grounded source
- `Evidence/402x874-material-lock-024.png` - apex / material read
- `Evidence/402x874-material-lock-047.png` - first-edge contact
- `Evidence/402x874-material-lock-054.png` - stable rest
- `Evidence/manifest.json` - measured capture contract

## Lead Decision Requested

Approve one focused V3 material pass while preserving the V1/V2 homography and timing exactly. The pass should change only the card rendering contract: low-frequency paper tooth that survives 55 px, subtler less-uniform ink coverage, a darker/thinner exposed stock edge, stronger but still fixed directional separation shadow, and slightly imperfect source-stack registration. Do not proceed to a multi-card deal until a single card reads as cardstock in the target frame without enlargement.

