#!/usr/bin/env node
// Keep the original audit immutable. Compare the current production implementation
// against that saved baseline, with visual-budget changes explicitly disclosed.
import fs from 'node:fs';
import path from 'node:path';
const dir=path.resolve(process.argv[2]||'bench/results/fx-optimized');
const beforeDir=path.resolve(process.argv[3]||'bench/results/fx-audit');
const load=(folder,name)=>JSON.parse(fs.readFileSync(path.join(folder,name),'utf8'));
const key=r=>`${r.group}/${r.id}/${r.n}`,f=n=>n==null?'—':Number(n).toFixed(2);
const modes=['normal','reduced'];
const pairs=modes.map(mode=>{const name=`fx-dpr2-${mode}.json`,before=load(beforeDir,name),after=load(dir,name);return {mode,before,after,map:new Map(before.results.map(r=>[key(r),r]))};});
const normal=pairs[0],lookup=(mode,group,id,n)=>pairs[mode].after.results.find(r=>r.group===group&&r.id===id&&r.n===n);
const names=Object.fromEntries([...fs.readFileSync('skills.js','utf8').matchAll(/entry\('([^']+)','([^']+)'/g)].map(m=>[m[1],m[2]]));
const title=id=>names[id]?`${names[id]} (${id})`:id;
const improvement=(a,b)=>a?`${((1-b/a)*100).toFixed(0)}%`:'—';
const table=rows=>['| 场景 / 数量 | 优化前 ms | 优化后 ms | 降幅 | 优化后 p95 ms |','|---|---:|---:|---:|---:|',...rows.map(r=>{
  const old=normal.map.get(key(r));return `| ${r.group}/${title(r.id)} ×${r.n} | ${f(old?.costMs.median)} | ${f(r.costMs.median)} | ${old?improvement(old.costMs.median,r.costMs.median):'新场景'} | ${f(r.costMs.p95)} |`;
})].join('\n');
const csv=['mode,group,id,n,before_median_ms,after_median_ms,before_p95_ms,after_p95_ms,delta_ms,first_draw_ms'];
for(const p of pairs)for(const r of p.after.results){if(!r.costMs)continue;const old=p.map.get(key(r));csv.push([p.mode,r.group,r.id,r.n,old?.costMs.median??'',r.costMs.median,old?.costMs.p95??'',r.costMs.p95,old?r.costMs.median-old.costMs.median:'',r.firstDrawMs??''].join(','));}
fs.writeFileSync(path.join(dir,'comparison.csv'),csv.join('\n')+'\n');
const highlights=[['hero','blizzard',12],['hero','blizzard',23],['hero','blizzard',24],['hero','snowburst',12],['hero','starforge',12],['hero','supernova',12],['core','overdrive-glow',64],['core','firewheel',64],['core','rings',300],['core','bolts',300],['variant','supernova:nova',23],['boss-scene','serpent:idle',1]];
const lines=['# 粒子特效优化结果','',`生成于 ${new Date().toISOString()}。原审计未覆盖；比较来自原始 JSON 与优化后当前工作区。`,'',
  '## 主要结果','',table(highlights.map(([g,id,n])=>lookup(0,g,id,n))),
  '', '以上是相同测试环境下的绘制压力成本（真实绘制 + 同步像素读回），**不是手机实测帧率**。同屏数量相同，但优化后密集场景采用装饰预算、合并和小型替代图案，因此不代表完全相同的逐像素画面。',
  '', '## 实现与视觉取舍','',
  '- **81 个技能身份保留**：复杂雪花、蜂群、射线等轮廓缓存 17 个姿态；简单线条仍用矢量，避免贴图透明面积比原图形更贵。缓存图案内部细节量化动画，外部位置、透明度及调用方的旋转/缩放仍连续；不是逐像素原样复刻。',
  '- **主特效**：不再对每个图元启用 shadowBlur。最多 6 个新主特效附带柔光，完整普通命中预算为正常 24 / 性能模式 12；其余保留小型同色技能图案，不直接消失。大范围脉冲/光束/标记最多 4 / 2 个全尺寸。',
  '- **拖尾**：热箭采用整轮箭雨的三层批路径，保留白热核心；密集技能拖尾保留首 6 / 末 2 支的完整花纹，其余用有色双层尾迹。所有箭和碰撞规则不变。',
  '- **普通碎屑**：原有按颜色/透明度批绘制已经较快，保留 300 个容量；不为优化而削弱碎砖反馈。普通箭尾改成透明度分桶。',
  '- **共享环 / 电弧 / 浮字**：近距同色冲击环合并并提高能量；环储存上限 48 / 24，绘制 24 / 12 个最新环并额外保留最多 3 个旧巨型脉冲。电弧存储上限 64、绘制 48 / 24，按透明度批路径、24 Hz 更新电弧折点。浮字上限 48，收益聚合文字保留。',
  '- **机械特效**：扩展信号绘制预算 32 / 16，持续场装饰 6 / 3，完整火轮 8 / 3，其余火轮保留运动光点。仅减少绘制，不删除伤害场、延迟任务或锯盘。',
  '- **四个 Boss**：眼与时钟的碎片批路径；大范围光晕/暗幕共享纹理。熔炉保留所有陨火与落点预警，详细拖尾限最新 24 / 8 枚。巨蟒星云与远景虚影半分辨率 30 Hz 缓存，实际蛇身和预警逐帧绘制；光晕、传送门螺旋、日蚀孔与暗边缓存。日蚀仍给每支箭开孔，不隐藏可交互光源。',
  '- **开场 / DOM**：开场 60 个旋转碎片保持数量，合为三种颜色路径；背景网点批路径。飞金币最多 24、成就火花最多 6、收益飞片最多 3；只在最后一枚金币落地时弹一次钱包。DOM 动画取消也会清理计数，不产生未处理 Promise 拒绝。',
  '- **缓存**：LRU 上限 16 MiB（RGBA 像素预算）/ 384 张，实际浏览器对象和 GPU 内存可能更高；按实际舞台缩放、DPR、性能模式选择密度，主题变更清理缓存。每帧最多新建 2 张技能贴图，超额直接画矢量而不是延迟命中反馈。中等图案采用 64px 基准半径，四技能混合不再挤满缓存；无 Canvas 时回退原矢量实现。',
  '', '## 覆盖与回归','',
  ...pairs.map(p=>`- ${p.mode}：${p.after.coverage.cases} 个案例，${p.after.coverage.profiles}/${p.after.coverage.catalog} 个技能，缺失 ${p.after.coverage.missingProfiles.length}，测试错误 ${p.after.errors.length}，页面异常 ${p.after.pageErrors.length}。`),
  '- Node 回归：`node --test *.test.cjs bench/fx.test.mjs`；结果见 `validation.txt`。未提交 / 推送 Git，未重置用户原有修改。',
  '', '## 每个技能（正常模式）','',
  '| 技能 | 普通命中 ×12 前→后 ms | 主特效 ×12 前→后 ms | 拖尾 ×64 前→后 ms | 主特效 ×24 后 ms | 性能模式主特效 ×12 后 ms |','|---|---:|---:|---:|---:|---:|'];
for(const id of Object.keys(names)){
  const pair=(group,n)=>{const r=lookup(0,group,id,n);return `${f(normal.map.get(key(r))?.costMs.median)} → ${f(r.costMs.median)}`;};
  lines.push(`| ${title(id)} | ${pair('impact',12)} | ${pair('hero',12)} | ${pair('trail',64)} | ${f(lookup(0,'hero',id,24).costMs.median)} | ${f(lookup(1,'hero',id,12).costMs.median)} |`);
}
const regressions=normal.after.results.filter(r=>{const old=normal.map.get(key(r));return old&&r.costMs.median-old.costMs.median>=.7&&r.costMs.median>old.costMs.median*1.2;}).sort((a,b)=>(b.costMs.median-normal.map.get(key(b)).costMs.median)-(a.costMs.median-normal.map.get(key(a)).costMs.median));
lines.push('','## 未改善 / 波动较大的场景','',regressions.length?table(regressions):'本轮共同场景没有同时满足「增加 ≥0.7ms 且 ≥20%」的明显回退。',
  '', '不得只摘最佳样本：简单特效存在计时噪声与贴图/矢量取舍；原图案在 24 个时关闭 blur，而新实现保留有限光晕，部分 24 个压力场景不一定比原来的无光晕状态更快。');
for(const [folder,name,heading] of [['animation','fx-dpr2-normal-animated-filtered.json','动态缓存复核'],['raf','fx-dpr2-normal-raf-filtered.json','无同步读回 rAF 复核'],['dom','fx-dpr2-normal-dom-filtered.json','DOM 动画复核']]){
  const file=path.join(dir,folder,name);if(!fs.existsSync(file))continue;const data=load(path.join(dir,folder),name);
  lines.push('',`## ${heading}`,'',`错误 ${data.errors.length} / 页面异常 ${data.pageErrors.length}。`);
  if(folder==='animation')lines.push('','| 场景 | 数量 | 中位 ms | p95 ms | 首帧 ms | 缓存 MiB |','|---|---:|---:|---:|---:|---:|',...data.results.filter(r=>r.group==='animation').map(r=>`| ${r.id} | ${r.n} | ${f(r.costMs.median)} | ${f(r.costMs.p95)} | ${f(r.firstDrawMs)} | ${f(r.cache?.bytes/1048576)} |`),'','动画复核循环所有姿态，并且每场景清空缓存；混合样本轮流使用四种重图案。物理不推进，不是整场战斗 FPS。');
  else lines.push('','| 场景 | 数量 | 实际 DOM 节点 | 均帧 ms | p95 ms |','|---|---:|---:|---:|---:|',...data.results.filter(r=>r.frameMs).map(r=>`| ${r.group}/${r.id} | ${r.n} | ${r.actualNodes??'—'} | ${f(r.frameMs.mean)} | ${f(r.frameMs.p95)} |`),'','禁用垂直同步且使用软件光栅，不外推真实设备 FPS。');
}
lines.push('','## 测试限制与复跑','',
  '- 单技能 56 个、强制所有 hero、64 支热箭/火轮、70/300 枚陨火、重复开场与金币发射是容量或合成压力，不表示自然战斗常态。熔炉正常一次 3–4 枚陨火。',
  '- `serpent:idle` 仍是固定 emerge 快照；`serpent:live-body` 通过真实 tick/rAF 推进身体出现，但装配了全部第四阶段能力，且原始/优化数据不保证同姿态，不作为严格收益 A/B。',
  '- 主表冻结时间，缓存容易命中；另列动态冷缓存复核以避免只依赖静态结果。目标 Android WebView 的 GPU、发热与端到端帧率仍需真机验证。',
  '- 复跑见 `bench/FX-README.md`。完整逐案例比较见 `comparison.csv`，原始 JSON 留在本目录；最初审计留在 `bench/results/fx-audit/`。');
fs.writeFileSync(path.join(dir,'REPORT.md'),lines.join('\n')+'\n');
console.log(`Wrote ${path.relative(process.cwd(),dir)}/REPORT.md and comparison.csv; ${regressions.length} regression flags.`);
