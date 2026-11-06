#!/usr/bin/env python3
"""Render the 时之君主 score from CC0 VSCO-2-CE orchestral samples.

The piece is composed here as data and rendered offline into equal-length,
sample-aligned looping stems that the runtime layers with AudioStreamSynchronized.
Sources are fetched at a pinned commit; hashes accompany the outputs.
"""
import hashlib
import json
import re
import subprocess
import sys
from fractions import Fraction
from pathlib import Path
from urllib.parse import quote
from urllib.request import urlopen

import imageio_ffmpeg
import numpy as np
import soundfile as sf
from scipy.signal import butter, fftconvolve, resample_poly, sosfilt

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT.parent / "agent-tmp/godot/clock-audio"
COMMIT = "440300901dfe9275fd84e0b7763af1f8443ae62e"
REPO = "https://github.com/sgossner/VSCO-2-CE"
RATE = 48000
BPM = 120
BARS = 16
BEAT = 60 / BPM
LENGTH = int(round(BARS * 4 * BEAT * RATE))

NOTE = re.compile(r"_([A-G]#?)(-?\d)(?=[_.])")
PITCH = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def names(folder, pattern, notes):
    return [f"{folder}/{pattern.format(n)}" for n in notes]


# Pitched instruments: (files, octave correction applied to the file-name note).
# VSCO names the string sections one octave below scientific pitch; the
# corrections were checked against detected fundamentals (see --analyse);
# zones whose recording disagreed with its name are left out.
PITCHED = {
    "glock": (names("Percussion/Glock", "glock_medium_{}.wav", ["G4", "C5", "G5", "C6", "G6", "C7"]), 1),
    "harp": (names("Strings/Harp", "KSHarp_{}_mf.wav", ["B1", "D2", "F2", "A2", "C3", "E3", "G3", "B3", "D4", "F4", "A4", "C5", "E5", "G5"]), 0),
    "pizz": (names("Strings/Solo Contrabass/Pizz", "BKCtbss_Pizz_{}_v1_rr1.wav", ["E0", "F#0", "G0", "A#0", "C1", "D1", "E1", "F#1", "G#1", "A1"]), 1),
    "spic": (names("Strings/Cello Section/spic", "spic_{}_v2_RR1.wav", ["C1", "E1", "G1", "B1", "D2", "F2", "A2", "C3", "E3", "G3"]), 1),
    "cello_trem": (names("Strings/Cello Section/trem", "trem_{}_v2_1.wav", ["C1", "G1", "D2", "F2", "A2", "C3", "E3", "G3"]), 1),
    "violin_trem": (names("Strings/Violin Section/Trem", "VlnEns_Trem_{}_v1.wav", ["B2", "F#3", "A3", "C4", "E4", "G4", "B4", "D5"]), 1),
    "viola": (names("Strings/Viola Section/susvib", "ViolaEns_susvib_{}_v1_1.wav", ["G2", "B2", "D3", "F3", "A3", "C4", "E4", "G4"]), 1),
    "cello": (names("Strings/Cello Section/susvib", "susvib_{}_v1_1.wav", ["G1", "B1", "D2", "F2", "A2", "C3", "E3", "G3"]), 1),
    "bells": (["Percussion/TB_hit_C4_v4_rr1.wav", "Percussion/TB_hit_G4_v4_rr1.wav", "Percussion/TB_hit_C5_v4_rr1.wav", "Percussion/TB_hit_F5_v3_rr1.wav"], 1),
}
# Unpitched one-shots, addressed by short name.
HITS = {
    "tick": ["Percussion/Claves1_Hit_v2_rr1_Sum.wav", "Percussion/Claves1_Hit_v2_rr2_Sum.wav"],
    "tick_hard": ["Percussion/Claves1_Hit_v3_rr1_Sum.wav", "Percussion/Claves1_Hit_v3_rr2_Sum.wav"],
    "tock": ["VSCO 1 Percussion/varWood/wood_click_mp.wav", "VSCO 1 Percussion/varWood/wood_click3.wav"],
    "ghost": ["VSCO 1 Percussion/varWood/wood_click_pp_1.wav", "VSCO 1 Percussion/varWood/wood_click_pp_2.wav"],
    "timpani": [f"Percussion/Timpani/Timpani{i}_Hit_v3_rr1_Sum.wav" for i in range(1, 6)],
    "gong_p": ["Percussion/gongHit_p.wav"],
    "gong_f": ["Percussion/gongHit_f.wav"],
    "swell": ["Percussion/susCymb1-cresc-Long_v1.wav"],
    "swell_short": ["Percussion/susCymb1-cresc-Short_v1.wav"],
    "chimes": ["VSCO 1 Percussion/varMetal/various/windchimes_slowDesc1.wav"],
    "triangle": ["Percussion/temp/Triangle6-HitM_v1_rr1_Sum.wav"],
    "crank": ["Percussion/Ratchet1-Crank_v1_rr1_Sum.wav", "Percussion/Ratchet1-Crank_v1_rr2_Sum.wav"],
    "gliss": ["Miscellania Raw/Misc 2/glock_glisses/glock_fx_down_chromatic_slow_01.wav"],
}


