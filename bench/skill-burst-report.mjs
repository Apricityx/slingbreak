#!/usr/bin/env node
// Rank every skill's whole-board burst cost. Input is the JSON written by
//   node bench/skill-burst.mjs
// or
//   node bench/fx-run.mjs --skill-burst=1 '--filter=^skill-burst/' ...
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {summarizeSkillBurst,rankBy,problemSkills,SKILL_BURST_GROUP} from './skill-burst-summary.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const arg=process.argv[2]&&!process.argv[2].startsWith('--')?process.argv[2]:'bench/results/skill-burst';
const dir=path.resolve(root,arg);
const options=Object.fromEntries(process.argv.slice(2).filter(a=>a.startsWith('--')).map(a=>a.replace(/^--/,'').split('=')));
if(!fs.existsSync(dir))throw Error('No skill-burst result directory: '+dir);
const files=fs.readdirSync(dir).filter(name=>name.endsWith('.json'));
const sources=[];
for(const name of files){
  const data=JSON.parse(fs.readFileSync(path.join(dir,name),'utf8'));
  if(!data.results?.some(row=>row.group===SKILL_BURST_GROUP))continue;
  sources.push({name,data});
}
if(!sources.length)throw Error('No skill-burst cases in '+dir);
const primary=sources.find(source=>!source.data.config.reduced&&!source.data.config.raf)||sources[0];
const summary=summarizeSkillBurst(primary.data);
const baseline=summary.baseline;
const rows=summary.rows;
const board=rows[0],boardCount=board.n,specialRate=board.rate;
const percent=Math.round(specialRate*100);
const boardLabel=boardCount===240?'240 块恢复上限密集棋盘':'77 块满网格';
const minEvent=Number(options['min-event-ms']||options['min-delta-ms']||4);
const minDraw=Number(options['min-draw-ms']||6);
const minEarly=Number(options['min-early-ms']||8);
const problems=problemSkills(rows,{baselineEvent:baseline.event,minEventDeltaMs:minEvent,minDrawDeltaMs:minDraw,minEarlyDeltaMs:minEarly});
const byEvent=rankBy(rows,'event');
const heaviestSkill=byEvent.find(row=>row.id!=='none')||byEvent[0];
const byDelta=rankBy(rows,'eventDelta');
const byBurst=rankBy(rows.filter(row=>row.id!=='none'),'burstDelta');
const byFirst=rankBy(rows.filter(row=>row.id!=='none'),'firstDelta');
const byEarly=rankBy(rows.filter(row=>row.id!=='none'),'earlyDelta');
const f=n=>Number(n).toFixed(2);
const signed=n=>n>=0?'+'+f(n):f(n);
const tierName=tier=>({white:'普通',blue:'稀有',gold:'传说',none:'基线'}[tier]||tier);
const peak=row=>['particles','effects','signals','fields'].map(key=>row.peaks?.[key]??0).join(' / ');
const lines=['# 全技能整板击碎性能测试','',
  `生成于 ${new Date().toISOString()}。当前工作区（含未提交修改），独立临时浏览器存档。`,'',
  '## 结论','',
  `- 覆盖 ${rows.length-1} 个技能 + 1 个无技能基线，每个案例都在 ${boardLabel}（${percent}% 特殊砖，固定种子 843427）上于同一个模拟瞬间击碎整板。全部 ${rows.length} 案通过「每块只计一次击碎/收益、模拟不推进、尾段临时对象清零」校验。`,
  `- 无技能基线：击碎逻辑中位 ${f(baseline.burst)}ms，首次绘制中位 ${f(baseline.first)}ms，单次事件中位 ${f(baseline.event)}ms。`,
  `- 事件中位最高：${heaviestSkill.name}（${heaviestSkill.id}）${f(heaviestSkill.event)}ms，比基线高 ${f(heaviestSkill.eventDelta)}ms；同板固定种子下这是单技能相对成本，不是设备 FPS。`,
  `- 击碎逻辑增量最大：${byBurst[0].name}（${byBurst[0].id}）${signed(byBurst[0].burstDelta)}ms；冷首帧增量最大：${byFirst[0].name}（${byFirst[0].id}）${signed(byFirst[0].firstDelta)}ms；首秒绘制 p95 增量最大：${byEarly[0].name}（${byEarly[0].id}）${signed(byEarly[0].earlyDelta)}ms。`,
  `- 按「事件增量 ≥ ${minEvent}ms、冷首帧增量 ≥ ${minDraw}ms、首秒 p95 增量 ≥ ${minEarly}ms 或事件达到基线 1.5 倍」标记，${problems.length} 个技能需复核：${problems.map(row=>row.name).join('、')||'无'}。`,'',
  '## 判定与边界','',
  '- 每个技能单独装备（单槽），不与其它技能共享预算；一个不参与排名的预热案例先跑，避免把首次整板击碎的 JIT 冷路径算进基线。相对无技能基线做差，避免把特殊砖自身的连锁成本算到技能头上。',
  '- 使用第 50 关，使 `boomerang`（最低 50 关）等全部 81 个技能都处于合法解锁状态；所有案例共享同一棋盘与基础生命。',
  boardCount===240?'- 240 块是真实存档恢复允许的砖块上限，12 × 20 密集小砖属于合成压力上界，不是自然关卡。':'- 77 块是 7 × 11 满网格（移除通常的缺口/障碍），是完整网格上界，不是自然随机布局。',
  specialRate===0?'- 0% 特殊砖：只保留技能自身开销，依赖特殊砖触发的 `aftershock` 等技能不会生效。':`- ${percent}% 是普通特殊砖比例的渐近上限；爆破/电弧/冰晶的递归会放大所有案例，因此必须看同板基线差值，不能只看绝对值。`,
  '- 通过生产 `generate(true)` 恢复 Matter 砖，正常 `shoot()` 初始化箭与技能任务，再把主箭伤害临时设为 1e9，逐块调用生产 `projectileHit()`；没有绕过深度上限或直接清空数组。',
  '- `burstMs` 是同步击碎逻辑；`firstDrawMs` 是随后一次完整绘制 + 1px 读回的冷首帧；`eventMs` 是两者逐轮相加。`earlyP95` 取 0–0.2s 与 0.2–1s 两段绘制 p95 的较大值。',
  '- 后续至少 6 秒墙钟、5.5 秒模拟，真实 tick/render、物理、粒子、HUD、DOM rAF 都保留；`frameMs` 不含同步击碎阻塞，必须同时看 `eventMs`。',
  '- 软件光栅、GPU/垂直同步关闭、DPR 2；绝对毫秒只适合同机比较，需在目标 Android X5 真机复核，不能把这里的结果当作手机 FPS。','',
  '## 完整排名（按相对无技能基线的单次事件增量）','',
  '| # | 技能 | 稀有度 | 击碎中位 | Δ击碎 | 首绘中位 | Δ首绘 | 事件中位 | Δ事件 | 事件最大 | 首秒 p95 | Δ首秒 | 峰值 粒子/图案/信号/场 |',
  '|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|'];
