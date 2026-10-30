# Slingbreak · native Godot

Independent Godot 4.7.2 implementation. GDScript owns gameplay, collision and
prediction, all 81 skill hooks, four Boss state machines, persistence and input.
Godot CanvasItems draw the battlefield; Controls/Tweens draw the interface;
Godot Vorbis players, filters, delay and panning buses produce audio.

The project runs and exports using only `project.godot`, `export_presets.cfg`,
`src/`, `scenes/` and `assets/`. It requires no browser source, QuickJS, Skia,
GDExtension, Node process or asset extraction during a build. The separate
`game/` project is retained for independent behavior and visual comparisons.

This is a native preview, with remaining fidelity and device acceptance work
recorded in [the acceptance matrix](../docs/godot-port.md). Passing the native
checks does not establish complete gameplay or audiovisual agreement.

## Run

Use Godot 4.7.2 and matching export templates:

The project declares the Godot 4.7 feature level. Export and regression tools
require **4.7.2 stable** explicitly, preventing older editors or mismatched
engine versions from silently producing builds. Install the matching
`4.7.2.stable` export templates before exporting.

```sh
python3 godot/tools/build_runtime.py
godot --headless --path godot --editor --import
godot --path godot
```

`build_runtime.py` validates existing assets. It does not generate a runtime or
download a compiler. Frozen content includes skills, achievements, both palettes,
Lucide vectors, three raw fonts and their licenses, 24 vector contour frames per
skill, 180 effect voice samples, 903 music instrument samples, and adaptive score
patterns/transition recipes. Standard Ogg Vorbis data uses the `.vorbis` suffix
and is loaded with Godot's built-in decoder. The cache budget is 32 MiB of
compressed stream data; this is not a bound on total engine/decoder memory.

Skill strokes include 81 compressed, offline-baked native mesh bundles (24 contour
frames per skill). The original vector contours remain the loading fallback.
Their manifest fingerprints bind them to `assets/signatures.json`; exports reject
missing/stale bundles. Only when changing the contours or stroke bake, regenerate:

```sh
godot --headless --path godot --script res://tools/bake_strokes.gd
python3 godot/tools/build_runtime.py
python3 godot/tools/run_checks.py --godot /absolute/path/to/godot --gui --test native_stroke_test
```

The mesh cache holds 32 skill bundles. Retained display lists can keep additional
references, so this is not a bound on total RAM. Native progress writes use one
worker with atomic rename/latest-request coalescing; background, import/reload and
exit wait for completion. The single-threaded Web export retains synchronous saves.

## Preview

Visual feedback for a single edit, without exporting or opening a browser (about
5 s per shot). The real game runs under Xvfb with the GL compatibility renderer,
jumps to a page and saves one PNG:

```sh
python3 godot/tools/preview.py --page draft
python3 godot/tools/preview.py --page shop --theme dark
python3 godot/tools/preview.py --page boss --seconds 6
python3 godot/tools/preview.py --page game --watch
```

`--page` accepts `draft`, `game`, `shop`, `equipment`, `achievements`, `library`,
`settings`, `detail`, `swap`, `reset`, `report`, `pause`, `boss` and `intro`;
`--seconds` advances the simulation first (projectile, hit and break effects);
`--watch` re-captures whenever `src/`, `scenes/`, `assets/` or `project.godot`
changes, so the PNG can stay open in an image viewer. Output defaults to
`agent-tmp/godot/preview/preview-<page>.png`; `--out` overrides it. The tool is
dev-only and excluded from exports. It shortens the visual loop only: the Web
export and the browser checks remain the authority for browser behaviour.

## Android

Configure Android SDK, JDK and the debug keystore in Godot Editor Settings. No
NDK or custom native extension is needed. Then:

```sh
python3 godot/tools/build_android.py --godot /absolute/path/to/godot
python3 godot/tools/check-apk.py agent-tmp/godot/export/slingbreak-godot-native-preview.apk
```

