#!/usr/bin/env python3
"""Prepare a short ice fracture from the credited RPG sample.

Requires numpy, scipy and soundfile. Supply the original soundpack.zip from
https://opengameart.org/sites/default/files/soundpack.zip with --archive.
"""
import argparse
import hashlib
import io
from pathlib import Path
import zipfile

import numpy as np
from scipy.signal import butter, sosfilt
import soundfile as sf

SOURCE_SHA256 = "82d0406e9f7c4a363a14389d50ae96046a2f75cef43d73d51a4811ba6e131d0a"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", required=True, type=Path)
    args = parser.parse_args()
    with zipfile.ZipFile(args.archive) as archive:
        source = archive.read("soundpack/spells/frost.wav")
    if hashlib.sha256(source).hexdigest() != SOURCE_SHA256:
        raise ValueError("Frost source checksum mismatch")
    audio, rate = sf.read(io.BytesIO(source))
    if rate != 44100 or audio.ndim != 1:
        raise ValueError("Expected mono 44.1 kHz frost source")
    audio = sosfilt(butter(2, [1100, 8000], btype="bandpass", fs=rate, output="sos"), audio)
    # Find a distinct crack, rather than retaining a sequence of ice handling.
    window = int(rate * 0.004)
    energy = np.convolve(audio ** 2, np.ones(window) / window, mode="valid")
    start = max(0, int(np.argmax(energy)) - int(rate * 0.002))
    audio = audio[start:start + int(rate * 0.2)].copy()
    audio -= audio.mean()
    audio *= np.exp(-np.arange(len(audio)) / (rate * 0.045))
    attack, release = int(rate * 0.0007), int(rate * 0.025)
    audio[:attack] *= np.linspace(0, 1, attack)
    audio[-release:] *= np.linspace(1, 0, release)
    audio *= min(0.5 / abs(audio).max(), 0.04 / np.sqrt(np.mean(audio ** 2)))
    out = Path(__file__).resolve().parents[1] / "assets/audio/frost-freeze.vorbis"
    sf.write(out, audio, rate, format="OGG", subtype="VORBIS")
    decoded, decoded_rate = sf.read(out)
    if (abs(len(decoded) / decoded_rate - 0.2) > 0.001
            or abs(decoded).max() > 0.55 or np.sqrt(np.mean(decoded ** 2)) > 0.045):
        raise ValueError("Encoded frost exceeds duration or loudness bounds")
    print(f"{out.name}: source start {start/rate:.6f}s, duration {len(decoded)/decoded_rate:.3f}s, "
          f"peak {abs(decoded).max():.3f}, RMS {np.sqrt(np.mean(decoded ** 2)):.3f}")


if __name__ == "__main__":
    main()
