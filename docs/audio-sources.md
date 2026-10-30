# Audio Sources

## Brick explosion

- File: `godot/assets/audio/brick-explosion.wav`
- Source: SFXMint, “Impact Explosion 10”
- License: CC0 1.0
- Download URL: <https://sfxmint.com/dl/impact-explosion-10.wav>

This is a standalone sampled effect used only by the bomb brick. The other
effect cues remain the existing generated Vorbis catalogue until they are
replaced deliberately.

## Normal brick break

- Creator: Kenney, **Impact Sounds (1.0)**, 2019 (impact/foley collection).
- Official page: <https://kenney.nl/assets/impact-sounds>
- License: **CC0 1.0**, <https://creativecommons.org/publicdomain/zero/1.0/>
- Download mirror: `https://cc0-sounds.netlify.app/sounds/kenney_impactsounds/Audio/`
- Original files → project files (bytes are unchanged; only extensions/names change):
  - `impactMining_000.ogg` → `godot/assets/audio/brick-break-1.vorbis`
  - `impactMining_001.ogg` → `godot/assets/audio/brick-break-2.vorbis`
  - `impactMining_002.ogg` → `godot/assets/audio/brick-break-3.vorbis`

The three variants rotate without consuming gameplay RNG. They play dry at
0.55 gain, replacing the first two (impact/noise) voices of the original break
recipe **only for normal bricks**. Both original combo-note voices, their
delays and wet routing remain intact. Normal and special breaks share the
existing 18 ms throttle; special brick recipes remain unchanged.

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
a hit. Each event plays one dry light-impact sample at 0.32 gain, with three
variants rotating independently of break variants and gameplay RNG. It shares
the existing 30 ms `tap` throttle. UI `tap` cues keep their original synthesis;
destruction cues and combo notes are unaffected.
