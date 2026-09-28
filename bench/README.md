# SlingBreak 性能测试 · 粒子数量 vs FPS

衡量「屏幕上同时存在多少个粒子」与「帧率」之间的关系，并验证粒子渲染优化的效果。

基准页不是重写一份粒子系统，而是**直接加载游戏真实的 `game.js` 与 `render.js`**，
因此测到的就是发行版循环本身 —— Matter.js 物理、`Game.tick()` 里的粒子积分、
以及 `render.js` 里画粒子的那一段全部照常运行。

## 文件

| 文件 | 作用 |
| --- | --- |
| `bench.html` | 基准页。只提供 `render.js` 需要的最小 DOM（`#game` canvas、`#power-readout`），然后按顺序加载 `vendor/matter.min.js` → `game.js` → `render.js` → `bench.js`。 |
| `bench.js` | 测试驱动。冻结棋盘，只控制 `Game.particles` 数量，用 `requestAnimationFrame` 采样帧间隔，并额外跑一个「只看 `Game.tick`」的 CPU 微基准。 |
| `bench/run.mjs` | 无头运行器。起一个本地静态服务器 + 本地 Chrome，通过 DevTools Protocol 读取结果，落盘 JSON / Markdown。不依赖任何 npm 包。 |
| `bench/compare.mjs` | 对比两个结果目录，按中位帧时间输出 A/B 表。 |
| `bench/results/` | 每次运行产出的 `bench-*.json` / `bench-*.md`，以及 `COMPARISON.md`。 |

## 快速开始（无头，一条命令）

```bash
node bench/run.mjs
```

自动寻找 Chrome / Chromium（也会用 `~/.cache/ms-playwright` 里 Playwright 下载的浏览器），
需要时用 `CHROME_PATH=/path/to/chrome` 指定。

```bash
node bench/run.mjs --counts=0,100,300,1000,3000,8000   # 要扫的粒子数
node bench/run.mjs --sample=2000 --warmup=800 --prime=2000
node bench/run.mjs --dpr=2                              # 模拟高分屏(手机)像素密度
node bench/run.mjs --sim=0                              # 跳过 CPU 微基准
node bench/run.mjs --json-only --out=bench/results/baseline
node bench/compare.mjs bench/results/baseline bench/results/optimized
```

## 在真实设备 / WebView 上测

绝对 FPS 只在同一台机器内可比，最有价值的是把 `bench.html` 直接开在目标设备上。
`localStorage` 需要 http(s) 源，用任意静态服务器即可：

```bash
npx http-server . -p 8080        # 或 python3 -m http.server 8080
# http://<设备IP>:8080/bench.html
# http://<设备IP>:8080/bench.html?counts=0,300,1000,3000&sample=2000&dpr=1
```

结果表会打印在页面上，原始数据可通过 `window.__BENCH__` 取回。

## 方法学

- **单一变量**：棋盘、物理、弹弓都固定不变；唯一变化的是 `Game.particles.length`。
- **保持静止**：每帧把粒子的 `vy` 与 `life` 重置，让粒子和它的 alpha 分布在整个采样窗口内保持稳定
  （否则 `Game.tick()` 的重力和生命衰减会让画面在采样中途消失）。
- **端到端**：用 `requestAnimationFrame` 记录相邻帧的 `performance.now()` 差值。
  （无头 Chrome 开 `--disable-frame-rate-limit` 后 rAF 回调参数 `now` 不可靠，所以用 `performance.now()`。）
- **预热**：先跑 `prime` 毫秒让页面启动、字体加载与 JIT 稳定，再逐档 `warmup` + `sample`。
- **CPU 对照**：另外单独循环调用 `Game.tick()`，把「粒子积分」的成本从「粒子绘制」里剥出来。
- **runner 用 `--disable-frame-rate-limit --disable-gpu-vsync`**：让 rAF 尽量快跑，用帧时间(ms)而不是被垂直同步卡住的 FPS 来看成本。

---

## 优化：粒子渲染批处理

### 原来的写法（`render.js`）

```js
G.particles.forEach(p=>{
  ctx.save();
  ctx.globalAlpha=Math.min(1,p.life*2);
  ctx.translate(p.x,p.y);
  ctx.rotate(p.rot);
  ctx.fillStyle=p.color;          // 每次都解析颜色字符串
  ctx.fillRect(-p.size/2,-p.size/2,p.size,p.size);
  ctx.restore();
});
```

每个粒子要付：一次完整状态 `save`/`restore`、一次 `translate` + 一次 `rotate`（含三角函数）、
一次颜色字符串解析、一次 `globalAlpha` 变更、一次 `fillRect` 绘制调用。研究资料把这一组合称为
Canvas 2D 粒子最典型的反面模式（见下方来源）。

### 优化后的写法

把粒子按「绘制样式（颜色 + 量化后的 alpha）」分桶，每个桶合并成**一条路径、一次 `fill()`**：

