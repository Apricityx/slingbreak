#!/usr/bin/env python3
"""Build a pinned Godot Web template for the Chromium 89 runtime baseline."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT.parent / "agent-tmp/godot"
GODOT_REVISION = "ed1daf0bf001b61586d9930840f2f1394092c079"
EMSCRIPTEN_VERSION = "4.0.20"
WEBGL_GLOBAL_UNIFORMS = 128
WEBGL_SCENE_LIGHT_STRUCTS = 1
WEBGL_SCENE_DIRECTIONAL_LIGHTS = 1
WEBGL_SCENE_FORWARD_LIGHTS = 1
WEBGL_SCENE_ROUGHNESS_LOD = 0


def scene_limits(text):
    replacements = [
        ('"\\n#define MAX_LIGHT_DATA_STRUCTS " + itos(config->max_renderable_lights) + "\\n";',
         f'"\\n#define MAX_LIGHT_DATA_STRUCTS {WEBGL_SCENE_LIGHT_STRUCTS}\\n";'),
        ('"\\n#define MAX_DIRECTIONAL_LIGHT_DATA_STRUCTS " + itos(MAX_DIRECTIONAL_LIGHTS) + "\\n";',
         f'"\\n#define MAX_DIRECTIONAL_LIGHT_DATA_STRUCTS {WEBGL_SCENE_DIRECTIONAL_LIGHTS}\\n";'),
        ('"\\n#define MAX_FORWARD_LIGHTS " + itos(config->max_lights_per_object) + "u\\n";',
         f'"\\n#define MAX_FORWARD_LIGHTS {WEBGL_SCENE_FORWARD_LIGHTS}u\\n";'),
        ('"\\n#define MAX_ROUGHNESS_LOD " + itos(sky_globals.roughness_layers - 1) + ".0\\n";',
         f'"\\n#define MAX_ROUGHNESS_LOD {WEBGL_SCENE_ROUGHNESS_LOD}.0\\n";'),
    ]
    for old, new in replacements:
        if text.count(old) != 1:
            raise ValueError("Unexpected GLES3 scene shader define: " + old)
        text = text.replace(old, new)
    return text


def verify_template(template):
    with zipfile.ZipFile(template) as archive:
        for name in ["godot.js", "godot.wasm", "godot.html", "godot.audio.worklet.js", "godot.audio.position.worklet.js"]:
            if name not in archive.namelist():
                raise ValueError("Incomplete Web template: " + name)
        wasm = archive.read("godot.wasm")
    if wasm[:8] != b"\0asm\x01\0\0\0":
        raise ValueError("Invalid WebAssembly header")
    offset = 8
    while offset < len(wasm):
        section = wasm[offset]
        offset += 1
        if section == 13:
            raise ValueError("Wasm exception tag section is incompatible with Chromium 89")
        length, shift = 0, 0
        while True:
            if offset >= len(wasm) or shift > 28:
                raise ValueError("Invalid WebAssembly section size")
            byte = wasm[offset]
            offset += 1
            length |= (byte & 127) << shift
            if byte < 128:
                break
            shift += 7
        offset += length
        if offset > len(wasm):
            raise ValueError("Truncated WebAssembly section")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=OUTPUT / "web-template-source")
    parser.add_argument("--emsdk", type=Path, default=OUTPUT / "emsdk")
    parser.add_argument("--jobs", type=int, default=2)
    options = parser.parse_args()
    if options.jobs < 1:
        parser.error("--jobs must be positive")
    source, sdk = options.source.resolve(), options.emsdk.resolve()
    compiler = sdk / "upstream/emscripten/emcc"
    if not compiler.is_file():
        parser.error(f"Install Emscripten {EMSCRIPTEN_VERSION} in {sdk}, or pass --emsdk")
    env = os.environ.copy()
    env["EM_CONFIG"] = str(sdk / ".emscripten")
    env["PATH"] = str(compiler.parent) + os.pathsep + env["PATH"]
    version = subprocess.check_output([str(compiler), "--version"], env=env, text=True).splitlines()[0]
    if f" {EMSCRIPTEN_VERSION} " not in version:
        parser.error(f"Expected Emscripten {EMSCRIPTEN_VERSION}; detected {version}")
    if not source.exists():
        source.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "clone", "--depth", "1", "--branch", "4.7.2-stable",
                        "https://github.com/godotengine/godot.git", str(source)], check=True)
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=source, text=True).strip()
    if revision != GODOT_REVISION:
        parser.error(f"Expected Godot revision {GODOT_REVISION}; detected {revision}")
    # Wasm exception-based longjmp is unavailable on 89. Use Emscripten's JS
    # implementation instead. SIMD is also newer than our runtime baseline.
    detect = source / "platform/web/detect.py"
    original = detect.read_text()
    old = "-sSUPPORT_LONGJMP='wasm'"
    new = "-sSUPPORT_LONGJMP='emscripten'"
    pinned = subprocess.check_output(["git", "show", "HEAD:platform/web/detect.py"], cwd=source, text=True)
    patched = pinned.replace(old, new)
    if pinned.count(old) != 2 or original not in (pinned, patched):
        parser.error("Unexpected or modified Godot longjmp configuration; refusing to overwrite")
    uniform_files = [
        source / "drivers/gles3/rasterizer_canvas_gles3.cpp",
        source / "drivers/gles3/rasterizer_scene_gles3.cpp",
        source / "drivers/gles3/storage/particles_storage.cpp",
        source / "drivers/gles3/storage/texture_storage.cpp",
    ]
    uniform_old = "#define MAX_GLOBAL_SHADER_UNIFORMS 256"
    uniform_new = f"#define MAX_GLOBAL_SHADER_UNIFORMS {WEBGL_GLOBAL_UNIFORMS}"
    uniform_patches = []
    for path in uniform_files:
        tracked = subprocess.check_output(["git", "show", f"HEAD:{path.relative_to(source)}"], cwd=source, text=True)
        current = path.read_text()
        uniform_patch = tracked.replace(uniform_old, uniform_new)
        replacement = scene_limits(uniform_patch) if path.name == "rasterizer_scene_gles3.cpp" else uniform_patch
        if tracked.count(uniform_old) == 0 or current not in (tracked, uniform_patch, replacement):
            parser.error(f"Unexpected or modified GLES3 uniform configuration: {path}")
        uniform_patches.append((path, replacement))
    changes = subprocess.check_output(["git", "diff", "--name-only", "HEAD"], cwd=source, text=True).splitlines()
    allowed = {"platform/web/detect.py", *(str(path.relative_to(source)) for path in uniform_files)}
    if any(name not in allowed for name in changes):
        parser.error("Engine source has unrelated tracked modifications")
    if original != patched:
        detect.write_text(patched)
    for path, replacement in uniform_patches:
        if path.read_text() != replacement:
            path.write_text(replacement)
    scons = shutil.which("scons")
    if not scons:
        parser.error("Install SCons >= 4.4")
    flags = ["platform=web", "target=template_release", "threads=no", "dlink_enabled=no",
             "wasm_simd=no", "disable_3d=yes", "lto=none",
             "ccflags=-sMIN_CHROME_VERSION=89", "linkflags=-sMIN_CHROME_VERSION=89"]
    subprocess.run([scons, f"-j{options.jobs}"] + flags, cwd=source, env=env, check=True)
    built = source / "bin/godot.web.template_release.wasm32.nothreads.zip"
    verify_template(built)
    destination = OUTPUT / "web-template/web_release.zip"
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(built, destination)
    manifest = {"godotRevision": revision, "emscripten": EMSCRIPTEN_VERSION,
                "baseline": 89, "flags": flags, "longjmp": "emscripten",
                "maxGlobalShaderUniforms": WEBGL_GLOBAL_UNIFORMS,
                "sceneLightStructs": WEBGL_SCENE_LIGHT_STRUCTS,
                "sceneDirectionalLights": WEBGL_SCENE_DIRECTIONAL_LIGHTS,
                "sceneForwardLights": WEBGL_SCENE_FORWARD_LIGHTS,
                "sceneRoughnessLod": WEBGL_SCENE_ROUGHNESS_LOD,
                "sha256": hashlib.sha256(destination.read_bytes()).hexdigest()}
    destination.with_suffix(".json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Chromium 89 Web template: {destination}")


if __name__ == "__main__":
    main()
