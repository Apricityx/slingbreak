/*
 * SlingBreak particle -> FPS benchmark.
 *
 * This page loads the shipping game.js + render.js unchanged, so the measured
 * loop is the real one: Matter.js simulation, G.tick() particle integration and
 * the canvas draw path in render.js all run exactly as in the game.
 *
 * The harness only controls the one independent variable we care about -- the
 * number of live particles in G.particles -- then samples frame times with
 * requestAnimationFrame while that population is held constant.
 *
 * It therefore measures END-TO-END frame cost: simulation + particle update +
 * canvas rasterisation + the rest of the board (which stays fixed, giving a
 * baseline at 0 particles).
 *
 * Query params:
 *   counts=0,50,100,...   particle counts to sweep        (default below)
 *   warmup=600            ms discarded before each sample
 *   sample=1800           ms recorded per count
 *   sim=1                 also run the CPU-only per-tick micro-benchmark
 *   simTicks=1200         G.tick() iterations per count in the sim bench
 *   seed=1                deterministic RNG seed for particle layout
 *   autorun=1             start automatically (default 1)
 *
 * Exposes window.__BENCH__ = { running, done, config, results, sim }.
 */
(() => {
  'use strict';
  const G = window.Game;
  const out = document.getElementById('bench-output');
  const log = (...a) => console.log('[bench]', ...a);

  const params = new URLSearchParams(location.search);
  const num = (k, d) => { const v = parseFloat(params.get(k)); return Number.isFinite(v) ? v : d; };
  const flag = (k, d) => { const v = params.get(k); return v == null ? d : v !== '0'; };

  const COUNTS = (params.get('counts') || '0,50,100,200,300,500,750,1000,1500,2000,3000,4000,6000,8000')
    .split(',').map(n => Math.max(0, Math.floor(Number(n)))).filter(Number.isFinite);
  const WARMUP = num('warmup', 600);
  const PRIME = num('prime', 1200);
  const SAMPLE = num('sample', 1800);
  const SIM_TICKS = Math.max(1, Math.floor(num('simTicks', 1200)));
  const RUN_SIM = flag('sim', true);
  const SEED = (num('seed', 1) >>> 0) || 1;

  // Deterministic layout so two runs are directly comparable.
  let s = SEED;
  const rnd = () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; };
  // The colours the game actually feeds G.burst(): G.colors plus the literal hex
  // values used by core/skill bursts. More colours means more paint styles, which
  // is the worst case for the batched renderer -- so keep them all in.
  const COLORS = [...Object.values(G.colors), '#ced9a4', '#8a9480', '#a4d65e', '#93c446', '#87917f'];

  // The particle draw cost should be the only moving part, so hold the world
  // still: ready phase, no arrows, no drag, no board entrance animation.
  G.phase = 'ready';
  G.paused = false;
  G.drag = null;
  G.boardEntrance = null;

  const MAX = COUNTS.length ? Math.max(...COUNTS) : 0;
  const pool = [];
  for (let i = 0; i < MAX; i++) {
    // Match the life spread G.burst() produces (0.5..0.9s -> alpha 0.25..1) so the
    // renderer's per-particle alpha handling is actually exercised, not bypassed.
    const life = .5 + rnd() * .4;
    pool.push({
      x: rnd() * G.W,
      y: rnd() * G.H,
      vx: 0, vy: 0,
      life, _life: life, max: 1,
      size: 2 + rnd() * 5,             // same 2..7px range G.burst() produces
      color: COLORS[(rnd() * COLORS.length) | 0],
      rot: rnd() * 6,
    });
  }
  const fill = n => { G.particles = pool.slice(0, n); };
  // G.tick() adds gravity and decays life each step. Cancel both so the population
  // size AND its alpha spread stay fixed for the whole sample window.
  const anchor = () => { for (const p of G.particles) { p.vy = 0; p.life = p._life; } };

  const percentile = (sorted, p) => sorted[Math.min(sorted.length - 1, Math.max(0, Math.floor(p * sorted.length)))];
  const stats = times => {
    // `times` are absolute timestamps; frame cost is the gap between them.
    const deltas = [];
    for (let i = 1; i < times.length; i++) deltas.push(times[i] - times[i - 1]);
    const sorted = [...deltas].sort((a, b) => a - b);
    const mean = sorted.reduce((a, b) => a + b, 0) / sorted.length;
    return {
      frames: sorted.length,
      meanMs: mean,
      medianMs: percentile(sorted, .5),
      p95Ms: percentile(sorted, .95),
      minMs: sorted[0],
      maxMs: sorted[sorted.length - 1],
      fps: 1000 / mean,
      fpsMedian: 1000 / percentile(sorted, .5),
    };
  };

  const config = {
    W: G.W, H: G.H,
    devicePixelRatio: (window.devicePixelRatio || 1),
    canvasCss: G.view ? [G.view.width, G.view.height] : null,
    canvasBacking: [document.getElementById('game').width, document.getElementById('game').height],
    counts: COUNTS, warmupMs: WARMUP, primeMs: PRIME, sampleMs: SAMPLE, seed: SEED,
    userAgent: navigator.userAgent,
  };
  const state = { running: true, done: false, config, results: [], sim: null, error: null };
  window.__BENCH__ = state;

  // --- optional CPU-only micro-benchmark: isolate particle integration from draw.
  function runSim() {
    const rows = [];
    for (const n of COUNTS) {
      fill(n);
      // Keep the population alive for the whole run; this bench measures the
      // per-particle integration cost, not the decay/cull behaviour.
      for (const p of G.particles) p.life = 1e9;
      for (let i = 0; i < 120; i++) G.tick(1 / 60);           // JIT warmup
      const t0 = performance.now();
      for (let i = 0; i < SIM_TICKS; i++) G.tick(1 / 60);
      const ms = performance.now() - t0;
      rows.push({ particles: n, ticks: SIM_TICKS, ms, msPerTick: ms / SIM_TICKS });
    }
    return rows;
  }

  // --- requestAnimationFrame sweep over particle counts.
  let idx = 0;
  let phase = 'prime';
  let phaseAt = performance.now();
  let frames = [];

  function startLevel() {
    fill(COUNTS[idx]);
    phase = 'warmup';
    phaseAt = performance.now();
    frames = [];
  }

  function nextLevel() {
    idx++;
    if (idx >= COUNTS.length) return finish();
    startLevel();
  }

  function frame() {
    // NB: the rAF `now` argument is unreliable under --disable-frame-rate-limit
    // (it can jump by seconds), so timestamp with performance.now() instead.
    const t = performance.now();
    try {
      if (phase === 'prime') {
        // Let page startup, font loading and JIT settle before the first sample.
        if (t - phaseAt >= PRIME) startLevel();
      } else if (phase === 'warmup') {
        if (t - phaseAt >= WARMUP) { phase = 'sample'; phaseAt = t; frames = []; }
      } else {
        frames.push(t);
        if (frames.length > 1 && t - phaseAt >= SAMPLE) {
          const result = Object.assign({ particles: COUNTS[idx] }, stats(frames));
          result.spanMs = frames[frames.length - 1] - frames[0];
          state.results.push(result);
          log(`N=${result.particles}`, `${result.fps.toFixed(1)}fps`, `${result.meanMs.toFixed(2)}ms`, `p95 ${result.p95Ms.toFixed(2)}ms`);
          report();
          if (idx >= COUNTS.length - 1) return finish();
          nextLevel();
        }
      }
      anchor();
    } catch (err) {
      state.error = String(err && err.stack || err);
      console.error('[bench] failed', err);
      finish();
      return;
    }
    requestAnimationFrame(frame);
  }

  function finish() {
    if (state.done) return;
    state.running = false;
    if (RUN_SIM && !state.sim) { state.sim = runSim(); anchor(); }
    state.done = true;
    report();
    log('done', state.results.length + ' points');
    document.title = 'SlingBreak bench · done';
  }

  // --- reporting -------------------------------------------------------------
  const fmt = (n, d = 2) => Number(n).toFixed(d);

  function report() {
    const b = state.results.find(r => r.particles === 0);
    const lines = [];
    lines.push('SlingBreak · 粒子数量 vs FPS（真实游戏循环端到端采样）');
    lines.push(`环境: dpr=${config.devicePixelRatio}  canvas=${config.canvasBacking.join('x')}px  ua=${config.userAgent}`);
    lines.push(`采样: prime ${PRIME}ms / warmup ${WARMUP}ms / sample ${SAMPLE}ms per level, seed ${SEED}`);
    lines.push('');
    lines.push('| 粒子数 | FPS | 均帧 ms | 中位 ms | p95 ms | 相对 0 粒子 Δms | µs/粒子 |');
    lines.push('|---:|---:|---:|---:|---:|---:|---:|');
    for (const r of state.results) {
      const d = b ? r.meanMs - b.meanMs : null;
      const per = b && r.particles ? (d / r.particles) * 1000 : null;
      lines.push(`| ${r.particles} | ${fmt(r.fps, 1)} | ${fmt(r.meanMs)} | ${fmt(r.medianMs)} | ${fmt(r.p95Ms)} | ` +
        `${d == null ? '—' : (d >= 0 ? '+' : '') + fmt(d)} | ${per == null ? '—' : fmt(per, 3)} |`);
    }
    if (state.sim) {
      const sb = state.sim.find(r => r.particles === 0);
      lines.push('');
      lines.push('更新成本（仅 G.tick 物理+粒子积分，不含绘制）');
      lines.push('| 粒子数 | ms/tick | 相对 0 粒子 Δµs/tick | µs/粒子·tick |');
      lines.push('|---:|---:|---:|---:|');
      for (const r of state.sim) {
        const d = sb ? (r.msPerTick - sb.msPerTick) * 1000 : null;
        const per = sb && r.particles ? d / r.particles : null;
        lines.push(`| ${r.particles} | ${fmt(r.msPerTick, 4)} | ${d == null ? '—' : (d >= 0 ? '+' : '') + fmt(d, 2)} | ${per == null ? '—' : fmt(per, 3)} |`);
      }
    }
    lines.push('');
    lines.push(budgetLine());
    if (state.error) lines.push('ERROR: ' + state.error);
    out.textContent = lines.join('\n');
  }

  function budgetLine() {
    const capped = state.results.length > 1 && state.results.every(r => r.fps > 55 && r.fps < 65);
    const cross = target => {
      for (let i = 1; i < state.results.length; i++) {
        const a = state.results[i - 1], c = state.results[i];
        if (a.fps >= target && c.fps < target) {
          const t = (a.fps - target) / (a.fps - c.fps);
          return Math.round(a.particles + t * (c.particles - a.particles));
        }
      }
      return null;
    };
    const c60 = cross(60), c30 = cross(30);
    const parts = [];
    if (c60 != null) parts.push(`约 ${c60} 粒子时跌破 60 FPS`);
    if (c30 != null) parts.push(`约 ${c30} 粒子时跌破 30 FPS`);
    if (!parts.length) parts.push('采样范围内未跌破 60/30 FPS 门槛');
    if (capped) parts.push('（所有档位都贴近 60 FPS，浏览器把 rAF 锁在垂直同步；请用 --disable-frame-rate-limit 或看 ms 列）');
    return '预算: ' + parts.join('；') + '。';
  }

  if (flag('autorun', true)) {
    fill(COUNTS[0] ?? 0);
    requestAnimationFrame(frame);
  } else {
    out.textContent = 'autorun=0 · 在控制台调用 window.__benchStart() 开始';
    window.__benchStart = () => { idx = 0; startLevel(); requestAnimationFrame(frame); };
  }
  window.__bench = { G, counts: COUNTS, start: () => { idx = 0; startLevel(); requestAnimationFrame(frame); } };
})();
