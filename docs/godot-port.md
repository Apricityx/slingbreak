# Godot port acceptance · independent native runtime

The current scope discards the browser runtime and moves gameplay, interface,
audio and effects to Godot. Small visual differences are acceptable; the target
is close reproduction of the browser game's appearance and behavior.

## Implementation boundary

The active project runs no JavaScript and uses no QuickJS/Skia extension. Godot
owns fixed-step GDScript simulation, swept collisions and prediction, skill/Boss
state machines, CanvasItem rendering, native controls and motion, Vorbis audio,
input, lifecycle and saves. Builds copy only `src/`, `scenes/`, `assets/` and two
project configuration files into a fresh staging directory. They neither read
nor package `game/`. Web exports use Godot's own JavaScript/WASM loader, with
compiled GDScript rules in the PCK.

The browser project remains an independent reference. Fonts, vectors, palettes,
81 skills, achievements, voice samples, adaptive score data and effect profiles
are frozen as standalone assets. Each skill has 24 sampled signature contours;
playback draws native vectors. UI perspective flips currently use 2D scale
motion. No performance option is forced on to approximate fidelity.

Godot saves remain separate. Browser progress requires explicit import of its
`slingbreak-progress` envelope. No WebView profile or X5 save is shared or modified.
The preview retains package `io.github.apricityx.slingbreak.godot.preview` and its
debug signing identity for updates without clearing progress.

## Evidence and remaining work

| Area | Current evidence | Remaining acceptance |
| --- | --- | --- |
| Independence | Clean staging Android/Web exports; source contains no old runtime dependency; actual resource contents checked; Chrome 131 startup | Chromium 89 custom-template startup and Android hardware startup |
| Physics | Independent Matter free-flight comparisons at normal, slow, changing and wind steps; 64-bit integration; sweep/miss/tunnelling and prediction invariants | Collision order across obstacles/Bosses and all steering paths |
| Skills | All 81 IDs have native hooks; 85 independent numerical build comparisons; individual execution bounded; delayed lightning attribution and FIFO draft verified | Conditional activation and more skill combinations |
| Achievements/rewards | Single-arrow threshold, no duplicate payment and fifth-level reroll grant tests | Every achievement condition, child/source arrow combinations, report reconciliation |
| Bosses | Eye, Forge, Serpent, Clock native state machines; health/phase save/reload and forced phase/death progression checks | Full attacks/counterplay, live resistance/reward agreement and active-ability restoration |
| Saves | Envelope, board, counters, flags, settings and Boss validation; JSON roundtrip and natural Boss deck restore tests | More malformed inputs; legacy balance migration; active attack restoration; Android file dialogs |
| Themes/board | Native light/dark captures; fonts and licenses packaged; board/aim/core paths | All visual states, OS theme notifications and raster/spacing refinement |
| Effects | Native signatures/trails/fields/particles/rings/beams/glow/shake; local GPU core halo; bounded pools | Independent dynamic comparisons, blur/glow strength and all Boss attack visuals |
| UI | All gameplay pages/dialogs rebuilt; gradient deal glints with reel-lock timing; sRGB charging colours; counter-rotating dashed core rings; real GUI click/scroll/navigation and motion interruption tests | Exact modal/HUD/reset choreography and platform-specific controls |
| Audio | 180 Vorbis effect samples, 903 music instruments; 96 native players; pause/UI separation, pan, wet routing, cache bounds and cleanup checked | Hardware listening/latency, stream loading spikes and precise wet/dry/filter/limiter output |
| Music | Three adaptive Boss scores, phase/mood bus fades, native crash/stun/riser/collapse transition voices; 35 scheduling/routing checks pass with Dummy output | Every phase/mood audible output; device timing under load |
| Input/lifecycle | Mouse/keyboard native input, nested pause ownership, focus drag cancellation; 17 motion/colour/glint checks pass | Complete touch/back/rotation/background/resume and file dialog behavior on Android |
| Performance | Five-minute native simulation soak with effects enabled | Rendered frame percentiles, memory after long sessions and audio latency on device |

These rows distinguish implemented paths and test coverage from full fidelity
acceptance. Individual skill tests primarily establish bounded execution; Boss
phase tests force HP to zero. Neither proves full mechanics agreement. Static
outer dialog geometry checks allow a 40 px height difference and are only a
diagnostic. Screenshots and review remain necessary.

## Recorded native checks (2026-10-10)

The native regression run reported 231 checks with zero failures. Independent
reference comparisons reported 12,661 checks with zero failures: 85 skill builds
and 1,800 Matter samples at normal/slow/variable steps and with furnace wind.
The economy comparison caught Treasury's missing base-rounding step. The
projectile integrator now retains double precision instead of accumulating
Vector2 quantisation; collision/render reads still use float32 geometry.
Dummy-output audio checks reported 35/35 after adding transition voices and fades. Actual
Linux GUI input and native transition runs reported zero failures. Non-reduced
motion checks reported 17/17, covering selection landing, reroll, swap, settings
over an unfinished reel, interrupted reroll, reset, retired overlays, sRGB
interpolation, glint layout/cleanup/interruption and the reel-lock landing beat.

