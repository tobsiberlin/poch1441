#!/usr/bin/env python3
"""Replicate-Sichtung fuer physische Poch-1441-Spielfelder.

Die generierten Bilder sind Material-/Form-Referenzen. Regeltexte und Labels
werden in HTML/CSS gesetzt, weil Bildmodelle bei Zahlen/Buchstaben unzuverlaessig
sind. Regelgeometrie bleibt strikt: 8 Aussenmulden + Mitte.
"""
import base64
import json
import os
import sys
import time
from pathlib import Path

import replicate
import requests
from PIL import Image, ImageDraw, ImageFont

ROOT = Path("/Users/tobsi/poch1441")
RAW = ROOT / "Assets_Raw" / "physical-board" / "replicate"
ART = ROOT / "artifacts" / "physical-board"
HTML = ROOT / "artifacts" / "physical-board-sichtung.html"
TEMP_HTML = Path("/Users/tobsi/Library/Mobile Documents/com~apple~CloudDocs/TEMP/physical-board-sichtung.html")
LOG = RAW / "log.json"

RAW.mkdir(parents=True, exist_ok=True)
ART.mkdir(parents=True, exist_ok=True)

KEY_FILE = Path("~/.config/replicate.key").expanduser()
if KEY_FILE.exists():
    os.environ["REPLICATE_API_TOKEN"] = KEY_FILE.read_text().strip()

MODEL = "black-forest-labs/flux-1.1-pro"
DATE = "2026-07-09"

RULES = (
    "strictly a Poch game board with exactly eight outer recessed basins and one larger central pot, "
    "the eight outer basins correspond to ace, king, queen, jack, ten, mariage, sequence, poch, "
    "the one central pot is a real concave bowl for the center treasury, "
    "no extra pockets, no roulette layout, no casino wheel, no invented bonus fields, "
    "the board is for chips and playing cards, functional physical tabletop object"
)

NEGATIVE = (
    "no readable text, no letters, no numbers, no logos, no watermark, "
    "no roulette, no casino, no poker table felt, no slot machine, no neon, no LED glow, "
    "no sci-fi holograms, no glossy plastic, no cheap toy, no red plastic cups, "
    "no extra basins, no flat center disk, no raised center button, no medallion center, "
    "no 7 8 9 labels, no misaligned pockets"
)

BASE = (
    "ultra premium product design render, top-down three-quarter view, modern physical Poch 1441 board, "
    "large circular disc, substantial thickness, flat-bottom recessed wells for coin stacks, "
    "matte graphite black surface, machined bevels, brushed brass micro inlays, muted mineral color rims, "
    "soft cinematic studio lighting, realistic contact shadows, luxurious tactile board game object, "
    "Apple Watch Ultra material restraint meets heirloom tabletop craft"
)

GLASS_BASE = (
    "premium mobile game board concept, neomorphism and sci-fi glassmorphism, top-down three-quarter view, "
    "translucent smoky graphite glass disc, frosted glass layers, soft inner shadows, heavy metallic bevels, "
    "clear tactile depth, luxury industrial interface object, elegant and sophisticated, "
    "not a flat UI mockup, not a casino wheel"
)

CRAFT_BASE = (
    "premium physical Poch 1441 game board concept, warm handcrafted material language, top-down three-quarter view, "
    "solid walnut wood or dark warm wood body, matte hand-finished surface, satin brass inlay rings, "
    "colored matte enamel or ceramic basin interiors using muted jewel pigment tones, "
    "bone or ivory-like small markers, heirloom tabletop craft meets clean modern mobile game UI, "
    "low-reflection matte render, soft natural studio lighting, not glossy product photography"
)

CENTER_BOWL = (
    "the center must be a large deep concave central bowl, visibly lower than the board surface, "
    "flat dark bottom, thick machined brass or graphite rim, inner wall shadow, able to hold a tall stack of chips, "
    "not a flat disk, not a button, not an emblem"
)

STRICT_CENTER_BOWL = (
    "STRICT: the center is an empty deep physical cup-shaped bowl, like a real tabletop game pot, "
    "black shadow inside, visible vertical inner wall, flat bottom lower than the board surface, "
    "wide raised rim, coins could be placed inside; it is not glass lens, not a dial, not a button, not a medallion"
)

CARD_HINTS = (
    "subtle embedded ivory playing-card hint plaques on the board surface near the inner circle, "
    "one small plaque or glyph group per outer basin like a historical Poch board reference, "
    "abstract French card suit/rank hints only, secondary and understated, not readable text"
)

TOKEN_ASSET = (
    "premium mobile game asset sheet of luxury game tokens and coins, top-down view, centered layout, "
    "heavy solid polished copper, bronze and rose gold coins, deep tactile geometric ridges on the edges, "
    "hyper-realistic metallic reflections, sharp glossy highlights, intense 3D volumetric depth, "
    "some isolated flat coins, small neat stacks of 3 and 5 coins, realistic soft ambient occlusion shadows, "
    "solid dark graphite background, photorealistic studio lighting"
)

TOKEN_IN_POT_RULE = (
    "tokens follow PM68 reference: heavy glass-and-metal chips arranged naturally as overlapping small stacks inside the bowls, "
    "not flat dots, not yellow UI circles, with hard contact ambient occlusion plus soft height shadow and subtle glass refraction"
)

