# Audio Sources

## Abyss Eye redesign

The Godot Eye encounter uses eight sampled effects rather than the previous
synthesized Eye cues. Sources are the CC0 **Horror Sound Pack**, **Horror Strings**,
and Kenney **Impact Sounds** collections distributed at <https://cc0-sounds.netlify.app/>.
The collection pages explicitly label these assets CC0. Exact source URLs, original
SHA-256 hashes, edited durations and collection/license links ship in
`godot/assets/audio/abyss-credits.json`.

`godot/tools/prepare_abyss_audio.py` downloads and caches the originals, removes DC,
converts to 48 kHz, trims cues, folds positional effects to mono, applies short edge
fades, limits peak to 0.75 and RMS to 0.12, and encodes Vorbis quality 6. Decoded
peaks must stay below 0.95. Run with numpy, scipy, soundfile and imageio-ffmpeg
installed. See [the encounter design](abyss-eye-redesign.md) for integration.

### Abyss Eye score (orchestral)

The Eye BGM is an original adaptive score (D minor, 96 BPM, 16 bars / 40 s) rendered
from real orchestral recordings in **Versilian Studios Chamber Orchestra 2 Community
Edition** (CC0-1.0), pinned at commit `440300901dfe9275fd84e0b7763af1f8443ae62e`:
contrabass, cello, viola and violin sections (sustain, spiccato, tremolo), F horn,
tenor trombone, tuba, flute, harp, glockenspiel, timpani, bass drum, gong, suspended
cymbal and Nepalese bells. `godot/tools/prepare_eye_music.py` composes the piece as
data and renders five sample-aligned loop stems (`eye-bed`, `eye-pulse`, `eye-stars`,
`eye-theme`, `eye-daze`) plus the `eye-shift` (impact at 1.58 s, the phase-rupture
frame) and `eye-finale` stingers. Processing: 48 kHz conversion, pre-roll trim,
detected-octave mapping, resample repitching (warned beyond ±5 semitones), crossfaded
sustain extension, a synthetic 2.3 s hall convolution with the tail folded into the
loop, body-RMS level matching, a shared headroom gain and Vorbis q6. Every source URL
and SHA-256 plus output hashes ship in `godot/assets/audio/eye-music-credits.json`;
rerunning verifies sources against those hashes. `--preview` writes an adaptive
walkthrough mix to `agent-tmp/godot/eye-music/preview.ogg`.

At runtime `abyss_music.gd` plays the stems through one `AudioStreamSynchronized`
(one clock, no drift) and mixes them from the encounter: the bed and starlight rise
with the intro; phases add the pulse and then the horn theme; a gaze charge thins the
pulse and drops to near-silence just before the sweep fires; exposure opens the harp
daze layer; doom raises everything; phase shifts and the collapse use the stingers.

### Crimson infection laser (V4)

Three additional 48 kHz positional cues are edited from Kenney **Sci-fi Sounds**
(CC0-1.0): <https://kenney.nl/assets/sci-fi-sounds>. The public download mirror is
<https://cc0-sounds.netlify.app/collection/sci-fi-sounds>.

- `computerNoise_002.ogg` → `eye-lock.vorbis` (0.22s acquisition).
- `laserLarge_001.ogg` + `forceField_003.ogg` → `eye-laser.vorbis` (0.9s transient/body/tail).
- `slime_001.ogg` + `forceField_003.ogg` → `eye-infect.vorbis` (0.42s conversion).

`godot/tools/prepare_eye_laser_audio.py` performs offline sample time/pitch edits,
mono conversion, layering, DC removal, 5ms attack / 40ms release and peak/RMS level
matching, then Vorbis quality 7 encoding. It uses source audio, no runtime
oscillator. `godot/assets/audio/eye-laser-credits.json` records source/output
hashes, durations, author and license; subsequent builds verify source hashes.
The laser starts at the live boundary and on each retarget, infection confirms
the actual brick conversion, and interruption/phase/death stop the sustained cue.

## 星渊巨蟒 sampled score

The Godot serpent fight streams three recorded orchestral loops instead of the
synthesized sequencer score. All three are CC0 on OpenGameArt (verified on each
page; the cc0-sounds mirror was not used because some of its "CC0" labels do not
match the originals):

