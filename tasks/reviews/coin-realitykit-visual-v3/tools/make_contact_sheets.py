#!/usr/bin/env python3
import pathlib
import sys
from PIL import Image, ImageDraw

root = pathlib.Path(sys.argv[1])
for run_dir in sorted((root / "frames").glob("*/*")):
    frames = sorted(run_dir.glob("frame-*.png"))
    if not frames:
        continue
    selected = frames[::max(1, len(frames) // 8)][:8]
    thumbs = []
    for path in selected:
        image = Image.open(path).convert("RGB")
        image.thumbnail((220, 160))
        thumbs.append((path.name, image.copy()))
    sheet = Image.new("RGB", (220 * 4, 190 * 2), (24, 20, 18))
    draw = ImageDraw.Draw(sheet)
    for index, (name, image) in enumerate(thumbs):
        x = (index % 4) * 220
        y = (index // 4) * 190
        sheet.paste(image, (x, y))
        draw.text((x + 4, y + 164), name, fill=(240, 226, 199))
    sheet.save(run_dir / "contact-sheet.png")
