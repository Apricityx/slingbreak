#!/usr/bin/env python3
"""Render the 深渊之眼 score from CC0 VSCO-2-CE orchestral samples.

The piece is composed here as data (D minor, 96 BPM, 16 bars) and rendered
offline into five equal-length, sample-aligned looping stems plus two one-shot
stingers. The runtime layers the stems with AudioStreamSynchronized and mixes
them from the encounter state. Sources are fetched at a pinned commit; their
hashes and the outputs are recorded in assets/audio/eye-music-credits.json.

Run with the agent venv: numpy, scipy, soundfile, imageio-ffmpeg.
  python godot/tools/prepare_eye_music.py [--preview]
"""
import hashlib
import http.client
import json
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from fractions import Fraction
from pathlib import Path
from urllib.parse import quote
from urllib.request import urlopen

import imageio_ffmpeg
import numpy as np
import soundfile as sf
from scipy.signal import butter, fftconvolve, resample_poly, sosfilt

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT.parent / "agent-tmp/godot/eye-music"
COMMIT = "440300901dfe9275fd84e0b7763af1f8443ae62e"
REPO = "https://github.com/sgossner/VSCO-2-CE"
RATE = 48000
BPM = 96
BEAT = 60 / BPM
BAR = 4 * BEAT
BARS = 16
LENGTH = int(round(BARS * BAR * RATE))
STEMS = ["bed", "pulse", "stars", "theme", "daze"]
CREDITS = ROOT / "assets/audio/eye-music-credits.json"

NOTE = re.compile(r"_([A-G]#?)(-?\d)(?=[_.])")
PITCH = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}

# Pitched instruments: folder, file filter (one dynamic layer), sustained?
PITCHED = {
    "bass": ("Strings/Solo Contrabass/SusNV", r"_v1_rr1", True),
    "bass_spic": ("Strings/Solo Contrabass/Spic", r"_v3_rr1|_v1_rr1", False),
    "cello": ("Strings/Cello Section/susvib", r"_v1_1", True),
    "cello_spic": ("Strings/Cello Section/spic", r"_v2_RR1", False),
    "viola": ("Strings/Viola Section/susvib", r"_v1_1", True),
    "violin": ("Strings/Violin Section/susVib", r"_v1", True),
    "violin_trem": ("Strings/Violin Section/Trem", r"_v1", True),
    "horn": ("Brass/F Horn/sus", r"_v2_1", True),
    "trombone": ("Brass/Tenor Trombone/sus", r"_v2_1", True),
    "tuba": ("Brass/Tuba/sus", r"_v2_rr1", True),
    "flute": ("Woodwinds/Flute/susNV", r"_v1_1", True),
    "harp": ("Strings/Harp", r"KSHarp_", False),
    "glock": ("Percussion/Glock", r"glock_medium", False),
}
HITS = {
    "timpani": [f"Percussion/Timpani/Timpani{i}_Hit_v3_rr1_Sum.wav" for i in range(1, 6)],
    "timp_roll": ["Percussion/Timpani/Rolls/Timpani2_Roll_v5_rr1_Sum.wav"],
    "bdrum": ["VSCO 1 Percussion/drums/bass/bdrum_mp_1.wav", "VSCO 1 Percussion/drums/bass/bdrum_mp_2.wav"],
    "bdrum_f": ["VSCO 1 Percussion/drums/bass/bdrum_fff_1.wav"],
    "gong": ["Percussion/gongHit_f.wav"],
    "gong_fff": ["Percussion/gongHit_fff.wav"],
    "swell": ["Percussion/susCymb1-cresc-Long_v1.wav"],
    "bells": ["Miscellania Raw/Misc 2/NepaleseBells/fx_long_1_main.wav"],
}


