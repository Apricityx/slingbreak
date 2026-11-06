#!/usr/bin/env python3
"""Prepare CC0 sampled Abyss audio; sources and hashes accompany the outputs."""
import hashlib
import json
from pathlib import Path
from urllib.request import urlopen
from urllib.parse import quote
import numpy as np
import soundfile as sf
import imageio_ffmpeg
import subprocess
from scipy.signal import resample_poly
from math import gcd

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT.parent / "agent-tmp/godot/abyss-audio"
SOURCES = {
    "eye-awaken": ("Horror Sound Pack/SFX/Deep Growl.wav", 3.0, False),
    "eye-charge": ("Horror Sound Pack/SFX/Acceleration Into Cutoff.wav", 4.8, False),
    "eye-cast": ("Horror Strings/OGG/Stabs_Strings_High_1.ogg", 1.2, False),
    "eye-beam": ("Horror Sound Pack/SFX/Eerie Sound.wav", 2.8, False),
    "eye-break": ("kenney_impactsounds/Audio/impactGlass_heavy_000.ogg", 0.8, False),
    "eye-hit": ("kenney_impactsounds/Audio/impactMetal_heavy_000.ogg", 0.32, False),
    "eye-pulse": ("Horror Strings/OGG/Stabs_Strings_Low_1.ogg", 0.8, False),
    "eye-death": ("Horror Sound Pack/SFX/Jumpscare - 04.wav", 3.0, False),
}

def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    manifest = ROOT / "assets/audio/abyss-credits.json"
    pinned = {entry["source"]: entry["sha256"] for entry in json.loads(manifest.read_text())["samples"]} if manifest.exists() else {}
    records = []
    for name, (source, duration, loop) in SOURCES.items():
        url = "https://cc0-sounds.netlify.app/sounds/" + quote(source)
        original = CACHE / (name + Path(source).suffix)
        if not original.exists():
            original.write_bytes(urlopen(url, timeout=90).read())
        digest = hashlib.sha256(original.read_bytes()).hexdigest()
        if url in pinned and digest != pinned[url]:
            raise ValueError(f"Source changed: {source}")
        data, rate = sf.read(original, always_2d=True)
        if rate != 48000:
            factor = gcd(rate, 48000)
            data = resample_poly(data, 48000 // factor, rate // factor)
        if duration:
            data = data[:int(duration * 48000)]
        data -= np.mean(data, axis=0)
        # Preserve stereo music; mono cues retain the runtime's positional pan.
        if not loop:
            data = np.mean(data, axis=1, keepdims=True)
        fade = min(len(data) // 4, int((0.16 if loop else 0.06) * 48000))
        data[:fade] *= np.linspace(0, 1, fade)[:, None]
        data[-fade:] *= np.linspace(1, 0, fade)[:, None]
        peak = float(np.max(np.abs(data)))
        rms = float(np.sqrt(np.mean(data ** 2)))
        data *= min(0.75 / max(peak, 1e-9), (0.16 if loop else 0.12) / max(rms, 1e-9))
        folder = "music" if loop else "audio"
        dest = ROOT / f"assets/{folder}/{name}.vorbis"
        wav = CACHE / (name + "-edited.wav")
        sf.write(wav, data, 48000, subtype="PCM_24")
        subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-v", "error", "-y", "-i", str(wav),
                        "-c:a", "libvorbis", "-q:a", "6", "-f", "ogg", str(dest)], check=True)
        decoded, _ = sf.read(dest)
        assert np.max(np.abs(decoded)) < 0.95
        records.append({"file": f"{folder}/{dest.name}", "source": url,
                        "sha256": digest,
                        "duration": len(data) / 48000, "loop": loop})
        print(name, records[-1]["duration"])
    (ROOT / "assets/audio/abyss-credits.json").write_text(json.dumps({
        "license": "CC0-1.0", "licenseUrl": "https://creativecommons.org/publicdomain/zero/1.0/",
        "collections": ["https://cc0-sounds.netlify.app/collection/Horror%20Sound%20Pack",
                        "https://cc0-sounds.netlify.app/collection/Horror%20Strings",
                        "https://kenney.nl/assets/impact-sounds"],
        "changes": "48 kHz conversion, editing, fades, DC removal and level matching; Vorbis encoding.",
        "samples": records}, indent=2) + "\n")

if __name__ == "__main__":
    main()
