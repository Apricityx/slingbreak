# Godot 特效合批性能记录

> 以下至「第二轮」之前为 2026-10-29 的历史结果。2026-10-30 电弧砖已改为雷神降临逐跳视觉，旧电弧 shader 已删除；第三轮又将高频技能与火团合批。当前实现与同条件复测见文末，历史 CPU Storm 结果不代表当前 renderer。

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

## 第二轮：紧凑 shader 与雷神电弧（2026-10-30）

本轮允许更换实现和轻微视觉变化，不再承诺保留旧放射电弧。

### 当前实现

- **电弧砖复用雷神降临**：`simulation.gd::hit()` 在原 nearest 循环中，对每个真实目标生成一个 `storm` skill event。无技能为 5 个目标、1.6 倍伤害；有技能为 7 个目标、2 倍伤害，命中时序、递归与 active arrow 击杀归属不变。`skill_impacts.gd` 的逐跳绘制原样复用，不查找或推断玩法目标。
- 删除旧 `arc_batch.gdshader` 及 UID、Board 的 arc 节点、旧 lightning 模板和 special 绘制分支。不再发出电弧砖的 legacy bolt，避免「雷神主弧 + 旧细线 + 放射闪核」重复。`special_break("lightning")` 不生成无终点事件；孤立电弧砖不伪造连锁。其他技能的通用 v1 bolt 基础设施不在此次删除范围内。
- 电弧从原 48 容量 special 队列迁至已有 64 容量 skill 队列，每跳 0.5s；这会在密集混播时与普通技能竞争视觉名额，队列上限未扩大。普通／强化版、完整／reduced 都使用同一视觉路径。
- 原 special batch 收窄并改名为 `coin_batch.gd`。硬币面只用一个 disc，轮廓、币面、内圈和印纹在 fragment 合成；4 处闪芒与 10 片菱形碎片仍在，真实 ¥ 字体子层保留。每事件 **101 顶点、186 indices**，共享不可变模板。
- 冰晶／火星每片只用一个 quad，fragment 合成外形、亮线、尾部与热点。完整模式仍是 10／18 片，reduced 仍是 4／6 片，不主动切性能模式。每事件分别 **40／72 顶点**。
- 爆炸改用包围有效半径的 12 边形，避开旧正方形空角；时间包络移至 vertex，外围只求冲击波／微光而不求湍流噪声。火团和冰层换多项式 hash，冰层复用晶体噪声生成 veins，瞬时冰闪不再求未使用的 fbm。噪声图案、细线抗锯齿与局部遮挡允许轻微变化，保留主体和完整收尾。

### 新夹具与比较边界

- `brick_lightning` 与 `storm` GIF 通过真正击碎一块电弧砖，验证 5／7 跳端点及落点受击；不再调用旧无终点 special event。普通背景砖与发射源不重叠。
- `native_effects_probe.gd` 的 `lightning_N` 现在表示 **N 跳**，不是 N 个旧放射闪光；它不能与历史 `lightning_48` 直接比较。新增 `lightning_chains_1/8/12`，分别代表 1／8／12 个五跳电弧砖（5／40／60 跳），均低于队列上限。
- 隔离的 `baseline-project/` 保持本轮开始前的生产源码，只适配测量夹具：同样的端点和触发顺序，旧版生成每砖一个放射源 + 五条 legacy bolt，新版每跳一个 Storm。绝不把旧版改成新版绘制，也不回退工作区文件。
- 混播按相同顺序投递 64 个普通技能事件、12 个五跳电弧砖、36 个其他 special、16 个爆炸和 32 个冰层。旧版分队列留下 64 个普通事件 + 60 条 bolt + 48 个 special；新版共享 skill 队列，留下 **39 个普通事件 + 25 个 Storm hop + 36 个 special**。因此混播是**同触发负载／原队列预算下的整体结果**，不是相同可见元素数量的纯 shader A/B；电弧独立 1／8／12 砖另测，避免用挤掉普通技能伪装单项收益。
- 两轮交错运行 baseline A → final A → baseline B → final B，仍为 412×915、60 砖、预热 15／采样 60、全程可见的 0.06–0.12s；最终 JSON 记录 probe、simulation、effects、Storm 与所有相关 renderer 的 SHA-256。运行期间不改相关源码，不并行 GIF 或 GUI 测试。主机存在其他项目构建负载，墙钟数据应视为诊断而非稳定 FPS 门禁。
- 连续 240 帧压力测试也给旧版补齐五跳端点，保持相同逐帧触发序列。此测试包含真实 UI 布局容器但隐藏 UI／关闭音频，不含真实物理；其分辨率与固定峰值探针不同，不能交叉当作同口径 FPS。

