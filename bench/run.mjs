#!/usr/bin/env node
/*
 * Headless runner for the SlingBreak particle/FPS benchmark.
 *
 * Serves this folder over HTTP, launches a local Chrome for Testing / Chrome /
 * Chromium, opens bench.html and reads back window.__BENCH__. No npm packages
 * are required: the DevTools Protocol is spoken over Node's global WebSocket.
 *
 * Usage:
 *   node bench/run.mjs
 *   node bench/run.mjs --counts=0,100,300,1000,3000,8000 --sample=2000 --dpr=2
 *   CHROME_PATH=/path/to/chrome node bench/run.mjs
 *
 * Options:
 *   --counts=0,50,...   particle counts to sweep
 *   --sample=1800       ms sampled per count
 *   --warmup=600        ms discarded per count
 *   --sim=0|1           run the CPU-only tick micro-benchmark (default 1)
 *   --simTicks=1200     tick iterations per count in the sim bench
 *   --dpr=1|2           device scale factor emulation
 *   --seed=1            particle layout seed
 *   --timeout=180       overall seconds before giving up
 *   --chrome=PATH       explicit Chrome/Chromium binary
 *   --out=DIR           output directory (default bench/results)
 *   --json-only         skip writing the markdown report
 *
 * The full environment (headless, software raster, dpr) is printed with the
 * results, because absolute FPS numbers are only comparable within one machine.
 * Re-run the same page in the target WebView for numbers that reflect a device.
 */
import { spawn } from 'node:child_process';
import http from 'node:http';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..');
const sleep = ms => new Promise(r => setTimeout(r, ms));

function parseArgs(argv) {
  const args = {};
  for (const raw of argv) {
    const m = /^--([^=]+)(?:=(.*))?$/.exec(raw);
    if (!m) continue;
    args[m[1]] = m[2] === undefined ? true : m[2];
  }
  return args;
}

const args = parseArgs(process.argv.slice(2));
const opts = {
  counts: args.counts || '0,50,100,200,300,500,750,1000,1500,2000,3000,4000,6000,8000',
  sample: Number(args.sample ?? 1800),
  warmup: Number(args.warmup ?? 600),
  sim: args.sim === undefined ? 1 : Number(args.sim),
  simTicks: Number(args.simTicks ?? 1200),
  dpr: Number(args.dpr ?? 1),
  seed: Number(args.seed ?? 1),
  timeout: Number(args.timeout ?? 180),
  out: path.resolve(ROOT, args.out || 'bench/results'),
  jsonOnly: Boolean(args['json-only']),
};

function findChrome() {
  if (process.env.CHROME_PATH && fs.existsSync(process.env.CHROME_PATH)) return process.env.CHROME_PATH;
  if (args.chrome && fs.existsSync(args.chrome)) return args.chrome;
  const fixed = [
    '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable', '/usr/bin/chromium',
    '/usr/bin/chromium-browser', '/snap/bin/chromium',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  ];
  for (const p of fixed) if (fs.existsSync(p)) return p;
  const pw = path.join(os.homedir(), '.cache', 'ms-playwright');
  if (fs.existsSync(pw)) {
    for (const dir of fs.readdirSync(pw)) {
      for (const sub of ['chrome-linux64/chrome', 'chrome-linux/chrome', 'chrome-mac/Chromium.app/Contents/MacOS/Chromium']) {
        const p = path.join(pw, dir, sub);
        if (fs.existsSync(p)) return p;
      }
    }
  }
  throw new Error('Chrome not found. Set CHROME_PATH or pass --chrome=/path/to/chrome');
}

const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8', '.png': 'image/png', '.svg': 'image/svg+xml',
};

function startServer() {
  const server = http.createServer((req, res) => {
    let pathname;
    try { pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname); } catch { pathname = '/'; }
    if (pathname === '/') pathname = '/bench.html';
    const file = path.resolve(ROOT, '.' + pathname);
    if (file !== ROOT && !file.startsWith(ROOT + path.sep)) { res.writeHead(403); res.end('forbidden'); return; }
    fs.readFile(file, (err, data) => {
      if (err) { res.writeHead(404); res.end('not found'); return; }
      res.writeHead(200, { 'content-type': MIME[path.extname(file)] || 'application/octet-stream', 'cache-control': 'no-store' });
      res.end(data);
    });
  });
  return new Promise(resolve => server.listen(0, '127.0.0.1', () => resolve(server)));
}

