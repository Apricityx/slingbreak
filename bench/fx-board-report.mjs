#!/usr/bin/env node
// Whole-board live tests have different semantics from frozen FX snapshots.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const dir=path.resolve(process.argv[2]||path.join(root,'bench/results/fx-optimized/board-burst'));
const sources=[];
for(const [engine,folder] of [['modern',dir],['chrome89',path.join(dir,'chrome89')]]){
  if(!fs.existsSync(folder))continue;
  for(const file of fs.readdirSync(folder).filter(f=>f.endsWith('.json'))){
    const data=JSON.parse(fs.readFileSync(path.join(folder,file),'utf8'));
    if(!data.results?.some(r=>r.group==='board-burst'))continue;
    if(data.errors.length||data.pageErrors.length)throw Error(`Benchmark errors in ${file}`);
    for(const row of data.results.filter(r=>r.group==='board-burst')){
      for(const run of row.runs){
        const o=run.outcome;
        if(o.destroyed!==row.n||o.totalDelta!==row.n||o.remaining!==0||o.simulationAdvanced!==0||
          o.coinDelta!==o.shotMoney||o.coinDelta!==o.levelMoney||o.coinDelta<=0||Object.values(run.tail).some(n=>n!==0))
          throw Error(`Invalid whole-board result: ${file} / ${row.id} / ${row.n}`);
      }
    }
    sources.push({engine,file:path.relative(dir,path.join(folder,file)),data,rows:data.results.filter(r=>r.group==='board-burst')});
  }
}
const normal=sources.find(s=>s.engine==='modern'&&!s.data.config.reduced&&!s.data.config.raf);
if(!normal)throw Error('Missing normal synchronous whole-board results');
const reduced=sources.find(s=>s.engine==='modern'&&s.data.config.reduced&&!s.data.config.raf);
const key=r=>`${r.id}/${r.n}`,rmap=new Map((reduced?.rows||[]).map(r=>[key(r),r]));
const outcomes=new Map();
for(const s of sources)for(const r of s.rows)for(const run of r.runs){
  const fingerprint=JSON.stringify([run.fixture.counts,run.fixture.hp,run.outcome.destroyed,run.outcome.totalDelta,run.outcome.coinDelta]);
  if(outcomes.has(key(r))&&outcomes.get(key(r))!==fingerprint)throw Error(`Board/reward mismatch across repetitions or modes: ${s.file} / ${key(r)}`);
  outcomes.set(key(r),fingerprint);
}
const f=n=>Number(n).toFixed(2),load=r=>r.loadout==='chain'?'四技能连锁':'无技能';
const hot=r=>Math.max(...r.phases.slice(0,2).filter(p=>p.costMs).map(p=>p.costMs.p95));
const worst=[...normal.rows].sort((a,b)=>b.eventMs.median-a.eventMs.median)[0];
const spikiest=[...normal.rows].sort((a,b)=>b.eventMs.max-a.eventMs.max)[0];
const lines=['# 整板同时击碎：极限压力测试','',
  `生成于 ${new Date().toISOString()}。当前工作区（含未提交修改），独立临时浏览器存档。原审计与优化结果没有被覆盖。`,'',
  '## 结论','',
  `- ${sources.reduce((n,s)=>n+s.rows.length,0)} 个案例、${sources.reduce((n,s)=>n+s.rows.reduce((m,r)=>m+r.runs.length,0),0)} 次完整击碎。全部通过：每块只计一次击碎/收益、模拟瞬间不推进、尾段临时对象全部清零，页面无异常。`,
  '- 同一输入在所有重复、模式与浏览器之间的砖块配额、HP、击碎数、累计数和收益一致。',
  `- 正常模式最重瞬间：${worst.n} 块、${Math.round(worst.rate*100)}% 特殊砖、${load(worst)}；击碎逻辑中位 ${f(worst.burstMs.median)}ms，首次绘制中位 ${f(worst.firstDrawMs.median)}ms，单次「逻辑 + 首次绘制」中位 ${f(worst.eventMs.median)}ms。`,
  `- 正常模式最大单次事件 ${f(spikiest.eventMs.max)}ms（${spikiest.n} 块、${Math.round(spikiest.rate*100)}% 特殊砖、${load(spikiest)}）。这些极限下仍有明显同步阻塞，不能宣称已经消除卡顿。`,
  '- 瞬间击碎包含伤害递归、Matter 移除、特殊砖、技能任务、成就、HUD 和粒子创建；不能用静态碎屑的绘制成本代替。低尾段中位数也不能掩盖爆发尖峰。',
   '- 测试走完整生产伤害、奖励、箭与技能任务；生产改造内容须结合本次源码快照和优化对照报告阅读。','',
  '## 输入与测量','',
  '- 77 块：7 × 11 满网格，移除通常的缺口/障碍，属于满网格上界，不是自然生成关卡。',
  '- 240 块：真实存档恢复允许的砖块数量上限，12 × 20 密集网格、54 × 28 砖；是合成容量极限，不是默认关卡布局。',
  '- 特殊砖目标占比 0% / 22% / 50%，数量为 floor(砖数 × 占比)，五种特殊砖均衡分配、固定种子 843427 随机散布。22% 是普通特殊砖占比的渐近上限，50% 是超常极限。',
  '- 无技能与四槽技能组：连环殉爆 cascade、连锁风暴 storm、绝对零度 blizzard、棱镜折射 prism。第 9 关，使用生产基础 HP。',
  '- 通过生产 generate(true) 创建真正的 Matter 砖块；正常 shoot() 初始化主箭/技能预算。所有剩余砖在同一同步循环中调用生产 projectileHit()，测试性地将该箭伤害临时设为 1e9；没有绕过深度上限或清空砖数组来伪造击碎。伤害在 finally 中恢复。',
  '- 从首击后立即绘制计冷首帧。Game.fx 清空，棋盘/字体预热；不会预热命中粒子。瞬间逻辑与首帧逐次记录，不从各自中位数相加推算事件中位数；射击初始化不计入击碎逻辑。',
  '- 后续至少 6 秒墙钟、5.5 秒模拟，按生产物理步长/累计器运行真实 tick/render，并恢复 DOM 的原生 rAF 动画。保留停顿、慢镜、核心显现及后续实际核心击破，仅延后自动生成下一关。',
  '- 按模拟年龄分 0–0.2s / 0.2–1s / 1–3s / 3s–结束统计，记录每 100ms 的更新/绘制/数量轨迹与帧边界峰值（不是创建过程的瞬时内部峰值）。截图不计入采样帧间隔。',
  '- 同步模式计绘制 + 1px 读回；rAF 模式没有读回。禁用 GPU/垂直同步；这些帧间隔不是手机 FPS，音频未解锁，亦未验证目标 X5 的温升和 GPU。',
  `- 正常同步每案 ${normal.data.config.boardRepeats} 次独立重置；少量事件样本的 p95/max 只用于暴露波动，不应视为稳定分位估计。CPU：${normal.data.environment.cpu}；DPR：${normal.data.config.dpr}。`,'',
  '## 瞬间成本与爆发动画（ms）','',
  '| 砖数 | 目标 / 实际特殊占比 | 技能 | 逻辑中位 | 首绘中位 | 整个事件中位 / 最大 | 首秒绘制 p95 上界 | 性能模式逻辑 / 事件中位 |',
  '|---:|---:|---|---:|---:|---:|---:|---:|'];
