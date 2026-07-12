#!/usr/bin/env python3
"""Generate and present twenty PM49-bound Poch board directions.

Ten directions are authored in-repo and ten are parsed from the Gemini
counter-review. FLUX Kontext keeps the locked PM49 silhouette and 8+1 geometry
as the common comparison base. Images stay external to the HTML to avoid the
large base64 reports produced by the older exploration pipeline.
"""

from __future__ import annotations

import html
import json
import os
import re
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import replicate
import requests
from PIL import Image


ROOT = Path("/Users/tobsi/poch1441")
SOURCE = ROOT / "App/Assets.xcassets/PochRingPM49.imageset/poch_ring_pm49.png"
OUT = ROOT / "artifacts/board-direction-20260710"
RENDERED = OUT / "rendered"
HTML = OUT / "board-20-sichtung.html"
MANIFEST = OUT / "board-20-manifest.json"
GEMINI = OUT / "gemini-directions.md"
VISION_AUDIT = OUT / "vision-audit.md"
MODEL = "black-forest-labs/flux-kontext-pro"

KEY_FILE = Path("~/.config/replicate.key").expanduser()
if KEY_FILE.exists():
    os.environ["REPLICATE_API_TOKEN"] = KEY_FILE.read_text().strip()

LOCK = (
    "Edit the supplied PM49 board reference while preserving its exact centered "
    "orthographic top-down camera, exact circular silhouette, exact radial symmetry, "
    "and exact layout of eight evenly spaced outer recessed wells plus one larger "
    "true recessed center well. Keep all nine wells as physical flat-bottom coin "
    "bowls fully inside the board. Preserve the quiet PM49 premium identity. "
)

FUNCTION = (
    "Each outer well needs an understated blank inlay bay on the inner web for a "
    "future vector card hint, but the image itself contains no letters, numbers, "
    "card art, icons, emblems or logos. The wells must accept small overlapping "
    "PM68-style glass-metal tokens without hiding the upper label zone. "
)

LIGHT = (
    "Use soft even overhead studio light, subtle ambient occlusion inside the wells, "
    "a controlled grazing highlight only on machined bevels, and generous dark "
    "negative space. Keep the board UI-ready and readable at 120 pixels. "
)

NEGATIVE = (
    "Do not add or remove wells. No text, letters, numbers, card faces, suit symbols, "
    "logo, watermark, center emblem, raised center button, lens, speaker, subwoofer, "
    "camera aperture, roulette wheel, poker chip silhouette, radial segment wheel, "
    "technical gauge, clockwork, jewel cabochons, candy, chrome, mirror glass, broad "
    "gold ring, neon, LED, emission, bloom, halo, underglow, dramatic hotspot, tilt, "
    "perspective change, floating tokens, cracks or chipped pigment. "
)