def midi(name):
    match = NOTE.search(name)
    return 12 * (int(match.group(2)) + 1) + PITCH[match.group(1)]


def fetch(path, pinned, records):
    url = f"https://raw.githubusercontent.com/sgossner/VSCO-2-CE/{COMMIT}/{quote(path)}"
    local = CACHE / "samples" / path
    if not local.exists():
        local.parent.mkdir(parents=True, exist_ok=True)
        for attempt in range(5):
            try:
                body = urlopen(url, timeout=120).read()
                break
            except OSError:
                if attempt == 4:
                    raise
        partial = local.with_suffix(".part")
        partial.write_bytes(body)
        partial.replace(local)
    digest = hashlib.sha256(local.read_bytes()).hexdigest()
    if url in pinned and pinned[url] != digest:
        raise ValueError(f"Source changed: {path}")
    records[url] = digest
    return local


def load(local):
    data, rate = sf.read(local, always_2d=True, dtype="float64")
    if data.shape[1] == 1:
        data = np.repeat(data, 2, axis=1)
    data = data[:, :2]
    if rate != RATE:
        ratio = Fraction(RATE, rate)
        data = resample_poly(data, ratio.numerator, ratio.denominator)
    data -= np.mean(data, axis=0)
    peak = float(np.max(np.abs(data))) or 1.0
    # Trim the recorded pre-roll so hits land on the grid.
    start = max(0, int(np.argmax(np.max(np.abs(data), axis=1) > peak * 0.04)) - int(0.002 * RATE))
    data = data[start:] / peak
    fade = min(len(data) // 8, int(0.02 * RATE))
    data[-fade:] *= np.linspace(1, 0, fade)[:, None]
    return data


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


def analyse(pinned, records):
    for name, (files, octave) in PITCHED.items():
        for path in files:
            data = load(fetch(path, pinned, records))
            named = midi(path) + 12 * octave
            print(f"{name:12s} {Path(path).name:40s} named={named} detected={fundamental(data):.2f}")
    for files in HITS.values():
        for path in files:
            fetch(path, pinned, records)



class Sampler:
    """Nearest-sample playback with polyphase repitching and constant-power pan."""

    def __init__(self, pinned, records):
        self.pinned, self.records = pinned, records
        self.pitched, self.hits, self.cache = {}, {}, {}

    def sample(self, path):
        if path not in self.cache:
            data = load(fetch(path, self.pinned, self.records))
            self.cache[path] = data[: 10 * RATE]
        return self.cache[path]

    def zones(self, name):
        if name not in self.pitched:
            files, octave = PITCHED[name]
            self.pitched[name] = sorted((midi(path) + 12 * octave, path) for path in files)
        return self.pitched[name]

    def note(self, name, pitch):
        key = (name, pitch)
        if key not in self.cache:
            root, path = min(self.zones(name), key=lambda zone: (abs(zone[0] - pitch), zone[0] < pitch))
            shift = pitch - root
            if abs(shift) > 6:
                raise ValueError(f"{name} {pitch} is {shift} semitones from its nearest sample")
            data = self.sample(path)
            if shift:
                # Playing faster raises pitch: fewer output samples per input sample.
                ratio = Fraction(2 ** (-shift / 12)).limit_denominator(200)
                data = resample_poly(data, ratio.numerator, ratio.denominator)
            self.cache[key] = data
        return self.cache[key]

    def hit(self, name, index):
        files = HITS[name]
        return self.sample(files[index % len(files)])

    def timpani(self, pitch):
        """Timpani hits are tuned drums; pick and nudge the closest one."""
        if "timpani_tuning" not in self.cache:
            self.cache["timpani_tuning"] = [fundamental(self.hit("timpani", i)) for i in range(len(HITS["timpani"]))]
        tuning = self.cache["timpani_tuning"]
        key = ("timpani", pitch)
        if key not in self.cache:
            index = int(np.argmin([abs(t - pitch) for t in tuning]))
            ratio = Fraction(2 ** (-(pitch - tuning[index]) / 12)).limit_denominator(200)
            self.cache[key] = resample_poly(self.hit("timpani", index), ratio.numerator, ratio.denominator)
        return self.cache[key]


class Track:
    """A circular stereo buffer; anything ringing past the end wraps to the start."""

    def __init__(self, length=LENGTH):
        self.length = length
        self.data = np.zeros((length, 2))

    def add(self, sound, beat, gain=1.0, pan=0.0, hold=None, release=0.25):
        start = int(round(beat * BEAT * RATE))
        sound = sound[: self.length]
        if hold is not None:
            # Sustained notes stop after `hold` beats with a smooth release.
            end = min(len(sound), int((hold * BEAT + release) * RATE))
            sound = sound[:end].copy()
            fade = min(end, int(release * RATE))
            sound[end - fade:] *= np.linspace(1, 0, fade)[:, None] ** 2
        angle = (pan + 1) * np.pi / 4
        mixed = sound * np.array([np.cos(angle), np.sin(angle)]) * np.sqrt(2) * gain
        index = (start + np.arange(len(mixed))) % self.length
        np.add.at(self.data, index, mixed)


def room(seconds=2.4, seed=7):
    """A decorrelated stereo hall impulse: exponential noise tail, darker as it decays."""
    rng = np.random.default_rng(seed)
    count = int(seconds * RATE)
    t = np.arange(count) / RATE
    noise = rng.standard_normal((count, 2)) * np.exp(-6.9 * t / seconds)[:, None]
    early = sosfilt(butter(2, 7000, fs=RATE, output="sos"), noise[: count // 6], axis=0)
    late = sosfilt(butter(2, 2600, fs=RATE, output="sos"), noise, axis=0)
    late[: count // 6] = early * 0.6 + late[: count // 6] * 0.4
    late[: int(0.018 * RATE)] = 0
    return late / np.sqrt(np.sum(late ** 2) / 2)


def reverb(data, wet, impulse):
    """Circular convolution, so the hall tail of the last bar rings into the first."""
    wrapped = np.zeros_like(data)
    for channel in range(2):
        tail = fftconvolve(data[:, channel], impulse[:, channel])
        for offset in range(0, len(tail), len(data)):
            chunk = tail[offset: offset + len(data)]
            wrapped[: len(chunk), channel] += chunk
    return data * (1 - wet * 0.35) + wrapped * wet


def highpass(data, hz=32):
    # Two passes over a doubled buffer give a seam-free circular filter.
    sos = butter(2, hz, "highpass", fs=RATE, output="sos")
    doubled = np.concatenate([data, data])
    return sosfilt(sos, doubled, axis=0)[len(data):]


# D minor lament, one chord per two bars: (pitch classes, bass, bass fifth).
CHORDS = [([2, 5, 9], 38, 45), ([10, 2, 5], 34, 41), ([7, 10, 2], 31, 38), ([9, 1, 4], 33, 40),
          ([2, 5, 9], 38, 45), ([10, 2, 5, 9], 34, 41), ([4, 7, 10, 2], 40, 46), ([9, 1, 4, 7], 33, 40)]
# Plain hunt on four bells: every row is a permutation, and the eighth returns home.
HUNT = [[0, 1, 2, 3], [1, 0, 3, 2], [1, 3, 0, 2], [3, 1, 2, 0], [3, 2, 1, 0], [2, 3, 0, 1], [2, 0, 3, 1], [0, 2, 1, 3]]


def voice(tones, low, high):
    return [n for n in range(low, high + 1) if n % 12 in tones]


def lowest(pc, low):
    return low + (pc - low) % 12


def escapement(s):
    """The escapement: tick-tock on every beat, with a contrabass pizzicato pulse."""
    t = Track()
    for beat in range(BARS * 4):
        if beat % 2 == 0:
            t.add(s.hit("tick_hard" if beat % 4 == 0 else "tick", beat // 2), beat, 1.0 if beat % 4 == 0 else 0.85, -0.3)
        else:
            t.add(s.hit("tock", beat // 2), beat, 0.7, 0.3)
            if beat >= 32:
                t.add(s.hit("ghost", beat), beat - 0.25, 0.22, 0.1)
    for bar in range(BARS):
        tones, bass, fifth = CHORDS[bar // 2]
        # Plucks are damped after a beat so the clicks, not the bass, carry the pulse.
        t.add(s.note("pizz", bass), bar * 4, 0.2, -0.05, hold=1.4, release=0.3)
        t.add(s.note("pizz", fifth), bar * 4 + 2, 0.14, 0.05, hold=1.2, release=0.3)
        t.add(s.note("pizz", bass + 12 if bass + 12 <= 50 else bass), bar * 4 + 3.5, 0.09, 0, hold=0.4, release=0.2)
    return t


def movement(s):
    """The movement: harp gear-train arpeggios, change-rung glock and cello spiccato."""
    t = Track()
    for bar in range(BARS):
        tones, bass, _ = CHORDS[bar // 2]
        notes = voice(tones, 50, 76)
        shape = [0, 1, 2, 3, 4, 3, 2, 1]
        offset = 0 if bar % 2 == 0 else 1
        for step in range(16):
            if bar < 8 and step % 2:
                continue
            note = notes[min(len(notes) - 1, shape[step % 8] + offset + (2 if step >= 8 else 0))]
            accent = 0.62 if step % 4 == 0 else 0.42
            t.add(s.note("harp", note), bar * 4 + step / 4, accent, 0.35 * np.sin(step * np.pi / 8))
        bells = voice(tones, 81, 94)[-4:]
        row = HUNT[bar % 8]
        beats = range(4) if bar % 2 == 0 else (0, 2)
        for beat in beats:
            t.add(s.note("glock", bells[row[beat]]), bar * 4 + beat, 0.8 if beat else 0.95, 0.45)
        if bar >= 8:
            root = lowest(bass % 12, 50)
            for beat in (0, 0.5, 1.5, 2.5, 3.5):
                t.add(s.note("spic", root + (7 if beat == 2.5 else 0)), bar * 4 + beat, 0.5 if beat else 0.62, -0.4)
    return t


def tension(s):
    """Tremolo strings and tuned timpani; a cymbal swell crests on bars 9 and 1."""
    t = Track()
    for index, (tones, bass, _) in enumerate(CHORDS):
        beat = index * 8
        upper = voice(tones, 64, 81)
        for note, pan in ((upper[-1], 0.35), (upper[-3], -0.2)):
            t.add(s.note("violin_trem", note), beat, 0.42, pan, hold=8, release=0.5)
        t.add(s.note("cello_trem", lowest(bass % 12, 43)), beat, 0.36, -0.35, hold=8, release=0.5)
        t.add(s.timpani(lowest(bass % 12, 38)), beat, 0.85, 0.1)
        t.add(s.timpani(lowest(bass % 12, 38)), beat + 5.5, 0.4, 0.1)
    for step in range(16):
        t.add(s.timpani(lowest(9, 38)), 56 + step / 2, 0.22 + 0.5 * step / 15, 0.1)
    swell = s.hit("swell", 0)
    crest = int(np.argmax(np.max(np.abs(swell), axis=1))) / RATE / BEAT
    for target in (32, 64):
        t.add(swell, target - crest, 0.5, 0)
    return t


def chime(s):
    """Tubular bells on every chord change over a soft divisi string pad."""
    t = Track()
    for index, (tones, bass, _) in enumerate(CHORDS):
        beat = index * 8
        t.add(s.note("bells", lowest(bass % 12, 74)), beat, 0.6, 0)
        if index % 4 == 0:
            t.add(s.note("bells", lowest(bass % 12, 74) + 7), beat + 0.02, 0.35, 0.2)
        pads = voice(tones, 62, 76)
        for note, pan in ((pads[0], -0.3), (pads[2], 0.3)):
            t.add(s.note("viola", note), beat, 0.3, pan, hold=8, release=1.2)
        t.add(s.note("cello", lowest(bass % 12, 43)), beat, 0.2, 0, hold=8, release=1.2)
    t.add(s.hit("chimes", 0), 58, 0.3, 0.4)
    return t


def stinger(seconds, events):
    """A one-shot cue; the long buffer keeps the hall tail from wrapping."""
    t = Track(int(12 * RATE))
    for event in events:
        t.add(*event)
    return t, int(seconds * RATE)


def strike(s):
    root = 74
    return stinger(4.5, [(s.note("bells", root), 0, 0.8, -0.1), (s.note("bells", root + 7), 0.02, 0.5, 0.15),
                         (s.hit("gong_p", 0), 0, 0.6, 0), (s.timpani(38), 0, 0.9, 0.1),
                         (s.note("glock", 86), 0, 0.42, 0.4), (s.note("glock", 93), 0.5, 0.36, 0.45),
                         (s.note("violin_trem", 74), 0, 0.3, 0.3, 4, 1.2), (s.note("cello_trem", 50), 0, 0.36, -0.3, 4, 1.2)])


def unwind(s):
    events = [(s.hit("gliss", 0), 0, 0.6, 0.35), (s.hit("gong_f", 0), 0, 0.7, 0), (s.timpani(38), 0, 0.9, 0.1),
              (s.hit("crank", 0), 0, 0.5, -0.4), (s.hit("crank", 1), 0.75, 0.4, -0.3)]
    for step, note in enumerate([86, 81, 77, 74]):
        events.append((s.note("bells", note), step * 1.5, 0.7 - step * 0.08, 0.2 - step * 0.1))
    events += [(s.timpani(38), 4.5, 0.7, 0.1), (s.note("pizz", 26), 4.5, 0.9, 0)]
    return stinger(6.5, events)


def windup(s):
    swell = s.hit("swell_short", 0)
    crest = int(np.argmax(np.max(np.abs(swell), axis=1))) / RATE / BEAT
    events = [(s.hit("crank", i), i * 0.5, 0.35 + i * 0.1, -0.3 + i * 0.2) for i in range(4)]
    events += [(swell, 4.5 - crest, 0.45, 0), (s.note("bells", 74), 4.5, 0.75, 0), (s.note("bells", 81), 4.52, 0.45, 0.2),
               (s.timpani(38), 4.5, 0.85, 0.1), (s.note("pizz", 38), 4.5, 0.8, 0)]
    return stinger(5.5, events)


# name: (builder, hall wet, target RMS). Loop stems share one length and grid.
LOOPS = {"clock-escapement": (escapement, 0.16, 0.08), "clock-movement": (movement, 0.38, 0.10),
         "clock-tension": (tension, 0.34, 0.11), "clock-chime": (chime, 0.5, 0.09)}
CUES = {"clock-strike": strike, "clock-unwind": unwind, "clock-windup": windup}


def encode(name, data, loop):
    folder = "music" if loop else "audio"
    wav = CACHE / f"{name}.wav"
    dest = ROOT / f"assets/{folder}/{name}.vorbis"
    sf.write(wav, data, RATE, subtype="PCM_24")
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-v", "error", "-y", "-i", str(wav),
                    "-c:a", "libvorbis", "-q:a", "6", "-f", "ogg", str(dest)], check=True)
    decoded, _ = sf.read(dest, always_2d=True)
    assert np.max(np.abs(decoded)) < 0.95, name
    # Synchronized stems must decode to exactly the same length.
    assert not loop or len(decoded) == LENGTH, (name, len(decoded))
    return {"file": f"{folder}/{dest.name}", "duration": round(len(data) / RATE, 4), "loop": loop}


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    manifest = ROOT / "assets/audio/clock-credits.json"
    pinned = {entry["source"]: entry["sha256"] for entry in json.loads(manifest.read_text())["sources"]} if manifest.exists() else {}
    records = {}
    if "--analyse" in sys.argv:
        return analyse(pinned, records)
    sampler = Sampler(pinned, records)
    impulse = room()
    stems = {}
    for name, (build, wet, target) in LOOPS.items():
        data = highpass(reverb(build(sampler).data, wet, impulse))
        data -= np.mean(data, axis=0)
        rms = float(np.sqrt(np.mean(data ** 2)))
        stems[name] = data * min(target / rms, 0.75 / float(np.max(np.abs(data))))
    # Full mix at the loudest runtime levels must stay clear of clipping.
    loudest = float(np.max(np.abs(sum(stems.values()))))
    scale = min(1.0, 0.9 / loudest)
    outputs = []
    for name, data in stems.items():
        outputs.append(encode(name, data * scale, True))
        print(name, f"peak={np.max(np.abs(data * scale)):.3f} rms={np.sqrt(np.mean((data * scale) ** 2)):.3f}")
    # Rewind: the dial's music played backwards; reversed hall tails swell into each chord.
    rewind = (stems["clock-movement"] + stems["clock-chime"])[::-1] * scale * 0.8
    outputs.append(encode("clock-rewind", rewind, True))
    for name, build in CUES.items():
        track, length = build(sampler)
        data = reverb(track.data, 0.42, impulse)[:length]
        fade = int(0.6 * RATE)
        data[-fade:] *= np.linspace(1, 0, fade)[:, None] ** 2
        data *= min(0.75 / float(np.max(np.abs(data))), 0.16 / float(np.sqrt(np.mean(data ** 2))))
        outputs.append(encode(name, data, False))
    preview = np.tile(sum(stems.values()) * scale, (2, 1))
    sf.write(CACHE / "clock-full-mix-preview.wav", preview, RATE, subtype="PCM_16")
    manifest.write_text(json.dumps({
        "title": "时之君主 (The Clock Sovereign)", "bpm": BPM, "bars": BARS,
        "license": "CC0-1.0", "licenseUrl": "https://creativecommons.org/publicdomain/zero/1.0/",
        "collections": [f"{REPO}/tree/{COMMIT}"],
        "credit": "Versilian Studios Chamber Orchestra 2 Community Edition (VSCO-2-CE), Sam Gossner / Versilian Studios",
        "changes": "Original score rendered from individual samples: 48 kHz conversion, onset trimming, repitching, "
                   "panning, synthetic hall reverb, loop-wrapped tails, level matching; Vorbis encoding.",
        "outputs": outputs,
        "sources": [{"source": url, "sha256": digest} for url, digest in sorted(records.items())]}, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
