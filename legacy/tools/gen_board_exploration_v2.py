#!/usr/bin/env python3
"""Render two independent, PM49-free Poch board exploration series."""

from __future__ import annotations

import argparse
import json
import os
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import replicate
import requests
from PIL import Image


ROOT = Path("/Users/tobsi/poch1441")
OUT = ROOT / "artifacts/board-exploration-v2"
REFERENCE = OUT / "reference/neutral-topology.png"
MANIFEST = OUT / "manifest.json"
MODEL = "black-forest-labs/flux-kontext-pro"

KEY_FILE = Path("~/.config/replicate.key").expanduser()
if KEY_FILE.exists():
    os.environ["REPLICATE_API_TOKEN"] = KEY_FILE.read_text().strip()


TOPOLOGY = (
    "The supplied image is an abstract engineering topology diagram, not a style reference. "
    "Reimagine the object from zero as a newly designed premium industrial product from 2026. "
    "Do not reproduce the diagram's flat grey appearance. Show a perfectly centered orthographic "
    "top-down view. Preserve exactly eight evenly spaced outer physical recessed coin wells "
    "and exactly one larger physical recessed center well, nine wells total. Every well has "
    "a broad flat token floor and softly radiused walls. Align exactly one blank card-category "
    "marker zone with every outer well, eight marker zones total. Keep all wells empty. "
)

PRODUCT = (
    "This is unmistakably the signature board of the Poch 1441 mobile game: a quiet dark "
    "graphite or technical-ceramic body, sparse warm satin-metal precision accents and restrained "
    "mineral pigments derived from its card-back palette: muted gold, garnet rose, emerald, "
    "amethyst and sapphire petrol. The pigments are material orientation cues, never decoration "
    "or emitted light. The board must be believable as a real manufacturable collector object, "
    "quiet, tactile, precise and contemporary. Design the broad flat well floors and softly "
    "radiused walls for naturally overlapping piles of heavy translucent glass game tokens. "
    "Use controlled matte materials, realistic thickness, robust bridges and soft diffuse "
    "overhead product lighting on a neutral near-black app background. "
    "Future heritage means timeless brand quality, never historical styling. Color may appear "
    "only as restrained material pigment or a fine replaceable inlay, never emitted light. "
)

NEGATIVE = (
    "No text, letters, numbers, card art, suit symbols, labels, logo or watermark. No historical "
    "styling of any kind. No retro, "
    "vintage, antique, medieval, tavern, rustic wood toy, patina, distressed finish, parchment "
    "or historical illustration. No casino, roulette wheel, poker chip silhouette, radial "
    "betting segments, clock face, gauge, gear, speaker, subwoofer, lens, camera aperture, "
    "jewelry, gems, candy or fantasy artifact. No glow, neon, LED, bloom, halo, underlight, "
    "mirror chrome, broad gold ring, dramatic reflections, tilted camera or extra wells. "
)


