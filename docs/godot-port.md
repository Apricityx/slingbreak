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
| Input/lifecycle | Mouse/keyboard native input, nested pause ownership, focus drag cancellation; 21 motion/copy/colour/glint checks pass; Android touch shooting and modal smoke checks | Complete back/rotation/background/resume and file dialog behavior on Android |
| Performance | Five-minute simulation soak, paired desktop CPU probes and retained-drawing checks; optimized APK installed for a short Android smoke check | Reliable rendered frame percentiles, memory after long sessions and audio latency on device |

These rows distinguish implemented paths and test coverage from full fidelity
acceptance. Individual skill tests primarily establish bounded execution; Boss
phase tests force HP to zero. Neither proves full mechanics agreement. Static
outer dialog geometry checks allow a 40 px height difference and are only a
diagnostic. Screenshots and review remain necessary.

## High-frequency motion migration (2026-10-11)

Projectiles now keep presentation position, heading and trail snapshots separate
from swept-collision state. Display time advances continuously between fixed
steps and does not rewind across hit-stop/resume. Core entrance, halo, board
entrance and decorative Boss timing read presentation time. Generic particles,
floating income, rings, electric deformation, hit flashes and shake decay update
at render cadence; the sling releases through an analytic damped spring.
Skill-specific signatures, fields and gameplay hooks retain their existing
implementation for a later migration stage.

UI motion retains the current pose when interrupted and gives scale and opacity
separate owners. Card flights capture their visible transform and inherited
opacity before reparenting. Modal backdrops retire with their panels, nested
sheets keep their contents and reel state, and HUD counters, Boss meters and
charge gauges transition in place. Skill-bar movement uses visual copies while
containers retain layout ownership. Achievement groups and Boss announcements
keep stable nodes; shop updates preserve the sheet, scroll and keyboard focus.
Reel locks retain the final texture, and report/reset/coin flights use the shared
native motion/easing paths.

The implementation phase omitted tests and engine startup at the user's request.
The subsequently requested Android build fixed explicit-type declarations and a
Control property name collision found by the importer. Import/export completed
without script errors, and the APK passed its resource, v2/v3 signature and 16 KB
ZIP alignment checks. No gameplay regression, visual comparison or device
verification was run for these motion changes. The previously recorded checks
below and the aim-fix APK describe the earlier implementation.

## UI choreography follow-up (2026-10-11)

Modal sheets now animate their viewport height with a fixed content width rather
than stretching text to disguise a layout change. Their opening and closing
follow the triggering control, retaining its rectangle if a theme or skill-bar
update replaces it. Covered sheets retain scroll, card/reel nodes and focus;
returning restores the correct detail identity. Live content-collapse animations
drive the sheet height directly instead of repeatedly restarting a resize tween.

Cards, emblems, rarity badges and settlement-bar segments have layout slots with
independent visual children. The reference's 440 ms staggered flap, sequential
reel locks, text reveal, rarity beat and tier glint use native Tweens and the JS
cubic Bezier curves. Perspective rotation remains a small 2D scale approximation.
The 640 ms selection flight exchanges fixed-layout card and skill-slot faces;
skill-bar movement and landing use copies that cannot be reset by container sort.
Replacement candidates collapse before their emblem flies to the detail header,
which changes name/description before folding back to the original slot.

Draft refresh, detail availability/charges, shop upgrades, build lists,
equipment tags and the achievement disclosure update in place. Retiring copies
preserve captured geometry, clipping, draw order, inherited opacity, theme and
shader parameters. Skill-bar faces crossfade within the same moving transform.
Each card-deal batch owns its delayed callbacks so an old batch cannot unlock a
new list. Interrupted refresh/replacement restores visible cards and the original
detail header. Level digits roll, toast replacement crossfades, charge gain/spend
rings fade continuously, and achievement cards animate over the earnings reading
while their motion pauses behind modal UI.

