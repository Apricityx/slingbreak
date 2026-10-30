#!/usr/bin/env python3
"""Create reviewable browser/native UI pairs; measure layout, not pixel identity."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "agent-tmp/godot"
PAGES = ("draft", "shop", "equipment", "library", "detail", "reset")
results = []
for theme in ("light", "dark"):
    for page in PAGES:
        browser = json.loads((BASE / f"ui-reference/{page}-{theme}.json").read_text())[0]
        native = json.loads((BASE / f"ui-native/{page}-{theme}.json").read_text())[0]
        row = {"page": page, "theme": theme, "browser": {k: browser[k] for k in ("x", "y", "w", "h")},
               "native": {k: native[k] for k in ("x", "y", "w", "h")}}
        row["widthError"] = abs(browser["w"] - native["w"])
        row["heightError"] = abs(browser["h"] - native["h"])
        row["withinLayoutGate"] = row["widthError"] <= 1 and row["heightError"] <= 40
        results.append(row)
    sheet = Image.new("RGB", (3 * 824, 2 * 949), "#e2e6dc" if theme == "light" else "#131711")
    draw = ImageDraw.Draw(sheet)
    for index, page in enumerate(PAGES):
        x, y = index % 3 * 824, index // 3 * 949
        for column, folder in enumerate(("ui-reference", "ui-native")):
            image = Image.open(BASE / f"{folder}/{page}-{theme}.png").convert("RGB")
            sheet.paste(image, (x + column * 412, y + 34))
            draw.text((x + column * 412 + 12, y + 10), f"{page} / {'Chromium 89' if column == 0 else 'Godot'}", fill="#22271f" if theme == "light" else "#e6eedc")
    sheet.save(BASE / f"ui-comparison-{theme}.png")
(BASE / "ui-layout-comparison.json").write_text(json.dumps(results, indent=2) + "\n")
failed = [row for row in results if not row["withinLayoutGate"]]
print(f"Independent UI layout samples: {len(results) - len(failed)}/{len(results)} within 1px width / 40px height gate")
print("The gate checks sampled geometry only; it is not a pixel or animation parity claim.")
if failed:
    raise SystemExit(json.dumps(failed, indent=2))