CODEX = [
    {
        "id": "C01", "name": "Graphite Archipelago",
        "intent": "Separate functional islands in a calm monolithic field.",
        "prompt": (
            "Use a low-profile disc of matte sintered graphite ceramic. Mill nine generous "
            "soft circular bowls directly into the body. Around each outer bowl, create a "
            "slightly raised graphite island with a small flush blank marker tablet facing "
            "the center. Hairline muted mineral pigment appears only inside each inner lip."
        ),
    },
    {
        "id": "C02", "name": "Floating Halo Chassis",
        "intent": "A thin precision top deck floating above a dense structural core.",
        "prompt": (
            "Build a two-layer object: a bead-blasted dark titanium top deck floats over a "
            "smaller matte-black mineral core with a quiet shadow gap. Nine technical ceramic "
            "bowl liners sit flush through the top deck. A separate thin inner halo carries "
            "eight blank rounded-rectangle marker bays without radial segmentation."
        ),
    },
    {
        "id": "C03", "name": "Obround Atelier",
        "intent": "Modernizes the historic egg-shaped bowls without copying their style.",
        "prompt": (
            "Use a perfectly circular dark mineral-composite body with eight tangential, "
            "soft-obround outer wells, each shaped like a refined capsule and oriented around "
            "the ring. Use a circular center well. Give every outer well a small matte ceramic "
            "card plaque recessed into its inward-facing shoulder. Thin satin-brass microbevels."
        ),
    },
    {
        "id": "C04", "name": "Ceramic Twin Shell",
        "intent": "A seamless dark shell reveals a second colored material only in use zones.",
        "prompt": (
            "Form the board from a thick seamless shell of charcoal technical ceramic over a "
            "muted mineral-enamel inner body. The enamel is visible only on the flat bottoms "
            "and upper inside lips of the nine bowls. Eight blank marker recesses are molded "
            "into the inner ceramic bridge as quiet tactile depressions."
        ),
    },
    {
        "id": "C05", "name": "Precision Cup Array",
        "intent": "Nine serviceable bowls become the hero components of a quiet chassis.",
        "prompt": (
            "Create a broad graphite-anodized aluminum tray with nine individually machined "
            "matte-black ceramic cup inserts, eight equal cups plus one larger center cup. "
            "Each outer cup includes one integrated inward-facing blank marker shelf in the "
            "same ceramic piece. Show microscopic assembly seams, not decorative rings."
        ),
    },
    {
        "id": "C06", "name": "Soft Octant",
        "intent": "Eight-fold logic expressed through restrained outer geometry, not a wheel.",
        "prompt": (
            "Use a circular low-profile board whose vertical outer edge has eight broad soft "
            "facets while the top remains visually calm. Machine eight rounded-square outer "
            "wells and one circular center well into matte dark slate ceramic. Place eight "
            "small flush trapezoid marker plates on a continuous unsegmented inner field."
        ),
    },
    {
        "id": "C07", "name": "Frosted Core",
        "intent": "Contemporary depth through translucent material without glassmorphism.",
        "prompt": (
            "Use a thick disc of smoke-grey frosted glass-ceramic composite with an opaque "
            "graphite underside, so the mass reads softly translucent only at the vertical "
            "edge. Insert nine fully opaque matte graphite ceramic wells. Etch eight blank "
            "card-shaped marker windows beneath the frosted surface, never illuminated."
        ),
    },
    {
        "id": "C08", "name": "Ribbon Datum",
        "intent": "One continuous precision datum organizes wells and labels without roulette cues.",
        "prompt": (
            "Carve the nine bowls into a monolithic matte black mineral body. Inlay one thin, "
            "broken satin-brass ribbon that travels as a calm rounded octagonal path between "
            "the outer wells and center, widening locally into eight blank marker pads. The "
            "ribbon must not form radial segments or encircle individual wells."
        ),
    },
    {
        "id": "C09", "name": "Folded Titanium Basin",
        "intent": "A precise metal object with formed depth and almost no decorative surface.",
        "prompt": (
            "Construct the board from a deep-drawn and bead-blasted dark titanium upper basin "
            "bonded to a dense black ceramic base. The nine wells are smoothly formed into "
            "the titanium skin with matte dark enamel floors. Eight inward-facing blank marker "
            "tabs are laser-cut and folded nearly flush from the same upper skin."
        ),
    },
    {
        "id": "C10", "name": "Quiet Composite 200",
        "intent": "The most realistic production candidate for a 200 mm collector board.",
        "prompt": (
            "Design a 200 mm manufacturable collector board with a precision-cast charcoal "
            "mineral composite body, replaceable satin ceramic well liners, an 8 mm solid edge, "
            "4 mm outer-well depth and 6 mm center-well depth. Integrate eight blank matte "
            "enamel marker plates and tiny hidden fasteners on the underside only."
        ),
    },
]


