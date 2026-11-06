#!/usr/bin/env python3
"""Export the standalone Godot PCK that the native preview runtimes load."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import tempfile
from engine_command import run_engine
from export_native import OUTPUT, ROOT, stage_project, verify_assets


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--output", type=Path)
    parser.add_argument("--platform", choices=["android", "linux"], default="android",
                        help="Export platform preset (launcher packs use Android Preview)")
    options = parser.parse_args(argv)
    engine = shutil.which(options.godot)
    if not engine:
        parser.error("Set GODOT_BIN or --godot to Godot 4.7.2")
    version = subprocess.check_output([engine, "--version"], text=True).strip()
    if not version.startswith("4.7.2.stable."):
        parser.error(f"Expected Godot 4.7.2 stable; detected {version}")
    verify_assets()
    stages = OUTPUT / "staging"
    stages.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix="native-pack-", dir=stages))
    stage_project(stage)
    output = (options.output or OUTPUT / "export/slingbreak-godot-native-preview.pck").resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    # The staging checkout contains no game/, generated/, native/, or addons/.
    run_engine([engine, "--headless", "--path", str(stage), "--editor", "--import"])
    preset = "Android Preview" if options.platform == "android" else "Linux Preview"
    run_engine([engine, "--headless", "--path", str(stage), "--export-pack", preset, str(output)])
    subprocess.run(["python3", str(ROOT / "tools/check-pck.py"), str(output)], check=True)
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix(".pck.sha256").write_text(f"{digest}  {output.name}\n")
    project_version = re.search(r'^config/version="([^"]+)"$', (stage / "project.godot").read_text(), re.M)
    output.with_suffix(".pck.json").write_text(json.dumps({
        "version": project_version.group(1) if project_version else "unversioned",
        "godot": version, "platform": options.platform,
        "bytes": output.stat().st_size, "sha256": digest, "stage": str(stage),
    }, indent=2) + "\n")
    print(f"{output.stat().st_size / 1048576:.0f} MiB")
    print(f"Standalone PCK export: {output}\nStaging project: {stage}")


if __name__ == "__main__":
    main()
