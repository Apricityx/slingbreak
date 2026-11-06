#!/usr/bin/env python3
"""Prepare layered CC0 bomb-brick explosions (requires numpy, scipy and soundfile).

Each variant is pre-mixed offline from verified CC0 recordings, so the runtime
still plays exactly one voice per bomb:
  body   - Warfork rocket / Kenney low-frequency blast: the thump and roar
  crunch - Kenney explosion crunch, band-passed: the mid-range bite
  crack  - rock breaking / Warfork gibs, high-passed: the bright detonation
  debris - rock falling, delayed: rubble raining down after the blast
Sources are cached outside the project and never synthesized.
Example: python3 godot/tools/prepare_brick_bomb.py --cache /tmp/opencode/bomb-audio
"""
import argparse
import hashlib
from pathlib import Path
import urllib.parse
import urllib.request

import numpy as np
from scipy.signal import butter, resample_poly, sosfilt
import soundfile as sf

SOURCE = "https://cc0-sounds.netlify.app/sounds/"
RATE = 44100
LENGTH = 1.15
HASHES = {
    "warfork-cc0/sounds/weapons/rocket_strong_explosion.ogg": "3e993793ea882bb7ba023d7f3221146c9abcf12d09d3298b75d84cf5d9038cf4",
    "warfork-cc0/sounds/misc/gibs_explosion.wav": "a678f7b35f1372b77f028464a195aad8715979b72291e01bd03442157af02542",
    "sci-fi-sounds/Audio/lowFrequency_explosion_000.ogg": "3cb48d86dab63140cfb9aaeea4d4a6846abaca5831d157d8adbec0490da26343",
    "sci-fi-sounds/Audio/lowFrequency_explosion_001.ogg": "cdda50600a4928f2f1b8371224d53c171ac799c1cf2c30b11999508985250b3b",
    "sci-fi-sounds/Audio/explosionCrunch_000.ogg": "4b597d658d0ae101f0a030fbeea5fc3a4292ab85f017470a8254a8e7959cbd69",
    "sci-fi-sounds/Audio/explosionCrunch_001.ogg": "fdd04d6f0032d4d57c134ad37f3587d2d00e58c9572715275bd8cf4f43593576",
    "sci-fi-sounds/Audio/explosionCrunch_002.ogg": "be2b8ddc62e4a24c91e2e77793de98549ce216faf2f323a917e7d6f34321ff97",
    "sci-fi-sounds/Audio/explosionCrunch_003.ogg": "8c7197bb3a1c504690319c3abe0e62a5423ee246dd70caab57963d0b7aa8144f",
    "sci-fi-sounds/Audio/explosionCrunch_004.ogg": "9c3a1c73cadf0de5d5a578b31a264f20b1ac7cb6ec9bbd34a203f58402ea5390",
    "75-cc0-breaking-falling-hit-sfx/bfh1_rock_breaking_01.ogg": "970cac3139e1530009ca87f8ee0dd800dc4da61917a5e62bdc83d475a9bf4da7",
    "75-cc0-breaking-falling-hit-sfx/bfh1_rock_breaking_02.ogg": "3e06b794511f693b6aaca5eee1d47491bab74d814746a68de6c8bf4eec744ccc",
    "75-cc0-breaking-falling-hit-sfx/bfh1_rock_breaking_03.ogg": "a4f7a3ccebff4e8211b6aa146b8ff708bdea1c4e41115ab3b8a0d0c33094d6ee",
    "75-cc0-breaking-falling-hit-sfx/bfh1_rock_falling_01.ogg": "9e58d2d3302c1bad27267cef6a2b3b47bb636f49f77d8e4b986ac81a26e80d7b",
    "75-cc0-breaking-falling-hit-sfx/bfh1_rock_falling_02.ogg": "c8421825c5e08e4bf4ed290232963aeffcf4e179c28d33a6714c5fb9704f799f",
    "75-cc0-breaking-falling-hit-sfx/bfh1_rock_falling_03.ogg": "16080f9bc90924b0e4ede52922529e30e34e72af32a505b39bdfc5ebcbb9248c",
    "75-cc0-breaking-falling-hit-sfx/bfh1_rock_falling_04.ogg": "a60fb182abebc50819d4794adbed365c940219307b713c3224d93b7f384635e9",
}
ROCKET = "warfork-cc0/sounds/weapons/rocket_strong_explosion.ogg"
LOW = "sci-fi-sounds/Audio/lowFrequency_explosion_{:03}.ogg"
CRUNCH = "sci-fi-sounds/Audio/explosionCrunch_{:03}.ogg"
BREAK = "75-cc0-breaking-falling-hit-sfx/bfh1_rock_breaking_{:02}.ogg"
FALL = "75-cc0-breaking-falling-hit-sfx/bfh1_rock_falling_{:02}.ogg"
# (body, crunch, crack, debris): every variant differs in every layer.
VARIANTS = [
    (ROCKET, CRUNCH.format(0), BREAK.format(1), FALL.format(1)),
    (LOW.format(1), CRUNCH.format(4), "warfork-cc0/sounds/misc/gibs_explosion.wav", FALL.format(3)),
    (LOW.format(0), CRUNCH.format(2), BREAK.format(3), FALL.format(2)),
    (ROCKET, CRUNCH.format(3), BREAK.format(2), FALL.format(4)),
]