class CDP {
  constructor(url) {
    this.ws = new WebSocket(url);
    this.seq = 0;
    this.pending = new Map();
    this.listeners = new Set();
    this.ws.addEventListener('message', ev => {
      let msg; try { msg = JSON.parse(ev.data); } catch { return; }
      if (msg.id != null && this.pending.has(msg.id)) {
        const { resolve, reject } = this.pending.get(msg.id);
        this.pending.delete(msg.id);
        if (msg.error) reject(new Error(msg.error.message)); else resolve(msg.result);
      } else if (msg.method) {
        for (const listener of this.listeners) listener(msg);
      }
    });
  }
  ready() {
    return new Promise((resolve, reject) => {
      this.ws.addEventListener('open', () => resolve(), { once: true });
      this.ws.addEventListener('error', () => reject(new Error('CDP socket error')), { once: true });
    });
  }
  send(method, params = {}, sessionId) {
    const id = ++this.seq;
    const payload = { id, method, params };
    if (sessionId) payload.sessionId = sessionId;
    this.ws.send(JSON.stringify(payload));
    return new Promise((resolve, reject) => this.pending.set(id, { resolve, reject }));
  }
  on(fn) { this.listeners.add(fn); }
  close() { try { this.ws.close(); } catch { /* ignore */ } }
}

function launchChrome(binary) {
  const child = spawn(binary, [
    '--headless=new',
    '--no-sandbox',
    '--disable-dev-shm-usage',
    '--disable-frame-rate-limit',   // let rAF run as fast as the machine allows
    '--disable-gpu-vsync',
    '--disable-background-timer-throttling',
    '--disable-renderer-backgrounding',
    '--disable-backgrounding-occluded-windows',
    '--hide-scrollbars',
    '--mute-audio',
    '--no-first-run',
    '--window-size=1200,900',
    '--remote-debugging-port=0',
    'about:blank',
  ], { stdio: ['ignore', 'ignore', 'pipe'] });

  return new Promise((resolve, reject) => {
    let stderr = '';
    const timer = setTimeout(() => reject(new Error('Chrome did not expose a DevTools endpoint:\n' + stderr)), 20000);
    child.stderr.setEncoding('utf8');
    child.stderr.on('data', chunk => {
      stderr += chunk;
      const m = /DevTools listening on (ws:\/\/\S+)/.exec(stderr);
      if (m) { clearTimeout(timer); resolve({ child, wsUrl: m[1] }); }
    });
    child.on('exit', code => { clearTimeout(timer); reject(new Error('Chrome exited early (code ' + code + '):\n' + stderr)); });
  });
}

async function poll(cdp, sessionId, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  let lastError = null;
  while (Date.now() < deadline) {
    try {
      const { result, exceptionDetails } = await cdp.send('Runtime.evaluate', {
        expression: 'JSON.stringify(window.__BENCH__ || null)',
        returnByValue: true,
      }, sessionId);
      if (exceptionDetails) lastError = exceptionDetails.text;
      else if (result && result.value) {
        const bench = JSON.parse(result.value);
        if (bench.done) return bench;
        if (bench.error) throw new Error('page reported error: ' + bench.error);
      }
    } catch (err) {
      lastError = err.message; // context may be mid-navigation
    }
    await sleep(400);
  }
  throw new Error('timed out waiting for benchmark' + (lastError ? ' (last: ' + lastError + ')' : ''));
}

const fmt = (n, d = 2) => Number(n).toFixed(d);

