#!/usr/bin/env python3
"""Prepare the CC0 sampled 熔炉巨像 score; sources and hashes accompany the outputs."""
import hashlib
import json
import shutil
import subprocess
import zipfile
from math import gcd
from pathlib import Path
from urllib.parse import quote
from urllib.request import urlopen
import numpy as np
import soundfile as sf
import imageio_ffmpeg
from scipy.ndimage import maximum_filter1d, uniform_filter1d
from scipy.signal import butter, resample_poly, sosfiltfilt

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT.parent / "agent-tmp/godot/forge-audio"
FILES = "https://opengameart.org/sites/default/files/"
RATE = 48000
METAL = "boss_battle_#2_metal_pack.zip"
LOOPS = "sfx_loops.zip"
PAGES = {
    METAL: ("https://opengameart.org/content/boss-battle-2-symphonic-metal", "nene"),
    LOOPS: ("https://opengameart.org/content/30-cc0-sfx-loops", "rubberduck"),
    "Heavy Concept A Bass Master.wav": ("https://opengameart.org/content/dramatic-boss-encounter", "cynicmusic"),
    "Sinister Boss Appears.wav": ("https://opengameart.org/content/sinister-boss-appears", "cynicmusic"),
}
# name: (file, archive member, cut seconds, tail seconds). The cut lands one
# beat-grid step before the head's first downbeat, so the next pass enters in
# time; the recording's decay past the cut is overlap-added onto the head.
# The ZIP's names are swapped (see its page): "opening" is the seamless loop.
MUSIC = {
    "forge-smoulder": ("Sinister Boss Appears.wav", None, 40.32, 4.0),
    "forge-stoke": ("Heavy Concept A Bass Master.wav", None, 30.01, 6.0),
    "forge-inferno": (METAL, "boss_battle_#2_metal_opening.wav", 0, 0),
}
# Furnace bed layers: (member, gain, low-pass Hz or 0). Drone, roar, bubbling.
BED = [("ambient_01.ogg", 1.0, 0), ("noise_01.ogg", 0.9, 1100), ("water_boiling.ogg", 1.6, 0)]
BED_SECONDS = 24.0


def fetch(file):
    original = CACHE / file
    if not original.exists():
        partial = original.with_suffix(original.suffix + ".part")
        with urlopen(FILES + quote(file), timeout=600) as response, partial.open("wb") as out:
            shutil.copyfileobj(response, out)
        partial.rename(original)
    return original