def source(cache, name):
    path = cache / name.replace("/", "__")
    if not path.exists():
        path.write_bytes(urllib.request.urlopen(SOURCE + urllib.parse.quote(name), timeout=45).read())
    if hashlib.sha256(path.read_bytes()).hexdigest() != HASHES[name]:
        raise ValueError("Source checksum mismatch: " + name)
    audio, rate = sf.read(path, always_2d=True)
    audio = audio.mean(axis=1)
    if rate == 48000:
        audio = resample_poly(audio, 147, 160)
    elif rate != RATE:
        raise ValueError("Unexpected source rate: " + name)
    return audio


def placed(audio, delay=0.0):
    audio = audio - audio.mean()
    # Align the first real transient, not leading room noise.
    start = max(0, np.flatnonzero(abs(audio) >= abs(audio).max() * 0.15)[0] - int(RATE * 0.002))
    result = np.zeros(int(RATE * LENGTH))
    offset = int(RATE * delay)
    audio = audio[start:start + len(result) - offset]
    result[offset:offset + len(audio)] = audio
    return result


def shaped(audio, band, btype, decay, delay=0.0, hold=0.0):
    audio = sosfilt(butter(2, band, btype=btype, fs=RATE, output="sos"), audio)
    t = np.arange(len(audio)) / RATE
    return audio * np.exp(-np.maximum(t - delay - hold, 0) / decay)


def peak(audio, value):
    # Transient layers are levelled by peak: their energy sits in a few ms,
    # so window RMS would blow a click up far past the body.
    return audio * value / max(abs(audio).max(), 1e-9)


def mix(cache, body, crunch, crack, debris):
    # Body stays above 55 Hz and is gently saturated: phone speakers drop
    # sub-bass, so the harmonics carry the weight there.
    body = peak(shaped(placed(source(cache, body)), [55, 1800], "bandpass", 0.22, hold=0.06), 1.0)
    body = np.tanh(body * 1.5) / np.tanh(1.5)
    crunch = peak(shaped(placed(source(cache, crunch), 0.004), [400, 5200], "bandpass", 0.16, 0.004, 0.03), 0.45)
    crack = peak(shaped(placed(source(cache, crack)), 2200, "highpass", 0.07), 0.35)
    debris = peak(shaped(placed(source(cache, debris), 0.16), [700, 9000], "bandpass", 0.26, 0.16, 0.08), 0.16)
    audio = body + crunch + crack + debris
    attack, release = int(RATE * 0.001), int(RATE * 0.28)
    audio[:attack] *= np.linspace(0, 1, attack)
    audio[-release:] *= np.linspace(1, 0, release) ** 2
    # Chains overlap several bombs: keep a fixed peak and loudness budget.
    return audio * min(0.86 / abs(audio).max(), 0.15 / np.sqrt(np.mean(audio ** 2)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", required=True, type=Path)
    parser.add_argument("--out", type=Path, default=Path(__file__).resolve().parents[1] / "assets/audio")
    args = parser.parse_args()
    args.cache.mkdir(parents=True, exist_ok=True)
    args.out.mkdir(parents=True, exist_ok=True)
    for index, layers in enumerate(VARIANTS):
        audio = mix(args.cache, *layers)
        path = args.out / f"brick-bomb-{index + 1}.vorbis"
        with sf.SoundFile(path, "w", RATE, 1, format="OGG", subtype="VORBIS") as handle:
            # SFC_SET_COMPRESSION_LEVEL 0.1 = Vorbis q9 (~120 kbps): the
            # default ~80 kbps smears the crack and debris transients.
            sf._snd.sf_command(handle._file, 0x1301, sf._ffi.new("double*", 0.1), sf._ffi.sizeof("double"))
            handle.write(audio)
        decoded, _ = sf.read(path)
        if abs(decoded).max() > 0.92 or np.sqrt(np.mean(decoded ** 2)) > 0.16:
            raise ValueError("Encoded loudness exceeds preparation bounds: " + str(path))
        print(f"{path.name}: {len(decoded)/RATE:.3f}s, peak {abs(decoded).max():.3f}, "
              f"RMS {np.sqrt(np.mean(decoded ** 2)):.3f}")


if __name__ == "__main__":
    main()
