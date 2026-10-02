# 全特效压力测试

```bash
node bench/fx-run.mjs --dpr=2 --sample=120
node bench/fx-run.mjs --dpr=2 --sample=120 --reduced=1
node bench/fx-report.mjs
```

依次运行，**不要并行**跑两个 Chrome 压测，避免抢占 CPU 污染结果。默认输出到
`bench/results/fx-audit/`。无 npm 依赖，要求 Node 22+ 和 Chrome/Chromium；可用
`CHROME_PATH` 指定浏览器。

## 覆盖

- 81 个技能的普通命中图案、hero 发光图案、14 点箭矢拖尾。
- 特殊大范围新星、横纵光束、轨道标记等运行时变体。
- 普通碎屑、环、电弧、浮字、聚合收益文字、热拖尾和火轮。
- 扩展技能的全部实际信号类型、锯盘、持续场。
- 四个 Boss 的独立粒子绘制器，以及完整场景/可直接启动的技能。
- 固定 60 碎片的开场动画。
- 整板同时击碎：77 / 240 块，0% / 22% / 50% 特殊砖，无技能 / 四槽连锁，真实击碎和后续模拟。
- 可选：DOM 飞金币、成就火花、收益飞片；另用真实 rAF 测合成调度。

## 过滤与复核

```bash
node bench/fx-run.mjs '--filter=baseline|overdrive-glow|firewheel|blizzard' --sample=120
node bench/fx-run.mjs '--filter=baseline|overdrive-glow|firewheel|blizzard' --raf=1 --sample=1800
node bench/fx-run.mjs '--filter=^dom/' --dom=1 --sample=1200
```

`--raf=1` 不做同步像素读回，记录真实浏览器绘制调度的帧间隔；原有静态案例冻结物理模拟，
`board-burst/` 案例运行真实物理、连锁、HUD、DOM 与退场。
软件光栅 + 禁用垂直同步的 FPS 不能当作真实手机 FPS。

## 不侵入生产代码

测试服务器读取当前工作区的 `index.html` 和 JS；只在 HTTP 响应中插入私有数组与绘制器的
访问钩子，并禁用自动游戏循环，交给基准驱动。**不会改写这些文件**。
每次运行创建独立临时 Chrome profile 和随机端口，不读取用户 Chrome/WebView 的存档。
结果针对当前工作区，包括未提交修改，不只是 Git HEAD。

## 读数含义

主表计时的是实际绘制函数 + 1px 同步读回，确保绘制命令真正执行，而不是只统计 JS 入队。
另记录提交耗时；通用数组额外跑仅更新 `Game.tick()` 的微基准。
这是一种保守的**绘制压力基准**，不是端到端游戏帧率测试。

数量上限：普通碎屑 300、箭矢 64、技能特效 56、锯盘 6、扩展信号 80/96、收益聚合浮字 8。
有上限的类型会测到其上限，无上限的类型会测更极端的增长趋势。

**不要把合法数组容量误认为自然游戏中的同时数量**：

- 同一个普通技能的发射有 85ms 冷却和不同生命期，通常远少于 56 个。
- hero 是特定 force 事件开启的状态，不是每个技能每次命中都有发光。对每个图案强制开启
  hero 是为了找出模糊的最坏代价，不表示该组合自然可达。
- 64 支箭都是某种拖尾样式属于箭雨压力上界。64 个 firewheel 装饰属于极端假设；
  正常火轮只装备在射击主箭上，不应把此值描述成常态。
- 熔炉每次只发射 3–4 枚陨火；70/300 枚的成本只用于揭示线性/光栅增长，不能据此声称
  正常熔炉战会卡顿。
- 重复 4/16 次完整开场、DOM 金币发射也是明确的合成压力场景。

绝对时间受 CPU、光栅实现、DPR、背景负载影响。先比较相同环境内的排名、降级效果、
23→24 的模糊门槛，再在目标 Android WebView 上复核，不宜直接外推。

测试工具自检：`node --test bench/fx.test.mjs`。

## 优化后复跑与视觉复核

原审计留在 `results/fx-audit/`，优化结果另存，不覆盖原始对照：

```bash
node bench/fx-run.mjs --dpr=2 --sample=120 --out=bench/results/fx-optimized
node bench/fx-run.mjs --dpr=2 --sample=120 --reduced=1 --out=bench/results/fx-optimized
node bench/fx-run.mjs --dpr=2 --sample=4000 --animated=1 '--filter=^animation/' --out=bench/results/fx-optimized/animation
node bench/fx-run.mjs --dpr=2 --sample=1200 --raf=1 '--filter=baseline|overdrive-glow|firewheel|blizzard|serpent:back' --out=bench/results/fx-optimized/raf
node bench/fx-run.mjs --dpr=2 --sample=1200 --dom=1 '--filter=^dom/' --out=bench/results/fx-optimized/dom
node bench/fx-compare.mjs
```

仍须**串行执行**。`--animated=1` 增加冷缓存、全部动画姿态循环与四种重技能混合案例，
防止只测固定姿态的缓存命中。物理仍冻结，不能代表完整游戏帧率。每个同步案例另记录
`firstDrawMs`（首次绘制，未必是完全冷缓存）和缓存像素内存；仅动画案例显式清空缓存。

`--capture=1` 将选中案例的实际游戏 Canvas 保存为 PNG；和 `--filter` 配合，避免生成上千张图。
它不包含 HUD / DOM 特效；这些仍由独立 DOM/rAF 测试测量。视觉复核示例：

```bash
node bench/fx-run.mjs --capture=1 '--filter=^hero/blizzard$|^core/firewheel$|^boss-scene/serpent:live-body$' --out=bench/results/fx-optimized/visual
```