let rank=0;
for(const row of byDelta){
  rank++;
  lines.push(`| ${rank} | ${row.name} · ${row.id} | ${tierName(row.tier)} | ${f(row.burst)} | ${row.id==='none'?'—':signed(row.burstDelta)} | ${f(row.first)} | ${row.id==='none'?'—':signed(row.firstDelta)} | ${f(row.event)} | ${row.id==='none'?'—':signed(row.eventDelta)} | ${f(row.eventMax)} | ${f(row.earlyP95)} | ${row.id==='none'?'—':signed(row.earlyDelta)} | ${peak(row)} |`);
}
lines.push('','## 分项前三','',
  `- 击碎逻辑增量：${byBurst.slice(0,3).map(row=>`${row.name} ${signed(row.burstDelta)}ms`).join('、')}。`,
  `- 冷首帧增量：${byFirst.slice(0,3).map(row=>`${row.name} ${signed(row.firstDelta)}ms`).join('、')}。`,
  `- 首秒绘制 p95 增量：${byEarly.slice(0,3).map(row=>`${row.name} ${signed(row.earlyDelta)}ms`).join('、')}。`,
  `- 单次事件绝对中位：${byEvent.slice(0,3).map(row=>`${row.name} ${f(row.event)}ms`).join('、')}。`,'',
  `## 需复核技能（事件 ${minEvent}ms / 冷首帧 ${minDraw}ms / 首秒 p95 ${minEarly}ms）`,'');
