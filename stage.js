(() => {
  'use strict';
  // One fixed design surface for every device. The whole UI lays out at
  // DESIGN_W × DESIGN_H CSS px and is scaled uniformly to fit the safe viewport;
  // leftover space becomes letterbox bars. Nothing inside the stage reads the
  // real viewport, so layout, board and HUD are identical everywhere.
  const DESIGN_W = 412, DESIGN_H = 915;

  // A near-exact fit stays full-bleed; any real letterbox gets a framed stage
  // with a small margin so its bezel and shadow have room on every side.
  const FULL_BLEED_SLACK = 12, FRAME_MARGIN = 14, FRAME_MARGIN_MAX_RATIO = .025;

  // Pure fit so tests can check any viewport without a DOM.
  const fit = (vw, vh, inset = {top: 0, right: 0, bottom: 0, left: 0}) => {
    const w = Math.max(1, vw - inset.left - inset.right), h = Math.max(1, vh - inset.top - inset.bottom);
    const bare = Math.min(w / DESIGN_W, h / DESIGN_H);
    const framed = Math.max(w - DESIGN_W * bare, h - DESIGN_H * bare) >= FULL_BLEED_SLACK;
    // Tiny screens keep the margin proportional so the board isn't squeezed.
    const m = framed ? Math.min(FRAME_MARGIN, Math.min(w, h) * FRAME_MARGIN_MAX_RATIO) : 0;
    const k = framed ? Math.min((w - 2 * m) / DESIGN_W, (h - 2 * m) / DESIGN_H) : bare;
    // Whole-pixel offsets keep the scaled stage from straddling device pixels.
    return {k, framed, x: Math.round(inset.left + (w - DESIGN_W * k) / 2), y: Math.round(inset.top + (h - DESIGN_H * k) / 2)};
  };

  const root = document.documentElement;
  // env() is CSS-only, so a hidden probe reports the safe-area insets.
  const probe = document.createElement('div');
  probe.setAttribute('aria-hidden', 'true');
  probe.style.cssText = 'position:fixed;visibility:hidden;pointer-events:none;padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)';
  document.body.append(probe);
  const insets = () => {
    const s = getComputedStyle(probe), px = v => parseFloat(v) || 0;
    return {top: px(s.paddingTop), right: px(s.paddingRight), bottom: px(s.paddingBottom), left: px(s.paddingLeft)};
  };

  const Stage = window.SlingStage = {width: DESIGN_W, height: DESIGN_H, k: 1, x: 0, y: 0, framed: false, fit,
    // Viewport (client) px → stage design px, and back.
    toStage: (cx, cy) => ({x: (cx - Stage.x) / Stage.k, y: (cy - Stage.y) / Stage.k}),
    toClient: (sx, sy) => ({x: Stage.x + sx * Stage.k, y: Stage.y + sy * Stage.k}),
    // A client rect expressed in stage design px.
    rect: r => ({left: (r.left - Stage.x) / Stage.k, top: (r.top - Stage.y) / Stage.k, width: r.width / Stage.k, height: r.height / Stage.k})
  };

  const apply = () => {
    const vv = window.visualViewport, vw = vv?.width || innerWidth, vh = vv?.height || innerHeight;
    const next = fit(vw, vh, insets());
    if (next.k === Stage.k && next.x === Stage.x && next.y === Stage.y && next.framed === Stage.framed) return;
    Object.assign(Stage, next);
    root.classList.toggle('stage-framed', next.framed);
    root.style.setProperty('--stage-k', next.k);
    root.style.setProperty('--stage-x', next.x + 'px');
    root.style.setProperty('--stage-y', next.y + 'px');
    // Layout size never changes, so ResizeObserver stays silent; listeners
    // that depend on the on-screen size (canvas backing store) hear this.
    window.dispatchEvent(new Event('stagechange'));
  };
  addEventListener('resize', apply);
  window.visualViewport?.addEventListener('resize', apply);
  addEventListener('orientationchange', apply);
  apply();
})();