The source-editing stage omitted engine startup, tests and export as requested.
The subsequently requested APK build fixed the charge-ring colour's explicit type;
import/export completed without script errors, and resources, signatures and ZIP
alignment passed. The UI-motion APK below includes this follow-up; the earlier
motion APK predates it. No gameplay regression, visual comparison or device test
was run. Earlier regression results do not establish correctness or visual
fidelity of these new paths. Subsequent review
should cover rapid refresh/selection, nested dialogs, interruption during each
replacement beat, scroll/focus retention, long descriptions, both themes and
different refresh rates.

## Performance follow-up (2026-10-11)

Runtime investigation of the UI-motion preview found missing-meta reads with a
null default emitting errors and stack traces during modal layout (`motion_extent`,
`opener`, `waiting` and related optional keys). Optional reads now check `has_meta`
first. The old fixed visual fixture run emitted 163 errors; the optimized run
emitted none. This is runtime evidence; a clean import/export had not exercised
these paths.

Frozen UI copies instantiate each native Control once and copy its stored visual
properties, with cached class-property lists and per-instance theme overrides.
They resolve the shared font before sizing; layout Containers still become neutral
Controls. The previous `duplicate(0)` path recursively copied children, discarded
them, and then copied them again. Font, texture, clipping, pose and shader state
remain preserved. UI animation now uses the viewport's display-resolution glyph
atlas rather than regenerating it for every intermediate node scale; board text
retains its fixed world-scale oversampling.

Bricks and obstacles retain native CanvasItem vector display lists. HP, flash,
freeze, expiry/ward states, moving bounds, entrance time and palette changes
invalidate only the affected item; removal, generation and draw order are handled
explicitly. Bounty targets are redrawn each round at random and paint a pulsing
gold marker in the dynamic pass, so choosing or clearing them never invalidates a
retained brick. The battlefield still submits arrows, effects, core and Boss motion
each rendered frame. No raster cache, resolution reduction, prediction sampling
change or performance-mode switch is used.

A sequential same-driver comparison used Godot 4.7.2/X11/Mesa llvmpipe, seed 9128,
30 UI copies and 270 measured frames per battlefield workload after 30 warm-up
frames. Values below are CPU milliseconds, **not Android frame time**:

Board samples cover `_process`, the main dynamic `_draw` and retained brick/wall
submission. Separate background/halo draw callbacks and GPU work are excluded.

| CPU sample | Previous p50 / p95 | Optimized p50 / p95 |
| --- | --- | --- |
| Entire draft copy | 111.48 / 114.34 | 12.28 / 16.74 |
| First card copy | 26.79 / 27.46 | 3.49 / 10.84 |
| Ordinary board update + draw | 7.18 / 8.02 | 1.68 / 2.19 |
| Fixed flying/impact board update + draw | 10.25 / 13.74 | 3.51 / 11.88 |
| Flying/impact simulation | 0.45 / 1.29 | 0.44 / 1.34 |

The flying fixture kept targets alive, with the same one-arrow/242-particle/five-
signature peaks on both runs. Busy p95 remains much closer to the old value than
the median: effect peaks still cost time. These samples exclude real audio and
device scheduling; desktop frame-interval maxima were noisy and do not demonstrate
a bounded or universally smooth frame rate. Reproduce with
`tests/native_performance_probe.gd` in a separate GUI run. Raw logs/JSON live in
`agent-tmp/godot/performance-paired-{before,after}.{log,json}`.

Checks passed: 566 native render fixtures, 16 retained invalidation/order checks,
21 motion checks (including frozen-copy font/style/geometry ownership), interface
input checks, and 386 Node/reference passes with one skip. Twelve before/after
fixed screenshots are pixel-identical for ordinary boards, all four Bosses and
brick states in both themes; this does not establish full animation agreement.
Six frozen-card screenshots also match their sources pixel-for-pixel across both
themes after releasing the source's keyboard focus. Frozen faces intentionally
have no focus ownership and do not draw the live button's focus border.
The five-minute logic-only soak passed with 0.079 ms p50, 0.492 ms p95 and 1.094 ms
p99, seven arrows/five jobs/300 particles at peak.