function markdown(bench) {
  const { config, results, sim } = bench;
  const base = results.find(r => r.particles === 0);
  const lines = [];
  lines.push('# SlingBreak 粒子数量 / FPS 基准');
  lines.push('');
  lines.push('复用游戏真实循环（`game.js` 物理 + `render.js` 绘制），端到端采样每档粒子数下的帧时间。');
  lines.push('');
  lines.push('| 项 | 值 |');
  lines.push('|---|---|');
  lines.push(`| 运行时间 | ${new Date().toISOString()} |`);
  lines.push(`| dpr | ${config.devicePixelRatio} |`);
  lines.push(`| canvas backing | ${config.canvasBacking.join(' × ')} px |`);
  lines.push(`| warmup / sample | ${config.warmupMs} ms / ${config.sampleMs} ms |`);
  lines.push(`| seed | ${config.seed} |`);
  lines.push(`| userAgent | \`${config.userAgent}\` |`);
  lines.push('');

  const cross = target => {
    for (let i = 1; i < results.length; i++) {
      const a = results[i - 1], c = results[i];
      if (a.fps >= target && c.fps < target) {
        const t = (a.fps - target) / (a.fps - c.fps);
        return Math.round(a.particles + t * (c.particles - a.particles));
      }
    }
    return null;
  };
  const c60 = cross(60), c30 = cross(30);
  const capped = results.length > 1 && results.every(r => r.fps > 55 && r.fps < 65);
  lines.push('## 结论');
  lines.push('');
  if (c60 != null) lines.push(`- 约 **${c60}** 粒子时跌破 **60 FPS**。`); else lines.push('- 采样范围内未跌破 60 FPS。');
  if (c30 != null) lines.push(`- 约 **${c30}** 粒子时跌破 **30 FPS**。`); else lines.push('- 采样范围内未跌破 30 FPS。');
  if (capped) lines.push('- ⚠️ 所有档位都接近 60 FPS，说明 rAF 被垂直同步锁住；请以帧时间（ms）列判断，或用 `--disable-frame-rate-limit` 运行。');
  lines.push('');

  lines.push('## 端到端（模拟 + 绘制）');
  lines.push('');
  lines.push('| 粒子数 | FPS | 均帧 ms | 中位 ms | p95 ms | 相对 0 粒子 Δms | µs/粒子 |');
  lines.push('|---:|---:|---:|---:|---:|---:|---:|');
  for (const r of results) {
    const d = base ? r.meanMs - base.meanMs : null;
    const per = base && r.particles ? (d / r.particles) * 1000 : null;
    lines.push(`| ${r.particles} | ${fmt(r.fps, 1)} | ${fmt(r.meanMs)} | ${fmt(r.medianMs)} | ${fmt(r.p95Ms)} | ` +
      `${d == null ? '—' : (d >= 0 ? '+' : '') + fmt(d)} | ${per == null ? '—' : fmt(per, 3)} |`);
  }

  if (sim && sim.length) {
    const sb = sim.find(r => r.particles === 0);
    lines.push('');
    lines.push('## 仅更新（`G.tick` 物理 + 粒子积分，不含绘制）');
    lines.push('');
    lines.push('| 粒子数 | ms/tick | 相对 0 粒子 Δµs/tick | µs/粒子·tick |');
    lines.push('|---:|---:|---:|---:|');
    for (const r of sim) {
      const d = sb ? (r.msPerTick - sb.msPerTick) * 1000 : null;
      const per = sb && r.particles ? d / r.particles : null;
      lines.push(`| ${r.particles} | ${fmt(r.msPerTick, 4)} | ${d == null ? '—' : (d >= 0 ? '+' : '') + fmt(d, 2)} | ${per == null ? '—' : fmt(per, 3)} |`);
    }
  }
  lines.push('');
  lines.push('> 绝对 FPS 只在同一台机器内可比。要得到设备真实数据，请在目标 WebView/浏览器直接打开 `bench.html`。');
  return lines.join('\n');
}

async function main() {
  const binary = findChrome();
  const server = await startServer();
  const port = server.address().port;
  const qs = new URLSearchParams({
    counts: opts.counts, sample: String(opts.sample), warmup: String(opts.warmup),
    sim: String(opts.sim), simTicks: String(opts.simTicks), seed: String(opts.seed),
  });
  const url = `http://127.0.0.1:${port}/bench.html?${qs}`;
  console.log(`[bench] chrome: ${binary}`);
  console.log(`[bench] url:    ${url}`);

  let chrome, cdp;
  try {
    const launched = await launchChrome(binary);
    chrome = launched.child;
    cdp = new CDP(launched.wsUrl);
    await cdp.ready();

    const { targetId } = await cdp.send('Target.createTarget', { url: 'about:blank' });
    const { sessionId } = await cdp.send('Target.attachToTarget', { targetId, flatten: true });

    cdp.on(msg => {
      if (msg.method === 'Runtime.consoleAPICalled') {
        const text = (msg.params.args || []).map(a => a.value ?? a.description ?? '').join(' ');
        if (text.startsWith('[bench')) console.log(text);
      } else if (msg.method === 'Runtime.exceptionThrown') {
        console.error('[bench] page exception:', msg.params.exceptionDetails?.text,
          msg.params.exceptionDetails?.exception?.description || '');
      }
    });

    await cdp.send('Runtime.enable', {}, sessionId);
    await cdp.send('Page.enable', {}, sessionId);
    await cdp.send('Emulation.setDeviceMetricsOverride', {
      width: 1000, height: 900, deviceScaleFactor: opts.dpr, mobile: false,
    }, sessionId);
    await cdp.send('Page.navigate', { url }, sessionId);

    const bench = await poll(cdp, sessionId, opts.timeout * 1000);
    const report = markdown(bench);

    fs.mkdirSync(opts.out, { recursive: true });
    const stamp = new Date().toISOString().replace(/[:.]/g, '-');
    const jsonPath = path.join(opts.out, `bench-${stamp}.json`);
    fs.writeFileSync(jsonPath, JSON.stringify(bench, null, 2) + '\n');
    console.log('[bench] wrote ' + path.relative(ROOT, jsonPath));
    if (!opts.jsonOnly) {
      const mdPath = path.join(opts.out, `bench-${stamp}.md`);
      fs.writeFileSync(mdPath, report + '\n');
      console.log('[bench] wrote ' + path.relative(ROOT, mdPath));
    }
    console.log('\n' + report);
  } finally {
    if (cdp) cdp.close();
    if (chrome) chrome.kill('SIGKILL');
    server.close();
  }
}

main().catch(err => { console.error('[bench] ' + err.message); process.exitCode = 1; });