# Independently proposed by Gemini 2.5 Pro from the same neutral brief and topology image.
GEMINI = [
    {
        "id": "G01", "name": "Monolith",
        "intent": "Absolute solidity and architectural permanence in one sculpted object.",
        "prompt": (
            "Precision-mill the complete board from one heavy block of dark charcoal fine-grain "
            "mineral composite with a deep matte finish. Distinguish eight circular blank marker "
            "zones only through a subtle satin honing contrast on the continuous inner field."
        ),
    },
    {
        "id": "G02", "name": "Floating Plate",
        "intent": "A lightweight layered object with a controlled floating shadow gap.",
        "prompt": (
            "Use a 4 mm bead-blasted dark-grey anodized aluminum top plate invisibly mounted "
            "over a smaller dense matte-black precision core. Cut all nine wells through the "
            "plate into the core. Laser-etch eight blank card-shaped marker silhouettes into "
            "the top plate with a non-reflective tonal finish."
        ),
    },
    {
        "id": "G03", "name": "Radial Joinery",
        "intent": "Eight-part precision assembly that exposes construction without nostalgia.",
        "prompt": (
            "Assemble eight identical sharply milled wedges of uniformly black, non-grained "
            "engineered wood composite inside a thin dark bronze containment edge. Each wedge "
            "holds one outer bowl and one flush inward marker tab. Use a separate matte ceramic "
            "center bowl; keep joints hairline and contemporary."
        ),
    },
    {
        "id": "G04", "name": "Ceramic Inlay",
        "intent": "A seamless technical marquetry of dark mass and one light inlay system.",
        "prompt": (
            "Use a heavy dark graphite sintered-metal disc. Set one complex bone-grey matte "
            "technical-ceramic inlay flush into it, forming the flat floors of all nine wells "
            "and a continuous inner marker band. Define eight blank marker fields with only "
            "fine shallow grooves in the ceramic."
        ),
    },
    {
        "id": "G05", "name": "Structural Web",
        "intent": "Negative space and a single technical frame replace the conventional solid disc.",
        "prompt": (
            "CNC-mill a lightweight hub-spoke-outer-ring frame from bead-blasted space-grey "
            "anodized aluminum over a thin matte carbon-mineral base. Keep exactly eight broad "
            "radial structural bridges, each with a blank marker surface, while the nine wells "
            "remain fully bounded physical bowls and never read as roulette segments."
        ),
    },
    {
        "id": "G06", "name": "Stepped Topography",
        "intent": "Functional zones expressed as calm micro-architecture and elevation changes.",
        "prompt": (
            "Mill one cool dark-grey mineral-composite cylinder into three levels: a high outer "
            "plateau containing eight wells, a lower continuous inner terrace containing eight "
            "blank shallow marker bays, and the lowest larger center basin. Use smooth vertical "
            "walls and finely sandblasted horizontal surfaces."
        ),
    },
    {
        "id": "G07", "name": "Modular Inserts",
        "intent": "A user-serviceable chassis with removable high-tolerance components.",
        "prompt": (
            "Machine a matte hard-anodized dark aluminum chassis with nine openings. Drop nine "
            "individual heavy satin-black ceramic bowl inserts into the openings with tiny "
            "precision seams. Define eight blank rectangular marker fields through a subtle "
            "horizontal brushing change on the otherwise matte chassis."
        ),
    },
    {
        "id": "G08", "name": "Faceted Geometry",
        "intent": "A strong contemporary octagonal language without becoming a segmented wheel.",
        "prompt": (
            "Form a low-profile softened-octagonal prism from very dark slate-blue mineral-filled "
            "polymer composite. Use eight softly faceted outer wells and one larger round center "
            "well. Place eight blank shallow trapezoidal marker depressions on one calm continuous "
            "inner plane, with no lines connecting them."
        ),
    },
    {
        "id": "G09", "name": "Enamel and Bronze",
        "intent": "Dense modern luxury through vitreous enamel and tightly controlled warm metal.",
        "prompt": (
            "Use a heavy dark structural disc with a battleship-grey matte vitreous-enamel top. "
            "Expose satin bronze only as extremely thin machined well lips and tiny edge catches, "
            "never a continuous outer ring. Create eight blank ghost marker zones through a "
            "slight enamel texture change."
        ),
    },
    {
        "id": "G10", "name": "Suspended Core",
        "intent": "The central pot and outer bowls become two visually tensioned assemblies.",
        "prompt": (
            "Separate a dark graphite outer ring containing eight wells from a matte light-grey "
            "technical-ceramic center hub containing the larger pot. Connect them with eight very "
            "short broad dark titanium bridges across a narrow shadow gap. Integrate one blank "
            "marker pad into each bridge; keep the silhouette compact and robust."
        ),
    },
]


