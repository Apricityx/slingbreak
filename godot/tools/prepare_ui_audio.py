#!/usr/bin/env python3
"""Prepare crisp sampled UI cues (requires numpy, scipy, soundfile, imageio-ffmpeg).

Every cue is pre-mixed offline from verified CC0 recordings, so the runtime
still plays exactly one voice per UI event:
  clicks  - Kenney Casino chips/cards: sub-2 ms transients for ticks and taps
  tones   - VSCO-2-CE xylophone/glockenspiel: tuned, short-decay mallet notes
  shimmer - VSCO-2-CE triangle and bell tree: high air on rare rewards
Pitch is only moved by small resampling steps between real recorded notes;
nothing is synthesized. Sub-300 Hz energy is removed for phone speakers.
Example: python3 godot/tools/prepare_ui_audio.py --cache agent-tmp/godot/ui-audio/src
"""
import argparse
import hashlib
import json
from fractions import Fraction
from pathlib import Path
from urllib.parse import quote
import subprocess
import urllib.request

import imageio_ffmpeg
import numpy as np
from scipy.signal import butter, resample_poly, sosfiltfilt
import soundfile as sf

ROOT = Path(__file__).resolve().parents[1]
RATE = 48000
PEAK = 0.8
KENNEY = "https://cc0-sounds.netlify.app/sounds/kenney_casinoaudio/Audio/"
VSCO = "https://raw.githubusercontent.com/sgossner/VSCO-2-CE/440300901dfe9275fd84e0b7763af1f8443ae62e/"
SOURCES = {
    "ca_chipsCollide1.ogg": KENNEY + "chipsCollide1.ogg",
    "ca_chipsCollide2.ogg": KENNEY + "chipsCollide2.ogg",
    "ca_chipsCollide3.ogg": KENNEY + "chipsCollide3.ogg",
    "ca_chipsCollide4.ogg": KENNEY + "chipsCollide4.ogg",
    "ca_chipsStack1.ogg": KENNEY + "chipsStack1.ogg",
    "ca_chipsHandle3.ogg": KENNEY + "chipsHandle3.ogg",
    "ca_chipLay1.ogg": KENNEY + "chipLay1.ogg",
    "ca_cardShove1.ogg": KENNEY + "cardShove1.ogg",
    "ca_cardShove2.ogg": KENNEY + "cardShove2.ogg",
    "ca_cardSlide7.ogg": KENNEY + "cardSlide7.ogg",
    "vs_claves_mf.wav": VSCO + "VSCO 1 Percussion/varWood/claves_mf.wav",
    "vs_claves_mp.wav": VSCO + "VSCO 1 Percussion/varWood/claves_mp.wav",
    "vs_Xylo_Medium_G5_ff_01_far.wav": VSCO + "Percussion/Xylo/Xylo_Medium_G5_ff_01_far.wav",
    "vs_Xylo_Medium_C6_ff_01_far.wav": VSCO + "Percussion/Xylo/Xylo_Medium_C6_ff_01_far.wav",
    "vs_Xylo_Medium_G6_ff_01_far.wav": VSCO + "Percussion/Xylo/Xylo_Medium_G6_ff_01_far.wav",
    "vs_Xylo_Medium_C7_ff_01_far.wav": VSCO + "Percussion/Xylo/Xylo_Medium_C7_ff_01_far.wav",
    "vs_glock_medium_C6.wav": VSCO + "Percussion/Glock/glock_medium_C6.wav",
    "vs_glock_medium_G6.wav": VSCO + "Percussion/Glock/glock_medium_G6.wav",
    "vs_glock_medium_C7.wav": VSCO + "Percussion/Glock/glock_medium_C7.wav",
    "vs_Triangle3-HitM_v1_rr1_Sum.wav": VSCO + "Percussion/Triangle3-HitM_v1_rr1_Sum.wav",
    "vs_Triangle3-HitM_v2_rr1_Sum.wav": VSCO + "Percussion/Triangle3-HitM_v2_rr1_Sum.wav",
    "vs_bell_tree_scrape1.wav": VSCO + "VSCO 1 Percussion/varMetal/various/bell_tree_scrape1.wav",
}
HASHES = {
    "vs_glock_medium_C6.wav": "e942cbf502cf6731df2925945fe3234c876cb63f047d91007b6929887f9e4904",
    "vs_Xylo_Medium_C6_ff_01_far.wav": "183d04381c44705f65c3750383f28695f4b2576311ace8fdbe567134f416ff27",
    "ca_chipsCollide1.ogg": "f41b3d106360fc68ebc061a211d4265b4cb5fa1fbe86e4d57d3673510e2c3784",
    "ca_chipsCollide2.ogg": "2a10c5ff4b2fbaa55a317fc258ddce3fec85bd26db2d3c2ad298b3b33ce23bc6",
    "ca_chipsCollide3.ogg": "1c5e885f72b64c38fff7ef05579e49310e7acf026cf123ffb65fffb57fb06e1c",
    "ca_chipsCollide4.ogg": "1ffa34af64adc62fce583c5aa9a3c98287b1673ef191576a5571f1ffd39529dd",
    "ca_chipsStack1.ogg": "12bf175b9afcea112175b241ad3336c6244ac5fdcdff8b5942ecc03f2225e0c4",
    "ca_chipsHandle3.ogg": "7c5a86e27b2bef839ae096dd655506cf46a82494bd01cc28f51bed6ab26cc342",
    "ca_chipLay1.ogg": "4b2111252ccb64eed67f171e061053849cfbb29873536c03948646f244a3905c",
    "ca_cardShove1.ogg": "1ea667aa6795d5f14239192116ebcbd8f3f47eb1c7faaf2ec56844b9067b8b06",
    "ca_cardShove2.ogg": "8e95c1d3ae94b5b91bc663432ad7c3bf4e03a541c22ec10fa51c65fe0e29054b",
    "ca_cardSlide7.ogg": "bda2040194f43484d03ee3c65ed6fff57251882ea7227abce4214bfa30bf2705",
    "vs_claves_mf.wav": "7906ca75132d3374a00d12c23b030807107e4576716b6a437a9a6a8c7824b291",
    "vs_claves_mp.wav": "d2d6d73c5a91baa06f0a43af2f6fa11b3184c75b626fa4446e578b74d55a9ccc",
    "vs_Xylo_Medium_G5_ff_01_far.wav": "d5b45edd0c164356c0425b663b9307bbb77a647ba7554423c6a8aa455ac8b2b3",
    "vs_Xylo_Medium_G6_ff_01_far.wav": "8d46e7cb1d2f61f466458f042bd20ce6086802a2396cfc1dab13a5d72232d8bf",
    "vs_Xylo_Medium_C7_ff_01_far.wav": "f922a9ca996341c3cd6d54d3f3c569812e5c4c3325b1bb19de503b113b9a9197",
    "vs_glock_medium_G6.wav": "a2ba94e59119cd5272c1161fc8b8fbfb94c7b44de45a9a6cc5973b1c332103af",
    "vs_glock_medium_C7.wav": "b2ecbe0e60c983bbfaa49a1f45f8a11559f7dba27b8c8a032eb2cb7366a36910",
    "vs_Triangle3-HitM_v1_rr1_Sum.wav": "95070247743dac4064497f7c2e04a97a4c7b0a2cc98894156c8eaebd076133cf",
    "vs_Triangle3-HitM_v2_rr1_Sum.wav": "4be477be0b659aa1f7d1ff570e3dc176a65a37eb2f2bf1e453a1ddc2cdbb33fe",
    "vs_bell_tree_scrape1.wav": "508c7c896f454e638fabdac7163cbd29b129ec1b63e6646aca9e94660c63d4a4",
}


