# Repository instructions

## Project layout

- All browser runtime resources live in `game/`: `index.html`, `manifest.json`, `src/`, `styles/`, `vendor/` and `icons/`. The project root stays minimal (tooling, tests, docs, Android and game). `game/` is deployable as one unit; keep cross-references inside it relative to `game/`.
- Browser source lives in `game/src/`, grouped into `core`, `skills`, `bosses`, `render`, `effects`, `audio`, `theme` and `ui`.
- Styles live in `game/styles/`; Node regression tests live in `tests/`; browser benchmark drivers live in `bench/`.
- The standalone Android X5 client lives in `android/` (arm64 only). Its game assets are generated from `game/` via a whitelist; do not maintain a second source copy. Keep signing keys, signing.properties, vendor core APKs and all build output out of Git. Preserve the fixed X5 HTTPS resource origin, verify APK signatures and reject downgrades. Gecko→X5 migration reads the old profile only, decodes the verified localStorage format and inserts missing values before game startup; never overwrite existing X5 saves, delete old profiles, or claim their localStorage is shared. Pin the tested core and restrict the compatibility patch to API 36; do not silently fall back to system WebView.
- Keep `game/index.html` and `game/manifest.json` in the game folder. Preserve the explicit script and stylesheet loading order in `game/index.html`; modules still extend `window.Game` in that order, without a build step.
- Keep generated benchmark results in the ignored `bench/results/`, and browsers, screenshots, profiles and other temporary artifacts in the ignored `agent-tmp/`. Do not commit these files.

## Browser compatibility

- The minimum runtime is **Chrome/Chromium 89**, including the legacy Tencent X5 WebView. All shipped game scripts, CSS, inline HTML scripts, launcher mode and browser benchmarks must work on this baseline without a transpilation/build step.
- Preserve the visual design, theme colours, animation timing, keyboard accessibility and gameplay. Do not achieve compatibility by disabling effects or forcing performance mode.
- Do not use `Array.prototype.at`, unguarded newer Web APIs, `color-mix()`, `:has()`, independent CSS/WAAPI `translate`/`rotate`/`scale`, `accent-color` or `overflow: clip`. Use indexing, explicit state/selectors, sRGB colour channels and composed `transform` functions instead.
- Optional post-89 APIs require feature detection and a visually equivalent fallback. In particular, body-level elements cannot appear above a modal dialog just by increasing z-index; use a dialog-based top-layer flight on browsers without Popover.
- When composing transforms, preserve existing translation/rotation (e.g. centred flight cards and the diamond-shaped core). Keep CSS keyframes and Web Animations compatible with each other.
- Do not use `transform: none !important` to suppress draft hover motion: that also overrides the Chrome 89 commit/flight animations. Use ordinary specificity, and explicitly stretch multi-row art columns in button grids on the old layout engine.
- Set dynamic colour tokens and their RGB channels through `SlingColors.set` / `SlingColors.style`; keep channel definitions beside static colour tokens. Colour interpolation must remain in sRGB, with transparent mixes preserving hue and changing alpha.
- Run `node --test tests/*.test.cjs bench/*.test.mjs`. Changes to browser-facing APIs/CSS also require the Chrome 89 browser compatibility test and visual checks; a modern-browser test with an old User-Agent is not sufficient.
- See [docs/chromium89-compatibility.md](docs/chromium89-compatibility.md) for the real-browser gate and FX smoke-test commands.