### 最终实测与限制

两轮百分位的中位数，单位 ms；对应 `baseline-final-a/b.json` 与 `storm-final-a/b.json`。两版无特效基线接近，表中结果包含基线，不扣除或归一化。

| 可见峰值场景 | p50 前 → 后 | p95 前 → 后 | 解释 |
| --- | ---: | ---: | --- |
| 无特效基线 | 12.39 → 11.89 | 15.91 → 15.61 | 相近 |
| 电弧砖 ×1（5 跳） | 14.92 → 14.94 | 20.76 → 21.02 | 基本持平，不宣称单砖提速 |
| 电弧砖 ×8（40 跳） | 31.34 → 23.70 | 36.81 → 30.57 | p50 下降约 24% |
| 电弧砖 ×12（60 跳） | 40.94 → 30.26 | 52.10 → 39.12 | p50 下降约 26% |
| 金币 ×48 | 31.49 → 15.17 | 37.28 → 19.20 | p50 下降约 52% |
| 冰晶 ×48 | 15.33 → 13.91 | 18.02 → 19.62 | 中位数略降，尾部未改善 |
| 爆炸 ×16 | 29.03 → 24.27 | 40.54 → 40.88 | 中位数下降，尾部未改善 |
| 同触发序列密集混播 | 75.04 → 43.21 | 92.24 → 54.29 | **队列结构与可见数量不同**，不是等元素 shader A/B |

Storm 的 CPU CanvasItem 绘制并非免费：60 跳场景全场 draw calls **465 → 1184**，Board draw p95 **2.22 → 6.48ms**。替换省掉了旧放射体的顶点／覆盖成本，却增加了多层抗锯齿折线提交；此路径将是后续硬件归因和可能合批的热点，不能称为所有维度都改善。

连续 240 帧：基线 p50／p95 **61.09／73.93ms**，新版单独复测为 **48.99／112.24ms**，超过 33.3ms 为 **235 → 237／240 帧**；GUI 全量门禁的再次运行为 **46.23／55.42ms**，234／240 帧超过 33.3ms。中位数下降但尾部波动明显，不能声称持续混播达标或稳定 30／60 FPS。不同运行的宿主负载与首次 shader 使用仍会影响结果。所有结果仅适用于 llvmpipe 软件渲染，尚未进行目标 Android／硬件 GPU 验收。

已逐项核对两轮峰值 JSON 和连续压力 JSON 的源码 SHA-256：均与被测的最终／隔离基线文件一致。最终证据：`agent-tmp/godot/fx-round2/final-summary.json`、`storm-continuous.json`、`gui-final.log`。这些均为忽略的临时产物。

验证：默认原生 **15/15**（含 18,000 帧模拟与六批技能），GUI **18/18**（含 566 帧渲染矩阵、972 个描边夹具、67 项合批/真实像素和 24 项混播检查），特殊砖／爆炸／冰冻专项 **3/3**（115／21／9 项检查）。无脚本／渲染错误或资源泄漏。`git diff --check` 通过。

最终浅／深色完整和 reduced 四套真实渲染循环 GIF，以及电弧砖／雷神降临并列 GIF 位于 `agent-tmp/godot/fx-round2/final-*.gif`、`storm-shared.gif`，包含完整峰值与收尾。电弧夹具新增真实受击粒子尾段，登记 `tail: 0.9`，不只登记 0.5s 主弧寿命。动图按实际毫秒而非帧序号检查。

### 复现本轮