- `serpent-stalk.vorbis` ← "Ancient Power Of Serpents" by josepharaoh99,
  <https://opengameart.org/content/ancient-power-of-serpents> (320 kbps MP3).
  Trimmed at 102.25 s and its 4.25 s decay folded over the head with an
  equal-power crossfade so it loops without a gap. Intro, eclipse, phase shift.
- `serpent-hunt.vorbis` ← "Determined Pursuit (epic orchestra loop)" by Emma_MA,
  <https://opengameart.org/content/determined-pursuit-epic-orchestra-loop>.
  Phases one and two.
- `serpent-frenzy.vorbis` ← "Epic Boss Battle [Seamlessly Looping]" by Juhani
  Junkala (SubspaceAudio), <https://opengameart.org/content/boss-battle-music>.
  Phase three onward, or rage.

`godot/tools/prepare_serpent_audio.py` caches the originals in
`agent-tmp/godot/serpent-audio/` (resumable; OpenGameArt is slow), pins their
SHA-256, converts to 48 kHz stereo, removes DC, levels to peak 0.8 / RMS 0.16 and
encodes Vorbis quality 6 (decoded peak < 0.95). Native loops keep their edges.
Sources, authors and hashes ship in `godot/assets/audio/serpent-credits.json`.
`godot/src/audio/serpent_music.gd` crossfades the stems from the fight state:
topple ducks the fight stem and closes the low-pass to 900 Hz, a dive muffles it
to 700 Hz, eclipse returns to the stalk bed at 1.4 kHz. A stem that has faded
below −40 dB stops, so the next phase starts that recording from its top.

## 熔炉巨像 sampled score

The Godot forge fight streams three recorded loops over a furnace bed instead of
the synthesized `scores.json` "forge" score (kept for the sequencer contract, no
longer played). All sources are CC0 on OpenGameArt, checked on each page, and all
three tracks sit in D minor, so the stems cross-fade without a key clash:

- `forge-smoulder.vorbis` ← "Sinister Boss Appears" by cynicmusic,
  <https://opengameart.org/content/sinister-boss-appears>. Ignition and phase one.
- `forge-stoke.vorbis` ← "Heavy Concept A Bass Master" from "Dramatic Boss
  Encounter" by cynicmusic, <https://opengameart.org/content/dramatic-boss-encounter>
  (drums and violin). Phase two.
- `forge-inferno.vorbis` ← "Boss Battle #2 [Symphonic Metal]" by nene,
  <https://opengameart.org/content/boss-battle-2-symphonic-metal>. The ZIP's file
  names are swapped (see the page); `boss_battle_#2_metal_opening.wav` is the
  seamless loop. Phase three or rage, and every meltdown.
- `forge-furnace.vorbis` ← "30 CC0 SFX loops" by rubberduck,
  <https://opengameart.org/content/30-cc0-sfx-loops>: `ambient_01` drone,
  `noise_01` low-passed to 1.1 kHz as fire roar, `water_boiling` as molten
  bubbling, each tiled to 24 s with cross-faded joints; the roar breathes twice
  per loop.

The two cynicmusic pieces end on a final hit and a ring-out. Each is cut one
beat-grid step before the head's first downbeat (Sinister 40.32 s, Heavy Concept
30.01 s), so the final hit lands on the next pass's downbeat, and the following
4 s / 6 s of decay is overlap-added onto the head under a cos² fade rather than
cross-faded, which keeps the opening attack at full level.

`godot/tools/prepare_forge_audio.py` (run with the audio venv that has
soundfile/scipy) caches the originals in `agent-tmp/godot/forge-audio/`, pins
their SHA-256, converts to 48 kHz stereo, removes DC, levels music to RMS 0.16
and the bed to 0.12, look-ahead limits peaks to 0.84 (Sinister peaks at 1.22 in
the source) and encodes Vorbis quality 6 (decoded peak < 0.95). Sources, authors,
archive members and hashes ship in `godot/assets/audio/forge-credits.json`.

`godot/src/audio/forge_music.gd` mixes the stems from the fight state:

- Ignition: the low-pass sweeps from 600 Hz open over the 3.4 s intro.
- Heat: the bed rises from 0.16 to 0.46 with the gauge.
- Open furnace: the bed roars to 0.7 and the fight stem ducks to 0.24 at 3.2 kHz.
- Meltdown: the inferno stem takes over.
- Phase shift: drops to the bed alone at 2.4 kHz, so the next stem starts from
  its top.
