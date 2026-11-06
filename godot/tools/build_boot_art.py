#!/usr/bin/env python3
"""Rebuild the native boot PNG (also consumed before Godot can load scenes)."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SCALE = 3
image = Image.new("RGB", (412 * SCALE, 915 * SCALE), "#d5d9cc")
draw = ImageDraw.Draw(image)


def line(points, fill, width=1):
    draw.line([(round(x * SCALE), round(y * SCALE)) for x, y in points],
              fill=fill, width=round(width * SCALE), joint="curve")


def text(value, y, size, color, font="regular"):
    face = ImageFont.truetype(str(ROOT / f"assets/fonts/{font}.bin"), size * SCALE)
    draw.text((206 * SCALE, y * SCALE), value, font=face, fill=color, anchor="mt")


text("SLING / BREAK", 267, 13, "#65715a")
# The CJK subset intentionally contains no ASCII punctuation; render the dot
# with the Latin face instead of baking a missing-glyph box into the splash.
cjk = ImageFont.truetype(str(ROOT / "assets/fonts/cjk.bin"), 40 * SCALE)
latin = ImageFont.truetype(str(ROOT / "assets/fonts/regular.bin"), 40 * SCALE)
width = draw.textlength("弓引力", font=cjk)
dot_width = draw.textlength(".", font=latin)
left = (image.width - width - dot_width) / 2
draw.text((left, 337*SCALE), "弓引力", font=cjk, fill="#293522", anchor="ls")
draw.text((left+width, 337*SCALE), ".", font=latin, fill="#293522", anchor="ls")
for x in range(100, 314, 18):
    for y in range(385, 617, 18):
        draw.ellipse((x*SCALE, y*SCALE, x*SCALE+2, y*SCALE+2), fill="#b9c2ad")
colors = ["#9bb67d", "#b4c891", "#8da46f"]
for row in range(3):
    for col in range(5):
        x, y = 118 + col * 36, 393 + row * 28
        draw.rounded_rectangle((x*SCALE, y*SCALE, (x+30)*SCALE, (y+21)*SCALE),
                               radius=3*SCALE, fill=colors[(row+col)%3])
        line([(x+5, y+4), (x+25, y+4)], "#cad7b2", 1)
line([(206, 582), (206, 618)], "#4c5b40", 7)
line([(173, 553), (184, 578), (206, 593), (228, 578), (239, 553)], "#4c5b40", 6)
line([(173, 553), (206, 608), (239, 553)], "#819469", 2)
line([(206, 606), (206, 514)], "#34412f", 2)
line([(199, 525), (206, 514), (213, 525)], "#34412f", 2)
line([(200, 598), (206, 605), (212, 598)], "#d27c60", 2)
text("PULL  /  RELEASE  /  BREAK", 698, 9, "#78816d")
target = ROOT / "assets/boot/splash.png"
target.parent.mkdir(parents=True, exist_ok=True)
image.save(target, optimize=True)
print(target)