def download(urls):
    for attempt in range(6):
        try:
            return urlopen(urls[attempt % len(urls)], timeout=60).read()
        except (OSError, http.client.HTTPException):
            if attempt == 5:
                raise
            time.sleep(2 ** (attempt // 2))


def blob_sha(body):
    return hashlib.sha1(b"blob %d\0" % len(body) + body).hexdigest()


def tree():
    local = CACHE / "tree.json"
    if not local.exists():
        CACHE.mkdir(parents=True, exist_ok=True)
        url = f"https://api.github.com/repos/sgossner/VSCO-2-CE/git/trees/{COMMIT}?recursive=1"
        local.write_bytes(download([url]))
    return {e["path"]: e["sha"] for e in json.loads(local.read_text())["tree"] if e["type"] == "blob"}


class Library:
    def __init__(self, pinned):
        self.pinned = pinned
        self.records = {}
        self.loaded = {}
        self.shifted = {}
        self.paths = tree()

    def fetch(self, path):
        url = f"https://raw.githubusercontent.com/sgossner/VSCO-2-CE/{COMMIT}/{quote(path)}"
        local = CACHE / "samples" / path
        if not local.exists():
            local.parent.mkdir(parents=True, exist_ok=True)
            # The jsDelivr mirror serves the same commit; git's blob hash proves it.
            body = download([f"https://cdn.jsdelivr.net/gh/sgossner/VSCO-2-CE@{COMMIT}/{quote(path)}", url])
            partial = local.with_suffix(".part")
            partial.write_bytes(body)
            partial.replace(local)
        body = local.read_bytes()
        if blob_sha(body) != self.paths[path]:
            local.unlink()
            raise ValueError(f"Not the file at commit {COMMIT}: {path}")
        digest = hashlib.sha256(body).hexdigest()
        if url in self.pinned and self.pinned[url] != digest:
            raise ValueError(f"Source changed: {path}")
        self.records[url] = digest
        return local

    def load(self, path, sustained):
        if path in self.loaded:
            return self.loaded[path]
        cached = CACHE / "decoded" / f"{path}.{int(sustained)}.npy"
        source = self.fetch(path)
        if cached.exists():
            self.loaded[path] = np.load(cached).astype(np.float64)
            return self.loaded[path]
        data, rate = sf.read(source, always_2d=True, dtype="float64")
        if data.shape[1] == 1:
            data = np.repeat(data, 2, axis=1)
        data = data[:, :2]
        if rate != RATE:
            ratio = Fraction(RATE, rate)
            data = resample_poly(data, ratio.numerator, ratio.denominator)
        data -= np.mean(data, axis=0)
        envelope = np.max(np.abs(data), axis=1)
        peak = float(np.max(envelope)) or 1.0
        # Trim the recorded pre-roll so notes land on the grid.
        start = max(0, int(np.argmax(envelope > peak * 0.03)) - int(0.004 * RATE))
        data = data[start:]
        if sustained:
            # Sustains are matched by body loudness, not by their attack peak.
            body = data[int(0.2 * RATE): int(1.6 * RATE)]
            data = data / max(float(np.sqrt(np.mean(body ** 2))) * 4, 1e-9)
        else:
            data = data / peak
        fade = min(len(data) // 8, int(0.03 * RATE))
        data[-fade:] *= np.linspace(1, 0, fade)[:, None]
        cached.parent.mkdir(parents=True, exist_ok=True)
        np.save(cached, data.astype(np.float32))
        self.loaded[path] = data
        return data

    def files(self, name):
        """One file per recorded note: the preferred layer, else the softest other layer."""
        folder, pattern, _ = PITCHED[name]
        candidates = sorted(p for p in self.paths if p.startswith(folder + "/") and p.endswith(".wav")
                            and "/" not in p[len(folder) + 1:] and NOTE.search(p.split("/")[-1]))
        chosen = {}
        for preferred in (True, False):
            for path in candidates:
                file = path.split("/")[-1]
                if bool(re.search(pattern, file)) == preferred:
                    chosen.setdefault(NOTE.search(file).group(0), path)
        return sorted(chosen.values())

    def prefetch(self):
        """Download every source in parallel; single requests are slow but independent."""
        paths = [p for name in PITCHED for p in self.files(name)] + [p for group in HITS.values() for p in group]
        with ThreadPoolExecutor(12) as pool:
            list(pool.map(self.fetch, paths))
        self.records.clear()  # Credit only what the render actually loads.
        print(f"{len(paths)} sources")

    def instrument(self, name):
        _, _, sustained = PITCHED[name]
        files = self.files(name)
        named = {}
        for path in files:
            match = NOTE.search(path.split("/")[-1])
            named.setdefault(12 * (int(match.group(2)) + 1) + PITCH[match.group(1)], path)
        # VSCO folders disagree on octave naming; detect it from the samples.
        offsets = [round((fundamental(self.load(p, sustained)) - m) / 12) for m, p in named.items()]
        octave = int(np.median(offsets))
        notes = sorted(m + 12 * octave for m in named)
        print(f"  {name}: octave {octave:+d}, {len(notes)} notes {notes[0]}..{notes[-1]}")
        return {"sustained": sustained, "notes": {m + 12 * octave: p for m, p in named.items()}}

    def shift(self, path, semis, sustained):
        key = (path, semis)
        if key not in self.shifted:
            data = self.load(path, sustained)
            if semis:
                ratio = Fraction(2 ** (-semis / 12)).limit_denominator(600)
                data = resample_poly(data, ratio.numerator, ratio.denominator)
            self.shifted[key] = data
        return self.shifted[key]


def fundamental(data):
    """Harmonic-product-spectrum pitch of the sustain, in MIDI."""
    mono = np.mean(data[int(0.08 * RATE): int(0.9 * RATE)], axis=1)
    spectrum = np.abs(np.fft.rfft(mono * np.hanning(len(mono)), 1 << 18))
    product = spectrum.copy()
    for k in (2, 3):
        product[: len(spectrum) // k] *= spectrum[::k][: len(spectrum) // k]
    freqs = np.fft.rfftfreq(1 << 18, 1 / RATE)
    band = (freqs > 28) & (freqs < 3000)
    hz = freqs[band][np.argmax(product[band])]
    return 69 + 12 * np.log2(hz / 440)


def midi_of(name):
    match = re.fullmatch(r"([A-G]#?|[A-G]b)(-?\d)", name)
    pc = match.group(1)
    if pc.endswith("b"):
        pc = {"Db": "C#", "Eb": "D#", "Gb": "F#", "Ab": "G#", "Bb": "A#"}[pc]
    return 12 * (int(match.group(2)) + 1) + PITCH[pc]


def near(pc, target):
    """The MIDI note of pitch class pc closest to target."""
    return target + ((pc - target + 6) % 12) - 6


class Track:
    """A circular (looping) or linear stereo buffer that notes are mixed into."""

    def __init__(self, lib, frames=LENGTH, loop=True, seed=1):
        self.lib = lib
        self.buffer = np.zeros((frames, 2))
        self.loop = loop
        self.rng = np.random.default_rng(seed)
        self.voices = {}

    def place(self, data, at, gain, pan):
        left, right = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        data = data * gain * np.array([left, right]) * np.sqrt(2)
        start = int(round(at * RATE))
        frames = len(self.buffer)
        if not self.loop:
            end = min(frames, start + len(data))
            self.buffer[start:end] += data[: end - start]
            return
        offset = 0
        while offset < len(data):
            index = (start + offset) % frames
            take = min(len(data) - offset, frames - index)
            self.buffer[index:index + take] += data[offset:offset + take]
            offset += take

    def voice(self, name):
        if name not in self.voices:
            self.voices[name] = self.lib.instrument(name)
        return self.voices[name]

    def note(self, name, midi, beat, beats, gain=1.0, pan=0.0, attack=0.0, release=0.35, envelope=None):
        inst = self.voice(name)
        # Ties pitch down: slowed brass darkens naturally, sped-up brass thins.
        source = min(inst["notes"], key=lambda m: (abs(m - midi), m < midi))
        if abs(source - midi) > 5:
            print(f"  warning: {name} {midi} repitched {midi - source:+d} semitones")
        data = self.lib.shift(inst["notes"][source], midi - source, inst["sustained"])
        if inst["sustained"]:
            data = sustain(data, int((beats * BEAT + release) * RATE))
        else:
            data = data[: int((beats * BEAT + release) * RATE)].copy()
        shape = np.ones(len(data))
        if attack:
            count = min(len(data), int(attack * RATE))
            shape[:count] = np.sin(np.linspace(0, np.pi / 2, count)) ** 2
        tail = min(len(data) // 2, int(release * RATE))
        if tail:
            shape[-tail:] *= np.cos(np.linspace(0, np.pi / 2, tail)) ** 2
        if envelope is not None:
            shape *= envelope(np.arange(len(data)) / RATE)
        jitter = self.rng.uniform(-0.004, 0.004) if beat > 0 else 0
        self.place(data * shape[:, None], beat * BEAT + jitter, gain * self.rng.uniform(0.94, 1.0), pan)

    def hit(self, name, beat, gain=1.0, pan=0.0, index=None, beats=None, envelope=None):
        files = HITS[name]
        path = files[index if index is not None else int(self.rng.integers(len(files)))]
        data = self.lib.load(path, False)
        if beats is not None:
            data = data[: int(beats * BEAT * RATE)].copy()
            tail = min(len(data) // 3, int(0.12 * RATE))
            data[-tail:] *= np.linspace(1, 0, tail)[:, None]
        if envelope is not None:
            data = data * envelope(np.arange(len(data)) / RATE)[:, None]
        self.place(data, beat * BEAT, gain, pan)


def sustain(data, frames):
    """Extend a sustained sample by crossfading repeats of its steady body."""
    if len(data) >= frames:
        return data[:frames].copy()
    a, b = int(0.4 * RATE), len(data) - int(0.15 * RATE)
    if b - a < int(0.8 * RATE):
        a = len(data) // 3
    body = data[a:b]
    cross = min(int(0.25 * RATE), len(body) // 3)
    fade_in = np.sin(np.linspace(0, np.pi / 2, cross))[:, None]
    out = data[:b].copy()
    while len(out) < frames:
        out[-cross:] = out[-cross:] * fade_in[::-1] + body[:cross] * fade_in
        out = np.concatenate([out, body[cross:]])
    return out[:frames]


def impulse(seconds=3.0, rt60=2.3, seed=7):
    """A decorrelated stereo hall tail with frequency-dependent decay."""
    rng = np.random.default_rng(seed)
    count = int(seconds * RATE)
    t = np.arange(count) / RATE
    noise = rng.standard_normal((count, 2))
    low = sosfilt(butter(2, 2200, "low", fs=RATE, output="sos"), noise, axis=0)
    high = noise - low
    tail = low * np.exp(-6.9 * t / rt60)[:, None] + high * np.exp(-6.9 * t / (rt60 * 0.4))[:, None]
    predelay = int(0.022 * RATE)
    tail = np.concatenate([np.zeros((predelay, 2)), tail])
    tail *= np.minimum(1, np.arange(len(tail)) / (0.03 * RATE))[:, None]
    return tail / np.sqrt(np.sum(tail ** 2) / 2)


IR = None


def space(buffer, wet, loop=True):
    global IR
    if IR is None:
        IR = impulse()
    out = buffer.copy()
    for ch in range(2):
        tail = fftconvolve(buffer[:, ch], IR[:, ch])
        if loop:
            # Fold the reverb tail of the last bar onto the loop start.
            folded = tail[: len(buffer)].copy()
            rest = tail[len(buffer):]
            folded[: len(rest)] += rest
            out[:, ch] += folded * wet
        else:
            out[:, ch] += tail[: len(buffer)] * wet
    return sosfilt(butter(2, 32, "high", fs=RATE, output="sos"), out, axis=0) if not loop else highpass_loop(out)


def highpass_loop(buffer):
    # Filter two passes of the loop so the state at the seam is settled.
    sos = butter(2, 32, "high", fs=RATE, output="sos")
    twice = sosfilt(sos, np.concatenate([buffer, buffer]), axis=0)
    return twice[len(buffer):]


# Two bars per chord: (root pitch class, third, fifth). Dm Bb Gm A | Dm Eb C A.
CHORDS = [(2, 5, 9), (10, 2, 5), (7, 10, 2), (9, 1, 4), (2, 5, 9), (3, 7, 10), (0, 4, 7), (9, 1, 4)]
# The eye motif: rising minor third, a falling half step, then it opens.
THEME = [
    (0, 1, "D4"), (1, 1, "F4"), (2, 2, "E4"), (4, 3, "A4"), (7, 1, "G4"),
    (8, 2, "F4"), (10, 1, "D4"), (11, 1, "F4"), (12, 4, "D4"),
    (16, 1, "D4"), (17, 1, "G4"), (18, 2, "A#4"), (20, 3, "A4"), (23, 1, "G4"),
    (24, 2, "C#5"), (26, 2, "E5"), (28, 4, "A4"),
    (32, 1, "A4"), (33, 1, "C5"), (34, 2, "A#4"), (36, 3, "F5"), (39, 1, "E5"),
    (40, 2, "D5"), (42, 1, "C5"), (43, 1, "A#4"), (44, 4, "G4"),
    (48, 1, "G4"), (49, 1, "C5"), (50, 2, "E5"), (52, 3, "D5"), (55, 1, "C5"),
    (56, 3, "C#5"), (59, 1, "E5"), (60, 4, "A4"),
]
# Eighth-note ostinato accents (3+3+2) for the spiccato basses.
PULSE = [1.0, 0.45, 0.55, 0.9, 0.45, 0.55, 0.85, 0.5]


def chord_at(bar):
    return CHORDS[(bar // 2) % len(CHORDS)]


def bed(lib):
    t = Track(lib, seed=11)
    for bar in range(0, BARS, 2):
        root, third, fifth = chord_at(bar)
        beat = bar * 4
        t.note("bass", near(root, 38), beat, 8, 0.85, 0, attack=0.5, release=0.6)
        t.note("cello", near(root, 50), beat, 8, 0.55, -0.35, attack=0.6, release=0.6)
        t.note("cello", near(fifth, 55), beat, 8, 0.42, -0.2, attack=0.7, release=0.6)
        t.note("viola", near(third, 62), beat, 8, 0.4, 0.3, attack=0.8, release=0.6)
    t.hit("bells", 0, 0.18, -0.4)
    t.hit("bells", 32, 0.14, 0.4)
    t.hit("swell", 60 - 6.5, 0.1, 0.0)
    return space(t.buffer, 0.55)


def pulse(lib):
    t = Track(lib, seed=12)
    timpani = sorted((fundamental(lib.load(p, False)) % 12, i) for i, p in enumerate(HITS["timpani"]))
    for bar in range(BARS):
        root, third, fifth = chord_at(bar)
        for step, accent in enumerate(PULSE):
            beat = bar * 4 + step / 2
            pitch = near(root, 33) if step != 6 else near(fifth, 40)
            t.note("bass_spic", pitch, beat, 0.5, 0.75 * accent, -0.1, release=0.05)
            if accent > 0.8:
                t.note("cello_spic", near(root, 45 if step != 6 else 52), beat, 0.5, 0.42 * accent, 0.25, release=0.05)
        drum = min(timpani, key=lambda d: min(abs((d[0] - root + 6) % 12 - 6), abs((d[0] - fifth + 6) % 12 - 6)))[1]
        t.hit("timpani", bar * 4, 0.55 if bar % 2 == 0 else 0.38, -0.15, index=drum)
        t.hit("bdrum", bar * 4, 0.42, 0)
        t.hit("bdrum", bar * 4 + 2.5, 0.3, 0)
        if bar % 4 == 3:
            t.hit("timpani", bar * 4 + 3, 0.32, 0.15, index=drum)
            t.hit("timpani", bar * 4 + 3.5, 0.4, 0.15, index=drum)
    return space(t.buffer, 0.22)


def stars(lib):
    t = Track(lib, seed=13)
    for bar in range(0, BARS, 2):
        root, third, fifth = chord_at(bar)
        t.note("violin_trem", near(third, 77), bar * 4, 8, 0.3, -0.45, attack=1.2, release=0.8)
        t.note("violin_trem", near(fifth, 81), bar * 4, 8, 0.26, 0.45, attack=1.4, release=0.8)
        t.note("glock", near(fifth, 84), bar * 4, 4, 0.22, 0.3, release=0.0)
    arp = lambda c: [near(c[0], 62), near(c[2], 67), near(c[1], 72), near(c[0], 74), near(c[2], 79), near(c[1], 84), near(c[0], 86), near(c[2], 79)]
    for bar in range(BARS):
        for step, midi in enumerate(arp(chord_at(bar))):
            pan = -0.6 + step * 0.17
            t.note("harp", midi, bar * 4 + step / 2, 2.5, 0.42 - step * 0.02, pan, release=0.4)
        if bar % 4 == 2:
            t.note("glock", near(chord_at(bar)[1], 88), bar * 4 + 2.5, 3, 0.16, -0.3, release=0.0)
    return space(t.buffer, 0.6)


def theme(lib):
    t = Track(lib, seed=14)
    for beat, beats, name in THEME:
        midi = midi_of(name)
        t.note("horn", midi, beat, beats, 0.62, -0.15, attack=0.04, release=0.45)
        if beat >= 32:
            t.note("violin", midi, beat, beats, 0.34, 0.3, attack=0.08, release=0.45)
    for bar in range(8, BARS, 2):
        root, third, fifth = chord_at(bar)
        t.note("trombone", near(root, 46), bar * 4, 8, 0.4, 0.2, attack=0.4, release=0.5)
        t.note("trombone", near(fifth, 52), bar * 4, 8, 0.32, 0.35, attack=0.5, release=0.5)
    for bar in range(12, BARS, 2):
        t.note("tuba", near(chord_at(bar)[0], 33), bar * 4, 8, 0.5, 0, attack=0.4, release=0.5)
    return space(t.buffer, 0.4)


def daze(lib):
    t = Track(lib, seed=15)
    for bar in range(BARS):
        root, third, fifth = chord_at(bar)
        notes = [near(root, 86), near(fifth, 81), near(third, 77), near(root, 74), near(fifth, 69), near(third, 65)]
        for step, midi in enumerate(notes):
            t.note("harp", midi, bar * 4 + step * 0.66, 3, 0.3, 0.6 - step * 0.22, release=0.6)
        if bar % 2 == 0:
            t.note("flute", near(third, 76), bar * 4 + 0.5, 7, 0.32, 0.2, attack=0.9, release=0.9)
        if bar % 4 == 0:
            t.note("glock", near(root, 86), bar * 4 + 1, 4, 0.13, -0.5, release=0.0)
    return space(t.buffer, 0.75)


REVEAL = 1.58  # Rig.REVEAL_AT: the shift stinger lands on the rupture frame.


def shift_stinger(lib):
    t = Track(lib, frames=int(5.0 * RATE), loop=False, seed=21)
    rise = lambda s: np.clip(s / REVEAL, 0, 1) ** 2
    t.hit("timp_roll", 0, 0.5, 0, beats=REVEAL / BEAT, envelope=rise)
    # Start the long cymbal swell so its crest lands on the impact, then choke it.
    swell = lib.load(HITS["swell"][0], False)
    crest = int(np.argmax(np.max(np.abs(swell), axis=1)))
    swell = swell[crest - int(REVEAL * RATE): crest + int(0.5 * RATE)].copy()
    swell[-int(0.3 * RATE):] *= np.linspace(1, 0, int(0.3 * RATE))[:, None]
    t.place(swell, 0, 0.35, 0)
    hit = REVEAL / BEAT
    t.hit("gong", hit, 0.7, 0.1)
    t.hit("bdrum_f", hit, 0.75, 0)
    t.hit("timpani", hit, 0.7, -0.1, index=0)
    for midi, name, gain, pan in [(38, "tuba", 0.6, 0), (50, "trombone", 0.5, 0.25), (57, "trombone", 0.42, 0.35),
                                  (62, "horn", 0.5, -0.25), (65, "horn", 0.45, -0.35), (69, "horn", 0.4, -0.1)]:
        t.note(name, midi, hit, 1.6 / BEAT, gain, pan, attack=0.02, release=0.9)
    t.note("violin_trem", 74, hit, 1.5 / BEAT, 0.32, 0.5, attack=0.1, release=0.9)
    t.note("violin_trem", 81, hit, 1.5 / BEAT, 0.26, -0.5, attack=0.1, release=0.9)
    return space(t.buffer, 0.5, loop=False)


def finale(lib):
    t = Track(lib, frames=int(9.0 * RATE), loop=False, seed=22)
    t.hit("gong_fff", 0, 0.75, 0)
    t.hit("bdrum_f", 0, 0.7, 0)
    t.hit("timpani", 0, 0.65, 0, index=0)
    # The collapse resolves into a Picardy D major: the abyss closes, light remains.
    swell = lambda s: np.clip((s + 0.2) / 1.6, 0, 1)
    for midi, name, gain, pan in [(38, "tuba", 0.5, 0), (50, "trombone", 0.42, 0.25), (57, "trombone", 0.36, 0.35),
                                  (62, "horn", 0.45, -0.25), (66, "horn", 0.42, -0.35), (69, "horn", 0.4, -0.1)]:
        t.note(name, midi, 0.6 / BEAT, 5.2 / BEAT, gain, pan, attack=0.3, release=2.2, envelope=swell)
    for i, midi in enumerate([62, 66, 69, 74, 78, 81, 86, 90]):
        t.note("harp", midi, (0.8 + i * 0.09) / BEAT, 4 / BEAT, 0.34, -0.5 + i * 0.13, release=1.5)
    t.note("violin_trem", 78, 0.9 / BEAT, 5 / BEAT, 0.3, 0.45, attack=0.9, release=2.0)
    t.note("violin_trem", 81, 0.9 / BEAT, 5 / BEAT, 0.26, -0.45, attack=1.0, release=2.0)
    t.note("glock", 90, 1.6 / BEAT, 4 / BEAT, 0.2, 0.2, release=0.0)
    return space(t.buffer, 0.6, loop=False)


# Body RMS per stem; the runtime mixes them at levels up to ~1.
LEVEL = {"bed": 0.085, "pulse": 0.09, "stars": 0.06, "theme": 0.085, "daze": 0.06}


def rms(data):
    return float(np.sqrt(np.mean(data ** 2)))


def encode(data, name, folder):
    wav = CACHE / f"{name}.wav"
    sf.write(wav, data, RATE, subtype="PCM_24")
    dest = ROOT / f"assets/{folder}/{name}.vorbis"
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-v", "error", "-y", "-i", str(wav),
                    "-c:a", "libvorbis", "-q:a", "6", "-f", "ogg", str(dest)], check=True)
    decoded, rate = sf.read(dest, always_2d=True)
    assert rate == RATE and np.max(np.abs(decoded)) < 0.97, name
    return dest, decoded


def preview(stems, stingers):
    """A 100-second walkthrough of the adaptive mix, for listening review only."""
    # (seconds, bed, pulse, stars, theme, daze)
    timeline = [(0, .5, 0, .6, 0, 0), (8, 1, .55, .45, 0, 0), (28, .7, .15, .9, 0, 0), (31, .2, 0, .1, 0, 0),
                (31.6, 1, .6, .5, .3, 0), (38, .45, .05, .1, 0, 1), (46, 1, .55, .45, 0, 0), (52, .25, .05, .1, 0, 0),
                (56, 1, .8, .5, .85, 0), (76, 1, 1, .85, 1, 0), (90, .2, .1, .2, .2, 0), (100, 0, 0, 0, 0, 0)]
    frames = int(100 * RATE)
    out = np.zeros((frames, 2))
    t = np.arange(frames) / RATE
    keys = [k[0] for k in timeline]
    for i, name in enumerate(STEMS):
        gain = np.interp(t, keys, [k[i + 1] for k in timeline])
        out += np.resize(stems[name], (frames, 2)) * gain[:, None]
    for name, at in [("eye-shift", 52), ("eye-finale", 90)]:
        start = int(at * RATE)
        data = stingers[name][: frames - start]
        out[start:start + len(data)] += data * 0.9
    out *= min(1, 0.9 / np.max(np.abs(out)))
    sf.write(CACHE / "preview.wav", out, RATE, subtype="PCM_16")
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-v", "error", "-y", "-i", str(CACHE / "preview.wav"),
                    "-c:a", "libvorbis", "-q:a", "6", str(CACHE / "preview.ogg")], check=True)
    print("preview", CACHE / "preview.ogg")


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    pinned = {entry["source"]: entry["sha256"] for entry in json.loads(CREDITS.read_text())["sources"]} if CREDITS.exists() else {}
    lib = Library(pinned)
    lib.prefetch()
    builders = {"bed": bed, "pulse": pulse, "stars": stars, "theme": theme, "daze": daze}
    stems = {}
    for name in STEMS:
        data = builders[name](lib)
        stems[name] = data * (LEVEL[name] / rms(data))
        print(f"{name:6s} rms={rms(stems[name]):.3f} peak={np.max(np.abs(stems[name])):.3f}")
    total = sum(stems.values())
    scale = min(1.0, 0.92 / float(np.max(np.abs(total))))
    print(f"all-stems peak={np.max(np.abs(total)):.3f} scale={scale:.3f}")
    stingers = {"eye-shift": shift_stinger(lib), "eye-finale": finale(lib)}
    for name, data in stingers.items():
        data *= 0.8 / float(np.max(np.abs(data)))
        data[-int(0.6 * RATE):] *= np.cos(np.linspace(0, np.pi / 2, int(0.6 * RATE)))[:, None] ** 2
    outputs = []
    for name in STEMS:
        stems[name] *= scale
        dest, decoded = encode(stems[name], f"eye-{name}", "music")
        assert len(decoded) == LENGTH, (name, len(decoded), LENGTH)
        # The loop seam must be continuous: compare the jump to typical motion.
        seam = float(np.max(np.abs(decoded[0] - decoded[-1])))
        motion = float(np.percentile(np.max(np.abs(np.diff(decoded, axis=0)), axis=1), 99.9))
        assert seam <= motion * 1.5 + 1e-3, (name, seam, motion)
        outputs.append({"file": f"music/{dest.name}", "sha256": hashlib.sha256(dest.read_bytes()).hexdigest(),
                        "frames": LENGTH, "loop": True})
    for name, data in stingers.items():
        dest, decoded = encode(data, name, "music")
        outputs.append({"file": f"music/{dest.name}", "sha256": hashlib.sha256(dest.read_bytes()).hexdigest(),
                        "frames": len(decoded), "loop": False})
    CREDITS.write_text(json.dumps({
        "title": "深渊之眼 (Abyss Eye) adaptive score",
        "composition": "Original; composed and rendered by godot/tools/prepare_eye_music.py.",
        "library": "Versilian Studios Chamber Orchestra 2 Community Edition (VSCO-2-CE)",
        "repository": REPO, "commit": COMMIT,
        "license": "CC0-1.0", "licenseUrl": "https://creativecommons.org/publicdomain/zero/1.0/",
        "tempo": BPM, "bars": BARS, "rate": RATE,
        "changes": "48 kHz conversion, pre-roll trim, repitching, sustain crossfade extension, "
                   "synthetic hall reverb, loop folding, level matching; Vorbis q6 encoding.",
        "outputs": outputs,
        "sources": [{"source": url, "sha256": digest} for url, digest in sorted(lib.records.items())],
    }, indent=2, ensure_ascii=False) + "\n")
    if "--preview" in sys.argv:
        preview(stems, stingers)


if __name__ == "__main__":
    main()