- Death: the music fades over 2.2 s while the low-pass closes to 500 Hz, and
  the embers settle before the board clears at 2.8 s.

A movie with the production mixer is recorded by `godot/tools/preview_forge_av.gd`:

```sh
cd godot && xvfb-run -a godot --path . --audio-driver Dummy --disable-vsync --write-movie ../agent-tmp/godot/forge-audio/av/forge-preview.avi --fixed-fps 30 --script res://tools/preview_forge_av.gd
```

## 时之君主 sampled score

The Godot clock fight plays an original 32 s D-minor lament (120 BPM, 16 bars:
Dm–B♭–Gm–A–Dm–B♭add9–Em7♭5–A7) rendered from individual orchestral samples
instead of the synthesized `scores.json` "clock" score (kept for the sequencer
contract, no longer played). Every sample comes from VSCO-2-CE by Sam Gossner
(CC0-1.0), pinned to commit `440300901dfe9275fd84e0b7763af1f8443ae62e` of
<https://github.com/sgossner/VSCO-2-CE>.

Five equal-length stems start on the same sample and loop together:

- `clock-escapement.vorbis`: claves tick, woodblock tock, ghost clicks from bar
  9, and damped contrabass pizzicato.
- `clock-movement.vorbis`: harp gear train (eighths, then sixteenths), glockenspiel
  rows in plain-hunt change-ringing order, and spiccato from bar 9.
- `clock-tension.vorbis`: violin and cello tremolo, timpani, and suspended-cymbal
  swells.
- `clock-chime.vorbis`: tubular bells, viola/cello pads, and wind chimes.
- `clock-rewind.vorbis`: the movement and chime stems reversed.

The cues `clock-windup` (intro: ratchet crank and glock gliss), `clock-strike`
(phase shift and stall: bells and gong) and `clock-unwind` (death) live in
`godot/assets/audio/`.

`godot/tools/prepare_clock_music.py` downloads the samples to
`agent-tmp/godot/clock-audio/samples/` (about 170 MB), checking them against the
SHA-256 values pinned in `godot/assets/audio/clock-credits.json`. It then
renders the stems:

- Each zone is repitched by at most ±6 semitones. Octaves are corrected from
  the detected pitch, and zones whose recording disagrees with their name are
  skipped.
- Notes are placed into a circular buffer, so release tails and reverb wrap
  into bar one.
- The stems get a synthetic hall convolution and are levelled so the summed
  mix peaks at or below 0.9.
- The output is encoded as Vorbis quality 6. The script asserts that the
  decoded peak is below 0.95 and that each loop decodes to exactly 1,536,000
  samples.

`--analyse` prints the detected pitch of every zone. The full mix, looped twice,
is written to `agent-tmp/godot/clock-audio/clock-full-mix-preview.wav`.

```sh
source ~/set_proxy.sh   # if GitHub raw is unreachable
agent-tmp/audio-venv/bin/python godot/tools/prepare_clock_music.py
```

`godot/src/audio/clock_music.gd` plays the stems through one
`AudioStreamSynchronized`, so the tick never drifts from the gear train. It
mixes them from the fight state, and the player's pitch acts as the mainspring:

- Intro: bells and pads only, at 2.4 kHz. The escapement starts once the dial
  is assembled.
- Phases one to three: the tension stem rises from 0 to 0.3, then to 0.56.
- Time stop: the ticks stop and the pitch sags to 0.55 at 900 Hz, like a stopped
  tape.
- Rewind: the reversed stem takes over at 6 kHz.
- Haste: the pitch rises to 1.12 and the ticks get louder.
- Midnight: all four forward stems play.
- Stall (exposed core): only the bells ring, at 3.2 kHz.
- Phase shift: bells only, at 3 kHz.
- Death: the music fades over 1.8 s while the pitch winds down to 0.7.

When every stem has faded out, the player stops, so the next entry restarts on
bar one.

## Bomb brick explosion

Replaces the former SFXMint `brick-explosion.wav` (removed). Each variant is
pre-mixed offline from four CC0 recordings, so a bomb is still one voice.