```sh
xvfb-run -a godot --path godot --audio-driver Dummy --disable-vsync \
  --script res://tests/native_effects_probe.gd -- \
  --samples=60 --warmup=15 --repeats=2 --age-start=0.06 --age-end=0.12 \
  --case=baseline,lightning_chains_,gold_48,ice_shards_48,bomb_16_full,mixed_full \
  --output=res://../agent-tmp/godot/fx-round2/current-peak.json

python3 godot/tools/preview_effects.py --skills brick_lightning storm
python3 godot/tools/preview_effects.py --skills brick_lightning brick_gold brick_frost brick_bomb
python3 godot/tools/preview_effects.py --skills brick_lightning brick_gold brick_frost brick_bomb --theme dark --reduced
python3 godot/tools/run_checks.py --godot godot --gui --test native_special_brick_test --test native_explosion_test --test native_frost_test
```

## 第三轮：持续混播长尾（2026-10-30）

### 归因与修复

- 新增 `effects_stress_fixture.gd`，持续回归和逐帧探针共用相同的 240 帧触发序列。新增 `native_effects_tail_probe.gd`，同时记录触发、Board process/draw、技能绘制、retained、火／冰更新、draw calls、事件数和源码指纹；冷／暖轮分开，隐藏层只用于归因，不修改事件。
- 修改前暖轮隐藏普通四技能，p50／p95 从 **46.46／62.56ms** 降至 **30.15／38.29ms**；隐藏 Storm 仅为 **40.51／56.58ms**。主要脚本热点是高频普通技能和 Storm 的多层抗锯齿线段／折线提交，不能只优化电弧。
- `skill_batch.gd` / `skill_batch.gdshader`：`echo/piercer/seeking/ricochet/storm` 各一份共享不可变几何，固定 64 实例池，GPU 由事件年龄驱动。保留真实端点、原 64 共享事件队列、强度、时长及 reduced 元素数，不删事件、不主动切性能模式。删除已被替代的 CPU 绘制分支，电弧砖／技能仍只有一条 Storm 视觉路径。
- 第一版统一 shader 使用运行期 effect 分支，降低 draw calls 却加重首次使用长尾；改为按技能编译期特化。特化本身并未消除冷帧尖峰，不能只用暖轮证明问题解决。
- 火团由按命中创建 Polygon2D／独立材质改为预分配 **16 实例 MultiMesh**；时间包络及载体半径在 vertex 求值。保留烟尘、冲击波、微光、18 片弹道火星与 1.4s 总寿命；有效范围随年龄收紧，微光只在约 1/1024 alpha 以下裁去。非周期火团 noise seed 单独 high/low 编码，不错误地按 TAU wrap；长局输入显式限制到 4096。
- `effect_warmup.gd`：首次可操作前，在 **128×128 不显示的独立 SubViewport** 中真实渲染两种模式、合计 **16 帧**。只预热高频技能／特殊砖路径，不运行真实模拟、不触碰真实 RNG、事件或存档，随后禁用并释放 viewport；每图形进程一次，headless 跳过。`main.gd` 显示“准备特效…”并暂停游戏时钟，完成后才创建真实 session／开场。此项将首次驱动准备移到启动阶段，**并没有让编译成本凭空消失**。
- 无预热冷轮出现数百毫秒尖峰而同帧脚本仅数毫秒；真实绘制预热后大幅缓解，支持首次 GL／llvmpipe shader/JIT 路径准备是额外原因。没有得到可用的底层 GL 调用栈，因此不将全部尖峰武断归因于某个编译函数。主机其他项目 Java／Gradle 负载与屏外对照仍有波动，不干预其他进程。

### 比较口径与视觉边界

- 基线为本轮开始时第二轮完成后的生产源码，保存在忽略目录 `agent-tmp/godot/fx-tail/baseline-project/`。只适配新诊断脚本，不修改基线的生产 renderer，不回退工作区。
- 同分辨率 412×915、60 砖、同一触发／视觉时间步、同一事件队列和寿命；本轮前后不再存在第二轮旧电弧／Storm 队列结构差异。每次进程分开记录首次 240 帧与 reset 后暖轮 240 帧，再测屏外控制；A/B 交错顺序，最终源码指纹冻结。
- 最终版的“首次混播”包括实际生产预热策略，但预热耗时另报，不冒充无预热冷编译。另保留无预热诊断，不能用丢弃慢帧、隐藏层或降低分辨率作为最终数据。
- 细线改为紧凑 ribbon + fragment 抗锯齿，多层颜色在单次 fragment 内合成；线头、折角和局部覆盖顺序有轻微差异，不承诺逐像素相等。按技能分组使跨技能遮挡与事件投递顺序不完全一致，但箭矢／文字在技能上方、火团／冰层在其后仍由 GUI 像素检查保护。
- A/B 动图检查修正 Echo 世界角度与 clockwise instance basis 造成的镜像、ricochet 的旋转符号及 Storm 分叉方向；原回撤、准星、贯穿轴、逐跳主弧和收尾节奏保留。火团纹理可有半精度输入带来的细节变化。

