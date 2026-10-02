#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {summarize} from './fx-profile.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const dir=path.resolve(process.argv[2]||path.join(root,'bench/results/fx-burst-optimized'));
const json=p=>JSON.parse(fs.readFileSync(p,'utf8'));
const key=r=>`${r.group}/${r.id}/${r.n}`;
function files(folder){return fs.readdirSync(folder).filter(n=>n.endsWith('.json')).map(n=>({name:n,data:json(path.join(folder,n))})).filter(s=>s.data.results);}
function validate(data){
  if(data.errors.length||data.pageErrors.length)throw Error('Page or benchmark errors');
  for(const r of data.results.filter(r=>r.group==='board-burst'))for(const run of r.runs){const o=run.outcome;
    if(o.destroyed!==r.n||o.totalDelta!==r.n||o.remaining!==0||o.simulationAdvanced!==0||
      o.coinDelta!==o.shotMoney||o.coinDelta!==o.levelMoney||Object.values(run.tail).some(n=>n!==0))throw Error('Invalid board '+key(r));
  }
}
const before=files(path.join(dir,'before')),after=files(path.join(dir,'after'));
const fingerprint=new Map();
for(const s of [...before,...after,...files(path.join(dir,'after/chrome89'))]){
  validate(s.data);for(const r of s.data.results.filter(r=>r.group==='board-burst'))for(const run of r.runs){
    const f=JSON.stringify([run.fixture,run.outcome]);if(fingerprint.has(key(r))&&fingerprint.get(key(r))!==f)throw Error('Gameplay changed: '+key(r));fingerprint.set(key(r),f);
  }
}
const number=n=>n.toFixed(2),change=(a,b)=>(1-b/a)*100;
const hot=r=>Math.max(...r.phases.slice(0,2).filter(p=>p.costMs).map(p=>p.costMs.p95));
const rows=[];
for(const reduced of [false,true]){
  const b=before.find(s=>s.data.config.reduced===reduced&&!s.data.config.raf),a=after.find(s=>s.data.config.reduced===reduced&&!s.data.config.raf);
  if(!b||!a)throw Error('Missing before/after mode');
  const map=new Map(a.data.results.map(r=>[key(r),r]));
  for(const r of b.data.results.filter(r=>r.group==='board-burst')){
    const next=map.get(key(r));if(!next||r.runs.length<3||next.runs.length<3)throw Error('Missing repetitions');
    rows.push({reduced,before:r,after:next});
  }
}
const normal=rows.filter(r=>!r.reduced),worst=Math.max(...normal.map(r=>r.after.eventMs.max));
const lines=['# 整板爆发 CPU／冷缓存改造对照','',
  '## 结论','',
  `- 同机、同一测试驱动、独立存档、串行前后对照；两种模式各 12 案，每案各 3 次。24 组全部通过完整 outcome 一致性校验（含直接/递归击碎数、核心、收益与配额），尾段对象清零。`,
  `- 改造后主体三轮现代引擎、正常同步读回组最大单次事件 ${number(worst)}ms；无读回/旧引擎和补测异常另列下方。仍不能保证极限爆发在 16.7ms 内，更不能据此声称 Android X5 稳定 60 FPS。`,
  '- 逻辑保持同步，不分摊伤害/任务到多帧，不减少奖励、箭、技能触发、命中停顿或慢镜。仅合并展示更新和重复工作。','',
  '## 实现','',
  '- `game.js`：复用 Intl 数字格式器；命中 HUD 标脏，到绘制边界统一刷新；半径查询先做轴向拒绝，近邻使用稳定 top-k，保持原排序中的同距顺序；只复用被容量淘汰的碎屑对象，随机序列、可见值、顺序和 300 上限不变。',
  '- `skills-ui.js` / `render.js`：统一刷新完整 HUD 包装链与待绘反馈，避免把成本漏到计时之外。暂停/商店等显式 UI 请求仍保留 rAF 后备。',
  '- `juice.js` / `milestone.js`：同帧连击脉冲和四 Boss 命中脉冲/HUD 分别合并；保持最终热度、技能身份、180ms 动画和 Boss 血量/预警。',
  '- `fx.js` / `skill-signatures.js` / `skill-effects.js`：只在就绪、无箭/拖拽/弹窗时，每个空闲回调预建一个常用复杂图案姿态；待建不超过 72、共享 atlas 仍为 16 MiB/384 张。冷态每帧两张新贴图；预算耗尽可复用同技能/颜色/密度/尺寸的相邻 1/16 生命周期姿态，否则保留矢量回退。Chrome 89 支持带检测的定时器后备。','',
  '## 全矩阵（ms）','',
  '| 模式 | 砖数 | 特殊 / 配装 | 击碎逻辑前 → 后 | 首绘前 → 后 | 事件中位前 → 后 | 事件降幅 | 后最大事件 | 首秒绘制 p95 前 → 后 |',
  '|---|---:|---|---:|---:|---:|---:|---:|---:|'];
