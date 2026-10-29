#!/usr/bin/env node
// One-command per-skill whole-board burst benchmark: run every catalog skill
// against the same dense board, then rank the results.
//
//   node bench/skill-burst.mjs
//   node bench/skill-burst.mjs --board-repeats=3 --out=bench/results/skill-burst-3x
//
// Extra arguments are passed through to bench/fx-run.mjs. Keep Chrome runs
// serial: never start two benchmark processes at the same time.
import {spawnSync} from 'node:child_process';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const args=process.argv.slice(2);
const outArg=args.find(arg=>arg.startsWith('--out='));
const out=outArg?outArg.slice('--out='.length):'bench/results/skill-burst';
const defaults=[
  'bench/fx-run.mjs','--skill-burst=1','--filter=^skill-burst/','--dpr=2','--sample=100',
  '--timeout=5400',`--out=${out}`
];
const run=spawnSync(process.execPath,[...defaults,...args],{cwd:root,stdio:'inherit'});
if(run.status!==0)process.exit(run.status??1);
if(!args.includes('--no-report')){
  const report=spawnSync(process.execPath,['bench/skill-burst-report.mjs',out],{cwd:root,stdio:'inherit'});
  if(report.status!==0)process.exit(report.status??1);
}