JOBS = [
    {
        "id": "PM51",
        "name": "Future Heritage A",
        "seed": 144151,
        "prompt": (
            f"{BASE}, {RULES}, dark graphite mineral composite disc, warm brass center rim, "
            "eight deep black wells with subtly different muted mineral rims, central pot larger and deeper, "
            "a few heavy brass chips in several wells and center, player hand cards barely visible at bottom edge, "
            "premium but not flashy, material over glow, {NEGATIVE}"
        ),
    },
    {
        "id": "PM52",
        "name": "Stone Edition A",
        "seed": 144152,
        "prompt": (
            f"{BASE}, {RULES}, matte black slate stone texture, satin brass rings around each basin, "
            "deeper physical pot wells with flat floors, chips lying naturally inside the wells, "
            "very clear 8 plus 1 geometry, quiet circular craft object, cards cropped at the lower edge, "
            "museum-grade board game photography, {NEGATIVE}"
        ),
    },
    {
        "id": "PM53",
        "name": "Graphite Collector",
        "seed": 144153,
        "prompt": (
            f"{BASE}, {RULES}, black anodized aluminum and ceramic, slightly elliptical perspective, "
            "wide calm surface, larger central treasury pot, understated radial brass tick marks between wells, "
            "muted emerald, amethyst, rose and gold mineral bezels around recessed wells, "
            "real manufacturable CNC object, {NEGATIVE}"
        ),
    },
    {
        "id": "PM54",
        "name": "Deep Pot Prototype",
        "seed": 144154,
        "prompt": (
            f"{BASE}, {RULES}, most functional version, larger outer basins for stacks of small coins, "
            "flat well bottoms, steep rounded side walls, thick outer rim, matte graphite body, "
            "brass and platinum micro bevels only where light catches, no ornamental center emblem, "
            "perfect for explaining the rules at first glance, {NEGATIVE}"
        ),
    },
    {
        "id": "PM55",
        "name": "Warm Mineral Board",
        "seed": 144155,
        "prompt": (
            f"{BASE}, {RULES}, slightly warmer dark mineral composite, brown-black ceramic, aged satin brass, "
            "subtle heritage feel without visible wood grain, precise modern basins, center pot with coin stack, "
            "balanced between historic craft and modern luxury technology, {NEGATIVE}"
        ),
    },
    {
        "id": "PM56",
        "name": "Tournament Table Object",
        "seed": 144156,
        "prompt": (
            f"{BASE}, {RULES}, dramatic app-key-art composition, board fills most of frame, "
            "bottom edge shows large premium French playing cards partially cropped, "
            "chips in pots are readable and physical, strong but soft shadows, no UI screen, no text, "
            "could be photographed as a real collector edition object, {NEGATIVE}"
        ),
    },
    {
        "id": "PM57",
        "name": "PM1 Heritage Pot Board",
        "seed": 144157,
        "prompt": (
            f"{BASE}, {RULES}, {CENTER_BOWL}, {CARD_HINTS}, stay close to PM1 aesthetics, "
            "dark satin graphite and black ceramic body, elegant warm brass micro dots aligned exactly one before each outer basin, "
            "eight black flat-bottom outer bowls with subtle colored mineral rims, physical board that could really be manufactured, "
            "small brass chip stacks in only a few bowls, premium product render, material over glow, {NEGATIVE}"
        ),
    },
    {
        "id": "PM58",
        "name": "Future Heritage With Cards",
        "seed": 144158,
        "prompt": (
            f"{BASE}, {RULES}, {CENTER_BOWL}, {CARD_HINTS}, future heritage version, "
            "matte graphite slab with satin brass center bowl rim, eight evenly spaced deep coin bowls, "
            "tiny flush inlaid card plaques around the center showing faint suit silhouettes, "
            "muted gold emerald amethyst rose and petrol mineral rims, restrained and expensive, no glowing UI, {NEGATIVE}"
        ),
    },
    {
        "id": "PM59",
        "name": "Stone Rule Board",
        "seed": 144159,
        "prompt": (
            f"{BASE}, {RULES}, {CENTER_BOWL}, {CARD_HINTS}, black slate and machined brass collector board, "
            "outer basins are larger and deeper for real coin stacks, central bowl is clearly the largest treasury pot, "
            "card-hint plaques are engraved ivory inserts arranged radially between center and basins, "
            "historical Poch board logic translated into modern premium industrial design, {NEGATIVE}"
        ),
    },
    {
        "id": "PM60",
        "name": "Readable Gameplay Board",
        "seed": 144160,
        "prompt": (
            f"{BASE}, {RULES}, {CENTER_BOWL}, {CARD_HINTS}, app gameplay composition, "
            "top-down view optimized for mobile readability, the nine required basins are unmistakable, "
            "each outer basin has a subtle colored rim and a nearby small card-hint insert, "
            "large empty center bowl ready for chips, bottom edge includes a premium hand of French playing cards, "
            "clear hierarchy, calm dark PM1 material language, {NEGATIVE}"
        ),
    },
    {
        "id": "PM61",
        "name": "Glass Neo Board A",
        "seed": 144161,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {CENTER_BOWL}, {CARD_HINTS}, "
            "eight large frosted circular glass basins with dark concave bottoms, one larger central glass treasury bowl, "
            "subtle cyan refraction on edges, muted brass alignment dots, exact 8 plus 1 geometry, "
            "heavy copper coin stacks resting inside several wells, premium but calm, {NEGATIVE}"
        ),
    },
    {
        "id": "PM62",
        "name": "Glass Neo Board B",
        "seed": 144162,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {CENTER_BOWL}, {CARD_HINTS}, "
            "thicker translucent dark glass board with brushed titanium and rose-gold rims, "
            "outer basins look like deep glass cups embedded into the surface, central bowl is unmistakably concave, "
            "small ivory card-hint plaques inside the inner ring, copper chips casting realistic shadows through glass, {NEGATIVE}"
        ),
    },
    {
        "id": "PM63",
        "name": "Neomorphic Frosted Pots",
        "seed": 144163,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {CENTER_BOWL}, {CARD_HINTS}, "
            "soft neomorphic raised wells and sunken bowls, smoky transparent graphite material, "
            "very soft inner shadows, minimal cyan and amethyst edge reflections, no neon emission, "
            "the board clearly explains Poch with eight outer pots and one center pot, {NEGATIVE}"
        ),
    },
    {
        "id": "PM64",
        "name": "Glass Instrument",
        "seed": 144164,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {CENTER_BOWL}, {CARD_HINTS}, "
            "precision instrument look, transparent layered dial only as material, not roulette, "
            "eight physical coin bowls made of dark glass and satin metal, large center treasury bowl with brass rim, "
            "tiny rank and suit hint plaques around the center, muted mineral color coding, {NEGATIVE}"
        ),
    },
    {
        "id": "PM65",
        "name": "Crystal Treasury Board",
        "seed": 144165,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {CENTER_BOWL}, {CARD_HINTS}, "
            "deep black crystal ceramic hybrid, glass wells with matte graphite bottoms, "
            "center bowl contains a short stack of rose-gold coins, each outer basin has a thick translucent glass lip, "
            "mobile game key art composition with cards cropped at bottom edge, {NEGATIVE}"
        ),
    },
    {
        "id": "PM66",
        "name": "Readable Glass Table",
        "seed": 144166,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {CENTER_BOWL}, {CARD_HINTS}, "
            "high readability gameplay board, larger basins, strong concave shadows, "
            "subtle glass plaques for card combinations, gold emerald amethyst rose and petrol rim accents, "
            "cards and coin stacks arranged like a premium mobile game screen, no clutter, {NEGATIVE}"
        ),
    },
    {
        "id": "PM67",
        "name": "Glass Tokens Sheet A",
        "seed": 144167,
        "prompt": (
            f"{TOKEN_ASSET}, luxury industrial game token aesthetic, cutout-ready asset sheet, "
            "no board, no readable text, no logos, no symbols, no plastic, no cartoon, no blurry details"
        ),
    },
    {
        "id": "PM68",
        "name": "Glass Tokens In Pot",
        "seed": 144168,
        "prompt": (
            "close-up UI asset of neat stacks of heavy metallic betting chips in a translucent dark glass circular Poch pot, "
            "top-down view, centered, premium brushed bronze and copper chips with deep 3D relief pattern, "
            "incredible physical thickness and heavy volumetric shading, sharp ambient occlusion directly under each chip, "
            "soft dynamic drop shadow through smoky glass, subtle cyan ambient edge reflection only, "
            "solid dark graphite background, no flat design, no plastic, no text, no logo, no blurry details"
        ),
    },
    {
        "id": "PM69",
        "name": "Glass Tokens Sheet B",
        "seed": 144169,
        "prompt": (
            f"{TOKEN_ASSET}, include bronze, rose-gold, graphite-black and pale platinum tokens, "
            "asset sheet arranged with generous spacing for cropping, top-down orthographic product render, "
            "deep shadows, polished metal edges, no readable text, no logos, no plastic, no cartoon"
        ),
    },
    {
        "id": "PM70",
        "name": "Neomorphic Rule Board",
        "seed": 144170,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {CENTER_BOWL}, {CARD_HINTS}, "
            "the most rule-explanatory version: eight outer glass bowls, one central bowl, "
            "near each outer bowl a small recessed card plaque hints the correct Poch combination, "
            "large heavy copper coins in several bowls, very calm premium dark interface, {NEGATIVE}"
        ),
    },
    {
        "id": "PM71",
        "name": "Glass Bowl Strict A",
        "seed": 144171,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {CARD_HINTS}, "
            "dark graphite background, eight outer translucent glass coin bowls, all concave and empty enough for chips, "
            "small muted brass chips in only two bowls, subtle cyan edge reflection, no blue board fill, "
            "premium app game object with clear physical basins, {NEGATIVE}, no lens, no central orb, no flat center"
        ),
    },
    {
        "id": "PM72",
        "name": "Neo Rule Table A",
        "seed": 144172,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {CARD_HINTS}, "
            "frosted smoked glass on matte black graphite, thick rose-gold rims, eight large symmetrical outer bowls, "
            "small ivory card-hint tiles printed into the graphite ring between center bowl and outer bowls, "
            "mobile readability, manufacturable luxury board, {NEGATIVE}, no central glass button, no dial"
        ),
    },
    {
        "id": "PM73",
        "name": "Dark Glass PM1 Hybrid",
        "seed": 144173,
        "prompt": (
            f"{BASE}, {GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {CARD_HINTS}, "
            "closer to PM1 graphite aesthetic, only the basin lips are smoky translucent glass, "
            "dark satin graphite surface with brass micro dots aligned before each bowl, "
            "all nine required bowls are true concave wells, understated color coding, {NEGATIVE}, no dial, no lens"
        ),
    },
    {
        "id": "PM74",
        "name": "Glass Poch Reference",
        "seed": 144174,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {CARD_HINTS}, "
            "inspired by a traditional Poch board layout but modernized, card combination hints are small embedded card illustrations around the center, "
            "the center is a real empty treasury bowl, outer bowls hold coins, thick black glass and brushed bronze, "
            "top-down three-quarter product photo, {NEGATIVE}, no readable card text, no flat central plaque"
        ),
    },
    {
        "id": "PM75",
        "name": "Neomorphic Cyan Restraint",
        "seed": 144175,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {CARD_HINTS}, "
            "very dark smoked glass with soft neomorphic highlights, restrained cyan refraction only on glass edges, "
            "eight outer bowls plus central bowl are separated by enough material, no clutter, heavy copper chip stacks, "
            "award-winning mobile game board art, {NEGATIVE}, no neon glow, no central lens"
        ),
    },
    {
        "id": "PM76",
        "name": "Premium Transparent Pots",
        "seed": 144176,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {CARD_HINTS}, "
            "transparent smoky glass pots set into matte graphite, each pot casts refracted shadows, "
            "large center cup is deep and dark, outer pots are shallow but usable, tiny card plaques are flush and secondary, "
            "show realistic coin physics and shadows, {NEGATIVE}, no roulette, no dial, no lens"
        ),
    },
    {
        "id": "PM77",
        "name": "Dark UI Board Study",
        "seed": 144177,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {CARD_HINTS}, "
            "closer to the shown UI reference but more premium and less generic, "
            "soft glassmorphic circles, dark blue graphite background, copper coin stacks, readable hierarchy, "
            "exactly eight outer coin wells and one center bowl, {NEGATIVE}, no invented fields, no extra pockets"
        ),
    },
    {
        "id": "PM78",
        "name": "Token Physics Board",
        "seed": 144178,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {CARD_HINTS}, "
            "focus on chips lying naturally in real concave bowls, heavy polished copper and rose-gold tokens, "
            "two-part shadows: hard ambient occlusion contact shadow plus soft height shadow, "
            "glass refraction subtly darkens the surface under tokens, exact 8 plus 1 Poch board, {NEGATIVE}, no lens"
        ),
    },
    {
        "id": "PM79",
        "name": "Walnut Enamel A",
        "seed": 144179,
        "prompt": (
            f"{CRAFT_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {CARD_HINTS}, "
            "dark walnut circular body, eight clearly defined outer basins plus one larger center bowl, "
            "each basin has a matte colored ceramic enamel interior and a thin satin brass inlay ring, "
            "ivory bone markers near each basin for future UI labels, no chrome, no glass, no glow, "
            "functional readable slot layout, enough calm surface for SwiftUI labels, {NEGATIVE}"
        ),
    },
    {
        "id": "PM80",
        "name": "Nussbaum Filz A",
        "seed": 144180,
        "prompt": (
            f"{CRAFT_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {CARD_HINTS}, "
            "warm walnut board with matte felt-lined basins, muted jewel-tone felt inserts, "
            "brass rims around each pot, central pot deep and empty with dark felt bottom, "
            "small ivory card-category plaques subtly embedded around the center ring, "
            "very low specular reflection, handmade luxury board, {NEGATIVE}"
        ),
    },
    {
        "id": "PM81",
        "name": "Ceramic Craft Board",
        "seed": 144181,
        "prompt": (
            f"{CRAFT_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {CARD_HINTS}, "
            "black-brown walnut body, matte ceramic cups inserted into the wood, "
            "five warm gold ceramic basins and three distinct muted jewel basins for special categories, "
            "satin brass rings retained, ivory markers and tiny card hint plaques, "
            "strictly readable Poch board, no empty membranes, every basin is a category slot, {NEGATIVE}"
        ),
    },
    {
        "id": "PM82",
        "name": "Heritage Signet Wood",
        "seed": 144182,
        "prompt": (
            f"{CRAFT_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {CARD_HINTS}, "
            "museum-grade modern heirloom board, dark oiled walnut, brass signet rings, "
            "matte enamel basin lips in gold, emerald, amethyst, rose and petrol pigments, "
            "center bowl is large and calm, no emblem, no text in artwork, "
            "small bone markers exactly one before each outer basin, UI-label breathing room, {NEGATIVE}"
        ),
    },
    {
        "id": "PM83",
        "name": "Quiet Tabletop Craft",
        "seed": 144183,
        "prompt": (
            f"{CRAFT_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {CARD_HINTS}, "
            "the most restrained UI-ready version, walnut body almost matte, very subdued brass inlay rings, "
            "eight outer category basins with flat bottoms, colored matte enamel only on the basin walls, "
            "large central treasury bowl, ivory markers, generous dark negative space, "
            "labels would be added as clean vector overlay, no shine, no chromed reflections, {NEGATIVE}"
        ),
    },
    {
        "id": "PM84",
        "name": "Glass Bowl Strict B",
        "seed": 144184,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, "
            "direct evolution of PM71 Glass Bowl Strict A, darker and calmer, round smoky graphite glass disc, "
            "exactly eight outer concave glass bowls plus one large empty center cup, satin brass micro-rims, "
            "deep black bowl interiors, restrained cyan edge refraction, no labels in artwork, "
            "large quiet negative space for SwiftUI overlays, {NEGATIVE}, no lens, no central button"
        ),
    },
    {
        "id": "PM85",
        "name": "Glass Bowl Strict C",
        "seed": 144185,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, "
            "PM71-style circular glass board with warmer rose-gold and bronze metal accents, "
            "eight physical recessed coin bowls are symmetrical and clearly countable, center is a deep treasury bowl, "
            "small heavy copper chip stacks in three bowls, matte dark graphite floor under translucent glass, "
            "premium mobile game board, {NEGATIVE}, no roulette, no flat center, no extra wells"
        ),
    },
    {
        "id": "PM86",
        "name": "Glass Bowl Strict D",
        "seed": 144186,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, "
            "more PM1-like material restraint: smoky glass only on bowl lips, graphite ceramic main body, "
            "thin brass inlay ring around every bowl, eight outer bowls and one larger center cup, "
            "subtle colored mineral shadows inside bowls, no bright glow, low reflection matte luxury, {NEGATIVE}"
        ),
    },
    {
        "id": "PM87",
        "name": "Glass Engraved Cards A",
        "seed": 144187,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, "
            "exactly eight outer concave bowls and one center cup, "
            "near each outer bowl there is a subtle engraved playing-card plaque flush in the board surface, "
            "laser-etched ivory and frosted-glass card silhouettes, one plaque per category, "
            "the engravings look carved into the material, not printed, no readable text required, "
            "premium rule-hint system inspired by a real Poch board, {NEGATIVE}, no extra pockets, no central lens"
        ),
    },
    {
        "id": "PM88",
        "name": "Glass Engraved Cards B",
        "seed": 144188,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, "
            "PM71 glass bowl board with a ring of eight tiny engraved card insets between the center bowl and outer bowls, "
            "each inset is a shallow milled card-shaped recess with faint French-suit glyphs and rank hints, "
            "subtle bone-white engraving, very low contrast, enough to suggest the rules without clutter, "
            "true physical engraving, exact 8 plus 1 board geometry, {NEGATIVE}, no readable text, no misaligned cards"
        ),
    },
    {
        "id": "PM89",
        "name": "Glass Engraved Cards C",
        "seed": 144189,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, "
            "most UI-readable engraved-card variant, dark smoked glass and graphite body, "
            "eight outer bowls each paired with a small recessed card plaque directly below its bowl, "
            "plaques are milled into the board and filled with matte ivory enamel, "
            "faint card silhouettes only, no generated letters, exact labels will be overlayed later, "
            "center bowl remains empty and dominant, {NEGATIVE}, no lens, no roulette"
        ),
    },
    {
        "id": "PM90",
        "name": "Glass Engraved Cards D",
        "seed": 144190,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, "
            "premium collector-edition glass Poch board, PM71 body language, "
            "engraved card hints are arranged like a quiet historical Poch board reference around the center, "
            "thin satin brass lines connect each engraved card plaque to its matching outer bowl, "
            "eight outer bowls are large concave chip pots, central cup is the deepest pot, "
            "material is smoky graphite glass, titanium, muted brass, {NEGATIVE}, no readable text, no extra basins"
        ),
    },
    {
        "id": "PM91",
        "name": "Glass Engraved Cards E",
        "seed": 144191,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, "
            "award-winning mobile game key asset, top-down three-quarter view, "
            "PM71 strict glass bowl board with eight outer basins and one center basin, "
            "engraved card-hint plaques are extremely subtle, etched into smoky glass as shallow relief, "
            "cards feel integrated into the board, not stickers, no clutter, no typography, "
            "large premium French cards cropped at bottom edge for context, {NEGATIVE}, no central lens, no extra pockets"
        ),
    },
    {
        "id": "PM92",
        "name": "Glass Fine Gold Edge A",
        "seed": 144192,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, "
            "PM71 strict glass bowl board, exactly eight outer bowls plus one deep central cup, "
            "each bowl has an extremely thin hairline satin-gold edge along the upper lip, "
            "gold edge catches light only as material, not glow, not neon, dark smoky glass and graphite, "
            "calm premium UI surface with room for overlays, {NEGATIVE}, no central lens, no wide gold ring"
        ),
    },
    {
        "id": "PM93",
        "name": "Glass Fine Gold Edge B",
        "seed": 144193,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, "
            "more physical collector-edition version of PM71, dark transparent glass pots, "
            "fine brushed brass/gold bevel only on the front upper rim of every basin, "
            "large empty center bowl with matching thin gold lip, copper chips in a few wells, "
            "matte graphite backing surface, {NEGATIVE}, no glow, no roulette, no flat center"
        ),
    },
    {
        "id": "PM94",
        "name": "Gold Edge Engraved Cards",
        "seed": 144194,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, "
            "glass board with thin satin-gold edges on all nine bowls and subtle engraved playing-card plaques, "
            "engraved plaques are carved into the board between center cup and outer bowls, "
            "eight outer category bowls are symmetrical, center is a real deep bowl, "
            "gold is a hairline material inlay only, no broad rings, {NEGATIVE}, no readable text, no lens"
        ),
    },
    {
        "id": "PM95",
        "name": "Quiet Gold Lip Board",
        "seed": 144195,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, "
            "the quietest fine-gold-lip variant, nearly black smoked glass disc, "
            "thin warm gold line exactly on the upper lip of each concave basin, "
            "all basins are dark and empty except a few heavy copper coins, center cup dominant and deep, "
            "minimal reflections, premium non-casino material, {NEGATIVE}, no neon, no central button"
        ),
    },
    {
        "id": "PM96",
        "name": "Glass Fine Color Edge A",
        "seed": 144196,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, "
            "PM71 strict glass bowl board with very thin colored material edges over the bowl lips, "
            "colors derived from premium card-back palette: muted gold, bronze, garnet, copper rose, amber ochre, amethyst, emerald, petrol sapphire, "
            "one distinct subtle color per outer basin, no glow, no neon, no full-color fills, "
            "large deep center bowl with platinum/gold hairline edge, {NEGATIVE}, no lens, no roulette"
        ),
    },
    {
        "id": "PM97",
        "name": "Glass Fine Color Edge B",
        "seed": 144197,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, "
            "dark graphite glass board, exact 8 plus 1 Poch geometry, "
            "thin matte mineral pigment line painted only on the upper front lip of each outer bowl, "
            "subtle card-back colors, low saturation, material pigment not light emission, "
            "engraved card-hint plaques near each bowl, center bowl empty and deep, {NEGATIVE}, no readable text, no central lens"
        ),
    },
    {
        "id": "PM98",
        "name": "Color Edge Engraved Cards",
        "seed": 144198,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, "
            "glassmorphism Poch board with eight outer bowls, each bowl paired with an engraved card plaque and a fine colored lip, "
            "the color lip is a hairline enamel inlay: gold, bronze, garnet, rose copper, amber, amethyst, emerald, petrol, "
            "center bowl has a restrained platinum hairline, all surfaces matte-smoky and readable, {NEGATIVE}, no glow, no extra basins"
        ),
    },
    {
        "id": "PM99",
        "name": "Muted Cardback Edge Board",
        "seed": 144199,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, "
            "most premium color-edge variant, PM71 body language, smoked graphite glass, "
            "muted card-back inspired colored hairlines on basin lips only, almost black until light catches them, "
            "engraved card hint plaques are shallow and elegant, exact eight outer pots plus central treasury bowl, "
            "UI-ready with strong negative space, {NEGATIVE}, no neon, no chromatic glow, no lens"
        ),
    },
    {
        "id": "PM100",
        "name": "PM74 Heritage Retake A",
        "seed": 144200,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {CARD_HINTS}, {TOKEN_IN_POT_RULE}, "
            "direct evolution of PM74 Glass Poch Reference, inspired by a traditional Poch board layout but modernized, "
            "round dark smoky glass and graphite board, eight outer basins and one large center bowl, "
            "small embedded card illustrations around the center like the real board reference, "
            "very premium, calm, no UI clutter, {NEGATIVE}, no readable text, no central lens"
        ),
    },
    {
        "id": "PM101",
        "name": "PM74 Heritage Retake B",
        "seed": 144201,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {CARD_HINTS}, {TOKEN_IN_POT_RULE}, "
            "PM74 body language with stronger physical craft, black glass basins set into matte graphite, "
            "tiny ivory card plaques are milled into the inner ring, one for each outer basin, "
            "center cup is empty and deepest, thin satin brass ring around center only, {NEGATIVE}, no roulette, no extra pots"
        ),
    },
    {
        "id": "PM102",
        "name": "PM74 Engraved Values A",
        "seed": 144202,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {TOKEN_IN_POT_RULE}, "
            "PM74-style glass board with values engraved into small bone-white plaques beside each outer bowl, "
            "engraved value hints for ace, king, queen, jack, ten, mariage, sequence, poch are shallow relief carvings, "
            "not printed labels, not glowing text, exact readable text not required, "
            "large deep center bowl with no emblem, {NEGATIVE}, no extra basins, no central lens"
        ),
    },
    {
        "id": "PM103",
        "name": "PM74 Engraved Values B",
        "seed": 144203,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {TOKEN_IN_POT_RULE}, "
            "modernized traditional Poch board with subtly carved rank and suit hints directly in the graphite surface, "
            "each of the eight outer bowls has a matching engraved value plaque and a shallow card silhouette, "
            "engraving is low contrast ivory/gold inlay, board remains calm and premium, "
            "center is a real cup-shaped pot, {NEGATIVE}, no readable typography required, no roulette"
        ),
    },
    {
        "id": "PM104",
        "name": "PM74 Fine Gold Rings",
        "seed": 144204,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {CARD_HINTS}, {TOKEN_IN_POT_RULE}, "
            "PM74 glass board with fine hairline satin-gold rings around every outer basin and the center bowl, "
            "gold rings are thin material inlays only, no glow and no broad casino rim, "
            "cards are engraved into the inner surface, exact 8 plus 1 geometry, {NEGATIVE}, no central lens"
        ),
    },
    {
        "id": "PM105",
        "name": "PM74 Color Rings A",
        "seed": 144205,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {CARD_HINTS}, {TOKEN_IN_POT_RULE}, "
            "PM74 glass board with fine muted colored material rings around the bowls, "
            "colors match premium card-back palette: gold, bronze, garnet, rose copper, amber, amethyst, emerald, petrol sapphire, "
            "rings are narrow matte enamel inlays on the upper lip, not light, not neon, "
            "center bowl has platinum hairline, {NEGATIVE}, no extra basins, no lens"
        ),
    },
    {
        "id": "PM106",
        "name": "PM74 Color Rings B",
        "seed": 144206,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {TOKEN_IN_POT_RULE}, "
            "PM74-style traditional-reference board, dark smoky glass and graphite, "
            "eight outer basins with subtle colored upper rims plus engraved card/value plaques below each basin, "
            "the color rims are almost black until light catches them, premium and quiet, "
            "center cup large, empty, and deep, {NEGATIVE}, no readable text, no casino glow"
        ),
    },
    {
        "id": "PM107",
        "name": "PM74 Full Rule Inlay",
        "seed": 144207,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {TOKEN_IN_POT_RULE}, "
            "most complete PM74 rule-inlay version, one engraved card plaque and one fine colored rim per outer bowl, "
            "thin brass radial guide lines connect plaques to bowls, all lines are subtle material cuts, "
            "glass tokens sit naturally inside selected bowls like PM68, "
            "clear 8 outer pots plus center pot, calm dark premium board, {NEGATIVE}, no extra fields, no central lens"
        ),
    },
    {
        "id": "PM108",
        "name": "PM100 Matte Values A",
        "seed": 144208,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {TOKEN_IN_POT_RULE}, "
            "direct retake of PM100 Heritage Retake A but with much less mirror reflection, satin smoked glass instead of glossy glass, "
            "matte graphite surface, exactly eight outer basins and one deep center bowl, "
            "each outer basin has an engraved value plaque carved into the surface: ace, king, queen, jack, ten, mariage, sequence, poch, "
            "engravings are shallow ivory/gold inlays, not printed, no bright highlights, {NEGATIVE}, no lens, no chrome"
        ),
    },
    {
        "id": "PM109",
        "name": "PM100 Matte Values B",
        "seed": 144209,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {TOKEN_IN_POT_RULE}, "
            "PM100 composition, anti-glare matte finish, low specular reflection, smoked black ceramic-glass board, "
            "eight true concave outer pots with flat dark bottoms, large center cup, "
            "milled card-value plaques directly above each pot, subtle bone-white relief, "
            "values should feel engraved into material, UI-readable hierarchy, {NEGATIVE}, no glowing rings, no central button"
        ),
    },
    {
        "id": "PM110",
        "name": "PM100 Matte Color Values",
        "seed": 144210,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {TOKEN_IN_POT_RULE}, "
            "PM100 body with reduced reflections and fine muted colored rim accents on every basin, "
            "engraved card values per basin are placed on small recessed plaques, "
            "rings use card-back-inspired pigment: gold, bronze, garnet, rose copper, amber, amethyst, emerald, petrol sapphire, "
            "colors are matte material edges only, not light, exact eight outer pots plus center, {NEGATIVE}, no neon, no lens"
        ),
    },
    {
        "id": "PM111",
        "name": "PM100 Matte Gold Values",
        "seed": 144211,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {TOKEN_IN_POT_RULE}, "
            "PM100 retake with almost black satin glass, very fine gold hairline on bowl lips, no broad glow, "
            "engraved card values per basin are low-contrast gold cuts in the graphite ring, "
            "center pot is deep and empty with PM68-like tokens nearby, "
            "premium dark mobile game board, minimal reflection, {NEGATIVE}, no chrome, no roulette"
        ),
    },
    {
        "id": "PM112",
        "name": "PM100 Matte Rule Board",
        "seed": 144212,
        "prompt": (
            f"{GLASS_BASE}, {RULES}, {STRICT_CENTER_BOWL}, {TOKEN_IN_POT_RULE}, "
            "most rule-clear PM100 retake, low-gloss smoked glass and matte graphite, "
            "each of the eight basins has an engraved mini-card silhouette and value plaque aligned to it, "
            "large center bowl remains clean and label-free, selected bowls contain natural PM68-style token stacks, "
            "calm composition, enough negative space for SwiftUI overlays, {NEGATIVE}, no lens, no extra basins"
        ),
    },
    {
        "id": "PM113",
        "name": "Orthographic Graphite Prompt A",
        "seed": 144213,
        "prompt": (
            "Top-down orthographic view of a premium circular game board for a card game, "
            "perfectly centered and radially symmetric. Matte dark graphite surface with fine brushed micro-texture, "
            "absolutely no gloss. Eight shallow recessed wells arranged evenly in a ring around one larger, "
            "slightly deeper central pot. Each well framed by a thin polished brass rim; wells carry subtle muted "
            "jewel-tone enamel inner rings — gold, rose, emerald, amethyst, sapphire — as flat matte pigment, "
            "never glowing. Central pot filled with a small pile of antique brass and gold coins. "
            "One thin brass concentric guide ring separates the outer wells from the center. "
            "Even soft diffuse lighting from directly above, minimal shadows, no hotspots, no speculars. "
            "Restrained quiet-luxury heritage craftsmanship, generous clean negative space around the board. "
            "Flat UI-ready asset. sharp product design render. "
            "Negative prompt: gloss, glass, chrome, mirror reflection, specular highlight, neon, glow, RGB, tilt, perspective, "
            "3/4 angle, side view, wood grain, walnut, felt, ornate, baroque, casino, roulette wheel, subwoofer, speaker, "
            "ball bearing, text, letters, numbers, labels, logo, watermark, harsh shadow, dramatic lighting, colored background"
        ),
    },
    {
        "id": "PM114",
        "name": "Orthographic Graphite Prompt B",
        "seed": 144214,
        "prompt": (
            "Top-down orthographic view, premium circular Poch-style card game board, perfectly centered, "
            "mathematically radial and symmetric, exactly eight shallow recessed outer wells and one larger central pot, "
            "matte dark graphite with fine brushed micro-texture, absolutely no gloss, no glass. "
            "Thin polished brass rim around every well, subtle matte enamel inner lip colors from muted jewel tones: "
            "gold, rose, emerald, amethyst, sapphire. Central pot slightly deeper, containing a small pile of antique brass coins. "
            "One thin brass guide ring between center and outer wells, clean negative space, flat UI-ready asset, "
            "soft overhead diffuse light, minimal shadows, no speculars, quiet luxury heritage craft. "
            "Avoid gloss, chrome, mirror, neon, glow, RGB, tilt, perspective, 3/4 view, wood, felt, ornate, casino, roulette, text, labels, watermark"
        ),
    },
    {
        "id": "PM115",
        "name": "Orthographic Graphite Prompt C",
        "seed": 144215,
        "prompt": (
            "Strict flat top-down orthographic product render of a premium circular game board, UI-ready, "
            "dark matte graphite surface, fine brushed micro texture, low contrast, no shine. "
            "Exactly eight evenly spaced shallow circular wells plus one larger center pot, center pot filled with a small pile of antique gold/brass coins. "
            "Every well has a thin brass rim and very subtle flat matte pigment enamel line inside the lip, muted gold, rose, emerald, amethyst, sapphire. "
            "Thin brass concentric guide ring, generous clean negative space, quiet heritage craftsmanship, sharp 8k asset style. "
            "No gloss, no glass, no chrome, no specular highlight, no neon, no glow, no perspective, no side view, no labels, no text, no casino, no roulette"
        ),
    },
]