const csv=['mode,n,rate,loadout,beforeBurstMs,afterBurstMs,beforeFirstDrawMs,afterFirstDrawMs,beforeEventMs,afterEventMs,eventReductionPercent,afterMaxEventMs,beforeEarlyDrawP95Ms,afterEarlyDrawP95Ms'];
for(const r of rows){const b=r.before,a=r.after;
  lines.push(`| ${r.reduced?'性能':'正常'} | ${a.n} | ${Math.round(a.rate*100)}% / ${a.loadout==='chain'?'四技能连锁':'无技能'} | ${number(b.burstMs.median)} → ${number(a.burstMs.median)} | ${number(b.firstDrawMs.median)} → ${number(a.firstDrawMs.median)} | ${number(b.eventMs.median)} → ${number(a.eventMs.median)} | ${number(change(b.eventMs.median,a.eventMs.median))}% | ${number(a.eventMs.max)} | ${number(hot(b))} → ${number(hot(a))} |`);
  csv.push([r.reduced?'reduced':'normal',a.n,a.rate,a.loadout,b.burstMs.median,a.burstMs.median,b.firstDrawMs.median,a.firstDrawMs.median,b.eventMs.median,a.eventMs.median,change(b.eventMs.median,a.eventMs.median),a.eventMs.max,hot(b),hot(a)].join(','));
}
const regressions=rows.filter(r=>r.after.eventMs.median>r.before.eventMs.median*1.2&&r.after.eventMs.median-r.before.eventMs.median>2);
lines.push('',`事件明显回退（>20% 且 >2ms）：${regressions.length} 组；所有组均已列出，不只选择改善项。`,'',
  '首绘上升不全是光栅变慢：after 将合并后的 HUD 刷新同步计入首绘，before 的普通 HUD 刷新仍在后续原生 rAF 中；这是对 after 更保守的口径，未移出计时来隐藏工作。','',
  '## 动态冷缓存（ms）','',
  '这些测试强制清空 atlas、循环全部动画姿态，不利用就绪预热掩盖首帧；物理冻结，不是实际帧率。','',
  '| 图案 | 数量 | 冷首帧前 → 后 | 绘制中位前 → 后 | 绘制 p95 前 → 后 |','|---|---:|---:|---:|---:|');
const animations=[];
for(const side of ['before','after']){const s=files(path.join(dir,'animation',side))[0];validate(s.data);animations.push(new Map(s.data.results.filter(r=>r.group==='animation').map(r=>[key(r),r])));}
for(const [k,b] of animations[0]){const a=animations[1].get(k);if(!a)throw Error('Missing animation '+k);
  lines.push(`| ${a.id} | ${a.n} | ${number(b.firstDrawMs)} → ${number(a.firstDrawMs)} | ${number(b.costMs.median)} → ${number(a.costMs.median)} | ${number(b.costMs.p95)} → ${number(a.costMs.p95)} |`);
}
lines.push('','没有宣称所有动画档位或冷首帧都改善。mixed ×56 的持续绘制下降，但雪爆两档冷首帧明显升高，其他档位有波动/回退；每案只有一个冷首帧样本，不能判断其稳定分位。空闲预热已由浏览器验证，强制清空缓存的合成爆发仍有矢量回退和尖峰。','',
  '## 无读回、旧引擎与异常尖峰','',
  '| after 组 | 最大事件 ms | 最大后续 tick ms |','|---|---:|---:|');