The five-minute simulation sample uses seed 9128 and 18,000 updates. It measured
0.064 ms p50, 0.375 ms p95, 0.795 ms p99 and 13.344 ms maximum per update. Static
memory was 27,553,694 bytes initially and 27,704,162 bytes finally; peaks were seven
arrows, five jobs and 300 particles. This includes native simulation, skills/Boss
updates and semantic snapshots, with performance mode off. It excludes CanvasItem
rendering, actual audio and device scheduling, so it is not an FPS claim or a
general memory-stability guarantee. The preceding run had p50 0.071 ms,
p95 0.530 ms, p99 2.206 ms and max 98.274 ms (27,522,754 → 27,673,222 bytes).
The lower latest maximum is a separate sample, not evidence of a guaranteed
performance improvement or a mobile frame-time bound.

The Node/benchmark reference suite reported 386 passes and one skip, zero failures.
The current port does not rely on that browser code; these are reference regression
results. The strict native runner now rejects script errors and exit leaks, even
when a fixture itself prints success and Godot exits with code 0. Export/import
commands also reject zero-exit script errors. Timeouts retain
partial engine logs so parse errors that leave a SceneTree alive are diagnosable.

The native GUI matrix originally rendered 564 fixtures in both themes and passed
all five GUI gates. Modern Chrome 131 started the exported Web game without script errors.
The final render run covered 566 fixtures, including pixel checks that the local
GPU halo appears outside the solid diamond in both themes; 17 motion checks include
the gradient sheen before/after reel lock and interrupting it by retiring its card.
The original browser project passed its separate real Chromium 89 baseline gate
(18 checks, zero page errors). This result applies to `game/`, not the Godot export.
The stock template first failed Chromium 89 on its Wasm Exception section. The
compatible template removed that section, then exposed the GLES3 template's
256-entry global uniform reserve plus other uniforms exceeding the tested
driver's 261 fragment-vector limit (16 KiB uniform blocks). The rebuilt template
reserves 128 entries and is being rechecked; modern browser results are not
Chromium 89 compatibility evidence.

Current native render fixtures are under `agent-tmp/godot/render-native/`; the
independent browser UI references and native pages are under
`agent-tmp/godot/{ui-reference,ui-native}/`. Test logs live in
`agent-tmp/godot/checks/`. All generated evidence is ignored by Git.

## Exports

### Aim preview update (2026-10-11)

The preview previously updated only after a 33 ms timer elapsed, leaving it at
roughly 30 Hz on a 60 Hz display and about 24 Hz on a 120 Hz display because the
timer reset discarded the remainder. It now recomputes once per rendered frame
using the latest pull and current colliders, and clears on release or pause.
Two coloured polylines retain every prediction sample and continuous fade,
replacing two individual draw calls per segment.

Prediction omits brick hit bookkeeping for builds that never read it. Seeking
still records hits, with precomputed padded bounds and an inclusive broad-phase
rejection; its target search keeps the original nearest/tie order without a
per-step predicate/result allocation. The launch integrator and simulation step
remain unchanged. `native_prediction_test` passed 630 checks, including 503
random/edge-case sweeps and comparisons of every
sample against the previous exhaustive preview for five builds, core targeting,
four Bosses and five pull directions; it also checks next-frame presentation at
60/120 Hz, release, new-drag startup and pause. The GUI render gate passed 566
fixtures. These are desktop checks, not Android frame-rate measurements.

The same 120-pull desktop CPU probe measured median prediction costs changing
from 3.44 to 0.55 ms (plain), 7.87 to 3.72 ms (seeking), and 3.51 to 0.62 ms
(corehunter). Actual mobile frame times remain unverified: the briefly connected
Redmi Note 8 disconnected before installation. The resulting arm64 preview is
`agent-tmp/godot/export/slingbreak-godot-aim-fix-20261011.apk`.

Godot 4.7.2 exports an arm64 native preview, version code 4 and name
`0.4.0-godot-native-preview`, at
`agent-tmp/godot/export/slingbreak-godot-native-preview.apk`. Web output lives in
`agent-tmp/godot/web-native/`. Resource gates validate skill/signature completeness,
raw font fingerprints/licenses, every Vorbis fingerprint and all regular and
transition instrument keys; obsolete runtime/development resources are rejected.

The preview certificate SHA-256 is
`084c9d3f340d7b0d225b32ebddee0bf6cbad68ffbd7da89f61629d11dd813510`, matching
earlier Godot previews. APK v2/v3 signature and 16 KB ZIP alignment checks passed
for the final independent export, with the expected certificate. ADB currently
reports zero connected devices. No independent native preview has been installed
or verified on the phone yet.

The initial compatibility preview was observed on Xiaomi 12S Pro/API 36, but that
observation applies to the former QuickJS/Skia client only. Historical Canvas
and mixer comparisons also apply only to that archived implementation. They must
not be presented as evidence for GDScript/CanvasItem/native-player fidelity.

See [build and verification commands](../godot/README.md). The separate X5 Android
project's ignored vendor core is not needed for Godot builds.