- Sources (mirror <https://cc0-sounds.netlify.app/sounds/>, licence files checked):
  - Warfork (Team Forbidden, CC0): `warfork-cc0/sounds/weapons/rocket_strong_explosion.ogg`,
    `warfork-cc0/sounds/misc/gibs_explosion.wav`
  - Kenney **Sci-fi Sounds** (CC0): `lowFrequency_explosion_000/001.ogg`, `explosionCrunch_000…004.ogg`
  - **75 CC0 breaking/falling/hit SFX** (CC0): `bfh1_rock_breaking_01…03.ogg`, `bfh1_rock_falling_01…04.ogg`
    (48 kHz, resampled to 44.1 kHz)
- Layers per variant (body, crunch, crack, debris), every layer differs between variants:
  - body: rocket / low-frequency blast, 55–1800 Hz band-pass, 60 ms hold + 220 ms decay,
    gentle tanh saturation so phone speakers keep the weight as harmonics
  - crunch: explosion crunch, 0.4–5.2 kHz band-pass, 4 ms late, 160 ms decay
  - crack: rock breaking / gibs, 2.2 kHz high-pass, 70 ms decay
  - debris: rock falling, 160 ms late, 0.7–9 kHz band-pass, 260 ms decay (rubble tail)
- Transient layers are levelled by peak (1 : 0.45 : 0.35 : 0.16), aligned to the first
  transient, 1.15 s long, 1 ms fade-in, 280 ms squared fade-out, then fitted to
  peak ≤0.86 and RMS ≤0.15; verified after decode. Encoded at Vorbis q9 (~120 kbps)
  so the crack and debris transients are not smeared.
- Rebuild: `godot/tools/prepare_brick_bomb.py --cache <dir>`; all sixteen source
  SHA-256 hashes are pinned. Output: `godot/assets/audio/brick-bomb-1…4.vorbis`.
- Runtime: four variants round-robin (no gameplay RNG) at 0.3 gain with a fixed small
  detune; chain depth adds +2.5 % pitch per level (capped at 6) so cascades climb.
  The 80 ms bomb density window is kept; the synthetic `boom` is no longer layered on top.

## Normal brick break

- Creator: Kenney, **Impact Sounds (1.0)**, 2019 (impact/foley collection).
- Official page: <https://kenney.nl/assets/impact-sounds>
- License: **CC0 1.0**, <https://creativecommons.org/publicdomain/zero/1.0/>
- Download mirror: `https://cc0-sounds.netlify.app/sounds/kenney_impactsounds/Audio/`
- Each project file blends the corresponding numbered source pair:
  - `impactGlass_heavy_000.ogg` + `impactMining_000.ogg` → `godot/assets/audio/brick-break-1.vorbis`
  - `impactGlass_heavy_001.ogg` + `impactMining_001.ogg` → `godot/assets/audio/brick-break-2.vorbis`
  - `impactGlass_heavy_002.ogg` + `impactMining_002.ogg` → `godot/assets/audio/brick-break-3.vorbis`

These are edited CC0 adaptations: each source is downmixed to mono, DC-removed,
aligned to its first fracture transient and cropped/padded to 240 ms. Glass and
stone are blended 85:15, band-limited to 650–7200 Hz (second-order Butterworth),
with an 85 ms exponential decay, 1 ms fade-in and 40 ms fade-out. This replaces
the previous 0.8–0.94 s stone/debris tail with a short crisp fracture, not an
increase in playback gain. Edited variants are level-matched with peak ≤0.65, RMS ≤0.055,
and the first 50 ms RMS is capped to the aligned original stone attack; decoded
Vorbis output is checked for peak ≤0.7 and RMS ≤0.065.

Rebuild with `godot/tools/prepare_brick_break.py --cache <temporary-directory>`
(Python dependencies: numpy, scipy, soundfile). The script verifies all six
original source SHA-256 hashes before processing.

The three variants rotate without consuming gameplay RNG. They play dry at
0.38 gain, replacing the first two (impact/noise) voices of the original break
recipe **only for normal bricks**. Both original combo-note voices, their
delays and wet routing remain intact. Normal and special breaks share the
existing 18 ms throttle; special brick recipes remain unchanged.

## Normal brick shatter (current)

Supersedes the `brick-break-*` set above at runtime (those files stay for
reference; `sound_engine.gd` no longer loads them).

- Creator / license: Kenney, **Impact Sounds (1.0)**, CC0 1.0 (same pack and mirror as above).
- Each variant is pre-mixed offline from three sources, so a break is still one voice:
  - body: `impactPunch_heavy_00N.ogg`, 90–750 Hz band-pass, 50 ms decay (weight)
  - crack: `impactGlass_heavy_00N.ogg`, 1.4 kHz high-pass, 50 ms decay (fracture)
  - grit: `impactMining_00(N+1).ogg`, 0.9–6 kHz band-pass, 12 ms late, 70 ms decay (crumble)
  - N = 0…3 → `godot/assets/audio/brick-shatter-1…4.vorbis`
- Layers are mixed by RMS (0.5 : 1 : 0.35), aligned to the first transient,
  260 ms long, 0.8 ms fade-in, 50 ms fade-out; peak ≤0.7, RMS ≤0.075, verified
  after Vorbis decode. Sub-200 Hz stays under ~12 % of the energy so phone
  speakers keep the crack.
- Rebuild: `godot/tools/prepare_brick_shatter.py --cache <dir>`; all twelve
  source SHA-256 hashes are pinned.
- Runtime: four variants round-robin (no gameplay RNG) at 0.4 gain, each with a
  fixed small detune, plus +1.2 % pitch per arrow kill (capped at 12 kills).
  Combo notes, delays, wet routing and the 18 ms throttle are unchanged.

## Brick hit (not destroyed)

- Creator / pack: Kenney, **Impact Sounds (1.0)**, 2019.
- Official page: <https://kenney.nl/assets/impact-sounds>
- License: **CC0 1.0**, <https://creativecommons.org/publicdomain/zero/1.0/>
- Download mirror: `https://cc0-sounds.netlify.app/sounds/kenney_impactsounds/Audio/`
- Original files → project files (unchanged Vorbis bytes):
  - `impactGeneric_light_000.ogg` → `godot/assets/audio/brick-hit-1.vorbis`
  - `impactGeneric_light_001.ogg` → `godot/assets/audio/brick-hit-2.vorbis`
  - `impactGeneric_light_002.ogg` → `godot/assets/audio/brick-hit-3.vorbis`

`brick_hit` replaces the synthesized impact/noise pair when any brick survives
a hit. Each event plays one dry light-impact sample at 0.22 gain, with three
variants rotating independently of break variants and gameplay RNG. It shares
the existing 30 ms `tap` throttle. UI `tap` cues keep their original synthesis;
destruction cues and combo notes are unaffected.

## Comfortable playback mix

The bomb samples play at 0.3 gain with an 80 ms density window even for
priority requests, preventing simultaneous bomb chains from stacking full-level
samples. Heavy synthetic events (`boom`, `win`, `core`, `shatter`, `forge`,
`meteor`, `clang`, `abyss`, `devour`) use 0.4–0.6 event gain.
The effects bus reserves 3 dB of headroom and uses a compressor (−12 dB threshold,
6:1 ratio, 1 ms attack, 120 ms release, no makeup gain) for overlapping effects.
UI and music buses and the user's saved volume are unchanged. Compression reduces
peaks but is not a hard peak ceiling or a guarantee about physical speaker volume;
device/headphone listening still needs verification.

## Arrow launch and frost

**RPG Sound Package / Heroes of Hawks Haven — Tuomo Untinen (Reemax).**
Licensed under **Creative Commons Attribution 3.0 Unported (CC-BY 3.0)**.

- Source: <https://opengameart.org/content/rpg-sound-package>
- License: <https://creativecommons.org/licenses/by/3.0/>
- Archive: <https://opengameart.org/sites/default/files/soundpack.zip>
- `soundpack/combat/bow.wav` → `godot/assets/audio/arrow-shoot.vorbis`
- `soundpack/spells/frost.wav` → `godot/assets/audio/frost-freeze.vorbis`
- The author describes frost as ice crushed by hand, not synthesized glass.

Changes: mono 44.1 kHz source audio was trimmed, filtered, faded, level-adjusted
and encoded as Ogg Vorbis. Bow is DC-removed and peak-scaled to 0.65, cropped to
0.300462585–0.66 s (immediate release, excluding the slow lead-in), with a
6.5 kHz second-order low-pass, 2 ms attack fade and 60 ms fade-out.

Frost now uses a **200 ms** isolated ice fracture rather than the previous
840 ms sequence of ice handling. The mono source is band-limited to 1.1–8 kHz
(second-order Butterworth); the strongest 4 ms energy window locates the crack,
with a 2 ms lead-in (source crop starts at about 0.517347 s). After cropping,
DC removal, a 45 ms exponential decay, 0.7 ms fade-in and 25 ms fade-out remove
the rumbling/rustling tail without slowing down playback or increasing runtime
gain. Preparation caps peak at 0.5 and RMS at 0.04; decoded Vorbis is checked
for peak ≤0.55 and RMS ≤0.045. Rebuild with
`python3 godot/tools/prepare_frost.py --archive <soundpack.zip>` (numpy, scipy,
soundfile required).

These are edited adaptations, not the unmodified original recordings.
Source WAV SHA-256:

- Bow: `d620c9d49ed7e1eb2d69c3dce7b440ce7fed46d7e8e7fd925f641af0e7322f85`
- Frost: `82d0406e9f7c4a363a14389d50ae96046a2f75cef43d73d51a4811ba6e131d0a`

`shoot` plays one dry sample at 0.24 gain, with a 65 ms density window;
`frost` plays one dry sample at 0.22 gain, with a 120 ms density window,
including priority chains. Both replace their entire synthetic recipe and
retain pause, mute, pan and effects-bus compression. Arrow launch includes
the echo skill's existing `shoot` event; frost covers frost bricks and the
existing frost skill events. Generic `shatter` and UI cues are unchanged.

Attribution, source/license links and modification notice are also available
in the game's Settings panel, backed by the shipped `assets/audio/credits.json`.
Retain these credits and this source notice when redistributing these assets.

## UI cues (sampled)

Card draft, reel and reward cues are pre-mixed from real recordings; each UI
event still plays one dry voice on the `SlingUI` bus. All sources are **CC0 1.0**:

- **Kenney — Casino Audio** (<https://kenney.nl/assets/casino-audio>, mirror
  <https://cc0-sounds.netlify.app/collection/kenney_casinoaudio/>): chip
  collisions/stacks/lays and card shoves/slide supply the sub-2 ms clicks.
- **VSCO-2-CE**, Sam Gossner / Versilian Studios
  (<https://github.com/sgossner/VSCO-2-CE>, commit
  `440300901dfe9275fd84e0b7763af1f8443ae62e`): medium xylophone and
  glockenspiel notes, claves, triangle and bell tree supply the tuned body and air.

| Cue | File(s) | Content | Gain |
| --- | --- | --- | --- |
| `tap` (UI only) | `ui-tap-1…3.vorbis` | claves click + 110 ms xylophone tok, rotating | 0.30 |
| `tick` (UI only) | `ui-tick-1…4.vorbis` | 35 ms chip-collision clicks, rotating | 0.30 |
| `deal` | `ui-deal.vorbis` | three card snaps on the 70 ms deal stagger | 0.22 |
| `pick` | `ui-pick-1…3.vorbis` | chip click + xylophone/glock, richer for blue/gold (`n`) | 0.22 |
| `whoosh` | `ui-whoosh.vorbis` | card slide swish, 900 Hz–12 kHz | 0.22 |
| `slot` | `ui-slot.vorbis` | stacked chips + card snap + low xylophone tok | 0.45 |
| `chime` (UI only) | `ui-chime.vorbis` | blue reveal: glock dyad over xylophone attack | 0.30 |
| `gold` (UI only) | `ui-gold.vorbis` | gold reveal: glock arpeggio, triangle, bell-tree glitter | 0.35 |
| `reroll` | `ui-reroll.vorbis` | chip tumble settling on a glock note | 0.25 |
| `upgrade` (also gameplay) | `ui-upgrade.vorbis` | ascending xylophone/glock run + triangle | 0.20 |

`tap`, `tick`, `chime` and `gold` requests without `ui:true` (gameplay taps,
clock/serpent bosses, gold bricks) keep their synthesized `cues.json` recipes.

Changes: 48 kHz mono, DC removal, transient alignment, per-layer Butterworth
high-pass (300 Hz–3.5 kHz; nothing below 300 Hz reaches phone speakers),
resampling by at most 4 semitones between recorded notes, exponential trims,
1 ms fade-in, layering, peak 0.8 and Vorbis q8. Runtime gains match the 50 ms RMS
of the replaced synthetic cues. Rebuild with
`python3 godot/tools/prepare_ui_audio.py --cache <temporary-directory>` (numpy,
scipy, soundfile, imageio-ffmpeg); it downloads and verifies all 22 pinned
source SHA-256 hashes and writes `godot/assets/audio/ui-credits.json`.
