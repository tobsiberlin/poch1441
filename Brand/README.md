# POCH 1441 brand system

## Current direction: Three Acts

`Three Acts` is the active digital and physical production candidate. Three
equal arcs represent the three phases of a Poch round. The ivory inner ring
holds the table together; the small coral diamond is the stake core. The mark
must remain static and must never rotate like a loading indicator.

Source masters:

- `poch-three-acts-balanced-v1.svg` - full-color symbol for digital use
- `poch-three-acts-balanced-mono-v1.svg` - one-color production symbol
- `poch-three-acts-micro-mono-v1.svg` - simplified 8-15 mm engraving master
- `poch-three-acts-wordmark-color-v1.svg` - primary color lockup
- `poch-three-acts-wordmark-mono-v1.svg` - one-color lockup
- `poch-three-acts-app-icon-v1.svg` - square iOS source master

Formal trademark clearance remains a separate product gate. Until that gate is
green, the mark is approved for internal builds and physical prototypes only.

## Rejected direction: Knock Groove O

The closed `Knock Groove O` is not approved for production. Its broad rounded
square counter and upper-right groove collide visually with the existing otelo
wordmark and app-level silhouette. Keep these files only as documented design
history. Do not ship this geometry in the app icon, wordmark, cards or physical
board.

The reusable idea is the small diamond as the stake core. New directions must
derive their silhouette from POCH's board, three phases or physical knock - not
from a notched rounded-square O.

## Manufacturing requirements for the successor

- Use the monochrome SVG masters as the source of truth.
- Minimum physical symbol size: 8 mm.
- At 8-15 mm, use the dedicated `poch-three-acts-micro-mono-v1.svg`. Its three
  arcs and stake core keep every engraved element at least 1.2 mm wide at the
  8 mm minimum.
- At 17 mm and above, the regular geometry may be milled, laser marked,
  embossed, debossed or screen printed without optical effects.
- Do not add bevels, metallic gradients, shields, seals or ornamental rings to
  the core mark. Material belongs to the product surface, not the logo geometry.
- `1441` is a quiet provenance mark. It must never outweigh `POCH`.

## Color system

- Ink blue `#101821` is the primary digital ground.
- Warm ivory `#F4F0E8` carries `POCH` and the primary symbol.
- Muted brass `#C8A35A` is reserved for the provenance `1441`.
- Copper coral `#C96E55` marks the small stake core.
- The production mark must always remain reproducible in one color.

The app icon uses the Three Acts geometry and remains recognizable at 24 px.
iOS applies its own icon mask; the raster master therefore remains square and
unmasked.
