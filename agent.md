# Agent development requirements

## Browser compatibility

- The minimum runtime is **Chrome/Chromium 89**, including the legacy Tencent X5 WebView. All shipped game scripts, CSS, inline HTML scripts, launcher mode and browser benchmarks must work on this baseline without a transpilation/build step.
- Preserve the visual design, theme colours, animation timing, keyboard accessibility and gameplay. Do not achieve compatibility by disabling effects or forcing performance mode.
- Do not use `Array.prototype.at`, unguarded newer Web APIs, `color-mix()`, `:has()`, independent CSS/WAAPI `translate`/`rotate`/`scale`, `accent-color` or `overflow: clip`. Use indexing, explicit state/selectors, sRGB colour channels and composed `transform` functions instead.
- Optional post-89 APIs require feature detection and a visually equivalent fallback. In particular, body-level elements cannot appear above a modal dialog just by increasing z-index; use a dialog-based top-layer flight on browsers without Popover.
- When composing transforms, preserve existing translation/rotation (e.g. centred flight cards and the diamond-shaped core). Keep CSS keyframes and Web Animations compatible with each other.
- Do not use `transform: none !important` to suppress draft hover motion: it also overrides the Chrome 89 commit/flight animations. Use ordinary specificity, and explicitly stretch multi-row art columns in button grids on the old layout engine.
- Set dynamic colour tokens and their RGB channels through `SlingColors.set` / `SlingColors.style`; keep channel definitions beside static colour tokens. Colour interpolation must remain in sRGB, with transparent mixes preserving hue and changing alpha.
- Run `node --test *.test.cjs bench/*.test.mjs`. Changes to browser-facing APIs/CSS also require the Chrome 89 browser compatibility test and visual checks; a modern-browser test with an old User-Agent is not sufficient.
- See [docs/chromium89-compatibility.md](docs/chromium89-compatibility.md) for the real-browser gate and FX smoke-test commands.
- Use `agent-tmp/` for downloaded browsers, screenshots, profiles and temporary artifacts; do not commit these files.
