# Godot 特效合批性能记录

## 范围与实现

2026-10-29：针对已归因的电弧、金币、冰晶和爆炸碎片热点优化 Godot 路径；不改玩法、伤害、事件队列上限或默认元素数量，不强制开启性能模式。

- `effect_mesh.gd`：每类效果的不可变三角网格模板，跨 Board 共享，不在每帧构建几何或三角化。
- `special_batch.gd` / `arc_batch.gdshader` / `coin_batch.gdshader`：有界 MultiMesh 提交，按原事件 progress/seed 重建几何。金币 ¥ 使用真实字体子层。
- `debris_batch.gd` / `debris.gdshader`：冰晶和弹道火星按原时钟、轨迹、色值、数量绘制。只跳过已完全透明的事件，不缩短可见节奏。
- 保持原爆炸火团、烟尘、冰冻波及持续冰层 shader，不靠降低这些效果的质量提速。
- 电弧中心四层闪核的八次 alpha-over 叠加保留；简单去重会让峰值变暗，此处没有这样做。
- `effect_foreground.gd` 保持箭矢、粒子、伤害文字位于特殊命中特效之上，原火团/冰层覆盖层仍在其后。
- 显式 MultiMesh 包围盒涵盖 vertex shader 扩展的范围，避免发射点刚出屏幕时整束特效被裁掉。
- GL Compatibility 自定义实例通道为半精度。seed 先按 `TAU` 包回，再拆成 high/low 两通道，避免长局 serial 增长导致轨迹相位失真。

## 测量口径

- Godot **4.7.2 stable**，GL Compatibility，Xvfb / Mesa llvmpipe 软件渲染。
- 生产分辨率 **412 × 915**，60 个可见砖块；关闭 UI、音频和物理；默认完整特效，不开性能模式。
- 固定可见队列，预热 15 帧、采样 60 帧、各运行两轮；不并行其他图形负载。
- 表中数据是两轮百分位的中位数，不是合并样本重新计算的百分位。
- 帧间隔包含实际渲染和主机调度，但不显式等待 GPU 完成；**不能外推为 Android/硬件 GPU 的 FPS**。
- 原 0.06–0.36s 时间扫描含电弧较长的透明尾段。优化跳过完全透明的绘制后，该场景 p50 会落在尾段，不能拿它宣称峰值达标。额外固定 0.06–0.12s、全程可见的峰值扫描，并用备份代码在隔离夹具中做前后对照。
- CPU Board draw 包括基础和新增 foreground 回调；合批更新仍计入 Board process。Frost/Explosion 子层与生命周期单独记录，避免只测父节点而漏报开销。

## 真实画面与差异

逐实际 GIF 毫秒对齐检查，不用 GIF frame index：Pillow 会把重复帧合并，按 index 对比会造成错误的快慢/峰值判断。

- 浅/深色、完整/reduced 均由真实 Godot 帧生成循环 GIF，包含密集普通砖作为背景、峰值和完整尾段。
- 电弧条数、分叉、闪核叠加、伸展范围和衰减曲线保留；金币硬币、闪芒、10 片碎片和真实 ¥ 字形保留。
- 金币 ¥ 改为独立字体子层，避免父级几何 shader 吞掉字形；修改前基线中该字形实际不可见，修改后恢复显示，这是明确可见的小差异。
- 冰晶 10 片、火星 18 片；既有 reduced 的 4/6 片及运动缩减仍由原设置决定，本次不主动启用。
- 细线、圆和折角现在由共享三角网格加约一像素羽化实现，不保证逐像素相同；低分辨率边缘和金币字体可有小幅差异。同类及跨类命中特效按批次分组，密集重叠处的局部遮挡顺序也不承诺逐像素一致；箭矢、文字与火团/冰层的大层级另有回归保护。不应表述为无损或完全一致。
- 四类特效混播另有实际截图，确认事件在可视棋盘内且无开局 UI 遮挡。

## 实测结果

### 全程可见的早期峰值（0.06–0.12s）

`before-peak.json` 使用修改前备份；`after-peak.json` 为当前 renderer。帧间隔单位 ms，调用数为包含 60 砖块基线在内的全场值。

| 场景 | p50 前 → 后 | p95 前 → 后 | p50 降低 | draw calls 前 → 后 |
| --- | ---: | ---: | ---: | ---: |
| 无特效基线 | 12.82 → 12.19 | 14.73 → 14.46 | — | 284 → 284 |
| 电弧 ×48 | 158.87 → 95.01 | 183.97 → 105.05 | 40.2% | 6620 → 285 |
| 金币 ×48 | 70.27 → 31.24 | 77.42 → 38.06 | 55.5% | 766 → 286 |
| 冰晶 ×48 | 59.41 → 16.24 | 63.89 → 20.06 | 72.7% | 2684 → 285 |
| 爆炸 ×16 | 44.11 → 28.55 | 54.14 → 35.52 | 35.3% | 876 → 301 |
| 技能 ×64 + 特殊 ×48 + 爆炸 ×16 + 冰层 ×32 | 108.39 → 72.19 | 130.71 → 84.98 | 33.4% | 3009 → 732 |