def fetch_output(output):
    if hasattr(output, "read"):
        return output.read()
    item = output[0] if isinstance(output, list) else output
    if hasattr(item, "url"):
        item = item.url
    response = requests.get(str(item), timeout=240)
    response.raise_for_status()
    return response.content


def label_image(src: Path, dest: Path, job: dict):
    img = Image.open(src).convert("RGB")
    img.thumbnail((1180, 1180), Image.Resampling.LANCZOS)
    pad = 86
    out = Image.new("RGB", (img.width, img.height + pad), (9, 8, 12))
    out.paste(img, (0, pad))
    draw = ImageDraw.Draw(out)
    try:
        font_big = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 30)
        font_small = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 20)
    except OSError:
        font_big = ImageFont.load_default()
        font_small = ImageFont.load_default()
    draw.text((18, 15), job["id"], fill=(226, 232, 240), font=font_big)
    draw.text((112, 22), job["name"], fill=(197, 160, 89), font=font_small)
    draw.text((18, 55), "8 Aussenmulden + Mitte · Labels bleiben HTML/SwiftUI", fill=(139, 147, 160), font=font_small)
    dest.parent.mkdir(parents=True, exist_ok=True)
    out.save(dest)


def generate(only: set[str], force: bool):
    log = json.loads(LOG.read_text()) if LOG.exists() else {}
    for job in JOBS:
        if only and job["id"] not in only:
            continue
        raw_path = RAW / f"{job['id']}.png"
        labeled_path = ART / f"{job['id']}.png"
        if raw_path.exists() and not force:
            print(f"[{job['id']}] exists, relabel")
            label_image(raw_path, labeled_path, job)
            continue
        print(f"[{job['id']}] {job['name']} via {MODEL}")
        for attempt in range(3):
            try:
                t0 = time.time()
                output = replicate.run(
                    MODEL,
                    input={
                        "prompt": job["prompt"],
                        "aspect_ratio": "4:3",
                        "output_format": "png",
                        "output_quality": 100,
                        "prompt_upsampling": False,
                        "safety_tolerance": 2,
                        "seed": job["seed"],
                    },
                )
                raw_path.write_bytes(fetch_output(output))
                label_image(raw_path, labeled_path, job)
                log[job["id"]] = {
                    "date": DATE,
                    "model": MODEL,
                    "seed": job["seed"],
                    "name": job["name"],
                    "prompt": job["prompt"],
                    "raw": str(raw_path.relative_to(ROOT)),
                    "labeled": str(labeled_path.relative_to(ROOT)),
                }
                print(f"[{job['id']}] ok ({time.time() - t0:.0f}s)")
                break
            except Exception as exc:
                msg = str(exc)
                if "insufficient credit" in msg.lower() or "payment" in msg.lower():
                    print("Replicate payment/credit blocked")
                    LOG.write_text(json.dumps(log, indent=2, ensure_ascii=False))
                    sys.exit(2)
                print(f"[{job['id']}] attempt {attempt + 1} failed: {msg[:260]}")
                time.sleep(4)
        else:
            print(f"[{job['id']}] failed")
    LOG.write_text(json.dumps(log, indent=2, ensure_ascii=False))


