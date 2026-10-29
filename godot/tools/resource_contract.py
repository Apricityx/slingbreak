"""Standalone resource checks shared by APK and PCK exports."""
import hashlib
import json


def check_resources(names, read):
    for name in names:
        if name.startswith(("tests/", "tools/", "runtime/", "native/", "build/", "generated/", "addons/")) or name.endswith((".js", ".gdextension", ".pcm")):
            raise SystemExit("Obsolete or development resource in export: " + name)
    for name in ["assets/ui/manifest.json", "assets/skills.json", "assets/signatures.json", "assets/fonts/manifest.json",
                  "src/ui/card_glint.gdshader", "src/render/core_glow.gdshader", "src/render/signature_stroke.gdshader",
                  "assets/strokes/manifest.json"]:
        if name not in names:
            raise SystemExit("Missing native resource: " + name)
    skills = json.loads(read("assets/skills.json"))
    ids = {item["id"] for item in skills}
    if len(skills) != 81 or len(ids) != 81:
        raise SystemExit("Standalone catalog is incomplete")
    contours = json.loads(read("assets/signatures.json"))["shapes"]
    if ids != set(contours) or any(len(frames) != 24 for frames in contours.values()):
        raise SystemExit("Standalone signature contours are incomplete")
    strokes = json.loads(read("assets/strokes/manifest.json"))
    if (strokes.get("version") != 1 or set(strokes["meshes"]) != ids
            or strokes["contourSha256"] != hashlib.sha256(read("assets/signatures.json")).hexdigest()):
        raise SystemExit("Baked stroke manifest does not match contours")
    for key, digest in strokes["meshes"].items():
        name = f"assets/strokes/{key}.res"
        if name not in names or hashlib.sha256(read(name)).hexdigest() != digest:
            raise SystemExit("Baked stroke fingerprint mismatch: " + key)
    fonts = json.loads(read("assets/fonts/manifest.json"))
    if len(fonts) != 3:
        raise SystemExit("Incomplete font catalog")
    for entry in fonts.values():
        if hashlib.sha256(read("assets/fonts/" + entry["rawFile"])).hexdigest() != entry["sha256"]:
            raise SystemExit("Font checksum mismatch")
    if not any("LICENSE" in name and name.startswith("assets/fonts/") for name in names):
        raise SystemExit("Font licenses were excluded from export")
    music_keys = set()
    for category, count in [("audio", 180), ("music", 903)]:
        prefix = "assets/" + category + "/"
        manifest = json.loads(read(prefix + "manifest.json"))
        if (manifest["sampleRate"] != 48000 or len(manifest["samples"]) != count
                or manifest.get("version") != 2 or manifest.get("codec") != "vorbis" or manifest.get("channels") != 1):
            raise SystemExit("Unexpected Vorbis manifest: " + category)
        for entry in manifest["samples"]:
            raw = read(prefix + entry["file"])
            if len(raw) != entry["bytes"] or not raw.startswith(b"OggS") or hashlib.sha256(raw).hexdigest() != entry["sha256"]:
                raise SystemExit("Invalid Vorbis asset: " + entry["file"])
            if category == "music":
                music_keys.add(entry["key"])
    scores = json.loads(read("assets/music/scores.json"))
    for score in scores.values():
        for phase in score["phases"]:
            for mood, pattern in phase.items():
                sequences = pattern.values() if mood == "transitions" else pattern["voices"]
                for voices in sequences:
                    if any(voice["key"] not in music_keys for voice in voices):
                        raise SystemExit("Missing music/transition instrument")
    print("Native resource contract: 81 skills/signatures/baked strokes, fonts/licenses, 180 effects, 903 music samples and transition voices; no legacy runtime")