def source(cache, name):
    path = cache / name
    if not path.exists():
        path.write_bytes(urllib.request.urlopen(quote(SOURCES[name], safe=":/"), timeout=60).read())
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != HASHES.get(name):
        raise ValueError("Source checksum mismatch: " + name)
    audio, rate = sf.read(path, always_2d=True)
    if rate != 44100:
        raise ValueError("Expected 44.1 kHz source: " + name)
    audio = resample_poly(audio.mean(axis=1), 160, 147)
    audio -= audio.mean()
    return audio / max(1e-8, np.max(np.abs(audio))), digest


def band(audio, high, low=None):
    if low is None:
        sos = butter(4, high, "highpass", fs=RATE, output="sos")
    else:
        sos = butter(4, [high, low], "bandpass", fs=RATE, output="sos")
    return sosfiltfilt(sos, audio)


def shift(audio, semitones):
    # Small resampling steps between recorded notes; pitch and length move together.
    if semitones == 0:
        return audio
    ratio = Fraction(2 ** (-semitones / 12)).limit_denominator(240)
    return resample_poly(audio, ratio.numerator, ratio.denominator)


def take(audio, seconds, high=300, low=None, semitones=0, decay=None, threshold=0.12, release=0.012):
    audio = shift(band(audio, high, low), semitones)
    # Align the first real transient, not leading handling/room noise.
    start = max(0, np.flatnonzero(abs(audio) >= abs(audio).max() * threshold)[0] - int(RATE * 0.0008))
    result = np.zeros(int(RATE * seconds))
    audio = audio[start:start + len(result)]
    result[:len(audio)] = audio
    if decay:
        result *= np.exp(-np.arange(len(result)) / (RATE * decay))
    result[:24] *= np.linspace(0, 1, 24)
    tail = int(RATE * release)
    result[-tail:] *= np.linspace(1, 0, tail) ** 2
    return result / max(1e-8, np.max(np.abs(result)))