优化后预算只作用于显示：普通命中完整图案 24/12，大范围特效 4/2，额外命中保留小型技能火花。
环储存 48/24、绘制最新 24/12 加最多 3 个旧巨型脉冲；电弧储存 64、绘制 48/24；浮字 48。
伤害、箭数、收益与实际持续场不因装饰预算削减。比较报告会明确列出「相同输入数量，
不同装饰实现」的限制，并完整披露显著回退，不只挑改善最大的样本。

## 整板同时击碎极限测试

默认全量测试包含 12 个 `board-burst/` 案例。单独复跑（**串行**）：

```bash
node bench/fx-run.mjs '--filter=^board-burst/' --board-repeats=3 --capture=1 --out=bench/results/fx-optimized/board-burst
node bench/fx-run.mjs '--filter=^board-burst/' --board-repeats=3 --reduced=1 --out=bench/results/fx-optimized/board-burst
node bench/fx-run.mjs '--filter=^board-burst/' --raf=1 --out=bench/results/fx-optimized/board-burst
node bench/fx-run.mjs '--filter=^board-burst/' --chrome=/absolute/path/to/real/chromium89 --capture=1 --out=bench/results/fx-optimized/board-burst/chrome89
node bench/fx-board-report.mjs
```

- 满网格 77 块（7 × 11，无缺口/障碍）与恢复容量极限 240 块（12 × 20，小砖密集布局）。
  两者均标为合成极限，尤其不能把 240 块当作默认关卡。
- 特殊砖目标占比 0%（对照）、22%（普通比例渐近上界）、50%（超常压力）；数量向下取整。
  固定种子，爆破/电弧/冰晶/分裂/金矿均衡分配，实际配额逐案写入 JSON。
- 两套配装：无技能；四槽 `cascade / storm / blizzard / prism`，只启用合法单级技能。
- 用真实 `generate(true)` 恢复 Matter 砖，正常 `shoot()` 初始化箭和任务预算，再临时设置
  主箭伤害为 1e9，调用生产 `projectileHit()` 在同一模拟瞬间击碎全板；真实递归、特殊效果、
  技能任务、箭容量、计分/成就/HUD 都保留。不会直接清空数组或绕过连锁深度限制。
- 默认每案一次，可用 `--board-repeats=3` 复测波动，每次独立重置；
  `--board-seconds=6` 控制最短墙钟观察期（至少 6 秒），还须模拟超过 5.5 秒并清完全部临时对象。
  按生产步长、累计器和原生 rAF 推进，不会把粒子强行固定在最重年龄。
- 保留实际核心显现及箭命中核心的清场效果，仅延后下一关生成，避免把新棋盘混入退场测量。
  DOM 自有 rAF 循环在本测试期间恢复；不解锁音频，不代表真实 WebView/GPU 或音频端到端性能。
- 分别记录击碎逻辑 `burstMs`、首次绘制 `firstDrawMs`、两者合计 `eventMs`、后续绘制/更新、
  每 100ms 轨迹、数量峰值、收益与全毁断言；瞬间事件无预热。
  后续整段绘制中位会被空闲尾段拉低，因此报告单列前 0.2 秒与 0.2–1 秒的 p95 上界。
- `frameMs` 是事件**之后**的 rAF 间隔，不含整板击碎的同步阻塞；必须同时看 `eventMs`。
  `--raf=1` 下首绘只计提交、无读回，不能与同步光栅首帧直接比较。
- `--capture=1` 保存每案第一轮的 before / instant / animated 三张 Canvas 图；截图不计入采样。
  JSON 另保留每次事件，`fx-board-report.mjs` 单独生成报告与逐轮 CSV，不改原静态对照报告。
- 本案例不使用 `--sample` 的静态预热/重复绘制逻辑；每次事件都必须真实击碎并退场。

自检：`node --test bench/fx-board.test.mjs bench/fx.test.mjs`。

## 击碎链 CPU 改造对照

本轮结果另存于 `results/fx-burst-optimized/`；不会覆盖上轮图案优化或整板原始数据。
`--source-root=/absolute/path/to/saved-source` 可让同一个测试驱动测试改造前源码快照
（须包含 `index.html`、生产 JS/CSS、`vendor/` 等资源），避免把未提交工作区误当成 Git HEAD。

```bash
node bench/fx-run.mjs --source-root=agent-tmp/perf-before-source '--filter=^board-burst/' --board-repeats=3 --out=bench/results/fx-burst-optimized/before
node bench/fx-run.mjs '--filter=^board-burst/' --board-repeats=3 --out=bench/results/fx-burst-optimized/after
# 前后都再加 --reduced=1；after 另跑 --raf=1 和实际 Chromium 89。
node bench/fx-run.mjs '--filter=^board-burst/chain:special-22$' --cpu-profile=1 --out=agent-tmp/perf-after-profile
node bench/fx-profile.mjs agent-tmp/perf-after-profile/cpu-profile.cpuprofile
node bench/fx-burst-compare.mjs
CHROME89_PUPPETEER=/absolute/path/to/puppeteer node bench/burst-ui.mjs
```

对照生成器需要 `before/after` 两种同步模式、`after/chrome89`、`animation/before/after`。
动态复跑使用上文 `--animated=1 '--filter=^animation/' --sample=4000`，分别指定源码快照。
CPU profile 会放大执行成本，**不要拿采样跑分替代未采样的前后指标**；分析工具单列
整板 `strike()` 子树的叶节点，不把六秒尾段读回或空闲算成击碎瓶颈。
浏览器集成检查验证整板 77 次击碎只刷新一次 HUD/收益/连击脉冲，四 Boss 的 64 次同步
伤害只触发一次血条展示/命中脉冲，并检查真实空闲预热。可用 `CHROME_BIN` 加测现代引擎。