def decode(data_bytes, suffix):
    """Decode through ffmpeg at the source rate, then resample to 48 kHz."""
    path = CACHE / ("decode-input" + suffix)
    path.write_bytes(data_bytes)
    rate = sf.info(path).samplerate
    raw = subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-v", "error", "-i", str(path), "-ac", "2", "-ar", str(rate),
                          "-f", "f32le", "-"], capture_output=True, check=True).stdout
    path.unlink()
    data = np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).astype(np.float64)
    if rate != RATE:
        factor = gcd(rate, RATE)
        data = resample_poly(data, RATE // factor, rate // factor)
    return data - np.mean(data, axis=0)


def source(file, member):
    original = fetch(file)
    if member is None:
        return original.read_bytes(), Path(file).suffix
    with zipfile.ZipFile(original) as archive:
        return archive.read(member), Path(member).suffix


def cut(data, at, tail):
    """Loop at `at`; the following `tail` seconds fade out over the head."""
    end, fold = int(at * RATE), int(tail * RATE)
    body, rest = data[:end].copy(), data[end:end + fold]
    fade = np.cos(np.linspace(0, np.pi / 2, len(rest)))[:, None] ** 2
    body[:len(rest)] += rest * fade
    return body


def tile(data, seconds, overlap=0.25):
    """Repeat a short loop to `seconds`, cross-fading every joint, wrap included."""
    total, xf = int(seconds * RATE), int(overlap * RATE)
    step = len(data) - xf
    ramp = np.linspace(0, np.pi / 2, xf)[:, None]
    out = np.zeros((total + xf, 2))
    position = 0
    while position < total:
        piece = data.copy()
        piece[:xf] *= np.sin(ramp)
        piece[-xf:] *= np.cos(ramp)
        span = min(len(piece), len(out) - position)
        out[position:position + span] += piece[:span]
        position += step
    # Fold the overhang onto the head so the bed itself loops without a seam.
    out[:xf] = out[:xf] * np.sin(ramp) + out[total:total + xf] * np.cos(ramp)
    return out[:total]


def limit(data, threshold=0.84):
    """Look-ahead peak limiter: 3 ms attack window, 60 ms smoothed release."""
    envelope = maximum_filter1d(np.max(np.abs(data), axis=1), int(0.006 * RATE))
    gain = np.minimum(1.0, threshold / np.maximum(envelope, 1e-9))
    gain = -maximum_filter1d(-gain, int(0.06 * RATE))
    gain = uniform_filter1d(gain, int(0.012 * RATE))
    return data * np.minimum(gain, threshold / np.maximum(envelope, 1e-9))[:, None]


def level(data, rms_target):
    rms = float(np.sqrt(np.mean(data ** 2)))
    return limit(data * rms_target / max(rms, 1e-9))


def encode(name, data):
    dest = ROOT / f"assets/music/{name}.vorbis"
    wav = CACHE / (name + "-edited.wav")
    sf.write(wav, data, RATE, subtype="PCM_24")
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-v", "error", "-y", "-i", str(wav),
                    "-c:a", "libvorbis", "-q:a", "6", "-f", "ogg", str(dest)], check=True)
    decoded, _ = sf.read(dest)
    assert np.max(np.abs(decoded)) < 0.95, name
    print(name, round(len(data) / RATE, 3), "rms", round(float(np.sqrt(np.mean(data ** 2))), 3),
          "peak", round(float(np.max(np.abs(data))), 3))
    return dest


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    manifest = ROOT / "assets/audio/forge-credits.json"
    previous = json.loads(manifest.read_text())["samples"] if manifest.exists() else []
    pinned = {entry["source"]: entry["sha256"] for entry in previous}
    digests = {}
    for file in PAGES:
        digest = hashlib.sha256(fetch(file).read_bytes()).hexdigest()
        if pinned.get(FILES + quote(file), digest) != digest:
            raise ValueError(f"Source changed: {file}")
        digests[file] = digest
    records = []

    def record(name, data, file, members):
        dest = encode(name, data)
        page, author = PAGES[file]
        records.append({"file": f"music/{dest.name}", "source": FILES + quote(file), "page": page, "author": author,
                        "members": members, "sha256": digests[file], "duration": len(data) / RATE, "loop": True})

    for name, (file, member, at, tail) in MUSIC.items():
        data = decode(*source(file, member))
        if at:
            data = cut(data, at, tail)
        # Seamless sources keep their edges; level is matched and peaks limited.
        record(name, level(data, 0.16), file, [member or file])
    bed = np.zeros((int(BED_SECONDS * RATE), 2))
    for member, gain, lowpass in BED:
        layer = decode(*source(LOOPS, member))
        if lowpass:
            layer = sosfiltfilt(butter(2, lowpass, fs=RATE, output="sos"), layer, axis=0)
        layer = tile(layer, BED_SECONDS)
        bed += gain * layer * 0.1 / float(np.sqrt(np.mean(layer ** 2)))
    # The roar breathes twice per loop like a bellows; whole cycles keep the seam.
    breath = 0.8 + 0.2 * np.sin(np.linspace(0, 4 * np.pi, len(bed), endpoint=False))
    record("forge-furnace", level(bed * breath[:, None], 0.12), LOOPS, [member for member, _, _ in BED])
    manifest.write_text(json.dumps({
        "license": "CC0-1.0", "licenseUrl": "https://creativecommons.org/publicdomain/zero/1.0/",
        "collections": [page for page, _ in PAGES.values()],
        "changes": "48 kHz conversion, DC removal, beat-aligned loop cut with overlap-added decay tail, "
                   "furnace bed layered from tiled SFX loops, level matching and peak limiting; Vorbis encoding.",
        "samples": records}, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