def mix(seconds, *layers):
    result = np.zeros(int(RATE * seconds))
    for audio, delay, gain in layers:
        offset = int(RATE * delay)
        part = audio[:len(result) - offset]
        result[offset:offset + len(part)] += part * gain
    tail = int(RATE * 0.02)
    result[-tail:] *= np.linspace(1, 0, tail) ** 2
    return result * PEAK / max(1e-8, np.max(np.abs(result)))


def render(s):
    """Return {output name: audio}. Note names are the VSCO file names."""
    xylo = lambda note, length, **kw: take(s["vs_Xylo_Medium_%s_ff_01_far.wav" % note], length, high=900, **kw)
    glock = lambda note, length, **kw: take(s["vs_glock_medium_%s.wav" % note], length, high=1200, **kw)
    chip = lambda name, length, **kw: take(s["ca_%s.ogg" % name], length, high=kw.pop("high", 1400), **kw)
    clave = take(s["vs_claves_mf.wav"], 0.03, high=2000, decay=0.008)
    soft_clave = take(s["vs_claves_mp.wav"], 0.03, high=2000, decay=0.008)
    triangle = take(s["vs_Triangle3-HitM_v1_rr1_Sum.wav"], 0.9, high=3000, decay=0.28, release=0.2)
    triangle_b = take(s["vs_Triangle3-HitM_v2_rr1_Sum.wav"], 0.7, high=3000, decay=0.22, release=0.16)
    cues = {}
    # Common reveal and generic tap: claves click on a tight xylophone tok.
    for index, (note, step, click) in enumerate([("G5", 0, clave), ("G5", 2, soft_clave), ("C6", 0, clave)]):
        cues["ui-tap-%d" % (index + 1)] = mix(0.11, (click, 0, 0.55), (xylo(note, 0.11, semitones=step, decay=0.03), 0.001, 1))
    # Reel ticks: the sharpest 30 ms of real chip collisions.
    for index, (name, step) in enumerate([("chipsCollide2", 0), ("chipsCollide3", 1), ("chipsCollide4", -1), ("chipsStack1", 0)]):
        cues["ui-tick-%d" % (index + 1)] = mix(0.035, (chip(name, 0.035, high=1800, semitones=step, decay=0.009, release=0.008), 0, 1))
    # Three card snaps follow the 70 ms Motion.deal stagger.
    shove = lambda name, step: chip(name, 0.13, high=700, semitones=step, decay=0.045, release=0.03)
    cues["ui-deal"] = mix(0.3, (shove("cardShove1", 0), 0, 0.8), (shove("cardShove2", 1), 0.07, 0.75), (shove("cardShove1", 2), 0.14, 0.7))
    # Choice confirmation climbs with rarity: chip click + mallet note(s).
    lay = chip("chipLay1", 0.06, high=1800, decay=0.02)
    cues["ui-pick-1"] = mix(0.22, (lay, 0, 0.6), (xylo("C6", 0.22, decay=0.06), 0.004, 1))
    cues["ui-pick-2"] = mix(0.3, (lay, 0, 0.55), (xylo("G5", 0.2, decay=0.06), 0.004, 0.85),
                            (xylo("C6", 0.26, decay=0.07), 0.05, 0.9), (glock("C6", 0.25, decay=0.08), 0.05, 0.35))
    cues["ui-pick-3"] = mix(0.42, (lay, 0, 0.55), (xylo("C6", 0.2, decay=0.06), 0.004, 0.85),
                            (xylo("C6", 0.3, semitones=4, decay=0.07), 0.05, 0.8), (glock("G6", 0.38, decay=0.1), 0.1, 0.7),
                            (triangle_b, 0.1, 0.2))
    # Card flight: the real card swish, band-limited to keep it airy.
    cues["ui-whoosh"] = mix(0.45, (take(s["ca_cardSlide7.ogg"], 0.45, high=900, low=12000, threshold=0.02, release=0.12), 0, 1))
    # Slot landing: stacked chips and a card snap with a short low tok.
    cues["ui-slot"] = mix(0.2, (chip("chipsStack1", 0.06, high=1500, decay=0.02), 0, 0.85),
                          (shove("cardShove2", 0), 0.002, 0.45), (xylo("G5", 0.18, decay=0.04), 0.003, 0.7), (clave, 0.003, 0.35))
    # Blue reveal: bright glockenspiel dyad with a xylophone attack.
    cues["ui-chime"] = mix(0.5, (xylo("C6", 0.12, decay=0.03), 0, 0.5), (glock("C6", 0.5, decay=0.16, release=0.12), 0, 0.9),
                           (glock("G6", 0.45, decay=0.14, release=0.12), 0.06, 0.8))
    # Gold reveal: fast C-E-G-C arpeggio, triangle and a brief bell-tree glitter.
    glitter = take(s["vs_bell_tree_scrape1.wav"], 0.5, high=3500, threshold=0.05, release=0.25)
    cues["ui-gold"] = mix(0.85, (lay, 0, 0.45),
                          (glock("C6", 0.3, decay=0.1), 0, 0.85), (glock("C6", 0.3, semitones=4, decay=0.1), 0.045, 0.8),
                          (glock("G6", 0.32, decay=0.11), 0.09, 0.8), (glock("C7", 0.7, decay=0.22, release=0.2), 0.135, 0.75),
                          (xylo("C7", 0.15, decay=0.04), 0.135, 0.45), (triangle, 0.135, 0.3), (glitter, 0.16, 0.18))
    # Reroll: a quick tumble of chips settling on a soft glock tick.
    cues["ui-reroll"] = mix(0.4, (chip("chipsHandle3", 0.16, high=1400, decay=0.06), 0, 0.6),
                            (chip("chipsCollide1", 0.06, decay=0.02), 0.04, 0.55), (chip("chipsCollide4", 0.06, semitones=2, decay=0.02), 0.09, 0.5),
                            (chip("chipsCollide2", 0.06, semitones=-1, decay=0.02), 0.15, 0.45), (glock("C6", 0.25, decay=0.08), 0.2, 0.35),
                            (xylo("C6", 0.12, decay=0.03), 0.2, 0.4))
    # Upgrade/reward: ascending xylophone with glock doubling and triangle air.
    notes = [("G5", 0, 0), ("C6", 0, 0.06), ("C6", 4, 0.12), ("G6", 0, 0.18)]
    layers = [(xylo(n, 0.2, semitones=st, decay=0.06), at, 0.8) for n, st, at in notes]
    layers += [(glock("C6", 0.35, semitones=4, decay=0.1), 0.12, 0.3), (glock("G6", 0.55, decay=0.18, release=0.16), 0.18, 0.55),
               (triangle_b, 0.18, 0.22)]
    cues["ui-upgrade"] = mix(0.75, *layers)
    return cues


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache", type=Path, default=ROOT.parent / "agent-tmp/godot/ui-audio/src")
    args = parser.parse_args()
    args.cache.mkdir(parents=True, exist_ok=True)
    samples, records = {}, []
    for name, url in SOURCES.items():
        samples[name], digest = source(args.cache, name)
        records.append({"file": name, "url": url, "sha256": digest})
    outputs = []
    for name, audio in render(samples).items():
        wav = args.cache / (name + ".wav")
        sf.write(wav, audio, RATE, subtype="PCM_24")
        dest = ROOT / "assets/audio" / (name + ".vorbis")
        subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-v", "error", "-y", "-i", str(wav),
                        "-c:a", "libvorbis", "-q:a", "8", "-f", "ogg", str(dest)], check=True)
        decoded, rate = sf.read(dest)
        if rate != RATE or decoded.ndim != 1 or np.max(np.abs(decoded)) >= 0.95:
            raise ValueError("Decoded cue failed checks: " + dest.name)
        outputs.append({"file": dest.name, "seconds": round(len(audio) / RATE, 4),
                        "sha256": hashlib.sha256(dest.read_bytes()).hexdigest()})
        print(dest.name, outputs[-1]["seconds"])
    credits = {
        "license": "CC0-1.0", "licenseUrl": "https://creativecommons.org/publicdomain/zero/1.0/",
        "credits": [
            {"author": "Kenney", "collection": "https://kenney.nl/assets/casino-audio",
             "mirror": "https://cc0-sounds.netlify.app/collection/kenney_casinoaudio/"},
            {"author": "Sam Gossner / Versilian Studios", "collection": "https://github.com/sgossner/VSCO-2-CE",
             "commit": "440300901dfe9275fd84e0b7763af1f8443ae62e"},
        ],
        "changes": "48kHz mono, transient alignment, 300Hz-3.5kHz high-pass per layer, <=4 semitone resampling between recorded notes, exponential trims, layering, peak leveling, Vorbis q8.",
        "sources": records, "outputs": outputs,
    }
    (ROOT / "assets/audio/ui-credits.json").write_text(json.dumps(credits, indent=2) + "\n")


if __name__ == "__main__":
    main()