for(const s of [...after,...files(path.join(dir,'after/chrome89'))]){const board=s.data.results.filter(r=>r.group==='board-burst');
  lines.push(`| ${s.data.config.userAgent.includes('Chrome/89.')?'Chromium 89':'现代'} / ${s.data.config.reduced?'性能':'正常'} / ${s.data.config.raf?'无读回':'同步读回'} | ${number(Math.max(...board.map(r=>r.eventMs.max)))} | ${number(Math.max(...board.map(r=>r.updateMs.max)))} |`);
}
lines.push('','正常同步 240 块 / 50% / 连锁退场曾出现一次 1552.3ms tick，无读回与旧引擎首次无技能事件分别达 145.2ms / 133.44ms。原始记录保留，不能用低 p95 或 43.4ms 同步事件最大值掩盖它们；尚未定位到单项根因，不能断言都是外部调度，也不能声称消除卡顿。');
if(fs.existsSync(path.join(dir,'recheck/before'))&&fs.existsSync(path.join(dir,'recheck/after'))){
  const b=files(path.join(dir,'recheck/before'))[0],a=files(path.join(dir,'recheck/after'))[0];
  validate(b.data);validate(a.data);const map=new Map(a.data.results.map(r=>[key(r),r]));
  lines.push('','## 性能模式 50% 特殊砖：独立复核','',
    '另跑 before/after 各五次；不替换、不拼接原三次结果，用于复核上述两组回退。','',
    '| 砖数 | 配装 | 事件中位前 → 后 ms | after 最大 ms |','|---:|---|---:|---:|');
  for(const r of b.data.results.filter(r=>r.group==='board-burst')){const next=map.get(key(r));if(!next)throw Error('Missing recheck');
    for(const row of [r,next])for(const run of row.runs)if(JSON.stringify([run.fixture,run.outcome])!==fingerprint.get(key(row)))throw Error('Recheck gameplay changed');
    lines.push(`| ${r.n} | ${r.loadout==='chain'?'四技能连锁':'无技能'} | ${number(r.eventMs.median)} → ${number(next.eventMs.median)} | ${number(next.eventMs.max)} |`);
  }
}
if(fs.existsSync(path.join(dir,'recheck/normal-tail'))){
  const s=files(path.join(dir,'recheck/normal-tail'))[0];validate(s.data);
  lines.push('','正常模式 50% 连锁另复核三次（不替换原数据）：','',
    '| 砖数 | 事件中位 / 最大 ms | 后续 tick 最大 ms |','|---:|---:|---:|');
  for(const r of s.data.results.filter(r=>r.group==='board-burst')){
    for(const run of r.runs)if(JSON.stringify([run.fixture,run.outcome])!==fingerprint.get(key(r)))throw Error('Tail recheck gameplay changed');
    lines.push(`| ${r.n} | ${number(r.eventMs.median)} / ${number(r.eventMs.max)} | ${number(r.updateMs.max)} |`);
  }
  lines.push('','独立复核不能证明已修复单次长阻塞；其与原始异常同时保留，下一步需要在目标真机按事件采样，而不是继续只看软件光栅平均值。');
}
lines.push('','## CPU 采样','',
  'CPU profile 与上述非采样跑分分开，采样会明显增加成本。下表只累计实际整板 `strike()` 子树的叶节点样本，不把六秒读回/空闲尾段算成击碎热点。两案、稀疏采样仅用于确认重复工作，不是精确占比。');
for(const side of ['before','after']){
  const p=path.join(root,'agent-tmp',`perf-${side}-profile/cpu-profile.cpuprofile`);if(!fs.existsSync(p))continue;
  const summary=summarize(json(p));fs.writeFileSync(path.join(dir,`cpu-${side}-summary.json`),JSON.stringify(summary,null,2)+'\n');
  lines.push('',`### ${side}（击碎子树 ${summary.burstSamples} 个样本，${number(summary.burstMs)}ms）`,'','| 叶节点 | 采样自身 ms |','|---|---:|');
  for(const row of summary.burst.slice(0,12))lines.push(`| ${row.location} | ${number(row.selfMs)} |`);
}
lines.push('','## 限制与复核','',
  '- 77 块为无缺口 7×11 满板，240 块为恢复容量极限 12×20 密集小砖；均是合成上界。五种特殊砖固定种子、均衡配额；主箭暂时设 1e9 伤害，同一模拟瞬间走真实 projectileHit。',
  '- `eventMs` 逐轮由逻辑 + 冷首绘相加，不能相加两个独立中位数。首次绘制包含本轮 HUD flush；后续 rAF 间隔不含击碎阻塞。',
  '- 所有 Chrome 串行，DPR=2、GPU/垂直同步关闭。同步绘制含 1px 读回，rAF 无读回另存；音频未解锁。墙钟命中停顿/慢镜保留。',
  '- 3 次事件样本仅用于比较中位数/暴露波动；不把 p95/max 当作稳定分位，不外推真机温升、GPU、音频或持续游玩 FPS。',
  '- [before/REPORT.md](before/REPORT.md) / [after/REPORT.md](after/REPORT.md) 包含完整逐轮结果、配额、年龄段与现代无读回/旧引擎结果。原审计结果未覆盖。',
  '- [source-checkpoints.json](source-checkpoints.json) 保存源码 SHA-256，[production.diff](production.diff) 是本轮生产改动；before 是本轮开始时的未提交工作区快照，不是 git HEAD。源码快照与原始 cpuprofile 暂存于 ignored `agent-tmp/`。',
  '- [runs.json](runs.json) 记录实际执行命令；浏览器集成检查/完整测试记录见 [VALIDATION.md](VALIDATION.md)。');
fs.writeFileSync(path.join(dir,'REPORT.md'),lines.join('\n')+'\n');fs.writeFileSync(path.join(dir,'comparison.csv'),csv.join('\n')+'\n');
console.log('Burst comparison:',path.relative(root,path.join(dir,'REPORT.md')));