Output: `agent-tmp/godot/export/slingbreak-godot-native-preview.apk`, arm64 only,
version code 4, `0.4.0-godot-native-preview`. The separate preview package is
`io.github.apricityx.slingbreak.godot.preview`. It has no Internet permission and
does not access the X5 application's saves. Install over the prior Godot preview
using the same debug certificate to retain its private save. Do not uninstall or
clear data when updating.

The exporter copies a fresh staging project into ignored `agent-tmp/godot/staging/`,
validates asset fingerprints, imports and exports that project, then checks the
APK's actual resource contents. Font `.bin` files and licenses must be present;
an ignored font directory is not exportable. Signature and 16 KB ZIP alignment
can be checked with Android SDK `apksigner verify --verbose --print-certs` and
`zipalign -c -P 16 4`. The preview is debug-signed, not a release build.

## Linux

Desktop export, x86_64 only, single self-contained binary with the PCK embedded:

```sh
python3 godot/tools/build_linux.py --godot godot
./agent-tmp/godot/export/slingbreak-godot-native-preview.x86_64
```

Output: `agent-tmp/godot/export/slingbreak-godot-native-preview.x86_64` (about
145 MB). It uses the GL compatibility renderer, so it needs the host's OpenGL 3.3
drivers plus X11 or Wayland; nothing else is bundled and there is no installer.
The binary is the same staged project as the Android and Web exports, so it runs
no browser code. Requires Godot's Linux export templates in
`~/.local/share/godot/export_templates/<version>/`.

## Web

The stock Godot 4.7.2 template uses Wasm exception-based longjmp and SIMD, which
cannot run on Chromium 89. Build the compatible template once with SCons >= 4.4
and Emscripten 4.0.20. Its source revision and output fingerprint are recorded:

```sh
git clone --depth 1 --branch 4.0.20 https://github.com/emscripten-core/emsdk.git agent-tmp/godot/emsdk
agent-tmp/godot/emsdk/emsdk install 4.0.20
agent-tmp/godot/emsdk/emsdk activate 4.0.20
python3 godot/tools/build_web_template.py --emsdk agent-tmp/godot/emsdk
```

This downloads the pinned engine source into ignored `agent-tmp/godot/` and builds
single-threaded Godot with Emscripten's JavaScript longjmp, without SIMD, and with
the GLES3 global uniform reserve reduced to 128 vec4 entries. The latter keeps
Godot's built-in WebGL 2 shaders within the old driver's uniform budget (261
fragment vectors and 16 KiB uniform blocks on the tested Chromium 89 renderer);
the native game does not use global shader parameters. Unused GLES3 3D light and
roughness arrays are also compiled at minimum sizes because this project has no
3D scenes. It keeps the 2D renderer, Controls, fonts and audio. Subsequent
exports reuse the template and reject
missing or mismatched metadata:

```sh
python3 godot/tools/build_web.py --godot /absolute/path/to/godot
python3 godot/tools/serve_web.py --host 127.0.0.1 --port 8083
```

Output: `agent-tmp/godot/web-native/`; deploy the entire directory. This uses the
compatible single-threaded Godot template, without extension support. The `.js`
files in this export are Godot's WebAssembly loader/audio glue. Game rules are
compiled GDScript inside the PCK; no reference-game JavaScript is included.
The server serves only the export directory with WebAssembly MIME and isolation
headers. HTTPS is appropriate for remote deployments. Web startup and Canvas
input are checked with `godot/tools/check-web.cjs`; set `CHROME89_PUPPETEER` and
`CHROME_BIN` to an installed Puppeteer module and actual browser binary.
Browser compatibility is a separate gate from Android's native runtime.
Set `GODOT_WEB_CHECK_OUT` to keep old-browser and modern-browser evidence in
separate directories. The checker records startup errors, pending requests,
console output and screenshots; the native GUI gate verifies semantic input results.

## Architecture