CPU 提交热点也显著下降：电弧 Board draw p95 **38.00 → 1.30ms**，金币 **7.39 → 1.31ms**。新增实例更新已包含在 Board process，峰值电弧为 1.28ms、金币为 1.48ms；不是把旧 CPU 计时移到未统计的回调中。

### 原 0.06–0.36s 扫时口径

保持上一轮归因条件，金币 p50 **68.19 → 30.08ms**、冰晶 **57.98 → 15.88ms**、爆炸 **45.28 → 29.78ms**、混播 **106.98 → 55.48ms**。电弧 p50 **145.48 → 13.25ms**，但其后测 p95 仍为 **105.87ms**；该 p50 包含透明尾段跳过，不作为峰值收益宣传。

### 仍有的限制

- **不是所有场景已达到 60 FPS。** 软件渲染下 48 个可见电弧峰值仍约 95ms、混播约 72ms。共享提交已解决主要脚本/调用瓶颈，剩余 shader 顶点运算、填充/混合和驱动开销仍需在目标硬件测量。
- 连续触发的 240 帧 `native_v_effects_test` 是功能和预算回归，不是稳定性能门禁。本轮通过 24 项检查、峰值队列 64，Board draw p95 4.36ms，但墙钟 p50 60.39ms、p95 142.80ms，235/240 帧超过 33.3ms。此负载含不断变化的事件/首次材质使用和桌面调度，不用它宣称稳定帧率改善。
- 为保持画面，本次没有减少电弧中心叠加、碎片数量、爆炸 shader 或持续冰层质量；不通过切换性能模式掩盖剩余成本。

## 回归与复现

`native_effect_batch_test.gd` 已接入默认原生与 GUI gate，覆盖：

- 每类容量、生命周期、透明尾段边界、活动状态 reset、再次触发。
- 模板共享且动画不重建 mesh、玩法 RNG 不被消耗。
- 实际驱动读取实例位置、半精度 high/low seed、超过 1 的 radius。
- draft 隐藏/恢复、现有 reduced 参数。
- 浅/深色真实像素可见性、屏外发射点、前景在电弧/金币上方的实际像素验证。

```sh
python3 godot/tools/run_checks.py --godot godot
python3 godot/tools/run_checks.py --godot godot --gui
python3 godot/tools/run_checks.py --godot godot --test native_special_brick_test --test native_explosion_test --test native_frost_test --test native_skill_effect_test --test native_skill_batch_two_test

xvfb-run -a godot --path godot --audio-driver Dummy --disable-vsync \
  --script res://tests/native_effects_probe.gd -- \
  --samples=60 --warmup=15 --repeats=2 \
  --case=baseline,lightning_48,gold_48,ice_shards_48,bomb_16,mixed \
  --output=res://../agent-tmp/godot/fx-optimization/after-full.json

# 单独测量全程可见的早期峰值，不与 GIF 采集或其他检查并行。
xvfb-run -a godot --path godot --audio-driver Dummy --disable-vsync \
  --script res://tests/native_effects_probe.gd -- \
  --samples=60 --warmup=15 --repeats=2 --age-start=0.06 --age-end=0.12 \
  --case=baseline,lightning_48,gold_48,ice_shards_48,bomb_16_full,mixed_full \
  --output=res://../agent-tmp/godot/fx-optimization/after-peak.json

python3 godot/tools/preview_effects.py --skills brick_lightning brick_gold brick_frost brick_bomb
python3 godot/tools/preview_effects.py --skills brick_lightning brick_gold brick_frost brick_bomb --theme dark
python3 godot/tools/preview_effects.py --skills brick_lightning brick_gold brick_frost brick_bomb --reduced
```

本轮临时证据位于忽略目录 `agent-tmp/godot/fx-optimization/`，不提交 GIF、截图、日志或构建产物。JSON 记录 renderer 源文件 SHA-256；基线隔离夹具使用修改前的 `board.gd`、`frost.gd`、`explosions.gd` 备份，不替换或回退工作区内其他人的文件。

测量后另一个技能批次把 Board 的 `SkillImpacts` 路由扩展为包括 `storm/blizzard/prism/alchemist`。已核对该列表是测量后 `board.gd` 的唯一变化；合批文件 hash 未变，性能夹具不触发这四个技能。保留该用户工作，不为匹配测量 hash 回退文件。

最终验证：默认原生 gate **9/9**，GUI gate **12/12**（含 566 帧原生渲染矩阵、972 个 stroke 像素夹具、76 项合批检查、24 项 V2 混播检查）；额外特殊砖/爆炸/冰冻/两批技能 gate **5/5**。所有门禁无脚本错误、渲染错误或泄漏。浅/深色完整及 reduced 四套循环 GIF 均已生成并打开，按实际时间对齐检查 240/280/360/720ms 的峰值/尾段。