The connected ADB endpoint identifies itself as Redmi Note 8 but reports Adreno 650,
1080×1920 and only a 30 Hz display mode. The old APK was installed and runtime logs
confirmed the missing-meta errors. `gfxinfo` recorded only five Android window
frames; SurfaceFlinger latency returned no valid surface timings and timestats
returned zero timestamps. These device counters cannot support a phone FPS claim.

The optimized APK subsequently installed over the UI-motion preview. Startup,
settings open/close, skill detail open/close and touch shooting were exercised;
the board showed damage, destroyed bricks and updated earnings. The captured
process log contained no Godot script errors, fatal exception or ANR entry. This
short check does not establish smooth animation timing or long-session stability.
Logs: `agent-tmp/godot/phone-performance-after-{start,play-final}.log`.

A desktop Dummy-output probe sampled nine common audio cues 30 times each after
clearing the stream cache (not the OS file cache). Stream-loading/scheduling medians
were 0.24–0.62 ms, with a 0.91 ms maximum; warm
medians were 0.014–0.030 ms. It does not measure Android APK reads, audio-device
latency or Boss music, so synchronous first-use loading remains a device profiling
item rather than a confirmed cause or a completed fix. Audio code was unchanged.

## Peak effects / selection follow-up (2026-10-11)

The subsequent report specifically reproduced mass shattering/skill release and
the draft-to-slot flight. This is a separate workload from the earlier one-arrow
performance test; the two sets of measurements must not be mixed.

- Skill contours use offline-baked antialiased triangle meshes, grouped only by
  contiguous primary/secondary colour runs to preserve alpha-over ordering. The
  shader preserves the authored absolute stroke width, clamped miter joins,
  feather and caps while scaling contour positions by effect radius. No frames,
  paths, particle counts or rendering resolution were removed. The original
  polylines remain a same-appearance fallback while meshes load.
- All 81 bundles/24 frames are checked in as `assets/strokes/*.res` with source
  and file SHA-256 fingerprints. The bake tool is excluded from exports. Loading
  requests start for equipped skills, visible draft/swap candidates and brick
  glyphs; only completed requests are collected in active play. The cache holds
  up to 32 bundles, not a bound on total RAM: retained CanvasItem lists own bundle
  references for their mesh RIDs beyond cache eviction. Readiness/eviction
  invalidates retained glyphs. Scene teardown drains pending loader references.
- Particle replacement uses the existing 300-particle cap as a circular array,
  reordered at most once per display frame. It preserves the exact RNG sequence,
  newest survivors, draw order and expiry while avoiding a 300-entry slice for
  each brick in a chain reaction.
- Exact draft inclusion odds are calculated only while a draft/swap offer exists.
  Selecting a skill no longer recalculates all catalog probabilities during board
  entrance snapshots. Visible offer probabilities and skill-selection rules are
  unchanged.
- The selected live card moves to the flight owner at its fixed layout dimensions;
  it does not create a new copy of Chinese labels. Surviving equipped slots reuse
  their original controls and shaped text. Old/new ghost faces crossfade only
  where the outgoing tint changes; motion duration, transforms and interruption
  guards remain intact.
- Save state is serialized on the main thread; one native worker writes/flushed
  `.pending` data and atomically renames it. Further saves coalesce to the latest
  payload. Import/reload/background/exit join pending writes; tests use a separate
  save filename. The deliberately single-threaded Web template retains a
  synchronous fallback. This is not a measured Android disk-latency result.

Sequential paired Godot 4.7.2/X11/Mesa llvmpipe runs against the preceding
performance APK staging use 80 signatures (20 each of mint/treasury/supernova/
pulse), 300 particles, 135 measured frames after 15 warm-up frames, 12 actual full-
queue selections, and 20 forced global-damage chain reactions. CPU milliseconds:

| Sample | Previous p50 / p95 | New p50 / p95 |
| --- | --- | --- |
| Choose snapshot after clearing draft | 12.442 / 13.319 | 0.296 / 0.492 |
| Full-queue choose command + UI presentation | 25.188 / 26.484 | 8.630 / 9.749 |
| Dynamic draw, 80 signatures | 33.448 / 37.109 | 6.732 / 8.409 |
| Dynamic draw, 80 signatures + 300 particles | 33.451 / 38.576 | 7.559 / 8.809 |
| Forced chain reaction including generation | 10.833 / 12.390 | 9.603 / 11.818 |

Full-scene draw calls in the combined fixture changed from 5,864 to 1,020.
The forced shattering logic improved much less than rendering. Selection test mode
excludes audio/disk saves. Draw CPU excludes retained/background/halo callbacks and
GPU execution. The software-rendered host intervals remain high (combined p50
137.9→92.4 ms; selection interval max 142.6→131.9 ms); these results do **not**
prove smooth phone FPS or that all peaks are resolved. Raw paired evidence:
`agent-tmp/godot/spike-paired-before.{log,json}` and
`spike-paired-after-final.log` / `spike-paired-after.json`.

Visual evidence: `native_stroke_test` compared actual original-polyline/baked-mesh
rasters for all 81 skills, four contour frames and three radii (972 fixtures).
Maximum channel difference was 1/255, no failures. All 24 frames per bundle are
also checked for valid mesh surfaces. UI regression verifies original-label
ownership, fixed card/text dimensions, full-queue survivor reuse and restored
visibility. No Android peak frame-time evidence was obtained in this follow-up:
the connected endpoint was foregrounding another game and was not interrupted.
First-use audio, mobile GPU load and long-session peak performance remain open
acceptance items.

Final desktop gates: 231 rule checks, 11 spike/save lifecycle checks, 630 prediction
checks, 35 audio scheduling checks, 566 rendered fixtures, 972 stroke rasters,
19 retained invalidation/lifetime checks, 25 UI-motion checks, GUI input checks and
386 Node passes/one skip. The five-minute/18,000-step logic soak passed (p50
0.076 ms, p95 0.414 ms, p99 0.868 ms, max 13.117 ms; seven arrows/five jobs/300
particles). This soak does not exercise the 80-signature GPU peak. The first
headless pass exposed unfinished loader references at prediction-test teardown;
draining them in board `_exit_tree` made the strict full headless gate pass without
leaks. Intermediate failed logs are retained, not considered valid acceptance.
The independent browser-rule oracle also passed 12,661 comparisons.

The Chromium 89 export smoke was rerun after the transient first-load WASM abort:
`web-spike89-rerun/report.json` reports HeadlessChrome 89.0.4389.0, WebGL 2,
zero errors, and non-blank draft/board/aiming/shooting/pause captures (1,343 to
2,629 sampled colours). The first `web-spike89/failure.json` is retained as an
intermittent loader failure, not counted as the final compatibility result.

Reproduce separately with `tests/native_spike_probe.gd`; do not run alongside
other checks/builds. Exploratory earlier logs used 80 different skills or lazy
runtime meshes, so they are not the paired workload above.

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

### Peak-effects/selection preview update (2026-10-11)

`agent-tmp/godot/export/slingbreak-godot-peak-fix-20261011.apk` adds the peak-effects
and selection optimizations above to the previous performance preview. It retains
arm64/package/version code 4/version name and the existing debug certificate, so
install it over the Godot preview without uninstalling or clearing data.