def fetch_output(output: object) -> bytes:
    if hasattr(output, "read"):
        return output.read()
    item = output[0] if isinstance(output, list) else output
    if hasattr(item, "url"):
        item = item.url()
    response = requests.get(str(item), timeout=240)
    response.raise_for_status()
    return response.content


def render(job: dict[str, str], force: bool) -> dict[str, object]:
    source = "codex" if job["id"].startswith("C") else "gemini"
    target = OUT / source / f"{job['id']}.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    prompt = f"{TOPOLOGY}{PRODUCT}{job['prompt']} {NEGATIVE}"
    if target.exists() and not force:
        with Image.open(target) as image:
            size = image.size
        return {**job, "source": source, "path": str(target.relative_to(OUT)),
                "status": "existing", "size": size, "final_prompt": prompt}

    for attempt in range(3):
        try:
            started = time.time()
            with REFERENCE.open("rb") as reference:
                output = replicate.run(
                    MODEL,
                    input={
                        "prompt": prompt,
                        "input_image": reference,
                        "aspect_ratio": "1:1",
                        "output_format": "png",
                        "safety_tolerance": 2,
                        "prompt_upsampling": False,
                        "seed": 261000 + int(job["id"][1:]) + (0 if source == "codex" else 100),
                    },
                )
            target.write_bytes(fetch_output(output))
            with Image.open(target) as image:
                size = image.size
            return {**job, "source": source, "path": str(target.relative_to(OUT)),
                    "status": "generated", "size": size,
                    "seconds": round(time.time() - started, 1), "final_prompt": prompt}
        except Exception as error:
            if attempt == 2:
                return {**job, "source": source, "status": "failed",
                        "error": str(error), "final_prompt": prompt}
            time.sleep(3 + attempt * 2)
    raise AssertionError("unreachable")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--series", choices=["codex", "gemini", "all"], default="all")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--workers", type=int, default=4)
    args = parser.parse_args()

    jobs = CODEX if args.series == "codex" else GEMINI if args.series == "gemini" else CODEX + GEMINI
    results: list[dict[str, object]] = []
    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        futures = {executor.submit(render, job, args.force): job for job in jobs}
        for future in as_completed(futures):
            result = future.result()
            results.append(result)
            print(f"{result['id']}: {result['status']}", flush=True)

    order = {job["id"]: index for index, job in enumerate(CODEX + GEMINI)}
    previous = []
    if MANIFEST.exists() and args.series != "all":
        previous = json.loads(MANIFEST.read_text(encoding="utf-8"))
    merged = {item["id"]: item for item in previous}
    merged.update({item["id"]: item for item in results})
    ordered = sorted(merged.values(), key=lambda item: order[item["id"]])
    MANIFEST.write_text(json.dumps(ordered, ensure_ascii=False, indent=2), encoding="utf-8")
    failures = [item for item in results if item["status"] == "failed"]
    print(f"manifest={MANIFEST} rendered={len(results) - len(failures)} failed={len(failures)}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
