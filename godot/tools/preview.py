#!/usr/bin/env python3
"""Capture one native preview PNG (about 5 s) so visual edits can be checked fast.

Wraps the real game under Xvfb with the GL compatibility renderer:

    python3 godot/tools/preview.py --page shop --theme dark
    python3 godot/tools/preview.py --page boss --seconds 6 --watch

`--watch` re-captures whenever a source, scene or asset file changes, so the PNG
can stay open in any image viewer. The web export is still the authority for
browser behaviour; this loop only shortens the visual feedback cycle.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT.parent / "agent-tmp/godot/preview"
WATCHED = ["src", "scenes", "assets", "project.godot"]
PAGES = ["draft", "game", "shop", "equipment", "achievements", "library", "settings",
         "detail", "swap", "reset", "report", "pause", "boss", "intro", "explosion", "frost"]


def snapshot():
    stamps = {}
    for entry in WATCHED:
        path = ROOT / entry
        if path.is_file():
            stamps[str(path)] = path.stat().st_mtime
            continue
        for file in path.rglob("*"):
            if file.is_file():
                stamps[str(file)] = file.stat().st_mtime
    return stamps


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--page", default="draft", choices=PAGES)
    parser.add_argument("--theme", default="light", choices=["light", "dark"])
    parser.add_argument("--seconds", type=float, default=0.0,
                        help="advance the simulation before capture (boss previews always advance)")
    parser.add_argument("--boss", default="serpent", help="boss id used by --page boss")
    parser.add_argument("--settle", type=float, default=1.5, help="seconds to wait before the shot")
    parser.add_argument("--out", type=Path)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--watch", action="store_true", help="re-capture on file changes until interrupted")
    options = parser.parse_args()

    engine = shutil.which(options.godot)
    if not engine:
        parser.error("Set GODOT_BIN or --godot to Godot 4.7.2")
    output = (options.out or OUTPUT / f"preview-{options.page}.png").resolve()
    command = [engine, "--path", str(ROOT), "--audio-driver", "Dummy", "--disable-vsync",
               "--script", "res://tools/preview_scene.gd", "--",
               "--page", options.page, "--theme", options.theme, "--seconds", str(options.seconds),
               "--boss", options.boss, "--settle", str(options.settle), "--out", str(output)]
    if shutil.which("xvfb-run"):
        command = ["xvfb-run", "-a", *command]
    elif not os.environ.get("DISPLAY"):
        parser.error("No display and no xvfb-run; install xvfb to capture previews")

    def run():
        started = time.time()
        result = subprocess.run(command, capture_output=True, text=True, errors="replace")
        noise = [line for line in (result.stdout + result.stderr).splitlines()
                 if line.startswith(("ERROR", "SCRIPT ERROR", "WARNING"))]
        if result.returncode or not output.is_file():
            print("\n".join(noise[-12:]) or "Preview failed", file=sys.stderr)
            return False
        print(f"{output}  ({time.time() - started:.1f}s)")
        for line in noise[-6:]:
            print("  " + line, file=sys.stderr)
        return True

    ok = run()
    if not options.watch:
        return 0 if ok else 1
    stamps = snapshot()
    print("watching godot/src, scenes, assets, project.godot - save a file to re-capture; Ctrl-C stops")
    try:
        while True:
            time.sleep(0.35)
            current = snapshot()
            if current != stamps:
                stamps = current
                time.sleep(0.15)  # let the editor finish writing
                run()
                stamps = snapshot()
    except KeyboardInterrupt:
        return 0


if __name__ == "__main__":
    sys.exit(main())