for(const r of normal.rows){const reducedRow=rmap.get(key(r));
  lines.push(`| ${r.n} | ${Math.round(r.rate*100)}% / ${f(r.runs[0].fixture.actualRate*100)}% | ${load(r)} | ${f(r.burstMs.median)} | ${f(r.firstDrawMs.median)} | ${f(r.eventMs.median)} / ${f(r.eventMs.max)} | ${f(hot(r))} | ${reducedRow?f(reducedRow.burstMs.median)+' / '+f(reducedRow.eventMs.median):'—'} |`);
}
lines.push('','首秒上界取前两年龄段各自 p95 的较大值；完整六秒绘制中位主要反映退场/空画面，不作为爆发结论。','',
  '## 五种特殊砖配额','',
  '| 砖数 | 目标占比 | 普通 | 爆破 | 电弧 | 冰晶 | 分裂 | 金矿 |','|---:|---:|---:|---:|---:|---:|---:|---:|');
for(const r of normal.rows.filter(r=>r.loadout==='plain')){const c=r.runs[0].fixture.counts;
  lines.push(`| ${r.n} | ${Math.round(r.rate*100)}% | ${c.normal} | ${c.bomb} | ${c.lightning} | ${c.frost} | ${c.prism} | ${c.gold} |`);
}
lines.push('','## 校验与动画峰值','',
  '| 模式 | 砖数 | 目标占比 / 技能 | 全毁校验 | 碎屑 / 环 / 电弧 / 箭 / 图案 | 最大更新 ms | rAF 间隔 p95 ms |','|---|---:|---|---|---|---:|---:|');
