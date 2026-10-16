# Chromium 89 compatibility

Chrome/Chromium 89 is the minimum runtime, including the legacy X5 WebView used
by the Android launcher. The source is shipped directly: there is no transpilation
or CSS build step. Development requirements live in the root `AGENTS.md`.
Browser source is grouped under `game/src/`, styles under `game/styles/`, and Node
tests under `tests/`; `game/index.html` keeps their explicit loading order.

## Changes

| Incompatibility | Compatible implementation | Visual behaviour |
| --- | --- | --- |
| `Array.at()` | Explicit last-item indexing in skills, serpent, achievements, transitions and browser FX driver | No change to gameplay or drawing |
| CSS sRGB colour mixing | `game/src/theme/colors.js` supplies dynamic RGB channels; `game/styles/tokens.css` supplies theme channels; `game/styles/color-blends.css` uses RGB/RGBA and `calc()` | Original interpolation weights, alpha, gradients and shadows retained; at most 8-bit channel rounding |
| Relational selectors | Explicit selected-theme / older-emblem classes, hidden badge group and existing card tier attributes | Same selection, stacking and glint states |
| Individual transform properties in CSS / WAAPI | Composed `transform` functions | Timings and easing retained; includes diamond rotation, centred cards/banners and emblems' resting stack transform |
| Popover top layer | Transparent modal `dialog` for flight and outgoing token | Still above the draft modal; transparent, unblurred backdrop; Escape cannot interrupt selection; final focus returns to canvas |
| Draft animation overflow | `overflow: hidden` on the options grid, auto vertical scrolling with a hidden dialog scrollbar | Contains transformed cards' scrollable overflow, keeps card width stable, and retains scrolling for real over-height content |
| Native accent-colour styling | Custom styled native checkbox and range input | Theme colours, keyboard controls, accessible input semantics and proportional filled volume track retained |
| Old button-grid stretching | Explicit `align-self: stretch` on the draft art column | Restores full-height tinted art band and centred emblem |
| Forge palm's square fallback | Same capsule drawn with arcs when Canvas `roundRect` is absent | Rounded ends remain visible on 89 |

The draft's hover reset must not use `transform: none !important`: that also
overrides WAAPI's compatible lift and flight transforms. Ordinary CSS specificity
keeps stationary cards while allowing animated emblems and the commit lift.

No performance mode is forced, effects are not disabled, and no global built-in
prototype polyfills or transpiler dependencies are added. Benchmarks launch using
`--headless`, which works with both old and current Chromium.

## Repeatable verification

Run the existing suite plus static compatibility / colour channel tests:

```sh
node --test tests/*.test.cjs bench/*.test.mjs
```

Install the test-only old browser tooling **under the ignored `agent-tmp/`**.
Puppeteer 6.0.0 pins Chromium revision 843427 (89.0.4389.0):

```sh
npm install --prefix agent-tmp/chrome89-tools puppeteer@6.0.0
# If npm blocks dependency install scripts, explicitly run the browser installer:
node agent-tmp/chrome89-tools/node_modules/puppeteer/install.js
CHROME89_PUPPETEER="$PWD/agent-tmp/chrome89-tools/node_modules/puppeteer" node bench/chrome89.mjs
```

The browser gate checks the **actual browser version** and refuses a modern
engine. It tests script parsing, startup, real Canvas painting, keyboard selection,
hover/commit transforms, card-art stretching, top-layer flights, full-queue
replacement, focus, theme selection, volume, running Web Audio with scheduled
sources, all four bosses, launcher and local-file entry, reduced motion and
mobile/tablet/desktop stage fits. It also compares 552 blend/theme/boss samples
against the original sRGB weights. Screenshots and JSON go into
`agent-tmp/chrome89-compat/`.

An additional modern-engine regression pass is available:

```sh
CHROME89_PUPPETEER="$PWD/agent-tmp/chrome89-tools/node_modules/puppeteer" \
CHROME_BIN=/absolute/path/to/current/chrome node bench/chrome89.mjs --compare-modern
```

