#!/usr/bin/env node
/*
 * Compare two benchmark result directories produced by run.mjs.
 *
 *   node bench/compare.mjs bench/results/baseline bench/results/optimized
 *   node bench/compare.mjs bench/results/baseline bench/results/optimized --label-a=naive --label-b=batched
 *
 * Differences are measured from each run's own 0-particle baseline and reported
 * against the median frame time, which is far less noisy than the mean when the
 * odd GC or scheduler hitch lands in a sample window.
 */
import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const dirs = args.filter(a => !a.startsWith('--'));
const opt = Object.fromEntries(args.filter(a => a.startsWith('--')).map(a => a.replace(/^--/, '').split('=')));
const [dirA, dirB] = dirs;
if (!dirA || !dirB) {
  console.error('usage: node bench/compare.mjs <dirA> <dirB> [--label-a=.. --label-b=..]');
  process.exit(1);
}

const load = dir => {
  const abs = path.resolve(dir);
  const file = fs.readdirSync(abs).find(f => f.endsWith('.json'));
  if (!file) throw new Error('no .json in ' + dir);
  return JSON.parse(fs.readFileSync(path.join(abs, file), 'utf8'));
};

const a = load(dirA);
const b = load(dirB);
const labelA = opt['label-a'] || path.basename(dirA);
const labelB = opt['label-b'] || path.basename(dirB);
const byN = (r, n) => r.results.find(x => x.particles === n);
const baseA = byN(a, 0).medianMs;
const baseB = byN(b, 0).medianMs;

const fmt = (n, d = 2) => Number(n).toFixed(d);

const lines = [];
lines.push(`# 粒子渲染 A/B：${labelA} vs ${labelB}`);
lines.push('');
lines.push(`- ${labelA}: \`${dirA}\` (dpr=${a.config.devicePixelRatio}, ${a.config.canvasBacking.join('×')}px)`);
lines.push(`- ${labelB}: \`${dirB}\` (dpr=${b.config.devicePixelRatio}, ${b.config.canvasBacking.join('×')}px)`);
lines.push('');
lines.push('帧时间 Δ 相对各自运行 0 粒子基线；速度比按中位数帧时间计算。');
lines.push('');
lines.push(`| 粒子数 | ${labelA} Δ中位 ms | ${labelB} Δ中位 ms | 提速 | ${labelA} µs/粒子 | ${labelB} µs/粒子 |`);
lines.push('|---:|---:|---:|---:|---:|---:|');
for (const n of a.results.map(r => r.particles)) {
  const A = byN(a, n), B = byN(b, n);
  if (!A || !B) continue;
  const da = A.medianMs - baseA, db = B.medianMs - baseB;
  const speed = n && db > 0.0001 ? fmt(da / db, 1) + '×' : '—';
  lines.push(`| ${n} | ${fmt(da)} | ${fmt(db)} | ${speed} | ${n ? fmt(da / n * 1000, 2) : '—'} | ${n ? fmt(db / n * 1000, 2) : '—'} |`);
}
lines.push('');
lines.push(`> 提速 = ${labelA} 相对基线的增量 ÷ ${labelB} 相对基线的增量。数值 >1 表示 ${labelB} 更快。`);
console.log(lines.join('\n'));