for(const s of sources)for(const r of s.rows){const p=r.peaks;
  lines.push(`| ${s.engine} / ${s.data.config.reduced?'性能':'正常'} / ${s.data.config.raf?'rAF':'读回'} | ${r.n} | ${Math.round(r.rate*100)}% / ${load(r)} | ${r.runs.length} 次通过 | ${p.particles} / ${p.rings} / ${p.bolts} / ${p.arrows} / ${p.effects} | ${f(r.updateMs.max)} | ${f(r.frameMs.p95)} |`);
}
lines.push('','`frameMs` 从事件后开始记录，强制击碎的同步阻塞另见 `eventMs`，不要把这段阻塞漏掉。电弧在首次 tick 前可能高于 64，生产 tick 会按原预算裁剪；此表保留裁剪前峰值。','',
  '## 浏览器与原始记录','');
for(const s of sources)lines.push(`- [${s.file}](${s.file})：${s.rows.length} 案；${s.data.config.userAgent}；Canvas ${s.data.config.canvas.join(' × ')}。`);
if(!sources.some(s=>s.engine==='chrome89'))lines.push('- 本目录尚无 Chromium 89 整板结果，不能声称通过旧引擎验证。');
const notesFile=path.join(dir,'run-notes.json');
if(fs.existsSync(notesFile)){
  lines.push('','## 未完成运行与复核','');
  for(const note of JSON.parse(fs.readFileSync(notesFile,'utf8')).notes)lines.push('- '+note);
}
if(fs.existsSync(path.join(dir,'VALIDATION.md')))lines.push('','完整测试命令与门禁结果见 [VALIDATION.md](VALIDATION.md)。');
lines.push('','截图文件的 before / instant / animated 分别为击碎前、击碎后首次画面、约 0.15s 的动画画面；仅透明 Canvas，不含 CSS 背景或 HUD。','',
  '复跑命令见 [bench/FX-README.md](../../../FX-README.md#整板同时击碎极限测试)。所有 Chrome 测试须串行，不能并行争抢 CPU。');
const header=['engine','mode','method','n','targetSpecialRate','actualSpecialRate','loadout','repeat','burstMs','firstDrawMs','eventMs','destroyed','remaining','coinDelta','directCalls','recursiveKills','wallMs','gameSeconds','coreCleared','peakParticles','peakRings','peakBolts','peakArrows','peakEffects','earlyDrawP95Ms','maxUpdateMs','frameP95Ms'];
const csv=[header.join(',')];
for(const s of sources)for(const r of s.rows)for(const run of r.runs)csv.push([
  s.engine,s.data.config.reduced?'reduced':'normal',s.data.config.raf?'raf':'readback',r.n,r.rate,run.fixture.actualRate,r.loadout,run.repeat,
  run.burstMs,run.firstDrawMs,run.eventMs,run.outcome.destroyed,run.outcome.remaining,run.outcome.coinDelta,run.outcome.directCalls,run.outcome.recursiveKills,
  run.wallMs,run.gameSeconds,run.coreCleared,r.peaks.particles,r.peaks.rings,r.peaks.bolts,r.peaks.arrows,r.peaks.effects,hot(r),r.updateMs.max,r.frameMs.p95
].join(','));
fs.writeFileSync(path.join(dir,'REPORT.md'),lines.join('\n')+'\n');
fs.writeFileSync(path.join(dir,'comparison.csv'),csv.join('\n')+'\n');
console.log('Whole-board report:',path.relative(root,path.join(dir,'REPORT.md')));