This pass omits `file://` because current desktop Chromium blocks the PWA manifest
on an opaque file origin; the old-engine file gate still runs. No file-access
security flag is used to make the test pass.

Render all skill signatures and boss abilities through the existing FX harness:

```sh
node bench/fx-run.mjs \
  --chrome="$PWD/agent-tmp/chrome89-tools/node_modules/puppeteer/.local-chromium/linux-843427/chrome-linux/chrome" \
  --sample=1 --dpr=1 --capture=1 --out=agent-tmp/chrome89-fx --timeout=180
```

`sample=1` makes this a compatibility smoke test, **not** a meaningful performance
measurement. Increase sampling for performance comparisons.

## Verified on 2026-10-01

- Node suite: 309 tests passed.
- Real Chromium 89.0.4389.0 gate and current Chromium 153.0.8010.12 regression gate passed.
- FX harness: all 81 profiles, 1,108 cases, zero missing profiles and zero errors.
- Deterministic before/after draft checks on the modern engine preserved geometry;
  sRGB values differ only in colour serialization / 8-bit rounding. Chrome 89's
  font metrics produce small height differences, not a redesign.

This is browser compatibility verification, not an Android X5 distribution test.
It does not verify Tencent kernel downloads, SDK initialization, device GPU
behaviour, native AAudio playback or audible end-to-end latency. Those still need
testing in the Android host. No Android APK was rebuilt or installed for this
upstream-only change.

## Draft layout regression (2026-10-02)

- `game/styles/draft.css`: contain deal-in transforms inside the options grid. Paint-only
  clipping previously let those transforms enlarge the dialog's scroll range by
  58–62 px, temporarily showing a scrollbar. Hide its gutter without disabling
  touch, wheel or keyboard scrolling for genuinely long drafts.
- `game/src/ui/skills-ui.js` / `game/styles/skills.css`: clone the original card with its untransformed
  layout dimensions, transparent border and fixed text boxes. Preserve those
  dimensions through flight using centred transforms rather than reflow. Give
  the incoming slot label its final fixed box throughout the shell morph too.
  Suppress the decorative flight dialogs' native focus outline (visible on modern
  Chromium keyboard selection); interactive cards keep their focus rings.
- `bench/draft-layout.mjs`: sample both animations frame by frame at 412×915,
  360×800 and 768×1024, with normal and deliberately long descriptions. Assert
  stable dialog size, scroll range, text widths and line counts, original-to-ghost
  line-break parity, and scrolling to real over-height content. Screenshots and
  frame reports are saved under `agent-tmp/draft-layout/`.

```sh
CHROME89_PUPPETEER="$PWD/agent-tmp/chrome89-tools/node_modules/puppeteer" \
node bench/draft-layout.mjs
# Optional modern-browser comparison:
CHROME89_PUPPETEER="$PWD/agent-tmp/chrome89-tools/node_modules/puppeteer" \
CHROME_BIN=/absolute/path/to/current/chrome node bench/draft-layout.mjs --compare-modern
```

The 309 Node tests, both compatibility gates and all six layout fixtures on each
of Chromium 89.0.4389.0 and 153.0.8010.12 passed. This change is upstream-only;
the Android assets/APK have not been rebuilt or installed.

## Draft commit clipping regression (2026-10-04)

The options grid must keep `overflow: hidden` to contain deal-in transforms, but
its 16 px top padding did not contain the commit's upward lift and 4% scale about
the card's 85% vertical transform origin. Tall cards lost several pixels of their
top edge. `game/src/ui/skills-ui.js` now reserves temporary, height-dependent commit headroom;
`game/styles/draft.css` pairs that extra top padding with an equal negative margin, preserving
the card positions, dialog dimensions and scroll range. The headroom is cleared
in selection cleanup, including interrupted animations.

