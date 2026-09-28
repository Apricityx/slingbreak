# SlingBreak 性能测试 · 粒子数量 vs FPS

衡量「屏幕上同时存在多少个粒子」与「帧率」之间的关系。

关键点是：基准页不是重写一份粒子系统，而是**直接加载游戏真实的 `game.js` 与 `render.js`**，
因此测到的就是发行版循环本身 —— Matter.js 物理、`Game.tick()` 里的粒子积分、
以及 `render.js` 里画粒子的那一段 `ctx.save/translate/rotate/fillRect/restore` 全部照常运行。

## 文件

| 文件 | 作用 |
| --- | --- |
| `bench.html` | 基准页。只提供 `render.js` 需要的最小 DOM（`#game` canvas、`#power-readout`），然后按顺序加载 `vendor/matter.min.js` → `game.js` → `render.js` → `bench.js`。 |
| `bench.js` | 测试驱动。冻结棋盘，只控制 `Game.particles` 数量，用 `requestAnimationFrame` 采样帧间隔，并额外跑一个「只看 `Game.tick`」的 CPU 微基准。 |
| `bench/run.mjs` | 无头运行器。起一个本地静态服务器 + 本地 Chrome，通过 DevTools Protocol 读取结果，落盘 JSON / Markdown。不依赖任何 npm 包。 |
| `bench/results/` | 每次运行产出的 `bench-*.json` 与 `bench-*.md`。 |

## 快速开始（无头，一条命令）

```bash
node bench/run.mjs
```

自动寻找 Chrome / Chromium（也会用 `~/.cache/ms-playwright` 里 Playwright 下载的浏览器），
需要时用 `CHROME_PATH=/path/to/chrome` 指定。

常用参数：

```bash
node bench/run.mjs --counts=0,100,300,1000,3000,8000   # 要扫的粒子数
node bench/run.mjs --sample=2000 --warmup=800           # 每档采样/预热时长(ms)
node bench/run.mjs --dpr=2                              # 模拟高分屏(手机)像素密度
node bench/run.mjs --sim=0                              # 跳过 CPU 微基准
node bench/run.mjs --json-only --out=bench/results
```

## 在真实设备 / WebView 上测

绝对 FPS 只在同一台机器内可比，最有价值的是把 `bench.html` 直接开在目标设备上。
`localStorage` 需要 http(s) 源，用任意静态服务器即可：

```bash
npx http-server . -p 8080        # 或 python3 -m http.server 8080
# 然后打开：
# http://<设备IP>:8080/bench.html
# http://<设备IP>:8080/bench.html?counts=0,300,1000,3000&sample=2000&dpr=1
```

页面会把结果表打印到页面上，同时可通过 `read window.__BENCH__` 取回原始数据。

## 方法学

- **单一变量**：棋盘、物理、弹弓都固定不变；唯一变化的是 `Game.particles.length`。
- **保持静止**：`Game.tick()` 每步会给粒子加重力，驱动层每帧把 `vy` 归零，让粒子均匀铺满画布，
  这样绘制成本在整段采样窗口内保持稳定。
- **端到端**：用 `requestAnimationFrame` 记录相邻帧的 `performance.now()` 差值，得到真实帧时间。
  （注意：无头 Chrome 开 `--disable-frame-rate-limit` 后，rAF 回调参数 `now` 不可靠，所以驱动层用的是 `performance.now()`。）
- **CPU 对照**：另外单独循环调用 `Game.tick()`，把「粒子积分」的成本从「粒子绘制」里剥出来。
- **无头 runner 用 `--disable-frame-rate-limit --disable-gpu-vsync`**：让 rAF 尽量快跑，
  用「帧时间(ms)」而不是被垂直同步卡住的 FPS 来看成本；报告里的预算行会插值出跌破 60/30 FPS 的粒子数。

## 一次基线结果

本机无头 Chromium 153、软件光栅、`dpr=2`（canvas backing 784×764）、`sample=1500ms`：

| 粒子数 | FPS | 均帧 ms |
|---:|---:|---:|
| 0 | 273.0 | 3.66 |
| 300 | 194.4 | 5.15 |
| 1000 | 120.8 | 8.28 |
| 2000 | 70.9 | 14.10 |
| 4000 | 42.6 | 23.50 |
| 8000 | 21.0 | 47.70 |

- 约 **2400 粒子**时帧时间超过 16.7ms（跌破 60 FPS），约 **5900 粒子**时跌破 30 FPS。
- 绘制约 **4.7–5.5 µs/粒子·帧**，而粒子积分只有约 **0.010 µs/粒子·tick**，
  即成本几乎全在 canvas 绘制，不在物理解算。
- 结论：游戏内 `Game.burst()` 会把 `Game.particles` 上限压在 **300**，对应约 +1.5ms/帧，
  离 60 FPS 预算（16.7ms）还有很大余量 —— 粒子系统不是当前版本的性能瓶颈。

> 上面的绝对值只代表这台无头机器。换设备请在目标 WebView 上重跑。

## 注意事项

- 无头模式默认是软件光栅，和手机 GPU 合成的绝对值不同；请用趋势与「µs/粒子」来判断。
- `bench.html` 需要 http(s)（`localStorage` 约束），不要用 `file://` 直接打开。
- 结果 JSON 里每条记录都带 `frames`、`spanMs`，可用于判断采样是否足够。