```js
const PARTICLE_ALPHA_STEPS = 8;
const drawParticles = () => {
  for (const p of G.particles) {
    let id = p._pid ?? (p._pid = colorId(p.color));   // 颜色只解析一次，缓存到粒子上
    const alpha = p.life * 2;
    const step = alpha >= 1 ? 8 : alpha <= 0 ? 0 : (alpha * 8) | 0;
    buckets[id * 9 + step].list.push(p);
  }
  for (const bucket of buckets) {
    ctx.globalAlpha = bucket.alpha;
    ctx.fillStyle = bucket.color;      // 每个样式只设置一次
    ctx.beginPath();
    for (const p of bucket.list) ctx.rect(p.x - p.size/2, p.y - p.size/2, p.size, p.size);
    ctx.fill();                        // 一次 fill 画出整桶
  }
};
```

消除的开销：每粒子 `save`/`restore`、`translate`/`rotate`、颜色解析、`globalAlpha` 变更。
绘制调用从「粒子数」降到「不同样式数」。桶跨帧复用，稳态下不再分配对象。
代价：正方形不再逐粒子旋转（2–7px 下肉眼不可辨），alpha 量化到 8 档。

### 效果（无头 Chromium 153，软件光栅，dpr=2，同机背靠背）

| 粒子数 | 原 Δ中位 ms | 新 Δ中位 ms | 提速 | 原 µs/粒子 | 新 µs/粒子 |
|---:|---:|---:|---:|---:|---:|
| 300 | 1.20 | 0.60 | 2.0× | 4.00 | 2.00 |
| 1000 | 5.20 | 1.30 | 4.0× | 5.20 | 1.30 |
| 2000 | 9.90 | 2.00 | 5.0× | 4.95 | 1.00 |
| 4000 | 20.90 | 5.00 | 4.2× | 5.22 | 1.25 |
| 8000 | 44.80 | 11.10 | 4.0× | 5.60 | 1.39 |

- 约 **4–5×** 的粒子绘制提速；单位粒子成本从约 **5.5µs** 降到约 **1.3µs**。
- 跌破 60 FPS 的粒子数从约 2750 提高到 **约 7700**（dpr=2 软件光栅）。
- 游戏内 `Game.burst()` 把粒子数上限压在 **300**：优化后在 60 FPS 的 16.7ms 预算里只占约 **0.6ms（≈3.6%）**。
- 粒子积分（`Game.tick`）本就只有约 **0.010 µs/粒子·tick**，瓶颈一直在绘制，不在物理。

正确性用像素级断言校验过：颜色 RGB 精确一致、alpha 与档位一致（如 0.5→128、0.75→191、0.125→32）、
位置映射正确、alpha=0 不绘制、不同颜色互不串色。

### 其它可选项（本次未采用）

- **OffscreenCanvas + Web Worker**：把绘制搬到 worker，能消除主线程卡顿（INP），
  但**不降低单帧成本**。当前 300 粒子上限没有这个必要。
- **WebGL 实例化**：几万粒子才划算，代价是引入第二套渲染管线与上下文，对当前规模是过度设计。
- **预渲染精灵 + `drawImage`**：对圆弧/渐变粒子有用；对纯色小方块，合并 `rect`+`fill` 更快
  （见 MeasureThat 基准：方形批量 `rect` 约 1495 ops/s，`drawImage` 约 240 ops/s）。

## 参考来源

- [MDN · Optimizing canvas](https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API/Tutorial/Optimizing_canvas) — 批量调用、避免不必要的状态变更、避免 `shadowBlur`。
- [web.dev · Improving HTML5 Canvas performance](https://web.dev/articles/canvas-performance) — “render by color”，按颜色而非位置渲染以省去状态切换。
- [Stack Overflow · HTML5 Canvas save() and restore() performance](https://stackoverflow.com/questions/38069462/html5-canvas-save-and-restore-performance) — 避免每元素 `save`/`restore`。
- [Canvas Kit Kat (3) 性能优化与发光](https://www.mo4tech.com/canvas-kit-kat-3-performance-optimization-and-glow-effects-part-1.html) — 指出与本项目完全相同的 `save/translate/rotate/globalAlpha` 反模式，单独 `globalAlpha` 切换就吃掉近 10ms。
- [MeasureThat · drawing lots of sprites](https://measurethat.net/Benchmarks/Show/10732/2/compare-drawing-lots-of-sprites-filled-circles-and-squa) — 纯色方块下批量 `rect` 最快，`drawImage`/逐粒子 `arc` 更慢。
- [web.dev · OffscreenCanvas](https://web.dev/articles/offscreen-canvas) / [MDN · OffscreenCanvas](https://developer.mozilla.org/en-US/docs/Web/API/OffscreenCanvas) — worker 离屏渲染的适用场景（解决卡顿而非降低单帧成本）。

## 注意事项

- 无头模式默认软件光栅，和手机 GPU 合成的绝对值不同；请用趋势与「µs/粒子」判断。
- `bench.html` 需要 http(s)（`localStorage` 约束），不要用 `file://` 直接打开。
- 结果 JSON 每条记录都带 `frames`、`spanMs`，可用于判断采样是否足够。
- A/B 对比用**中位帧时间**而非均值，长期调度抖动会污染均值。
