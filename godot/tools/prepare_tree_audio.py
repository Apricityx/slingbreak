#!/usr/bin/env python3
"""Reproducible upgrade-tree cues from verified CC0 acoustic recordings.

Uses the existing pinned Kenney/VSCO source cache; all tones are recordings.
Mix at 48 kHz / 24 bit, encode Vorbis q8, and measure the decoded result.
"""
import hashlib
import json
import subprocess
from pathlib import Path

import imageio_ffmpeg
import numpy as np
import soundfile as sf

from prepare_ui_audio import ROOT, RATE, SOURCES, source, take, mix


def main():
    cache = ROOT.parent / "agent-tmp/godot/ui-audio/src"
    cache.mkdir(parents=True, exist_ok=True)
    names = ["ca_chipsStack1.ogg", "ca_chipLay1.ogg", "ca_cardSlide7.ogg",
             "vs_Xylo_Medium_G5_ff_01_far.wav", "vs_Xylo_Medium_C6_ff_01_far.wav",
             "vs_glock_medium_C6.wav", "vs_glock_medium_G6.wav", "vs_glock_medium_C7.wav",
             "vs_Triangle3-HitM_v1_rr1_Sum.wav", "vs_bell_tree_scrape1.wav"]
    samples, records = {}, []
    for name in names:
        samples[name], digest = source(cache, name)
        records.append({"file": name, "url": SOURCES[name], "sha256": digest})
    chip = take(samples["ca_chipsStack1.ogg"], .08, high=700, decay=.025)
    lay = take(samples["ca_chipLay1.ogg"], .05, high=1200, decay=.02)
    xylo = lambda step=0: take(samples["vs_Xylo_Medium_C6_ff_01_far.wav"], .24, high=550, semitones=step, decay=.09)
    glock = lambda note, seconds: take(samples[f"vs_glock_medium_{note}.wav"], seconds, high=850, decay=seconds*.4, release=.12)
    triangle = take(samples["vs_Triangle3-HitM_v1_rr1_Sum.wav"], .7, high=3000, decay=.25, release=.18)
    air = take(samples["vs_bell_tree_scrape1.wav"], .65, high=3200, threshold=.05, release=.2)
    cues = {}
    for i, step in enumerate([0, 2, 4], 1):
        cues[f"tree-rank-{i}"] = mix(.38, (chip, 0, .75), (xylo(step), .004, 1), (glock("C6", .35), .018, .24))
    cues["tree-unlock"] = mix(.72, (chip, 0, .8), (xylo(), .004, .8), (xylo(4), .05, .7),
                              (glock("G6", .6), .10, .7), (triangle, .08, .22), (air, .12, .14))
    cues["tree-breakthrough"] = mix(1.12, (chip, 0, .65), (lay, .002, .4), (xylo(), .005, .85),
                                    (xylo(4), .045, .75), (glock("G6", .7), .085, .85),
                                    (glock("C7", .95), .13, .7), (triangle, .12, .3), (air, .16, .24))
    outputs = []
    for name, audio in cues.items():
        wav = cache / (name + ".wav")
        sf.write(wav, audio, RATE, subtype="PCM_24")
        path = ROOT / "assets/audio" / (name + ".vorbis")
        subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-v", "error", "-y", "-i", str(wav),
                        "-c:a", "libvorbis", "-q:a", "8", "-f", "ogg", str(path)], check=True)
        decoded, rate = sf.read(path)
        peak = float(abs(decoded).max())
        if rate != RATE or peak >= .95 or abs(decoded[-480:]).max() > .02:
            raise ValueError("Clipping or non-silent tail: " + name)
        outputs.append({"file": path.name, "seconds": len(decoded)/rate, "peak": round(peak, 5),
                        "rms": round(float(np.sqrt(np.mean(decoded**2))), 5),
                        "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
        print(name, outputs[-1])
    (ROOT / "assets/audio/tree-credits.json").write_text(json.dumps({
        "license": "CC0-1.0", "licenseUrl": "https://creativecommons.org/publicdomain/zero/1.0/",
        "credits": ["Kenney / Casino Audio", "Sam Gossner / Versilian Studios / VSCO-2-CE"],
        "changes": "Transient-aligned acoustic samples; high-pass, <=4 semitone resampling, offline layering; 48kHz mono Vorbis q8.",
        "sources": records, "outputs": outputs}, indent=2) + "\n")


if __name__ == "__main__":
    main()
