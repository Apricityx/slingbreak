#!/usr/bin/env python3
"""Prepare layered CC0 normal-brick shatters (requires numpy, scipy and soundfile).

Each variant is pre-mixed offline from three verified Kenney sources, so the
runtime still plays exactly one voice per break:
  body  - heavy punch, low-passed: the weight under the hit
  crack - heavy glass, high-passed: the bright fracture
  grit  - mining rubble, band-passed and slightly late: the crumble tail
Sources are cached outside the project and never synthesized.
Example: python3 godot/tools/prepare_brick_shatter.py --cache /tmp/opencode/brick-audio
"""
import argparse
import hashlib
from pathlib import Path
import urllib.request

import numpy as np
from scipy.signal import butter, sosfilt
import soundfile as sf

SOURCE = "https://cc0-sounds.netlify.app/sounds/kenney_impactsounds/Audio/"
VARIANTS = 4
LENGTH = 0.26
HASHES = {
    "impactPunch_heavy_000.ogg": "b33a8f14068aec24ec69ba85e5e87fdc41228975f6a1a3e44a6e7d6fc3d9f8d8",
    "impactPunch_heavy_001.ogg": "f92f5cb6ba4ff2766497292ffd90865654317eeca976f5652e0708dbdcdc0dd9",
    "impactPunch_heavy_002.ogg": "7993dd4c156b9979ad69f17be5ebe31850b16039a3857f8477141be54dfee1b3",
    "impactPunch_heavy_003.ogg": "4ab53b26f4ea575120dcc1348526c9e0db2afc6af7a442aa0489bdead2ca80b6",
    "impactGlass_heavy_000.ogg": "b44b39a940e8948e74b9bd3776bff980df43cf220abdaf0d467dc4c43c0244a5",
    "impactGlass_heavy_001.ogg": "58686e0e562612cc566791844a10e269f8d1921f4766c14ba43976fd0a429f4e",
    "impactGlass_heavy_002.ogg": "4978654ac840ad519692d5d5ba48a8101cabce13b9a577be73ad589185e5e9ed",
    "impactGlass_heavy_003.ogg": "aed07b154f24410c17e5262bbef832842fb275d41fe297f721af7501d0e9c23a",
    "impactMining_001.ogg": "61235a18de3f3d92118235398222dbf51d448f1be70b1c8bc962b10b86f2d9c6",
    "impactMining_002.ogg": "059558ec751115ca6b1441e00f0adc837c1a3eeb0a066b109e0fd879fc5d0b0c",
    "impactMining_003.ogg": "4237fa2cd80364ad81cd0af44f67d7497f1c5edcc7bdb02cd22be2ba4580c83d",
    "impactMining_004.ogg": "8ca3a99d85d845751ad8ce7b40509da58263a62e48cde70e5a30b5ccef4c9a3b",
}


def source(cache, name):
    path = cache / name
    if not path.exists():
        path.write_bytes(urllib.request.urlopen(SOURCE + name, timeout=45).read())
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != HASHES.get(name):
        raise ValueError("Source checksum mismatch: " + name)
    audio, rate = sf.read(path, always_2d=True)
    if rate != 44100:
        raise ValueError("Expected 44.1 kHz source: " + name)
    return audio.mean(axis=1), rate, digest


def transient(audio, rate, delay=0.0):
    audio = audio - audio.mean()
    # Align the first real transient, not leading handling/room noise.
    start = max(0, np.flatnonzero(abs(audio) >= abs(audio).max() * 0.12)[0] - int(rate * 0.001))
    result = np.zeros(int(rate * LENGTH))
    offset = int(rate * delay)
    audio = audio[start:start + len(result) - offset]
    result[offset:offset + len(audio)] = audio
    return result


def shaped(audio, rate, band, btype, decay, delay=0.0):
    audio = sosfilt(butter(2, band, btype=btype, fs=rate, output="sos"), audio)
    t = np.arange(len(audio)) / rate
    return audio * np.exp(-np.maximum(t - delay, 0) / decay)


def level(audio, rms):
    # Mix layers by energy, not peak: a punch peak hides far more low energy.
    return audio * rms / max(np.sqrt(np.mean(audio ** 2)), 1e-9)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", required=True, type=Path)
    args = parser.parse_args()
    args.cache.mkdir(parents=True, exist_ok=True)
    out = Path(__file__).resolve().parents[1] / "assets/audio"
    for index in range(VARIANTS):
        body, rate, _ = source(args.cache, f"impactPunch_heavy_{index:03}.ogg")
        crack, _, _ = source(args.cache, f"impactGlass_heavy_{index:03}.ogg")
        grit, _, _ = source(args.cache, f"impactMining_{(index + 1) % 5:03}.ogg")
        # Body stays above 90 Hz: phone speakers drop sub-bass and it only
        # eats compressor headroom in chains. The crack carries the read.
        body = level(shaped(transient(body, rate), rate, [90, 750], "bandpass", 0.05), 0.5)
        crack = level(shaped(transient(crack, rate), rate, 1400, "highpass", 0.05), 1.0)
        grit = level(shaped(transient(grit, rate, 0.012), rate, [900, 6000], "bandpass", 0.07, 0.012), 0.35)
        audio = body + crack + grit
        attack, release = int(rate * 0.0008), int(rate * 0.05)
        audio[:attack] *= np.linspace(0, 1, attack)
        audio[-release:] *= np.linspace(1, 0, release)
        # Dense chains overlap many of these: keep a fixed loudness budget.
        audio *= min(0.7 / abs(audio).max(), 0.075 / np.sqrt(np.mean(audio ** 2)))
        path = out / f"brick-shatter-{index + 1}.vorbis"
        sf.write(path, audio, rate, format="OGG", subtype="VORBIS")
        decoded, _ = sf.read(path)
        if abs(decoded).max() > 0.75 or np.sqrt(np.mean(decoded ** 2)) > 0.085:
            raise ValueError("Encoded loudness exceeds preparation bounds: " + str(path))
        print(f"{path.name}: {len(decoded)/rate:.3f}s, peak {abs(decoded).max():.3f}, "
              f"RMS {np.sqrt(np.mean(decoded ** 2)):.3f}")


if __name__ == "__main__":
    main()