INTERNAL = [
    {
        "id": "I01",
        "name": "PM49 Pure Refinement",
        "summary": "Die konservativste Reinzeichnung: PM49 bleibt sofort erkennbar, wird aber physischer und ruhiger.",
        "prompt": (
            "Stay extremely close to PM49. Refine the graphite microtexture, make the "
            "outer well floors slightly flatter and the center well subtly deeper, "
            "reduce edge shine, and keep the eight muted colored material lips. Add "
            "eight barely recessed blank graphite label shelves on the inner web."
        ),
    },
    {
        "id": "I02",
        "name": "Flush-Milled Monolith",
        "summary": "Mulden direkt aus dem Graphitblock gefräst, ohne aufgesetzte Cup-Optik.",
        "prompt": (
            "Rebuild the raised well collars as flush precision-milled recesses cut "
            "directly into one monolithic graphite ceramic body. Retain hairline matte "
            "pigment inlays inside each upper lip and a thin platinum center lip."
        ),
    },
    {
        "id": "I03",
        "name": "Heritage Card Halo",
        "summary": "Historische Kartenlogik als acht leise Einlegeflächen auf dem Innenring.",
        "prompt": (
            "Add a calm inner halo containing exactly eight small shallow inlay bays, "
            "one aligned with each outer well. The bays are dark ivory ceramic with no "
            "content, ready for vector card hints. Keep all wells and PM49 materials."
        ),
    },
    {
        "id": "I04",
        "name": "Brass Index Pins",
        "summary": "PM1s Messingpunkte werden zu präzisen Orientierungsstiften vor jeder Mulde.",
        "prompt": (
            "Keep exactly one tiny flush satin-brass alignment pin on the radial axis "
            "before every outer well, eight pins total and mathematically aligned. Add "
            "subtle blank debossed label bays behind the pins, with no ornament."
        ),
    },
    {
        "id": "I05",
        "name": "Collector Well Geometry",
        "summary": "Mehr reale Chipfläche: großzügigere Außenmulden und stärkerer Mittelpot.",
        "prompt": (
            "Increase all eight outer well openings by about six percent while keeping "
            "even robust material bridges. Increase the center opening by about eight "
            "percent. Use steep rounded walls and broad flat token floors like a real "
            "200 millimeter collector board."
        ),
    },
    {
        "id": "I06",
        "name": "Ceramic Liner Edition",
        "summary": "Graphitkörper mit eingesetzten mattschwarzen Keramikschalen und mineralischen Lippen.",
        "prompt": (
            "Insert separate satin-black ceramic bowl liners into the graphite body. "
            "The liners are visibly material, not glossy, with very thin muted mineral "
            "color inlays around the upper inside lips and restrained brass micro-bevels."
        ),
    },
    {
        "id": "I07",
        "name": "Mineral Pigment Cut",
        "summary": "Farbe erscheint nur als eingeschnittenes Mineralpigment, fast schwarz bis Licht darüberläuft.",
        "prompt": (
            "Replace painted-looking colored rims with hairline channels filled with "
            "matte mineral pigment. Use the PM49 eight-color sequence, each hue very "
            "dark and low saturation until grazing light catches the material."
        ),
    },
    {
        "id": "I08",
        "name": "Eight-Facet Heritage Edge",
        "summary": "Ein kaum sichtbarer achteckiger Schliff zitiert historische Bretter, ohne die Rundform zu verlieren.",
        "prompt": (
            "Keep the board visually circular but introduce eight extremely subtle "
            "large facets only on the vertical outer edge, one per well axis. The top "
            "surface remains round, calm and PM49-like with a hairline brass edge catch."
        ),
    },
    {
        "id": "I09",
        "name": "Quiet Guilloche",
        "summary": "Schwarz-auf-Schwarz-Fräsung gibt Nähe Prestige, verschwindet aber in kleiner Darstellung.",
        "prompt": (
            "Add an extremely low-contrast black-on-black precision guilloche pattern "
            "only in the broad dead space between wells. Keep it shallow, sparse and "
            "non-heraldic; it must disappear cleanly when the board is reduced."
        ),
    },
    {
        "id": "I10",
        "name": "Manufacturable 200",
        "summary": "Der kompromisslose reale Prototyp: CNC-Körper, echte Wandstärken und PM68-taugliche Böden.",
        "prompt": (
            "Render a manufacturable 200 mm collector object derived from PM49: CNC "
            "machined graphite-anodized aluminum body, replaceable matte ceramic well "
            "liners, 4 mm outer well depth, 5.5 mm center depth, robust bridges, satin "
            "brass and enamel inlays, no decorative complexity."
        ),
    },
]


def gemini_jobs() -> list[dict[str, object]]:
    source = GEMINI.read_text(encoding="utf-8")
    pattern = re.compile(
        r"### (G\d+) - ([^\n]+).*?"
        r"\*\*Vollständiger englischer Replicate-Renderprompt:\*\* `([^`]+)`.*?"
        r"\*\*Harte negative Zusätze:\*\* `([^`]+)`",
        re.S,
    )
    jobs = []
    for identifier, name, prompt, negative in pattern.findall(source):
        jobs.append(
            {
                "id": identifier,
                "name": name.strip(),
                "summary": "Externe Gemini-Gegenrichtung auf Basis desselben verbindlichen Briefs.",
                "prompt": f"{prompt.strip()} Additional exclusions: {negative.strip()}",
            }
        )
    if len(jobs) != 10:
        raise RuntimeError(f"Expected 10 Gemini directions, found {len(jobs)}")
    return jobs


def fetch_output(output: object) -> bytes:
    if hasattr(output, "read"):
        return output.read()
    item = output[0] if isinstance(output, list) else output
    if hasattr(item, "url"):
        item = item.url()
    response = requests.get(str(item), timeout=240)
    response.raise_for_status()
    return response.content


