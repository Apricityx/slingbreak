#!/usr/bin/env python3
"""Render native skill effects to a labelled, looping GIF (Godot + Pillow).

python3 godot/tools/preview_effects.py --skills shatter execute rage aftershock
python3 godot/tools/preview_effects.py --skills shatter --theme dark --reduced
"""
import argparse
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = ROOT.parent / "agent-tmp/godot/effect-gifs"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skills", nargs="+", default=["shatter", "execute", "rage", "aftershock"])
    parser.add_argument("--list", action="store_true", help="List registered visual fixtures")
    parser.add_argument("--theme", choices=["light", "dark"], default="light")
    parser.add_argument("--reduced", action="store_true")
    parser.add_argument("--fps", type=int, choices=[10, 20, 25, 50], default=25)
    parser.add_argument("--seconds", type=float, default=2.2, help="Loop duration, including a 0.2s lead-in")
    parser.add_argument("--speed", type=float, default=1, help="Visual playback speed; 0.5 is half speed")
    parser.add_argument("--out", type=Path)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    args = parser.parse_args()
    fixtures = json.loads((ROOT / "tools/effect_previews.json").read_text())
    if args.list:
        for key, item in fixtures.items():
            print(f"{key}: {item['duration']}s ({item['kind']})")
        return
    if not 1 <= len(args.skills) <= 4 or any(key not in fixtures for key in args.skills):
        parser.error("Select 1–4 registered skills; use --list")
    if not math.isfinite(args.speed) or not 0.1 <= args.speed <= 2:
        parser.error("--speed must be between 0.1 and 2")
    tail = max(fixtures[key]["tail"] for key in args.skills)
    if not math.isfinite(args.seconds) or not 0.2 + tail / args.speed + 0.2 <= args.seconds <= 12:
        parser.error(f"--seconds must include the full tail and pause: {0.4 + tail / args.speed:.2f}–12s")
    try:
        from PIL import Image
    except ImportError:
        parser.error("Install Pillow: python3 -m pip install Pillow")
    engine = shutil.which(args.godot)
    if not engine:
        parser.error("Godot executable not found")
    version = subprocess.check_output([engine, "--version"], text=True).strip()
    if not version.startswith("4.7.2.stable."):
        parser.error(f"Expected Godot 4.7.2 stable; got {version}")
    output = (args.out or DEFAULT_OUT / ("-".join(args.skills) + f"-{args.theme}" + ("-reduced" if args.reduced else "") + ".gif")).resolve()
    if output.suffix.lower() != ".gif":
        parser.error("--out must end in .gif")
    output.parent.mkdir(parents=True, exist_ok=True)
    count = math.ceil(args.seconds * args.fps)
    with tempfile.TemporaryDirectory(prefix="effect-frames-", dir=output.parent) as temp:
        config = {"skills": args.skills, "theme": args.theme, "reduced": args.reduced,
                  "fps": args.fps, "frames": count, "speed": args.speed, "out": temp}
        config_path = Path(temp) / "config.json"
        config_path.write_text(json.dumps(config))
        command = [engine, "--path", str(ROOT), "--audio-driver", "Dummy", "--disable-vsync",
                   "--script", "res://tools/preview_effects.gd", "--", str(config_path)]
        if shutil.which("xvfb-run"):
            command = ["xvfb-run", "-a", *command]
        elif not os.environ.get("DISPLAY"):
            parser.error("A real graphics driver is required: install xvfb or set DISPLAY")
        result = subprocess.run(command, capture_output=True, text=True, timeout=180)
        log = result.stdout + result.stderr
        output.with_suffix(".log").write_text(log)
        if result.returncode or re.search(r"^(SCRIPT ERROR:|ERROR:)", log, re.M):
            raise SystemExit(f"Native capture failed; see {output.with_suffix('.log')}\n{log[-3000:]}")
        files = sorted(Path(temp).glob("frame-*.png"))
        if len(files) != count:
            raise SystemExit(f"Missing frames: expected {count}, got {len(files)}")
        frames = []
        for file in files:
            with Image.open(file) as image:
                frames.append(image.convert("RGB"))
        # A common palette prevents colour flicker between independently quantized frames.
        samples = frames[::max(1, count // 12)]
        atlas = Image.new("RGB", (frames[0].width, frames[0].height * len(samples)))
        for i, sample in enumerate(samples):
            atlas.paste(sample, (0, i * sample.height))
        palette = atlas.quantize(colors=256)
        indexed = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
        indexed[0].save(output, save_all=True, append_images=indexed[1:], duration=1000 // args.fps,
                        loop=0, disposal=2, optimize=False)
        with Image.open(output) as gif:
            if not gif.is_animated:
                raise SystemExit("GIF has no animation")
        output.with_suffix(".json").write_text(json.dumps({**config, "out": str(output),
            "engine": version, "fixtures": {key: fixtures[key] for key in args.skills}}, indent=2))
    print(f"{output} ({count} captured frames, {args.fps} fps, speed {args.speed}x)")


if __name__ == "__main__":
    main()
