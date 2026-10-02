# 本轮验收与复跑记录

## 已完成的主体浏览器检查

- `runs.json`：前后正常/性能模式各 12 案 × 3 次（144 次整板事件）；after 另有现代无读回和真实 Chromium 89 各 12 案（24 次）。全部走生产伤害链、模拟不推进、唯一销毁/收益校验与真实退场；完整 outcome 在前后与各模式/浏览器一致。
- 动态缓存 before/after 各 10 案，9 个动态图案/氛围案加空画面基线；每案 `--sample=4000 --animated=1`。不使用空闲预热；并非所有冷首帧改善，见完整表。
- 全特效 smoke：现代正常/性能模式各 1,108 案、真实 Chromium 89 正常模式 1,108 案，81/81 技能图案、机械、四 Boss、开场；零错误。`sample=1` 是兼容/覆盖检查，不是可靠性能复跑。
- 实际 Chromium 89.0.4389.0 门禁 15 项通过：脚本解析、Canvas、三选一/替换飞行、焦点、主题、552 个 sRGB 样本、设置、实际 Web Audio 调度、四 Boss、launcher、file、减弱动态与屏幕适配。
- `bench/burst-ui.mjs` 的旧引擎集成检查通过：77 次击碎后，完整 HUD / 收益展示 / 连击脉冲各一次，第二次绘制不重播；四 Boss 各 64 次同步伤害，逻辑立即变化、血条/命中脉冲各一次；真实 idle 回调生成 17 张暴风雪姿态，待建清零、内存仍在原预算内。
- 该集成脚本初次观察 idle 曾超时：测试冻结了 rAF，Puppeteer 默认 rAF 轮询也被停止。仅测试轮询改为 `polling:100` 后完整复跑通过；生产代码没有为测试放宽条件。

## 视觉

- `visual-checks.json`：同种子 12/12 组整板 **instant Canvas PNG 的 SHA-256 完全相同**。说明本轮没有通过删掉瞬间 Canvas 效果降低成本；不包含 CSS/HUD/DOM。
- 实际查看了 240 块 / 22% 连锁的前后瞬间、旧引擎 240 块 / 50% 连锁动画、mixed ×56 前后动态图案、旧引擎整板 HUD 和 Boss 血条截图。技能轮廓、粒子、连击、核心与血条仍可辨认。
- 动态图案的前后截图并非固定同一动画帧，不作为逐像素 A/B。旧引擎 HUD 集成测试刻意冻结主 rAF，翻页/数字滚动动画截图可能仍显示上一状态，断言检查的是最终数据节点。
- 游戏 CSS 背景不在透明 Canvas PNG 中；查看器黑底不是改造后的游戏主题。

## 复跑

所有 Chrome **串行**；源码快照在 ignored `agent-tmp/perf-before-source/`。主体命令逐项保存在 `runs.json`，源码 hashes 与本轮生产 diff 分别在 `source-checkpoints.json` / `production.diff`。

```sh
node bench/fx-burst-compare.mjs
node bench/fx-board-report.mjs bench/results/fx-burst-optimized/before
node bench/fx-board-report.mjs bench/results/fx-burst-optimized/after
CHROME89_PUPPETEER=/absolute/path/to/puppeteer node bench/burst-ui.mjs
CHROME89_PUPPETEER=/absolute/path/to/puppeteer node bench/chrome89.mjs
node --test *.test.cjs bench/*.test.mjs
git diff --check
```

旧浏览器实际 binary 为：
`/home/apricityx/workspaces/SlayTheAmethystModded/agent-tmp/chrome89-tools/node_modules/puppeteer/.local-chromium/linux-843427/chrome-linux/chrome`。

## 补充检查

- `recheck-runs.json`：性能模式 50% 的 before/after 各 4 案 × 5 次（40 次事件），全毁/完整 outcome/尾段校验通过。独立复核的四组中位都更快；原三次的两组回退依然保留，不用后测覆盖。
- `final-runs.json`：正常模式 50% 连锁的 77/240 各三次（6 次事件）及现代性能模式全特效 smoke 通过。正常退场的长 tick 在该独立复核中没有重现；不视为根因已定位或问题已消失。
- 现代 Chromium 153.0.8010.12 的 HUD 集成检查三项、兼容门禁 14 项均通过（modern 门禁不测 file；该项已由真实旧引擎覆盖）。
- DOM smoke 11 案：空画面基线与真实 DOM 基线、飞金币/成就火花/收益飞片各 1/4/16 次；零错误。
- `node --test *.test.cjs bench/*.test.mjs`：**324 项通过，0 失败/跳过**。新增展示合并、半径/top-k 顺序、随机序列/碎屑复用、数字格式、idle 中断与冷态贴图预算、CPU 子树分析等回归测试。
- 现代/旧引擎 HUD 集成原始报告保存为本目录的 `hud-modern.json` / `hud-chrome89.json`；原始截图和兼容门禁日志留在 ignored `agent-tmp/`。
- `git diff --check` 已通过。
- 剩余卡顿诊断见 [DIAGNOSIS.md](DIAGNOSIS.md)：探针确认递归击碎链、Matter 逐体移除/箭创建、冷贴图与少量 DOM 强制布局的归属，并区分了 benchmark `getImageData`/桌面调度尖峰；未把 1552ms 单点错误归因给某个生产函数。

## 不能省略的限制

- 原三次性能模式有两组明显事件回退；动态冷首帧也有回退。本轮不宣称所有场景更快。
- 正常同步退场记录到一次 1552.3ms tick；现代无读回和旧引擎的首次无技能事件为 145.2ms / 133.44ms。尚未定位单项根因，完整原始数据保留，不归咎于外部调度或从统计中剔除。
- GPU/垂直同步关闭、桌面软件光栅、音频未解锁；没有 Android X5 真机 FPS / 温升 / GPU / 音频负载验收，也没有重建 APK。设计性的命中停顿与性能阻塞需分开理解。
- 原审计、上轮优化和上一组整板结果均未覆盖；用户原有修改未还原。所有改动尚未提交/推送。
