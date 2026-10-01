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
- 可选：DOM 飞金币、成就火花、收益飞片；另用真实 rAF 测合成调度。

## 过滤与复核

```bash
node bench/fx-run.mjs '--filter=baseline|overdrive-glow|firewheel|blizzard' --sample=120
node bench/fx-run.mjs '--filter=baseline|overdrive-glow|firewheel|blizzard' --raf=1 --sample=1800
node bench/fx-run.mjs '--filter=^dom/' --dom=1 --sample=1200
```

`--raf=1` 不做同步像素读回，记录真实浏览器绘制调度的帧间隔，但冻结物理模拟。
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
