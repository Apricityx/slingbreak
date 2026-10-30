#!/usr/bin/env python3
"""Export a standalone Godot project using only scenes/, src/ and assets/."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from engine_command import run_engine
from build_web_template import (GODOT_REVISION, WEBGL_GLOBAL_UNIFORMS,
                                WEBGL_SCENE_DIRECTIONAL_LIGHTS, WEBGL_SCENE_FORWARD_LIGHTS,
                                WEBGL_SCENE_LIGHT_STRUCTS, WEBGL_SCENE_ROUGHNESS_LOD,
                                verify_template)

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT.parent / "agent-tmp/godot"


def verify_assets():
    strokes = json.loads((ROOT / "assets/strokes/manifest.json").read_text())
    ids = {item["id"] for item in json.loads((ROOT / "assets/skills.json").read_text())}
    if strokes.get("version") != 1 or set(strokes["meshes"]) != ids or strokes["contourSha256"] != hashlib.sha256((ROOT / "assets/signatures.json").read_bytes()).hexdigest():
        raise SystemExit("Baked stroke manifest does not match contours")
    for key, digest in strokes["meshes"].items():
        if hashlib.sha256((ROOT / f"assets/strokes/{key}.res").read_bytes()).hexdigest() != digest:
            raise SystemExit(f"Baked stroke fingerprint mismatch: {key}")
    for category, count in [("audio", 180), ("music", 903)]:
        manifest = json.loads((ROOT / f"assets/{category}/manifest.json").read_text())
        if len(manifest["samples"]) != count or manifest.get("codec") != "vorbis":
            raise SystemExit(f"Unexpected standalone {category} manifest")
        for entry in manifest["samples"]:
            path = ROOT / f"assets/{category}" / entry["file"]
            if path.name != entry["file"]:
                raise SystemExit("Invalid asset filename")
            if hashlib.sha256(path.read_bytes()).hexdigest() != entry["sha256"]:
                raise SystemExit(f"Asset fingerprint mismatch: {path}")
    fonts = json.loads((ROOT / "assets/fonts/manifest.json").read_text())
    for entry in fonts.values():
        if hashlib.sha256((ROOT / "assets/fonts" / entry["rawFile"]).read_bytes()).hexdigest() != entry["sha256"]:
            raise SystemExit("Font fingerprint mismatch")


def stage_project(stage):
    for filename in ["project.godot", "export_presets.cfg"]:
        shutil.copy2(ROOT / filename, stage / filename)
    for directory in ["src", "scenes"]:
        shutil.copytree(ROOT / directory, stage / directory)
    # Fonts are loaded from raw .bin bytes. Keep the source font directory
    # visible to Godot so the JSON manifest and raw files enter the export;
    # the runtime never depends on the alternate imported font copies.
    for path in (ROOT / "assets").rglob("*"):
        if not path.is_file() or path.suffix not in [".json", ".bin", ".vorbis", ".png", ".svg", ".res"] and "LICENSE" not in path.name:
            continue
        target = stage / path.relative_to(ROOT)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
    for path in (stage / "src").rglob("*.gd"):
        text = path.read_text()
        for forbidden in ["res://generated/", "res://runtime/", "res://addons/", "evaluate_json", "SlingRuntime"]:
            if forbidden in text:
                raise SystemExit(f"Legacy runtime dependency in {path.relative_to(stage)}: {forbidden}")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", choices=["android", "linux", "web"])
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--output", type=Path)
    parser.add_argument("--web-template", type=Path, help="Chromium 89 template built by build_web_template.py")
    options = parser.parse_args(argv)
    engine = shutil.which(options.godot)
    if not engine:
        parser.error("Set GODOT_BIN or --godot to Godot 4.7.2")
    version = subprocess.check_output([engine, "--version"], text=True).strip()
    if not version.startswith("4.7.2.stable."):
        parser.error(f"Expected Godot 4.7.2 stable; detected {version}")
    template = None
    if options.platform == "web":
        template = (options.web_template or OUTPUT / "web-template/web_release.zip").resolve()
        metadata = template.with_suffix(".json")
        if not template.is_file() or not metadata.is_file():
            parser.error("Build the Chromium 89 template first: python3 godot/tools/build_web_template.py --emsdk /path/to/emsdk")
        manifest = json.loads(metadata.read_text())
        if (manifest.get("godotRevision") != GODOT_REVISION
                or manifest.get("baseline") != 89 or manifest.get("longjmp") != "emscripten"
                or manifest.get("maxGlobalShaderUniforms") != WEBGL_GLOBAL_UNIFORMS
                or manifest.get("sceneLightStructs") != WEBGL_SCENE_LIGHT_STRUCTS
                or manifest.get("sceneDirectionalLights") != WEBGL_SCENE_DIRECTIONAL_LIGHTS
                or manifest.get("sceneForwardLights") != WEBGL_SCENE_FORWARD_LIGHTS
                or manifest.get("sceneRoughnessLod") != WEBGL_SCENE_ROUGHNESS_LOD
                or manifest.get("sha256") != hashlib.sha256(template.read_bytes()).hexdigest()):
            parser.error("Invalid or mismatched Chromium 89 template metadata")
        verify_template(template)
    verify_assets()
    stages = OUTPUT / "staging"
    stages.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix=f"native-{options.platform}-", dir=stages))
    stage_project(stage)
    if template:
        presets = stage / "export_presets.cfg"
        before, web = presets.read_text().split("[preset.1.options]", 1)
        web = web.replace('custom_template/release=""', "custom_template/release=" + json.dumps(str(template)), 1)
        presets.write_text(before + "[preset.1.options]" + web)
    defaults = {"android": OUTPUT / "export/slingbreak-godot-native-preview.apk",
                "linux": OUTPUT / "export/slingbreak-godot-native-preview.x86_64",
                "web": OUTPUT / "web-native/index.html"}
    output = options.output or defaults[options.platform]
    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    # The staging checkout contains no game/, generated/, native/, or addons/.
    run_engine([engine, "--headless", "--path", str(stage), "--editor", "--import"])
    mode = "--export-debug" if options.platform == "android" else "--export-release"
    preset = {"android": "Android Preview", "linux": "Linux Preview", "web": "Web Preview"}[options.platform]
    run_engine([engine, "--headless", "--path", str(stage), mode, preset, str(output)])
    if options.platform == "android":
        subprocess.run(["python3", str(ROOT / "tools/check-apk.py"), str(output)], check=True)
    elif options.platform == "linux":
        if output.read_bytes()[:4] != b"\x7fELF":
            raise SystemExit(f"Linux export is not an ELF binary: {output}")
        output.chmod(0o755)
        print(f"{output.stat().st_size / 1048576:.0f} MiB, embedded PCK")
    else:
        subprocess.run(["python3", str(ROOT / "tools/check-pck.py"), str(output.with_suffix(".pck"))], check=True)
    print(f"Standalone {options.platform} export: {output}\nStaging project: {stage}")


if __name__ == "__main__":
    main()