- `src/core/`: fixed-step simulation, swept geometry, data and validated saves.
- `src/skills/`: skill hooks, source-arrow attribution and bounded delayed work.
- `src/bosses/`: Eye, Forge, Serpent and Clock mechanics and phase director.
- `src/render/`: CanvasItem board, signatures, trails, local core halo shader and Boss visuals.
- `src/effects/`: bounded effects and independent visual randomness.
- `src/audio/`: 96-player pool, paused gameplay/UI routing, adaptive score mixes.
- `src/ui/`: native pages, modal stack, card reels/flights, reports and HUD.
- `assets/`: standalone versioned content and audiovisual data.
- `tests/`, `tools/`: native regression and independent reference verification;
  excluded from exports.

Godot progress uses `user://slingbreak-progress.json`. Import/export uses the
explicit `slingbreak-progress` version-1 envelope. Imports validate before replacing
the live session; native saves are separate from browser/X5 storage. Reload keeps
board progress and Boss health/phase, while active attacks currently restart from
their safe phase setup. Full active-ability restoration remains pending.

## Verify

```sh
python3 godot/tools/run_checks.py --godot /absolute/path/to/godot
python3 godot/tools/run_checks.py --godot /absolute/path/to/godot --gui
python3 godot/tools/run_checks.py --godot /absolute/path/to/godot --test native_prediction_test
node godot/tools/capture-rules.cjs
python3 godot/tools/run_checks.py --godot /absolute/path/to/godot --test native_reference_test
node --test tests/*.test.cjs bench/*.test.mjs
```

Without a desktop display the GUI gate uses `xvfb-run`. It still invokes a real
graphics driver; a headless run cannot validate CanvasItem rendering. Checks
fail on script errors and leaked instances even when Godot exits with code 0.
Logs and screenshots are under ignored `agent-tmp/godot/`.

Native rule checks exercise individual skills, attribution, rewards, saves and
Boss progression. The render matrix draws signatures at three ages in both
themes, plus Boss phases and selected attacks. Forced visual fixtures and forced
HP phase progression are coverage tests, not full behavior comparisons. Audio
tests use Dummy output and validate scheduling, routing, transition voices,
mixing control and cleanup, not hardware latency or listening fidelity.

The independent rule oracle executes the browser's rules and Matter.js directly.
It compares 85 builds and 1,800 free-flight samples (normal steps, Timeslip,
release, wind and variable steps). Projectile integration stays in 64-bit scalar
values; CanvasItems and collision geometry read a float32 Vector2 view. Contact
response and steering writes update the same motion state. These comparisons
do not establish collision order or full Boss counterplay agreement.

The five-minute soak measures 18,000 simulation updates with full effects enabled;
it excludes GPU rendering, real audio and mobile scheduling. Do not interpret its
percentiles as Android frame-rate evidence.

For separate, repeatable CPU samples of frozen UI copies, ordinary battlefield
submission, and a fixed flying/impact workload, run without other checks in parallel:

```sh
xvfb-run -a godot --path godot --audio-driver Dummy --disable-vsync --script res://tests/native_performance_probe.gd
```

The probe reports board updates, vector submission and simulation separately.
Separate background/halo draw callbacks and GPU execution are excluded.
Its host frame intervals include the desktop graphics driver and scheduler;
neither these values nor CPU percentiles establish phone FPS. The GUI regression
gate includes retained-display-list invalidation for HP, impact flashes, freeze,
mark expiry, theme changes, moving targets, entrance motion and removed bricks.

For the separate mass-effects and full-queue selection workload:

```sh
xvfb-run -a godot --path godot --audio-driver Dummy --disable-vsync --script res://tests/native_spike_probe.gd
```

This probe holds 80 overlapping signatures and 300 particles, exercises 12 real
draft-to-slot choices and 20 forced chain reactions. It excludes real audio/disk
saves and does not establish phone FPS. The GUI gate compares 972 actual original-
polyline/baked-mesh rasters, and tests fixed flight layout/surviving slot identity.

For the V2 skill-effect regression and overlapping playback workload:

```sh
python3 godot/tools/run_checks.py --godot godot --gui --test native_v_effects_test
```