`bench/draft-layout.mjs` also records the commit phase, checks the top edge and
3 px pick ring against the grid's clipping boundary, asserts unchanged dialog
geometry and scroll range, and captures commit screenshots alongside flights.
Use the same real-Chromium-89 and modern comparison commands above.

## Project layout regression (2026-10-06)

- Game scripts are grouped under `src/`; all game styles are under `styles/`;
  Node regressions are under `tests/`. The particle benchmark entry moved to
  `bench/particles.html` and now loads its required theme dependency.
- SHA-256 checks confirmed that all 52 moved game scripts/styles are byte-identical
  to the original working tree, including its uncommitted edits. Script and
  stylesheet loading order in `index.html` is unchanged.
- `node --test tests/*.test.cjs bench/*.test.mjs`: 345 tests passed, no failures
  or skips. New directory regressions cover resource paths, nested deployment,
  complete source/style loading and wrapper ordering.
- Real Chromium 89.0.4389.0 gate: all 18 checks passed, including local-file
  loading, real Web Audio, four bosses, launcher and viewport fits. Reviewed
  opening/draft/board/Boss screenshots; runtime styles and rendering were not
  redesigned.
- The relocated particle runner completed its 0/300-particle smoke check on 89.
  The full FX smoke rerun completed 1,120 cases, all 81 profiles and 12 board
  cases, with zero benchmark or page errors.
- The first FX smoke run had one animation-drain timeout in the 240-brick
  `plain:special-0` case, with no page exceptions. Isolated before/after snapshot
  checks both passed, followed by the complete successful rerun. The initial
  failure is retained in `agent-tmp/project-layout-fx/`, not silently overwritten;
  this does not establish the cause or prove the timeout cannot recur.
- Logs, source hashes and screenshots remain in ignored `agent-tmp/` under
  `project-layout-*` and `chrome89-compat/`. These are compatibility smoke checks,
  not an Android X5 performance claim. No Android assets/APK were rebuilt.

## Game folder consolidation (2026-10-08)

- All browser runtime resources moved into `game/`: `index.html`, `manifest.json`,
  `src/`, `styles/`, `vendor/` and `icons/`. The project root now only holds
  tooling, tests, docs, `android/` and `game/`. Paths inside `game/` stayed
  folder-relative, so no script/style/icon reference inside `game/index.html`
  changed; the PWA now starts at `/game/index.html`.
- Node tests, benchmark drivers and the Android `syncGameAssets` whitelist were
  updated to the `game/` prefix; the Android asset origin (`assets/game/index.html`)
  is unchanged, so installed saves keep their origin.
- `node --test tests/*.test.cjs bench/*.test.mjs`: 365 tests passed, no failures.
- Real Chromium 89.0.4389.0 gate: all checks passed, zero page errors, including
  the moved entry, local-file entry, launcher, client settings and four bosses.
- `bench/draft-layout.mjs`: all six fixtures passed on 89. FX smoke rerun
  completed 1,120 cases across all 81 profiles with zero benchmark/page errors.
- These are compatibility smoke checks, not an Android X5 performance claim.
  No Android APK was rebuilt or installed for this layout change.

## Skill acquisition flight (2026-10-09)

The flight now uses a transparent, fixed-size dialog as a motion anchor. Its
card and slot surfaces keep their layout dimensions throughout the flight;
only composed `transform` and `opacity` keyframes move, resize and crossfade
them. No animated `left`, `top`, `width` or `height` can trigger text reflow or
change the clipping box between frames.

The skill is committed before takeoff so the destination comes from the actual
equipped HUD slot. The flight copies that slot's label, padding and surface
styles, and the landing pulse starts at scale 1. The draft stays open until its
fade completes; focus returns to the canvas after the decorative dialogs leave.
Commit lift, flight duration, queue replacement and board entrance remain.

`bench/draft-layout.mjs` covers normal descriptions, long descriptions and full
queue replacement at three viewport sizes. It checks fixed text layout, flight
keyframes and the geometry at both takeoff and landing, alongside the existing
scrolling and commit-clipping checks. Use the real-Chromium-89 command above.
