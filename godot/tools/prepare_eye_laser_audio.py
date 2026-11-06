#!/usr/bin/env python3
"""Edit/layer Kenney CC0 samples for crimson lock, laser and infection cues.

Run with uv --with numpy --with scipy --with soundfile --with imageio-ffmpeg.
Only recorded source samples are used; no oscillator or synthetic substitute.
"""
import hashlib
import json
from pathlib import Path
from urllib.request import urlopen
import subprocess
import numpy as np
import soundfile as sf
from scipy.signal import resample_poly
import imageio_ffmpeg
from math import gcd

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT.parent / "agent-tmp/godot/eye-nebula/audio"
RATE = 48000
FILES = ["laserLarge_001.ogg", "forceField_003.ogg", "computerNoise_002.ogg", "slime_001.ogg"]


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    manifest = ROOT / "assets/audio/eye-laser-credits.json"
    pinned = {e["file"]: e["sha256"] for e in json.loads(manifest.read_text())["sources"]} if manifest.exists() else {}
    records, samples = [], {}
    for name in FILES:
        url = "https://cc0-sounds.netlify.app/sounds/sci-fi-sounds/Audio/" + name
        path = CACHE / name
        if not path.exists():
            path.write_bytes(urlopen(url, timeout=60).read())
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if name in pinned and pinned[name] != digest:
            raise ValueError("Source hash changed: " + name)
        data, rate = sf.read(path, always_2d=True)
        data = data.mean(axis=1)
        factor = gcd(rate, RATE)
        data = resample_poly(data, RATE // factor, rate // factor)
        data -= data.mean()
        samples[name] = data / max(1e-8, np.max(np.abs(data)))
        records.append({"file": name, "url": url, "sha256": digest, "seconds": len(data)/RATE})

    def fit(data, seconds):
        # Bounded offline time/pitch edit of the actual recorded sample.
        return np.interp(np.linspace(0, len(data)-1, round(seconds*RATE)), np.arange(len(data)), data)

    laser = fit(samples[FILES[1]], .90)*.36
    transient = fit(samples[FILES[0]], .38)
    laser[:len(transient)] += transient*.70
    tail = fit(samples[FILES[0]], .56)[::-1]*.14
    laser[-len(tail):] += tail
    cues = {
        "eye-lock": fit(samples[FILES[2]], .22),
        "eye-laser": laser,
        "eye-infect": fit(samples[FILES[3]], .42)*.65 + fit(samples[FILES[1]], .42)*.32,
    }
    outputs = []
    for name, data in cues.items():
        data[:240] *= np.linspace(0, 1, 240)
        data[-1920:] *= np.linspace(1, 0, 1920)
        data *= min(.80/max(1e-8, np.max(np.abs(data))), .21/max(1e-8, np.sqrt(np.mean(data**2))))
        wav = CACHE / (name + ".wav")
        sf.write(wav, data, RATE, subtype="PCM_24")
        dest = ROOT / "assets/audio" / (name + ".vorbis")
        subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-v", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "7", "-f", "ogg", str(dest)], check=True)
        decoded, rate = sf.read(dest)
        assert rate == RATE and np.max(np.abs(decoded)) < .95
        outputs.append({"file": dest.name, "seconds": len(data)/RATE, "sha256": hashlib.sha256(dest.read_bytes()).hexdigest()})
        print(name, outputs[-1]["seconds"])
    manifest.write_text(json.dumps({"author": "Kenney", "license": "CC0-1.0", "licenseUrl": "https://creativecommons.org/publicdomain/zero/1.0/", "collection": "https://kenney.nl/assets/sci-fi-sounds", "mirror": "https://cc0-sounds.netlify.app/collection/sci-fi-sounds", "changes": "48kHz mono, sample-based time/pitch editing, layered laser transient + force-field body, 5ms attack / 40ms release, DC removal, level matching, Vorbis q7.", "sources": records, "outputs": outputs}, indent=2)+"\n")


if __name__ == "__main__":
    main()