if(problems.length){
  lines.push('| 技能 | 事件中位 / Δ | 击碎 / Δ | 冷首帧 / Δ | 首秒 p95 / Δ | 事件最大 |','|---|---:|---:|---:|---:|---:|');
  for(const row of rankBy(problems,'eventDelta'))lines.push(`| ${row.name} · ${row.id} | ${f(row.event)} / ${signed(row.eventDelta)} | ${f(row.burst)} / ${signed(row.burstDelta)} | ${f(row.first)} / ${signed(row.firstDelta)} | ${f(row.earlyP95)} / ${signed(row.earlyDelta)} | ${f(row.eventMax)} |`);
  lines.push('','阈值只用于分诊，不代表超过 60 FPS 预算或已确认可感知卡顿；需结合复跑波动与真机验证。');
}else lines.push('没有案例超过当前阈值。','');
lines.push('## 运行信息','',
  `- 文件：\`${primary.name}\`；${primary.data.config.userAgent}；Canvas ${primary.data.config.canvas.join(' × ')}；DPR ${primary.data.config.dpr}。`,
  `- CPU：${primary.data.environment?.cpu||'未知'}（${primary.data.environment?.cpuCount||'?'} 线程）；每案 ${primary.data.config.boardRepeats} 次独立重置。`,
  `- 其它同目录结果：${sources.filter(source=>source!==primary).map(source=>`\`${source.name}\``).join('、')||'无'}。`,'',
  '复跑命令见 [bench/FX-README.md](../../FX-README.md#全技能整板击碎性能测试)。所有 Chrome 压测必须串行，不能并行争抢 CPU。');
const header=['skill','name','tier','n','specialRate','burstMs','burstDeltaMs','firstDrawMs','firstDrawDeltaMs','eventMs','eventDeltaMs','eventMaxMs','earlyDrawP95Ms','earlyDrawDeltaMs','eventPerBrickMs','peakParticles','peakEffects','peakSignals','peakFields','maxUpdateMs','repeats'];
const csv=[header.join(',')];
for(const row of byDelta)csv.push([row.id,row.name,row.tier,row.n,row.rate,row.burst,row.burstDelta,row.first,row.firstDelta,row.event,row.eventDelta,row.eventMax,row.earlyP95,row.earlyDelta,row.eventPerBrick,row.peaks.particles??0,row.peaks.effects??0,row.peaks.signals??0,row.peaks.fields??0,row.updateMax,row.repeats].join(','));
fs.writeFileSync(path.join(dir,'REPORT.md'),lines.join('\n')+'\n');
fs.writeFileSync(path.join(dir,'skills.csv'),csv.join('\n')+'\n');
console.log('Skill-burst report:',path.relative(root,path.join(dir,'REPORT.md')));
console.log('Top event delta:',byDelta.filter(row=>row.id!=='none').slice(0,10).map(row=>`${row.id} ${signed(row.eventDelta)}ms`).join(', '));
console.log('Needs review:',problems.map(row=>`${row.id} ${signed(row.eventDelta)}ms`).join(', ')||'none');
