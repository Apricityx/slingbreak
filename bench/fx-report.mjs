#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
const dir=path.resolve(process.argv[2]||'bench/results/fx-audit');
const normal=JSON.parse(fs.readFileSync(path.join(dir,'fx-dpr2-normal.json')));
const reducedPath=path.join(dir,'fx-dpr2-reduced.json');
const reduced=fs.existsSync(reducedPath)?JSON.parse(fs.readFileSync(reducedPath)):null;
const f=n=>Number(n).toFixed(2),key=r=>`${r.group}/${r.id}/${r.n}`;
const base=normal.results.find(r=>r.id==='board').costMs.median;
const rmap=new Map((reduced?.results||[]).map(r=>[key(r),r]));
const names=Object.fromEntries([...fs.readFileSync('skills.js','utf8').matchAll(/entry\('([^']+)','([^']+)'/g)].map(m=>[m[1],m[2]]));
const name=id=>names[id]?`${names[id]} (${id})`:id;
const sorted=rows=>[...rows].sort((a,b)=>b.costMs.median-a.costMs.median);
const skills=normal.results.filter(r=>['impact','hero','trail'].includes(r.group));
const at=(group,id,n)=>normal.results.find(r=>r.group===group&&r.id===id&&r.n===n);
const table=rows=>['| 类型 / 特效 | 同屏数 | 中位 ms | p95 ms | 性能模式 ms |',
  '|---|---:|---:|---:|---:|',...rows.map(r=>`| ${r.group} / ${name(r.id)} | ${r.n} | ${f(r.costMs.median)} | ${f(r.costMs.p95)} | ${rmap.has(key(r))?f(rmap.get(key(r)).costMs.median):'—'} |`)].join('\n');
const lines=[
  '# 当前工作区粒子与特效性能压力测试',
  '',
  `测试时间：${normal.environment.date}。版本：\`${normal.environment.gitHead}\` **加当前未提交修改**。没有修改游戏逻辑或清除用户存档。`,
  '', '## 结论先读', '',
  `- **普通碎屑不是当前主要瓶颈**：游戏上限 300 个，总绘制成本 ${f(at('core','square-particles',300).costMs.median)}ms，空棋盘 ${f(base)}ms，增量约 ${f(at('core','square-particles',300).costMs.median-base)}ms。`,
  `- **复杂图案 + shadowBlur 是最明确的热点**：暴风雪 hero ×12 为 ${f(at('hero','blizzard',12).costMs.median)}ms；×23 为 ${f(at('hero','blizzard',23).costMs.median)}ms；×24 因关闭模糊反降为 ${f(at('hero','blizzard',24).costMs.median)}ms。无读回 rAF 复核亦保留这一门槛效应。`,
  `- **箭雨压力上界需要降级**：暴风雪拖尾 ×64 为 ${f(at('trail','blizzard',64).costMs.median)}ms；连击热拖尾 ×64 为 ${f(at('core','overdrive-glow',64).costMs.median)}ms；火轮 ×12 为 ${f(at('core','firewheel',12).costMs.median)}ms。`,
  `- **无上限扩散环比普通碎屑危险得多**：环 ×100 为 ${f(at('core','rings',100).costMs.median)}ms，×300 为 ${f(at('core','rings',300).costMs.median)}ms；300 电弧为 ${f(at('core','bolts',300).costMs.median)}ms。极端档位不代表日常自然同屏数。`,
  '- **Boss 重点是巨蟒的大面积渐变/背景、传送门和日蚀光源**。碎片、尘点、线状星芒相对轻；不能因为合成 300 枚熔炉陨火很慢，就认定正常只发 3–4 枚的场景有严重问题。',
  '- **性能模式有效，但不是彻底解决**：实际会同时把 Canvas DPR 上限降到 1、关闭部分模糊/动画；拖尾和多数图案数量不变，仍应做按绘制预算降级。',
  '',
  '## 方法与适用范围',
  '',
  `- CPU：${normal.environment.cpu}；Chromium：${normal.config.userAgent}。`,
  `- 视口 412 × 915；DPR=${normal.config.dpr}；游戏 Canvas ${normal.config.canvas.join(' × ')}。禁用 GPU，使用软件光栅。`,
  `- 扫描全部 ${normal.coverage.profiles} 个技能视觉配置，与 ${normal.coverage.catalog} 个技能目录逐项对应，缺失 ${normal.coverage.missingProfiles.length} 个。普通命中特效 1/12/56，强制主特效 1/12/23/24/56，拖尾 1/12/64。`,
  `- 正常模式 ${normal.results.length} 个案例；性能模式 ${reduced?.results.length||0} 个案例。`,
  '- 加载完整 index.html、真实绘制代码和真实 HUD。仅在测试服务器响应中插入私有数组访问钩子；源文件不改写。',
  '- 性能模式主表对照的是 Canvas DPR 上限与 JS 绘制降级；不是整套 DOM 动画节省量的 A/B。DOM 粒子另在正常模式复核。',
  '- 冻结时间与模拟，保持可见年龄分布，每案例预热 3 帧，计时窗口至少 120ms、至少 12 次。记录提交耗时与“绘制 + 同步 1px 读回”耗时。读回确保 Canvas 光栅工作完成，避免只测到命令入队。',
  '- **表格是同步光栅压力成本，不是游戏实测 FPS**。读回本身有成本；绝对值不能外推手机 GPU/WebView。16.67ms/33.33ms 只作为 60/30Hz 绘制预算参照，不保证帧率。物理、连锁逻辑和音频开销不计入这些表。',
  '- Boss 单粒子表使用相同 Canvas 尺寸，调用真实私有绘制器，独立于整个游戏场景；不能直接和“完整画面”表相减。Boss 场景另用生产棋盘生成与实际技能启动器测试。',
  '- 超过硬上限的档位仅用于定位增长趋势。无硬上限不表示实际能达到 300/1000 个；触发频率和生命期仍限制实际数量。',
  '- hero 压力样本为每个图案强制打开发光，用于定位最坏代价；并非每个技能正常命中都会进入 hero。单技能普通特效受 85ms 冷却/生命期限制，通常远低于 56 个。64 火轮也是假设性同屏上界：自然流程只给主箭装备火轮。',
  '- 熔炉陨火每次实际发射 3–4 枚，70/300 枚仅为合成压力；开场始终是 60 碎片，4/16 份场景也是合成压力。完整限制说明见 `bench/FX-README.md`。',
  `- 完整画面基线 ${f(base)}ms；独立空画布基线 ${f(normal.results.find(r=>r.id==='empty-canvas').costMs.median)}ms。`,
  '',
  '## 最重的技能特效（容量范围内的压力上界，前 20）',
  '',table(sorted(skills).slice(0,20)),
  '',
  '## 12 个同时触发的发光压力：最重的主特效',
  '',table(sorted(skills.filter(r=>r.group==='hero'&&r.n===12)).slice(0,15)),
  '',
  '## 64 支箭的拖尾压力：前 15',
  '',table(sorted(skills.filter(r=>r.group==='trail'&&r.n===64)).slice(0,15)),
  '',
  '## 通用粒子与相邻发光效果',
  '',table(normal.results.filter(r=>['core','adjacent'].includes(r.group))),
  '', '## 实际使用的技能变体（大范围新星、横纵光束、标记）',
  '',table(normal.results.filter(r=>r.group==='variant')),
  '', '## 扩展技能机械特效（信号、锯盘、持续场）',
  '',table(normal.results.filter(r=>r.group==='mechanic')),
  '',
  '## Boss 粒子（独立绘制压力）',
  '',table(normal.results.filter(r=>r.group==='boss-particle')),
  '',
  '## Boss 完整场景',
  '',table(normal.results.filter(r=>r.group==='boss-scene')),
  '',
  '## 每个技能的测试结果（81 项，不遗漏轻量技能）',
  '',
  '| 技能 | 普通命中 ×12 / ×56 ms | 发光主特效 ×12 / ×23 / ×24 ms | 拖尾 ×12 / ×64 ms |',
  '|---|---:|---:|---:|',
];
for(const id of [...new Set(skills.map(r=>r.id))]){
  const get=(g,n)=>f(skills.find(r=>r.id===id&&r.group===g&&r.n===n).costMs.median);
  lines.push(`| ${name(id)} | ${get('impact',12)} / ${get('impact',56)} | ${get('hero',12)} / ${get('hero',23)} / ${get('hero',24)} | ${get('trail',12)} / ${get('trail',64)} |`);
}
lines.push('','## 实现风险与优化优先级','',
  '1. **优先解决强制主特效的逐图元 shadowBlur**：`skill-effects.js:224` 在 `hero && effects.length < 24` 时启用 blur=8；整段 signature 的每次 stroke/fill 都会走模糊。复杂雪花/射线图案倍增光栅成本。先缓存光晕精灵或单独绘制一次光晕，避免让所有轮廓分别模糊。',
  '2. **不能只依赖 56 个技能特效上限**：23 个时有模糊、24 个时忽然关闭，最高成本不一定出现在 56 个。应按累计绘制预算降级，而不是仅在一个数量门槛后关闭模糊。',
  '3. **连击 overdrive 热拖尾**：`juice.js:90-96` 给每支热箭执行 shadowBlur=14，最多 64 支箭，无详细特效预算。建议共享精灵/降级前 N 支发光，其余保留清晰线条。',
  '4. **拖尾没有整体降级**：`skill-effects.js:232-257` 每帧为多股曲线创建 map 数组/点对象并多次 stroke；`index < 12` 只限制箭头装饰，不限制 64 支箭的拖尾。雪花/水晶类的装饰需要额外逐点绘制。建议复用点缓冲、批路径、按同屏箭数缩减装饰和曲线股数。',
  '5. **无硬数量预算的共享特效**：`Game.rings`、`Game.bolts`、`Game.texts` 仅按生命期清理，没有同屏上限。大量连锁可堆积；实测大面积环的开销明显高于浮字。建议先限制/合并环，再处理电弧，浮字可按区域合并。',
  '6. **Boss 高面积效果**：巨蟒除了 flare、portal、spark、eclipse，还有 `boss-serpent.js:574-597` 每帧三个大范围星云渐变和 26/48/70px 宽的虚影曲线；背景不是免费成本。日蚀还为每支箭各绘一个 destination-out 渐变洞。熔炉陨火逐点圆形拖尾。建议缓存静态渐变纹理、限制光源孔/陨火数、降低大面积渐变分辨率。',
  '7. **性能模式不是完整的数量削减**：会关闭 shadowBlur/冻结部分动画，普通粒子生成减少、Canvas DPR 上限降到 1，但技能 effect 56 上限和拖尾图案数量不变；原始样本另测，不能认为开启后所有特效都会轻量。',
  '',
  `测试错误：normal=${normal.errors.length} / 页面异常=${normal.pageErrors.length}；reduced=${reduced?.errors.length??'未运行'}。`,
  '',
  '完整原始样本见同目录 JSON；所有逐项结果见 `fx-all.csv`。');
const rafPath=path.join(dir,'fx-dpr2-normal-raf-filtered.json');
if(fs.existsSync(rafPath)){
  const raf=JSON.parse(fs.readFileSync(rafPath));
  lines.push('','## 无读回 rAF 复核（绘制循环；无物理模拟）','',
    '| 特效 | 同屏数 | 平均帧间隔 ms | p95 ms | rAF FPS |','|---|---:|---:|---:|---:|',
    ...raf.results.filter(r=>r.frameMs).map(r=>`| ${r.group}/${name(r.id)} | ${r.n} | ${f(r.frameMs.mean)} | ${f(r.frameMs.p95)} | ${f(r.fps)} |`),
    '', '本轮禁用垂直同步，不把此 FPS 当作真实手机帧率；用于检查同步读回排名是否在正常浏览器绘制调度中仍然显著。');
}
const layersPath=path.join(dir,'layers/fx-dpr2-normal-filtered.json');
let layers;
if(fs.existsSync(layersPath)){
  layers=JSON.parse(fs.readFileSync(layersPath));
  const lr=JSON.parse(fs.readFileSync(path.join(dir,'layers/fx-dpr2-normal-raf-filtered.json')));
  const lmap=new Map(lr.results.map(r=>[key(r),r]));
  lines.push('','## Boss 分层复核（正常模式）','',
    '| 场景 / 层 | 同步成本中位 ms | 无读回 rAF 均帧 ms |','|---|---:|---:|',
    ...layers.results.filter(r=>r.group!=='baseline').map(r=>`| ${r.group}/${r.id} | ${f(r.costMs.median)} | ${f(lmap.get(key(r)).frameMs.mean)} |`),
    '', 'back=背景，field=主体/场内粒子，front=前景。各层独立绘制，不含其余画面；分层之和不保证等于全场景。`serpent:idle` 是生成后固定的 emerge 快照，并非完整战斗各阶段的平均值。');
}
const domPath=path.join(dir,'fx-dpr2-normal-dom-filtered.json');
if(fs.existsSync(domPath)){
  const dom=JSON.parse(fs.readFileSync(domPath));
  lines.push('','## DOM 粒子（真实 rAF + 原生产 WAAPI 动画）','',
    '| 类型 | 发射份数 | 实际节点 | 生成 ms | rAF 均帧 ms | p95 ms |','|---|---:|---:|---:|---:|---:|',
    ...dom.results.filter(r=>r.group==='dom').map(r=>`| ${r.id} | ${r.n} | ${r.actualNodes} | ${f(r.spawnMs)} | ${f(r.frameMs.mean)} | ${f(r.frameMs.p95)} |`),
    '', '自然单次金币飞行 14 节点、成就火花最多 6 节点；强行重复 16 份金币为 224 节点，会出现较大的创建瞬时开销，但不是正常单次结算。成就火花超额请求仍被 6 节点上限挡住。本轮正常同屏数量下未发现持续帧开销严重增加。');
}
const extrasPath=path.join(dir,'extras/fx-dpr2-normal-filtered.json');
if(fs.existsSync(extrasPath)){
  const ex=JSON.parse(fs.readFileSync(extrasPath));
  const er=JSON.parse(fs.readFileSync(path.join(dir,'extras/fx-dpr2-reduced-filtered.json')));
  const em=new Map(er.results.map(r=>[key(r),r]));
  const ef=JSON.parse(fs.readFileSync(path.join(dir,'extras/fx-dpr2-normal-raf-filtered.json')));
  lines.push('','## 补充：吞噬碎块、断链、眼拖尾与巨蟒战斗态','',
    '| 场景 / 特效 | 数量 | 正常 ms | 性能模式 ms |','|---|---:|---:|---:|',
    ...ex.results.filter(r=>r.group!=='baseline').map(r=>`| ${r.group}/${r.id} | ${r.n} | ${f(r.costMs.median)} | ${f(em.get(key(r)).costMs.median)} |`),
    '', `巨蟒 live-body 无读回复核均帧 ${f(ef.results.find(r=>r.id==='serpent:live-body').frameMs.mean)}ms。此案例为第四阶段全能力同时启用的压力构筑，生成后通过真实 Game.tick 推进至身体出现，**不是自然每关随机只抽取部分能力的常态**。冻结取样的姿态、活鳞数量与日蚀状态可从 JSON 的 snapshot 复核；两种模式实际姿态有差异，不把本行当作严格同姿态 A/B。`);
}
lines.push('','## 仅更新成本（不含绘制）','',
  '| 类型 | 数量 | 每次 Game.tick 中位 ms |','|---|---:|---:|',
  ...normal.results.filter(r=>r.updateMs).map(r=>`| ${r.id} | ${r.n} | ${Number(r.updateMs.median).toFixed(4)} |`),
  '', '每档 12 组 ×100 次 tick，前两组预热丢弃，保持粒子生命期足够长。此处不包含箭矢飞行、命中连锁或音频，低于计时分辨率的微秒差值不作精细排名。');
fs.writeFileSync(path.join(dir,'REPORT.md'),lines.join('\n')+'\n');
const files=['fx-dpr2-normal.json','fx-dpr2-reduced.json','fx-dpr2-normal-raf-filtered.json',
  'fx-dpr2-normal-dom-filtered.json','layers/fx-dpr2-normal-filtered.json','layers/fx-dpr2-normal-raf-filtered.json',
  'extras/fx-dpr2-normal-filtered.json','extras/fx-dpr2-reduced-filtered.json','extras/fx-dpr2-normal-raf-filtered.json'];
const csv=['source,mode,group,id,count,isolated,synthetic,samples,median_ms,p95_ms,submit_median_ms,raf_mean_ms,raf_fps',
  ...files.filter(file=>fs.existsSync(path.join(dir,file))).flatMap(file=>{
    const b=JSON.parse(fs.readFileSync(path.join(dir,file)));
    return b.results.map(r=>[file,b.config.reduced?'reduced':'normal',r.group,r.id,r.n,!!r.isolated,!!r.synthetic,
      (r.costMs||r.frameMs).samples,r.costMs?f(r.costMs.median):'',r.costMs?f(r.costMs.p95):'',
      r.submitMs?f(r.submitMs.median):'',r.frameMs?f(r.frameMs.mean):'',r.fps?f(r.fps):''
    ].join(','));
  })];
fs.writeFileSync(path.join(dir,'fx-all.csv'),csv.join('\n')+'\n');
console.log('Wrote',path.join(dir,'REPORT.md'),'and fx-all.csv');