def render_job(job: dict[str, object], force: bool) -> dict[str, object]:
    target = RENDERED / f"{job['id']}.png"
    if target.exists() and not force:
        return {**job, "status": "existing", "path": str(target.relative_to(OUT))}

    prompt = f"{LOCK}{FUNCTION}{job['prompt']} {LIGHT}{NEGATIVE}"
    for attempt in range(3):
        try:
            started = time.time()
            with SOURCE.open("rb") as input_image:
                output = replicate.run(
                    MODEL,
                    input={
                        "prompt": prompt,
                        "input_image": input_image,
                        "aspect_ratio": "match_input_image",
                        "output_format": "png",
                        "safety_tolerance": 2,
                        "prompt_upsampling": False,
                        "seed": 144300 + int(str(job["id"])[1:]),
                    },
                )
            target.write_bytes(fetch_output(output))
            with Image.open(target) as image:
                size = image.size
            return {
                **job,
                "status": "generated",
                "path": str(target.relative_to(OUT)),
                "seconds": round(time.time() - started, 1),
                "size": size,
                "final_prompt": prompt,
            }
        except Exception as exc:  # Replicate transient failures are retried.
            if attempt == 2:
                return {**job, "status": "failed", "error": str(exc), "final_prompt": prompt}
            time.sleep(3 + attempt * 2)
    raise AssertionError("unreachable")


def vision_audit() -> dict[str, tuple[str, str]]:
    if not VISION_AUDIT.exists():
        return {}
    audits = {}
    for identifier, status, reason in re.findall(
        r"\|\s*([IG]\d{2})\s*\|\s*(PASS|FAIL)\s*\|\s*([^|\n]+)",
        VISION_AUDIT.read_text(encoding="utf-8"),
    ):
        audits[identifier] = (status.lower(), reason.strip())
    return audits


