#!/usr/bin/env node
// Compare two skill-burst result directories (for example before/after a fix).
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {summarizeSkillBurst,SKILL_BURST_GROUP} from './skill-burst-summary.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const [beforeArg,afterArg]=process.argv.slice(2).filter(arg=>!arg.startsWith('--'));
if(!beforeArg||!afterArg)throw Error('Usage: node bench/skill-burst-compare.mjs <before-dir> <after-dir>');
const load=arg=>{
  const dir=path.resolve(root,arg),files=fs.readdirSync(dir).filter(name=>name.endsWith('.json'));
  for(const name of files){
    const data=JSON.parse(fs.readFileSync(path.join(dir,name),'utf8'));
    if(!data.results?.some(row=>row.group===SKILL_BURST_GROUP))continue;
    if(data.config.reduced||data.config.raf)continue;
    return {dir,name,data,summary:summarizeSkillBurst(data)};
  }
  throw Error('No normal synchronous skill-burst result in '+dir);
};
const before=load(beforeArg),after=load(afterArg);
if(before.summary.rows.length!==after.summary.rows.length)throw Error('Skill coverage differs between runs');
const afterMap=new Map(after.summary.rows.map(row=>[row.id,row]));
const beforeBase=before.summary.baseline.event,afterBase=after.summary.baseline.event;
const rows=[];
for(const b of before.summary.rows){
  const a=afterMap.get(b.id);if(!a)throw Error('Missing skill in after run: '+b.id);
  const beforeRelative=b.event-beforeBase,afterRelative=a.event-afterBase;
  rows.push({id:b.id,name:a.name,tier:a.tier,before:b,after:a,
    eventDelta:a.event-b.event,relativeDelta:afterRelative-beforeRelative,
    beforeRelative,afterRelative,burstDelta:a.burst-b.burst,firstDelta:a.first-b.first,
    eventChange:beforeRelative?100*((afterRelative-beforeRelative)/beforeRelative):0});
}
rows.sort((x,y)=>y.relativeDelta-x.relativeDelta);
const f=n=>Number(n).toFixed(2),signed=n=>n>=0?'+'+f(n):f(n);
const improved=rows.filter(row=>row.relativeDelta<=-1).length;
const regressed=rows.filter(row=>row.relativeDelta>=2&&row.eventChange>=15);
const lines=['# 全技能整板击碎：修复前后对比','',
  `- 前：\`${before.name}\`；后：\`${after.name}\`；同一工作区、同一驱动、串行运行。`,
  `- 无技能基线：事件 ${f(beforeBase)} → ${f(afterBase)}ms；击碎 ${f(before.summary.baseline.burst)} → ${f(after.summary.baseline.burst)}ms；冷首帧 ${f(before.summary.baseline.first)} → ${f(after.summary.baseline.first)}ms。`,
  `- 事件中位相对基线改善 ≥1ms：${improved} 个技能；相对基线回退 ≥2ms 且 ≥15%：${regressed.length} 个技能。`,
  '- 原始事件会随同机负载整体漂移，因此排序与判定使用「该技能事件 − 本次运行基线事件」的相对成本；正数=变慢。','',
  '## 全部技能（按相对基线成本变化排序，正数=变慢）','',
  '| 技能 | 事件前 → 后 | 相对基线前 → 后 | 净变化 | 击碎前 → 后 | 首帧前 → 后 | 峰值特效 前/后 |',
  '|---|---:|---:|---:|---:|---:|---:|'];
const csv=['skill,name,tier,eventBeforeMs,eventAfterMs,baselineRelativeBeforeMs,baselineRelativeAfterMs,relativeDeltaMs,relativeChangePercent,burstBeforeMs,burstAfterMs,burstDeltaMs,firstBeforeMs,firstAfterMs,firstDeltaMs,effectsBefore,effectsAfter'];
for(const row of rows){
  const b=row.before,a=row.after;
  lines.push(`| ${row.name} · ${row.id} | ${f(b.event)} → ${f(a.event)} | ${f(row.beforeRelative)} → ${f(row.afterRelative)} | ${signed(row.relativeDelta)} | ${f(b.burst)} → ${f(a.burst)} | ${f(b.first)} → ${f(a.first)} | ${b.peaks.effects??0} / ${a.peaks.effects??0} |`);
  csv.push([row.id,row.name,row.tier,b.event,a.event,row.beforeRelative,row.afterRelative,row.relativeDelta,row.eventChange,b.burst,a.burst,row.burstDelta,b.first,a.first,row.firstDelta,b.peaks.effects??0,a.peaks.effects??0].join(','));
}
lines.push('','## 回退检查','');
if(regressed.length)for(const row of regressed)lines.push(`- ${row.name}（${row.id}）：相对基线 ${f(row.beforeRelative)} → ${f(row.afterRelative)}ms（${signed(row.relativeDelta)}，${f(row.eventChange)}%）。`);
else lines.push('没有技能达到「相对基线回退 ≥2ms 且 ≥15%」的标记阈值。');
lines.push('','复跑：`node bench/skill-burst.mjs --board-repeats=3 --out=bench/results/skill-burst-after`，再执行本对比工具。');
fs.writeFileSync(path.join(after.dir,'COMPARISON.md'),lines.join('\n')+'\n');
fs.writeFileSync(path.join(after.dir,'comparison.csv'),csv.join('\n')+'\n');
console.log('Skill-burst comparison:',path.relative(root,path.join(after.dir,'COMPARISON.md')));
console.log('Net improved:',rows.filter(row=>row.relativeDelta<0).slice(0,8).map(row=>`${row.id} ${signed(row.relativeDelta)}ms`).join(', ')||'none');
console.log('Regressed:',regressed.map(row=>`${row.id} ${signed(row.relativeDelta)}ms`).join(', ')||'none');
