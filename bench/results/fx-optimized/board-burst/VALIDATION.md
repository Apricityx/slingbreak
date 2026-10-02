# 整板压测验证记录

2026-10-02，当前工作区，未提交、未推送。测试仅使用隔离的 Chrome profile；没有读取或改写用户实际浏览器存档。

## 通过的运行

所有 Chrome 压测串行执行，Node 单元测试在浏览器压测结束后运行。

```sh
node bench/fx-run.mjs '--filter=^board-burst/' --board-repeats=3 --capture=1 --out=bench/results/fx-optimized/board-burst
node bench/fx-run.mjs '--filter=^board-burst/' --board-repeats=3 --reduced=1 --out=bench/results/fx-optimized/board-burst
node bench/fx-run.mjs '--filter=^board-burst/' --raf=1 --out=bench/results/fx-optimized/board-burst
node bench/fx-run.mjs '--filter=^board-burst/' --chrome=/absolute/path/to/real/chromium89 --capture=1 --timeout=300 --out=bench/results/fx-optimized/board-burst/chrome89
CHROME89_PUPPETEER=/absolute/path/to/puppeteer node bench/chrome89.mjs
node --test *.test.cjs bench/*.test.mjs
node bench/fx-board-report.mjs
git diff --check
```

- 压测保存结果：现代同步正常 / 性能、现代无读回 rAF、旧引擎同步正常各 12 个整板案例，无测试错误/页面异常。每份还包含运行器原有的独立空画布基线，不计入整板案例数。
- 正常与性能模式各 36 次事件；rAF 与 Chromium 89 各 12 次，总计 96 次事件。
- 全部全毁断言通过：模拟时间不变，击碎数和累计数都等于初始砖数，剩余为零；金币增加、shotMoney、levelMoney 一致且为正。
- 报告生成器额外校验：同一输入在每次重复、每种模式和两个引擎的初始配额/HP、击碎数、累计数和收益一致。
- 尾段粒子、环、电弧、浮字、箭、技能图案、收益聚合文字、信号、场与成就/纪录 DOM 节点全部归零。
- 真正的 Chromium 89.0.4389.0 门禁通过，15 个检查、零异常，包括 552 个 sRGB 对照、四个 Boss、音频源调度、file 入口、多视口。
- Node 全套：**313 passed、0 failed**。包含 24 组生产击碎单元校验（两种模式 × 12 输入），每砖唯一销毁 hook 校验，以及损伤覆盖异常时的 finally 恢复校验。
- `git diff --check` 通过。

## 超时与限制

第一次旧引擎整组运行被外部 240 秒超时终止，未产出完整 JSON；原因未确认，不计入指标。独立重跑 12 案全部通过。详见 [run-notes.json](run-notes.json)。

这是当前 CPU 的软件光栅压力测试；禁用 GPU/垂直同步，不是目标 Android X5 端到端帧率或温升测试。新脚本只由测试运行器加载，不进入游戏 `index.html`。

## 截图复核

已读取现代与 Chromium 89 的 240 块、50% 特殊砖、四技能连锁的 before / animated PNG：240 块密集网格可见，五种特殊砖按固定配额散布；全毁后可见电弧、冻结/棱镜图案、爆炸环、碎屑及 240 块收益聚合反馈。

现代图保存在本目录，旧引擎图在 `chrome89/`。Canvas 截图不含 CSS 背景和 HUD；绿底闪光是 Canvas 的实际核心反馈，不是背景主题变更。