Size: 87,045,253 bytes (83.01 MiB). SHA-256:
`b173933247fd07f413505369594a576775ad38bd9b773bda65468cd48675d72a`.
The increase is primarily 15.89 MiB of compressed baked stroke bundles. Import/
export, resource fingerprints/completeness, v2/v3 signature verification and
`zipalign -c -P 16 4` passed. All 45 runtime `.gd`/`.gdshader` files match staging
`native-android-0gj61anq`; the APK contains all 81 baked bundles and no bake tools.
Build log: `agent-tmp/godot/spike-android-export.log`. This APK was not installed
or played in this follow-up because the connected device was in another game.

### Performance preview update (2026-10-11)

`agent-tmp/godot/export/slingbreak-godot-performance-20261011.apk` includes the
retained battlefield drawing, frozen-copy optimization, glyph-cache configuration
and missing-meta fixes above, together with the previous UI-motion work. The older
UI-motion APK below does not include these performance fixes.

The arm64 debug preview retains package `io.github.apricityx.slingbreak.godot.preview`,
version code 4, `0.4.0-godot-native-preview`, API 24 minimum/API 36 target and the
existing certificate. Install over the previous Godot preview without uninstalling
to retain its private saves. The file is 70,351,534 bytes (67.09 MiB); SHA-256:
`d3dca7214d03dbf254e789bf671fbda33de5b0cc355e1be4e63fc561f0309773`.

Import/export, the standalone resource contract, APK v2/v3 signature verification
and `zipalign -c -P 16 4` passed. Build output:
`agent-tmp/godot/performance-export-20261011.log`. The connected Android endpoint
accepted an in-place update and passed the short gameplay/log checks described
above; reliable phone frame-time measurements remain unavailable.

### UI motion preview update (2026-10-11)

`agent-tmp/godot/export/slingbreak-godot-ui-motion-20261011.apk` includes the UI
choreography follow-up, the high-frequency motion migration and the previous
aim/audio/display changes. The arm64 debug preview retains package
`io.github.apricityx.slingbreak.godot.preview`, version code 4,
`0.4.0-godot-native-preview` and the existing preview certificate. It supports
Android 7.0/API 24 or newer and targets API 36. Install over the previous Godot
preview without uninstalling to retain its private saves.

The file is 70,347,269 bytes (67.09 MiB); SHA-256:
`b7463d2535e986218de77297332dc266bd788d8513ada2913a6747ed8b70ff96`.
Build output: `agent-tmp/godot/ui-motion-export-20261011-2.log`.
Godot import/export completed without script errors after fixing the charge-ring
colour declaration. The standalone resource contract passed, including both new
UI scripts (`motion_slot.gdc`, `sheet.gdc`). APK v2/v3 signatures verified with
the existing certificate, and `zipalign -c -P 16 4` passed. These are packaging
checks at the time of that build. Later investigation and device installation
are recorded in the performance follow-up above.

### Motion preview update (2026-10-11)

`agent-tmp/godot/export/slingbreak-godot-motion-20261011.apk` contains the
high-frequency motion migration above and the previous aim/audio/display changes.
The arm64 debug preview retains package, version code 4 and the existing preview
certificate, allowing installation over the earlier Godot preview without clearing
its private saves. The file is 70,318,299 bytes; SHA-256:
`b66e14591d78eb50d995d17a3cf4682b9ac8bae75896db1354682a28f6c8c4e7`.
Build output: `agent-tmp/godot/motion-export-20261011-3.log`.
Packaging checks do not establish motion smoothness or device performance.

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
for that independent export, with the expected certificate. At the time of that
build ADB reported zero connected devices; the later Android installation and
smoke checks are recorded in the performance follow-up above.

The initial compatibility preview was observed on Xiaomi 12S Pro/API 36, but that
observation applies to the former QuickJS/Skia client only. Historical Canvas
and mixer comparisons also apply only to that archived implementation. They must
not be presented as evidence for GDScript/CanvasItem/native-player fidelity.

See [build and verification commands](../godot/README.md). The separate X5 Android
project's ignored vendor core is not needed for Godot builds.