def b64(path: Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("ascii")


def write_html():
    cards = []
    for job in JOBS:
        path = ART / f"{job['id']}.png"
        if not path.exists():
            continue
        cards.append(f"""
        <section class="card">
          <img src="data:image/png;base64,{b64(path)}" alt="{job['id']} {job['name']}">
          <div class="meta">
            <h2>{job['id']} · {job['name']}</h2>
            <p><b>Regel-Overlay:</b> A · K · Q · J · 10 · MARIAGE · SEQUENZ · POCH · MITTE. Keine weiteren Potte.</p>
          </div>
        </section>
        """)
    html = f"""<!doctype html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Poch 1441 · Physical Board Replicate</title>
  <style>
    :root {{ color-scheme: dark; --bg:#07060a; --panel:#121018; --text:#e2e8f0; --muted:#9aa1ad; --gold:#c5a059; }}
    * {{ box-sizing:border-box; }}
    body {{ margin:0; background:radial-gradient(circle at 50% -10%, rgba(197,160,89,.16), transparent 520px), var(--bg); color:var(--text); font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif; }}
    header {{ max-width:1320px; margin:0 auto; padding:30px 24px 12px; }}
    h1 {{ margin:0 0 8px; font-size:34px; letter-spacing:.01em; }}
    .lead {{ margin:0; max-width:980px; color:var(--muted); line-height:1.45; font-weight:600; }}
    .rule {{ margin-top:14px; display:flex; flex-wrap:wrap; gap:8px; }}
    .pill {{ border:1px solid rgba(197,160,89,.28); border-radius:999px; padding:6px 10px; color:#d9dce5; background:rgba(255,255,255,.045); font-size:11px; font-weight:850; letter-spacing:.08em; }}
    main {{ max-width:1320px; margin:0 auto; padding:20px 24px 40px; display:grid; grid-template-columns:repeat(auto-fit,minmax(360px,1fr)); gap:20px; }}
    .card {{ background:linear-gradient(180deg,#17131d,#0d0b12); border:1px solid rgba(197,160,89,.22); border-radius:12px; padding:12px; box-shadow:0 20px 70px rgba(0,0,0,.34); }}
    img {{ display:block; width:100%; border-radius:8px; background:#08070b; }}
    h2 {{ font-size:18px; color:var(--gold); margin:12px 2px 5px; }}
    p {{ color:var(--muted); margin:0 2px 4px; line-height:1.35; font-size:13px; }}
    b {{ color:#dfe5ee; }}
  </style>
</head>
<body>
  <header>
    <h1>Poch 1441 · Physical Board Varianten</h1>
    <p class="lead">Replicate-Renderings inspiriert von Future Heritage / Stone Edition. Die Bilder sind Look-Referenzen; die finalen Pott-Labels kommen als saubere SwiftUI/Vektor-Ebene, damit sie regelkonform bleiben.</p>
    <div class="rule">
      <span class="pill">A</span><span class="pill">K</span><span class="pill">Q</span><span class="pill">J</span><span class="pill">10</span>
      <span class="pill">MARIAGE</span><span class="pill">SEQUENZ</span><span class="pill">POCH</span><span class="pill">MITTE</span>
    </div>
  </header>
  <main>{''.join(cards)}</main>
</body>
</html>
"""
    HTML.write_text(html, encoding="utf-8")
    TEMP_HTML.write_text(html, encoding="utf-8")
    print("HTML:", HTML)
    print("TEMP:", TEMP_HTML)


def main():
    args = set(sys.argv[1:])
    only = {arg for arg in args if arg.startswith("PM")}
    force = "--force" in args
    generate(only, force)
    write_html()


if __name__ == "__main__":
    main()
