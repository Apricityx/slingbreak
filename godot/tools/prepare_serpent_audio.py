#!/usr/bin/env python3
"""Prepare the CC0 sampled 星渊巨蟒 score; sources and hashes accompany the outputs."""
import hashlib
import json
import shutil
import subprocess
from math import gcd
from pathlib import Path
from urllib.parse import quote
from urllib.request import urlopen
import numpy as np
import soundfile as sf
import imageio_ffmpeg
from scipy.signal import resample_poly

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT.parent / "agent-tmp/godot/serpent-audio"
FILES = "https://opengameart.org/sites/default/files/"
RATE = 48000
# name: (file, page, author, keep seconds, folded tail seconds). A folded tail
# is cross-faded over the head so a fading recording loops without a gap.
SOURCES = {
    "serpent-stalk": ("Ancient Power Of Serpents.mp3", "https://opengameart.org/content/ancient-power-of-serpents",
                      "josepharaoh99", 102.25, 4.25),
    "serpent-hunt": ("determined_pursuit_loop.wav", "https://opengameart.org/content/determined-pursuit-epic-orchestra-loop",
                     "Emma_MA", 0, 0),
    "serpent-frenzy": ("Juhani Junkala - Epic Boss Battle [Seamlessly Looping].wav", "https://opengameart.org/content/boss-battle-music",
                       "Juhani Junkala (SubspaceAudio)", 0, 0),
}


def fetch(file):
    original = CACHE / file
    if not original.exists():
        partial = original.with_suffix(original.suffix + ".part")
        with urlopen(FILES + quote(file), timeout=120) as response, partial.open("wb") as out:
            shutil.copyfileobj(response, out)
        partial.rename(original)
    return original


def decode(path):
    """Decode through ffmpeg so MP3 and float WAV sources share one path."""
    info = sf.info(path) if path.suffix == ".wav" else None
    rate = info.samplerate if info else 44100
    raw = subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-v", "error", "-i", str(path), "-ac", "2", "-ar", str(rate),
                          "-f", "f32le", "-"], capture_output=True, check=True).stdout
    data = np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).astype(np.float64)
    if rate != RATE:
        factor = gcd(rate, RATE)
        data = resample_poly(data, RATE // factor, rate // factor)
    return data


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    manifest = ROOT / "assets/audio/serpent-credits.json"
    pinned = {entry["source"]: entry["sha256"] for entry in json.loads(manifest.read_text())["samples"]} if manifest.exists() else {}
    records = []
    for name, (file, page, author, keep, tail) in SOURCES.items():
        url = FILES + quote(file)
        original = fetch(file)
        digest = hashlib.sha256(original.read_bytes()).hexdigest()
        if url in pinned and digest != pinned[url]:
            raise ValueError(f"Source changed: {file}")
        data = decode(original)
        data -= np.mean(data, axis=0)
        if keep:
            end, fold = int(keep * RATE), int(tail * RATE)
            body, rest = data[:end].copy(), data[end:end + fold]
            # Equal-power fold: the recording's decay continues under the head.
            ramp = np.linspace(0, np.pi / 2, len(rest))[:, None]
            body[:len(rest)] = body[:len(rest)] * np.sin(ramp) + rest * np.cos(ramp)
            data = body
        # Seamless sources keep their edges; only level is matched.
        peak = float(np.max(np.abs(data)))
        rms = float(np.sqrt(np.mean(data ** 2)))
        data *= min(0.8 / max(peak, 1e-9), 0.16 / max(rms, 1e-9))
        dest = ROOT / f"assets/music/{name}.vorbis"
        wav = CACHE / (name + "-edited.wav")
        sf.write(wav, data, RATE, subtype="PCM_24")
        subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-v", "error", "-y", "-i", str(wav),
                        "-c:a", "libvorbis", "-q:a", "6", "-f", "ogg", str(dest)], check=True)
        decoded, _ = sf.read(dest)
        assert np.max(np.abs(decoded)) < 0.95
        records.append({"file": f"music/{dest.name}", "source": url, "page": page, "author": author,
                        "sha256": digest, "duration": len(data) / RATE, "loop": True})
        print(name, round(records[-1]["duration"], 3), "rms", round(float(np.sqrt(np.mean(data ** 2))), 3),
              "peak", round(float(np.max(np.abs(data))), 3))
    manifest.write_text(json.dumps({
        "license": "CC0-1.0", "licenseUrl": "https://creativecommons.org/publicdomain/zero/1.0/",
        "collections": ["https://opengameart.org/content/cc0-cinematic-music"],
        "changes": "48 kHz conversion, DC removal, loop editing (folded fade tail), level matching; Vorbis encoding.",
        "samples": records}, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
