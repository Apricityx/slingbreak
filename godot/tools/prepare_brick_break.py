#!/usr/bin/env python3
"""Prepare crisp CC0 brick breaks (requires numpy, scipy and soundfile).

Sources are verified, cached outside the project, and never synthesized.
Example: python3 godot/tools/prepare_brick_break.py --cache /tmp/opencode/brick-audio
"""
import argparse
import hashlib
from pathlib import Path
import urllib.request

import numpy as np
from scipy.signal import butter, sosfilt
import soundfile as sf

SOURCE = "https://cc0-sounds.netlify.app/sounds/kenney_impactsounds/Audio/"
HASHES = {
    "impactMining_000.ogg": "36b4ea107222d073c67ca64dde26944975609202d5090b2f2021213c1a7e35cd",
    "impactMining_001.ogg": "61235a18de3f3d92118235398222dbf51d448f1be70b1c8bc962b10b86f2d9c6",
    "impactMining_002.ogg": "059558ec751115ca6b1441e00f0adc837c1a3eeb0a066b109e0fd879fc5d0b0c",
    "impactGlass_heavy_000.ogg": "b44b39a940e8948e74b9bd3776bff980df43cf220abdaf0d467dc4c43c0244a5",
    "impactGlass_heavy_001.ogg": "58686e0e562612cc566791844a10e269f8d1921f4766c14ba43976fd0a429f4e",
    "impactGlass_heavy_002.ogg": "4978654ac840ad519692d5d5ba48a8101cabce13b9a577be73ad589185e5e9ed",
}


def source(cache, name):
    path = cache / name
    if not path.exists():
        path.write_bytes(urllib.request.urlopen(SOURCE + name, timeout=45).read())
    if hashlib.sha256(path.read_bytes()).hexdigest() != HASHES[name]:
        raise ValueError("Source checksum mismatch: " + name)
    audio, rate = sf.read(path, always_2d=True)
    if rate != 44100:
        raise ValueError("Expected 44.1 kHz source: " + name)
    return audio.mean(axis=1), rate


def transient(audio, rate):
    audio = audio - audio.mean()
    # Align the fracture, not the leading low-level handling/room noise.
    start = max(0, np.flatnonzero(abs(audio) >= abs(audio).max() * 0.12)[0] - int(rate * 0.002))
    result = np.zeros(int(rate * 0.24))
    audio = audio[start:start + len(result)]
    result[:len(audio)] = audio
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", required=True, type=Path)
    args = parser.parse_args()
    args.cache.mkdir(parents=True, exist_ok=True)
    out = Path(__file__).resolve().parents[1] / "assets/audio"
    for index in range(3):
        stone, rate = source(args.cache, f"impactMining_{index:03}.ogg")
        glass, _ = source(args.cache, f"impactGlass_heavy_{index:03}.ogg")
        audio = 0.85 * transient(glass, rate) + 0.15 * transient(stone, rate)
        audio = sosfilt(butter(2, [650, 7200], btype="bandpass", fs=rate, output="sos"), audio)
        audio *= np.exp(-np.arange(len(audio)) / (rate * 0.085))
        attack, release = int(rate * 0.001), int(rate * 0.04)
        audio[:attack] *= np.linspace(0, 1, attack)
        audio[-release:] *= np.linspace(1, 0, release)
        # Match the edited variants without exceeding the original stone attack.
        attack_frames = int(rate * 0.05)
        old_attack_rms = np.sqrt(np.mean(transient(stone, rate)[:attack_frames] ** 2))
        audio *= min(0.65 / abs(audio).max(), 0.055 / np.sqrt(np.mean(audio ** 2)),
                     old_attack_rms / np.sqrt(np.mean(audio[:attack_frames] ** 2)))
        path = out / f"brick-break-{index + 1}.vorbis"
        sf.write(path, audio, rate, format="OGG", subtype="VORBIS")
        decoded, _ = sf.read(path)
        if abs(decoded).max() > 0.7 or np.sqrt(np.mean(decoded ** 2)) > 0.065:
            raise ValueError("Encoded loudness exceeds preparation bounds: " + str(path))
        print(f"{path.name}: {len(decoded)/rate:.3f}s, peak {abs(decoded).max():.3f}, "
              f"RMS {np.sqrt(np.mean(decoded ** 2)):.3f}")


if __name__ == "__main__":
    main()