### 回归与复现

`native_skill_batch_test.gd` 覆盖五类容量、模板共享、真实实例位置、浅／深色像素、draft 隐藏／恢复、过期／reset、玩法 RNG 隔离、非周期 seed 与预热资源释放；`native_effect_startup_test.gd` 走非 test-mode 的真实启动门禁，验证准备时不推进游戏、真实事件为空。两者均接入默认原生／GUI gate。

### 最终持续混播结果

最终源码冻结后的两轮 A/B 交错，百分位取两轮中位数，单位 ms；证据为 `baseline-final-a/b.json` 与 `batch-final-a/b.json`。新版启动准备单独耗时 **1243／1305ms**（16 个真实图形帧；不含在下表游戏内采样中），更早首次驱动缓存未就绪时约 3.4s，不能保证所有设备启动耗时相同。

| 指标 | 修改前 | 修改后 | 口径 |
| --- | ---: | ---: | --- |
| 首次混播 p50 | 41.38 | 23.57 | 新版已完成实际启动预热 |
| 首次混播 p95 | 49.98 | 31.44 | 不丢弃首帧／慢帧 |
| 首次混播 p99 | 58.15 | 43.30 | 仍有尾部 |
| 暖轮 p50 | 41.93 | 24.46 | reset 后同触发序列 |
| 暖轮 p95 | 54.47 | 32.46 | 约降 40% |
| 暖轮 p99 | 66.25 | 37.63 | 约降 43% |
| Board draw p95 | 5.04 | 1.54 | 含 foreground |
| Board process p95 | 2.60 | 2.92 | 包含新增实例更新，不隐去此成本 |
| draw calls p50 | 820 | 333 | 含 60 砖等基础层 |

- 暖轮超过 33.3ms：**228／229 → 7／13 帧**（每轮 240）；超过 50ms：**42／11 → 0／0 帧**。两轮新版暖轮 max **40.42／38.04ms**。
- 首次混播仍有 max **85.91／83.90ms**，分别位于第 18／20 帧，脚本 process + draw 约 3.2／3.5ms；预热不能称为完全消除所有首次图形路径成本。无预热诊断曾达约 291ms；首次准备被移到启动且显著缓解，但剩余首用与主机调度影响尚未完全区分。
- 屏外控制新版暖轮 p95 **8.50／11.85ms**，max **12.82／24.71ms**，仍可见主机／调度波动；不把墙钟差异全归功于 shader。火团隐藏仍能降低暖轮开销，剩余像素／混合成本非零。
- **仍不是稳定 60 FPS 验收。** 当前仅为 Xvfb + llvmpipe；没有目标 Android／硬件 GPU 数据，也没有覆盖所有未来技能的首次 shader 路径。预热只覆盖本轮高频效果，不能声称全游戏无卡顿。
- 默认原生 **17/17**、GUI **20/20**、特殊砖／爆炸／冰冻专项 **3/3** 通过；新合批 GUI 128 项、真实启动 7 项，原有 566 帧渲染矩阵／972 个描边夹具和 115 项电弧连锁回归保留。功能门禁通过不等于帧率达标。持续门禁已改为显式调用生产预热并单独报告其耗时；探针仍可用无预热诊断。

```sh
python3 godot/tools/run_checks.py --godot godot
python3 godot/tools/run_checks.py --godot godot --gui
xvfb-run -a godot --path godot --audio-driver Dummy --disable-vsync \
  --script res://tests/native_effects_tail_probe.gd -- \
  --prewarm --passes=2 --case=full,offscreen \
  --output=res://../agent-tmp/godot/fx-tail/current-tail.json
# 诊断首次使用成本时去掉 --prewarm；不将它冒充实际启动策略。
python3 godot/tools/preview_effects.py --skills echo piercer seeking ricochet
python3 godot/tools/preview_effects.py --skills brick_lightning storm brick_bomb brick_frost --theme dark --reduced
```