This test plays `echo`, `piercer`, `seeking` and `ricochet` one at a time until
each event expires. It also covers the common `bomb`, `lightning`, `frost`,
`prism` and `gold` special-brick effects, including the frost wave and target
shards. It then continuously overlaps skill and special-brick effects for 240
rendered frames, with positions wrapped into the visible battlefield and the
opening draft UI closed. The test verifies event identity, lifecycle cleanup and the
64-event presentation budget, and reports p50/p95/p99/max host frame intervals
plus board draw time (both the base and foreground callbacks).
Frame intervals include the desktop graphics driver and scheduler; the 60/30 FPS
over-budget counts are diagnostics, not a phone FPS acceptance gate.

For per-effect performance attribution, run this separate probe **alone**, not
alongside checks, exports or other Godot instances:

```sh
xvfb-run -a godot --path godot --audio-driver Dummy --disable-vsync --script res://tests/native_effects_probe.gd -- --samples=90 --warmup=20
```

It renders a fixed 60-brick board without UI/audio, with emitters kept in view.
Single-instance and full-queue fixtures cover each V2 skill, common special
bricks, frozen shells, ice shards and ordinary breaks. CPU process/draw, retained
sync, skill/special draw callbacks, draw calls and post-draw wall intervals are
reported separately. Impact ages sweep repeatedly while populations stay fixed;
this is a controlled peak-load comparison, not a gameplay FPS benchmark.
The probe additionally instruments the foreground, explosion-debris and ice-shard
child draw callbacks; timing only `Board._draw()` misses those costs. Frozen-shell
and shader work is reflected in renderer/wall measurements, not GDScript draw
submission alone.

Test-only A/B cases hide explosion volumes, substitute a flat material or hide
the explosion/frost layers without changing event queues or production shaders.
Use `--case=bomb,mixed` (comma-separated prefixes), `--resolution=0.5`, `--repeats=3` and
`--output=res://../agent-tmp/godot/custom-effects-report.json` to narrow or repeat
comparisons. Default output is ignored `agent-tmp/godot/effects-probe.json`.
Use `--age-start=0.06 --age-end=0.12` for a separate always-visible lightning
peak test: the default 0.06–0.36s sweep includes its intentionally transparent
tail, so its median alone is not evidence that the peak meets a frame budget.
`--capture=res://../agent-tmp/godot/effects-probe.png` captures the first
`mixed_full` fixture outside its timed loop. Reports also record renderer source
hashes so results can be tied to an otherwise busy working checkout.
These measurements include the active renderer (which can be llvmpipe software
rendering on Xvfb), but do not explicitly wait for GPU completion or establish
Android/device frame rates.

Lightning, coins, ice shards and explosion debris now use shared immutable mesh
templates with bounded MultiMesh instances. Vertex shaders retain the original
trajectories and envelopes; invisible tails are no longer submitted. Fire-volume
and persistent-frost shaders are unchanged. The foreground layer preserves arrows
and damage text above special hits, below the existing fire/frost overlays.
GL Compatibility custom data is half-float: wrapped seeds are split into high/low
channels to avoid phase loss in long sessions, and explicit bounds include vertex
shader expansion at screen edges.

```sh
python3 godot/tools/run_checks.py --godot godot --gui --test native_effect_batch_test
python3 godot/tools/preview_effects.py --skills brick_lightning brick_gold brick_frost brick_bomb
```

The batch regression covers capacity, expiration/reset, shared template ownership,
float payloads, reduced mode, actual graphics visibility, offscreen emitters and
foreground ordering. See `../docs/godot-effects-performance.md` for measured results
and limitations.

Independent UI references are captured from the shipped browser page:

```sh
CHROME89_PUPPETEER=/absolute/path/to/puppeteer node godot/tools/capture-interface.cjs
godot --path godot --audio-driver Dummy --script res://tests/interface_capture.gd
python3 godot/tools/compare-interface.py
```

The comparator checks sampled outer geometry and produces side-by-side images;
it is not a pixel or animation agreement gate. Historical compatibility sources
and artifacts are locally archived under ignored
`agent-tmp/godot/legacy-compatibility/`; they are not project dependencies and their
former comparison results do not apply to the current native implementation.