def write_html(results: list[dict[str, object]]) -> None:
    audits = vision_audit()
    cards = []
    for job in results:
        identifier = str(job["id"])
        source = "Intern" if identifier.startswith("I") else "Gemini"
        path = html.escape(str(job.get("path", "")))
        state = "ready" if job.get("status") in {"generated", "existing"} else "failed"
        audit_state, audit_reason = audits.get(identifier, ("pending", "Pixelprüfung ausstehend"))
        cards.append(
            f"""
            <article class="candidate {state} qa-{audit_state}" data-source="{source.lower()}" data-qa="{audit_state}" data-id="{identifier}">
              <div class="candidate-head">
                <div><span class="id">{identifier}</span><span class="source">{source}</span><span class="qa">{audit_state.upper()}</span></div>
                <button class="star" type="button" aria-label="{identifier} vormerken">☆</button>
              </div>
              <div class="board-stage">
                <img src="{path}" alt="{html.escape(str(job['name']))}" loading="lazy">
                <div class="token-layer" aria-hidden="true">
                  <div class="pile center-pile"><i></i><i></i><i></i><i></i><i></i></div>
                  <div class="pile outer-pile"><i></i><i></i><i></i></div>
                </div>
              </div>
              <div class="candidate-copy">
                <h2>{identifier} · {html.escape(str(job['name']))}</h2>
                <p>{html.escape(str(job['summary']))}</p>
                <div class="scale-check">
                  <figure><img src="{path}" alt=""><figcaption>Akt 1 · 360 px</figcaption></figure>
                  <figure class="compact"><img src="{path}" alt=""><figcaption>Akt 2 · 120 px</figcaption></figure>
                  <figure class="icon"><img src="{path}" alt=""><figcaption>Signet · 64 px</figcaption></figure>
                </div>
                <div class="gates"><span>8 + Mitte</span><span>PM68-Fit</span><span>kein Glow</span></div>
                <p class="audit-note">{html.escape(audit_reason)}</p>
              </div>
            </article>
            """
        )

    page = f"""<!doctype html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Poch 1441 · Board Direction 20</title>
  <style>
    :root{{--bg:#07060a;--panel:#100e14;--line:rgba(198,154,74,.24);--gold:#c69a4a;--text:#e2e8f0;--muted:#969ca9}}
    *{{box-sizing:border-box}} body{{margin:0;background:radial-gradient(circle at 50% 0,rgba(198,154,74,.11),transparent 38rem),var(--bg);color:var(--text);font-family:-apple-system,BlinkMacSystemFont,"SF Pro Display",sans-serif}}
    header{{max-width:1480px;margin:auto;padding:38px 26px 22px}} .eyebrow{{color:var(--gold);font-size:11px;font-weight:800;letter-spacing:2px}} h1{{margin:8px 0 9px;font-size:clamp(28px,4vw,50px);letter-spacing:0}} .lead{{max-width:900px;margin:0;color:var(--muted);line-height:1.5;font-weight:560}}
    .toolbar{{position:sticky;top:0;z-index:10;display:flex;gap:8px;align-items:center;max-width:1480px;margin:auto;padding:12px 26px;background:rgba(7,6,10,.9);backdrop-filter:blur(18px);border-block:1px solid rgba(255,255,255,.05)}} button{{border:1px solid rgba(255,255,255,.1);background:#17141b;color:var(--muted);min-height:38px;padding:8px 12px;border-radius:6px;font:inherit;font-weight:700;cursor:pointer}} button.active{{border-color:var(--gold);color:var(--text);background:rgba(198,154,74,.14)}} .toolbar .spacer{{flex:1}} .count{{color:var(--muted);font-size:12px}}
    main{{max-width:1480px;margin:auto;padding:24px 26px 70px;display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:22px}} .candidate{{min-width:0;border:1px solid var(--line);background:linear-gradient(180deg,#131018,#0c0a0f);border-radius:8px;overflow:hidden;box-shadow:0 26px 70px rgba(0,0,0,.3)}} .candidate.hidden{{display:none}} .candidate-head{{height:48px;padding:0 14px;display:flex;align-items:center;justify-content:space-between;background:#09080c}} .id{{font-weight:900;margin-right:10px}} .source{{color:var(--gold);font-size:11px;font-weight:800;letter-spacing:1px;text-transform:uppercase}} .star{{font-size:20px;padding:0;width:34px;min-height:32px}} .star.active{{color:var(--gold)}}
    .qa{{margin-left:9px;padding:3px 6px;border-radius:999px;font-size:8px;font-weight:900;letter-spacing:.8px;background:rgba(46,139,107,.16);color:#8db8a7}} .qa-fail{{border-color:rgba(158,59,78,.5)}} .qa-fail .qa{{background:rgba(158,59,78,.2);color:#df8999}} .board-stage{{position:relative;container-type:inline-size;background:#090a0d;aspect-ratio:1;overflow:hidden}} .board-stage>img{{display:block;width:100%;height:100%;object-fit:cover}} .token-layer{{display:none;position:absolute;inset:0;pointer-events:none}} body.tokens .token-layer{{display:block}} .pile{{position:absolute;width:12cqi;height:9cqi}} .center-pile{{left:45cqi;top:46cqi}} .outer-pile{{left:43.5cqi;top:10cqi}} .pile i{{position:absolute;width:4.6cqi;aspect-ratio:1;border-radius:50%;background:radial-gradient(circle at 34% 26%,#f4d5bb 0 9%,#9d6e61 32%,#2e3036 66%,#111319 100%);border:.55cqi solid #b7a99b;box-shadow:0 .8cqi 1.1cqi rgba(0,0,0,.7),inset 0 0 0 .22cqi rgba(255,255,255,.25)}} .pile i:nth-child(1){{left:0;top:2.4cqi}}.pile i:nth-child(2){{left:3.2cqi;top:0}}.pile i:nth-child(3){{left:6.1cqi;top:2.7cqi}}.pile i:nth-child(4){{left:2.1cqi;top:4.7cqi}}.pile i:nth-child(5){{left:6cqi;top:5.2cqi}}
    .candidate-copy{{padding:17px}} h2{{font-size:20px;margin:0 0 7px;color:#d1aa5a;letter-spacing:0}} .candidate-copy>p{{min-height:44px;margin:0;color:var(--muted);line-height:1.45}} .scale-check{{display:grid;grid-template-columns:1fr 120px 76px;gap:10px;align-items:end;margin-top:16px;padding-top:14px;border-top:1px solid rgba(255,255,255,.06)}} figure{{margin:0}} figure img{{display:block;width:100%;aspect-ratio:1;object-fit:cover;border:1px solid rgba(255,255,255,.08);border-radius:4px}} figcaption{{font-size:9px;color:var(--muted);margin-top:5px}} .gates{{display:flex;gap:6px;flex-wrap:wrap;margin-top:13px}} .gates span{{padding:5px 8px;border:1px solid rgba(46,139,107,.28);color:#8db8a7;border-radius:999px;font-size:9px;font-weight:800;letter-spacing:.6px;text-transform:uppercase}} .audit-note{{min-height:0!important;margin-top:11px!important;font-size:11px;opacity:.76}} .qa-fail .audit-note{{color:#df8999}}
    @media(max-width:900px){{main{{grid-template-columns:1fr}}.toolbar{{overflow:auto}}}} @media(max-width:520px){{header,main,.toolbar{{padding-inline:14px}}.scale-check{{grid-template-columns:1fr 92px 64px}}}}
  </style>
</head>
<body>
  <header><div class="eyebrow">POCH 1441 · BOARD STUDY 20</div><h1>Ein Brett. Zwanzig belastbare Richtungen.</h1><p class="lead">Alle Kandidaten starten vom gelockten PM49-Körper und müssen exakt acht Außenmulden plus Mitte bewahren. Die Größenleiste zeigt sofort, welche Details in Akt 2 kollabieren. Der Token-Schalter simuliert für alle dieselbe PM68-Belegung.</p></header>
  <nav class="toolbar"><button class="filter active" data-filter="all">Alle</button><button class="filter" data-filter="pass">Nur Regel-Pass</button><button class="filter" data-filter="intern">Intern</button><button class="filter" data-filter="gemini">Gemini</button><button id="tokens">Tokens zeigen</button><button id="shortlist">Nur Auswahl</button><span class="spacer"></span><span class="count">20 Kandidaten</span></nav>
  <main>{''.join(cards)}</main>
  <script>
    const cards=[...document.querySelectorAll('.candidate')];
    let filter='all', shortlist=false;
    const saved=new Set(JSON.parse(localStorage.getItem('poch-board-shortlist')||'[]'));
    function paint(){{cards.forEach(c=>{{const star=c.querySelector('.star');star.classList.toggle('active',saved.has(c.dataset.id));star.textContent=saved.has(c.dataset.id)?'★':'☆';const sourceOK=filter==='all'||(filter==='pass'?c.dataset.qa==='pass':c.dataset.source===filter);const listOK=!shortlist||saved.has(c.dataset.id);c.classList.toggle('hidden',!(sourceOK&&listOK));}});}}
    document.querySelectorAll('.filter').forEach(b=>b.onclick=()=>{{document.querySelectorAll('.filter').forEach(x=>x.classList.remove('active'));b.classList.add('active');filter=b.dataset.filter;paint();}});
    cards.forEach(c=>c.querySelector('.star').onclick=()=>{{saved.has(c.dataset.id)?saved.delete(c.dataset.id):saved.add(c.dataset.id);localStorage.setItem('poch-board-shortlist',JSON.stringify([...saved]));paint();}});
    document.querySelector('#tokens').onclick=e=>{{document.body.classList.toggle('tokens');e.currentTarget.classList.toggle('active');}};
    document.querySelector('#shortlist').onclick=e=>{{shortlist=!shortlist;e.currentTarget.classList.toggle('active');paint();}};
    paint();
  </script>
</body></html>"""
    HTML.write_text(page, encoding="utf-8")


def main() -> None:
    RENDERED.mkdir(parents=True, exist_ok=True)
    selected = {arg for arg in sys.argv[1:] if re.fullmatch(r"[IG]\d{2}", arg)}
    force = "--force" in sys.argv
    jobs = INTERNAL + gemini_jobs()
    if selected:
        jobs = [job for job in jobs if str(job["id"]) in selected]

    results = []
    lock = threading.Lock()
    with ThreadPoolExecutor(max_workers=4) as executor:
        futures = {executor.submit(render_job, job, force): job for job in jobs}
        for future in as_completed(futures):
            result = future.result()
            with lock:
                results.append(result)
                print(f"[{result['id']}] {result['status']}", flush=True)

    order = {job["id"]: index for index, job in enumerate(INTERNAL + gemini_jobs())}
    results.sort(key=lambda item: order[item["id"]])
    MANIFEST.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    write_html(results)
    failures = [result for result in results if result["status"] == "failed"]
    print(f"HTML: {HTML}")
    if failures:
        raise SystemExit(f"Failed: {', '.join(str(item['id']) for item in failures)}")


if __name__ == "__main__":
    main()
