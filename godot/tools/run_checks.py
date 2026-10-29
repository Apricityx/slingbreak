#!/usr/bin/env python3
"""Run native checks and fail on Godot script errors, including exit-code-zero errors."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--gui", action="store_true", help="Use a real graphics driver; xvfb-run is supported")
    parser.add_argument("--test", action="append", help="Run only this test basename, repeatable")
    args = parser.parse_args()
    engine = shutil.which(args.godot)
    if not engine:
        parser.error("Set GODOT_BIN or --godot")
    tests = args.test or (["native_render_test", "native_stroke_test", "native_retained_test", "interface_input_test", "native_motion_test", "native_hud_test", "interface_capture", "transition_test"]
                          if args.gui else ["native_test", "native_spike_test", "native_prediction_test", "native_audio_test", "ui_test", "transition_test", "native_soak_test"])
    out = ROOT.parent / "agent-tmp/godot/checks"
    out.mkdir(parents=True, exist_ok=True)
    failures = []
    for test in tests:
        if not re.fullmatch(r"[a-z_]+", test) or not (ROOT / f"tests/{test}.gd").is_file():
            parser.error("Unknown test: " + test)
        command = [engine, "--path", str(ROOT), "--audio-driver", "Dummy", "--script", f"res://tests/{test}.gd"]
        if not args.gui:
            command.insert(1, "--headless")
        elif not os.environ.get("DISPLAY"):
            command = ["xvfb-run", "-a"] + command
        try:
            result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=300)
        except subprocess.TimeoutExpired as timeout:
            output = timeout.stdout or b""
            if isinstance(output, bytes):
                output = output.decode("utf-8", errors="replace")
            output += "\nERROR: Native test timed out after 300 seconds\n"
            result = subprocess.CompletedProcess(command, 1, output)
        (out / f"{test}.log").write_text(result.stdout)
        errors = re.findall(r"^(?:SCRIPT ERROR:|ERROR:|WARNING:.*(?:leaked|resources still)).*$", result.stdout, re.M)
        bad = result.returncode != 0 or errors
        print(f"{'FAIL' if bad else 'PASS'} {test}", flush=True)
        for line in result.stdout.splitlines():
            if "checks" in line or "Native " in line or "fixture frames" in line:
                print("  " + line, flush=True)
        if bad:
            failures.append(test)
            print("\n".join(errors[:8]) or result.stdout[-2000:], flush=True)
    print(f"Native gate: {len(tests)-len(failures)}/{len(tests)}; logs: {out}")
    raise SystemExit(1 if failures else 0)


if __name__ == "__main__":
    main()
