#!/usr/bin/env python3
"""Freeze Boss transition recipes using the standalone instrument catalog.

This is an offline content operation. It reads no browser source, synthesizes
no audio and never runs during a build or while playing.
"""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    catalog = json.loads((ROOT / "assets/music/manifest.json").read_text())
    shapes = [(entry["key"], json.loads(entry["key"])) for entry in catalog["samples"]]
    scores_path = ROOT / "assets/music/scores.json"
    scores = json.loads(scores_path.read_text())

    def voice(**options):
        shape = dict(type="sine", freq=220, detune=0, dur=.2, attack=.004,
                     hold=0, q=.8, ftype="lowpass", buffer=False)
        shape.update(options)
        for key, candidate in shapes:
            if candidate.keys() != shape.keys():
                continue
            if all(math.isclose(value, candidate[name], rel_tol=1e-12, abs_tol=1e-12)
                   if isinstance(value, (float, int)) and not isinstance(value, bool)
                   else value == candidate[name] for name, value in shape.items()):
                return key
        raise SystemExit(f"No frozen instrument matches {shape}")

    def item(volume, delay=0, wet=False, **shape):
        return dict(key=voice(**shape), volume=volume, delay=delay, wet=wet, bus="fx", pan=0)

    def crash(delay):
        return [item(.16, delay, buffer=True, dur=1.6, cutoff=5000, cutTo=1500, ftype="highpass"),
                item(.4, delay, freq=90, to=32, dur=.9)]

    def riser(duration):
        return item(.12, buffer=True, attack=duration, dur=.1, cutoff=300, cutTo=6000, ftype="bandpass", q=2)

    def chord(notes, volume, duration, delay):
        result = []
        for note in notes:
            result.append(item(volume, delay, type="sawtooth", freq=440 * 2 ** ((note - 69) / 12),
                               attack=.01, dur=duration, cutoff=3000, cutTo=600))
            result.append(item(volume * .6, delay, wet=True, freq=440 * 2 ** ((note + 12 - 69) / 12), dur=duration * 1.5))
        return result

    for boss, score in scores.items():
        risers = dict(eye=["glare", "mend", "doom"], serpent=[], clock=["wind", "rewind", "midnight"])[boss]
        for phase in score["phases"]:
            transitions = dict(phase=crash(.02), stun=chord(score["stab"], .07, 1.1, .02),
                               dying=[riser(1.2)] + crash(1.3) + chord(score["stinger"], .06, 5, 1.3))
            for mood in ["devour"] + risers:
                transitions[mood] = [riser(60 / phase[mood]["bpm"] * 8)]
            phase["transitions"] = transitions
    scores_path.write_text(json.dumps(scores, separators=(",", ":")) + "\n")
    print("Frozen phase, stun, riser and collapse voices for all three adaptive scores")


if __name__ == "__main__":
    main()
