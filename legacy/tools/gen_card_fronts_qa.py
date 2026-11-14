#!/usr/bin/env python3
"""Speicherarme QA-Sichtung fuer Kartenvorderseiten.

Laedt die App-Assets nach Dateinamen und baut eine kleine HTML-Tabelle:
Zeilen = Suit, Spalten = Rank. So fallen falsche Zuordnungen sofort auf.
"""
from pathlib import Path
import os

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts" / "sichtung-karten-franzoesisch.html"
CARDS = ROOT / "App" / "Assets.xcassets" / "Cards"

SUITS = [
    ("spades", "Pik", "♠"),
    ("hearts", "Herz", "♥"),
    ("clubs", "Kreuz", "♣"),
    ("diamonds", "Karo", "♦"),
]
RANKS = [
    ("ace", "A"),
    ("king", "K"),
    ("queen", "Q"),
    ("jack", "J"),
    ("ten", "10"),
    ("nine", "9"),
    ("eight", "8"),
    ("seven", "7"),
]


def rel(path: Path) -> str:
    return os.path.relpath(path, OUT.parent)


def main() -> None:
    rows = []
    for suit, suit_name, suit_symbol in SUITS:
        cells = []
        for rank, rank_label in RANKS:
            name = f"card_{suit}_{rank}"
            path = CARDS / f"{name}.imageset" / f"{name}@2x.png"
            if not path.exists():
                cells.append(f"<td class='missing'>{rank_label}{suit_symbol}<br>fehlt</td>")
                continue
            cells.append(
                f"<td><img src='{rel(path)}' alt='{rank_label} {suit_name}'>"
                f"<b>{rank_label} {suit_name}</b><small>{name}</small></td>"
            )
        rows.append("<tr>" + "".join(cells) + "</tr>")

    fan_cards = [
        ("spades", "seven", -28, -34, -18),
        ("diamonds", "queen", -18, -22, -10),
        ("clubs", "king", -8, -10, -4),
        ("spades", "queen", 4, 0, 3),
        ("spades", "jack", 15, -10, 9),
        ("spades", "ace", 26, -28, 15),
    ]
    fan = []
    for suit, rank, rot, x, y in fan_cards:
        name = f"card_{suit}_{rank}"
        path = CARDS / f"{name}.imageset" / f"{name}@2x.png"
        fan.append(
            f"<img class='fan-card' style='--r:{rot}deg;--x:{x}px;--y:{y}px' "
            f"src='{rel(path)}' alt='{name}'>"
        )

    html = f"""<!doctype html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Poch 1441 · Karten-QA</title>
  <style>
    :root {{ color-scheme: dark; --bg:#08070b; --panel:#151219; --text:#e8edf5; --muted:#9aa3af; --gold:#c5a059; }}
    body {{ margin:0; background:var(--bg); color:var(--text); font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif; }}
    header {{ max-width:1280px; margin:0 auto; padding:24px 20px 10px; }}
    h1 {{ margin:0 0 8px; font-size:28px; }}
    p {{ margin:0; color:var(--muted); line-height:1.45; }}
    main {{ max-width:1280px; margin:0 auto; padding:10px 20px 28px; overflow-x:auto; }}
    .stage {{ margin:16px 0 28px; min-height:390px; border:1px solid rgba(197,160,89,.16); border-radius:14px;
      background:radial-gradient(circle at 50% 35%, #1c2226 0, #101116 48%, #08070b 100%); position:relative; overflow:hidden; }}
    .fan {{ position:absolute; left:50%; top:52%; width:460px; height:330px; transform:translate(-50%,-50%); }}
    .fan-card {{ position:absolute; left:165px; top:65px; width:126px; border-radius:14px;
      transform:translate(var(--x), var(--y)) rotate(var(--r)); transform-origin:50% 92%;
      box-shadow:0 18px 34px rgba(0,0,0,.46), 0 3px 8px rgba(0,0,0,.34);
      filter:contrast(1.02); }}
    .fan-card::after {{ content:""; }}
    .caption {{ position:absolute; left:0; right:0; bottom:18px; text-align:center; color:var(--muted); font-size:13px; }}
    h2 {{ margin:22px 0 8px; color:var(--gold); font-size:18px; }}
    table {{ border-collapse:separate; border-spacing:10px; }}
    td {{ width:118px; background:linear-gradient(180deg,#18141e,#100d14); border:1px solid rgba(197,160,89,.18); border-radius:9px; padding:8px; text-align:center; }}
    img {{ display:block; width:100%; border-radius:8px; box-shadow:0 12px 28px rgba(0,0,0,.35); }}
    b {{ display:block; margin-top:7px; color:var(--gold); font-size:13px; }}
    small {{ display:block; margin-top:3px; color:var(--muted); font-size:9px; }}
    .missing {{ color:#ff6b7d; }}
  </style>
</head>
<body>
  <header>
    <h1>Französisches Blatt · QA-Matrix</h1>
    <p>Zeilen sind die technische Suit-Zuordnung, Spalten die internationalen Ränge. Jede Zelle lädt exakt das App-Asset mit demselben Dateinamen.</p>
  </header>
  <main>
    <h2>Mockup-nahe Hand/Fächer</h2>
    <section class="stage">
      <div class="fan">{''.join(fan)}</div>
      <div class="caption">Aktuelle App-Assets mit Padding, weißem Stock und CSS-Schatten/Wölbungsanmutung.</div>
    </section>
    <h2>Pik ♠</h2><table>{rows[0]}</table>
    <h2>Herz ♥</h2><table>{rows[1]}</table>
    <h2>Kreuz ♣</h2><table>{rows[2]}</table>
    <h2>Karo ♦</h2><table>{rows[3]}</table>
  </main>
</body>
</html>
"""
    OUT.write_text(html, encoding="utf-8")
    print(OUT)


if __name__ == "__main__":
    main()
