# 第九批金色技能特效：蜂群女王 / 歼星轨道炮 / 冰火连爆 / 雷霆骰子

完成日期：2026-10-30。目标运行时：Godot **4.7.2.stable.official.ed1daf0bf**。

四个技能已接入真实玩法钩子、独立视觉事件、固定容量 GPU 合批与启动预热；已完成原生检查、真实 OpenGL 检查及两套循环 GIF 验收。

## 实现入口

- `godot/src/render/skill_batch_nine.gd`：四个 `MultiMeshInstance2D` 家族、共享不可变网格、64 槽实例缓冲、包含跳电终点的动态 AABB。
- `godot/src/render/skill_batch_nine.gdshader`：按家族编译专用 shader；冲击包络、蜂体条纹、轨道炮芯、冰火晶面、骰面及黄金跳电全部由 GPU 生成。
- `godot/src/skills/mechanics.gd`：`on_shoot()`、`projectile_hit()`、`detonate()`、`arc()` 的真实事件出口。
- `godot/src/core/simulation.gd::area()`：仅针对 `frostfire` 去掉旧闭合圈和 signature；范围伤害循环及音效保留。
- `godot/src/render/board.gd`：固定家族节点初始化、沿现有 `skill_batches` 路径提交事件；跳过旧 CanvasItem 再绘制。
- `godot/src/render/effect_warmup.gd`：在现有 16 帧真实绘制中预热四家族、两种事件阶段及 full/reduced 网格。
- `godot/tools/preview_skill_batch_nine.gd`：真实发射/碰撞/延迟任务的受控采集夹具。
- `godot/tools/effect_previews.json`、`godot/tools/preview_effects.gd`：注册及调用夹具。
- `godot/tests/native_skill_batch_nine_test.gd`：玩法、事件、GPU 生命周期和真实像素验收。

## 四层表现与真实触发

### 1. swarmqueen · 蜂群女王

**触发**：`on_shoot()` 中原有八次 `g.launch()`，每次返回有效子箭才创建一个视觉快照。64 箭上限导致发射失败时，不展示虚构蜂体。八箭角度仍为 `(index - 3.5) * 0.12`，原速度、1.5 倍伤害、3 穿透及 homing 标记原样保留。

| 层 | 实际实现 |
| --- | --- |
| A 冲击核心 | 每条成功弹道的蜂蜡白金出膛闪点，指数衰减，前 0.08s 集中 |
| B 主体 | 八条真实角度上的蜂体从发射口分离，短距加速展开；事件 seed 只调节视觉纵向错落 |
| C 材质 | 金黑腹部条纹、双翼菱形晶面、暗色轮廓、短针状尾迹 |
| D 场景响应 | 发射口位置与真实子箭方向逐一对应；饱和时仅剩实际获准发射的弹道 |

时长 **0.54s**。reduced 保留所有实际子箭、条纹和双翼，删除装饰尾迹、尾段位移缩为 25%；不能靠减少真实箭道来省预算。

### 2. railgun · 歼星轨道炮

**触发**：真实 `on_shoot()` 主箭出膛创建 0.40s 事件；每次有效 `projectile_hit()` 创建 0.42s 穿透冲击。该技能本身在 `damage()` 和 `penetration()` 中提供属性加成，不添加虚构全屏激光或新伤害任务。

| 层 | 实际实现 |
| --- | --- |
| A 冲击核心 | 碰撞中心白青高温芯，快速消退 |
| B 主体 | 随实际箭速方向定向的双侧轨道与中间白热弹芯；长度随时间缩短 |
| C 材质 | 深/浅主题反差外缘、青色导轨、两侧菱形剥落碎屑 |
| D 场景响应 | 每个真实穿透位置分别断裂；出膛阶段不展示碰撞碎屑，命中阶段才剥落 |

reduced 将 6 片剥落减为 2 片、外飞位移减至 25%，保留双轨和方向。原 4 倍基础伤害、穿透属性及碰撞扣减归属不变。

### 3. frostfire · 冰火连爆

**触发**：`projectile_hit()` 原有 100px 冻结范围立即生效，发射冷态晶片事件；对实际冻结目标设置视觉 `frost_born` / `frost_direction`，复用独立 GPU 冰层。原 `later(0.09, ...)` 到期后才在 `detonate()` 创建热态碎片及现有 100px 火团。

| 层 | 实际实现 |
| --- | --- |
| A 冲击核心 | 命中瞬间白蓝冰核；0.09s 后独立白热爆芯 |
| B 主体 | 冷态尖晶先快速成形；真实延迟爆炸再生成 GPU 火团、交错冷/热碎片 |
| C 材质 | 冰晶内棱线、青蓝晶面、橙金热碎片，复用火团噪声材质 |
| D 场景响应 | 实际范围目标结晶，持续冰层与瞬时爆裂独立；火团保留既有场景响应，reduced 禁用场景位移 |

冷态事件 **0.56s**，热态事件从真实爆炸时刻起 **0.62s**；主序列总计约 **0.71s**，火团完整尾段至首次命中后 **1.49s**。仍冻结的砖块继续显示冰层，这不是残留瞬时事件。

reduced：8 片晶片减为 4 片，外飞及重力表现降为 25%，保留完整冻结范围和火团身份。100px、1.5 倍基础爆炸伤害、冻结双倍结算、任务预算和 0.09s 时序不变。预算不足会保留真实冻结，不能凭空显示被拒绝的爆炸。

### 4. thunderlottery · 雷霆骰子

**触发**：保留原有 `g.rng.randf() < 0.35` 一次抽取和 **0.07s** 延迟；仅真正执行 `arc(..., 6, damage * 3, "thunderlottery")` 时生成骰面与跳电事件。

| 层 | 实际实现 |
| --- | --- |
| A 冲击核心 | 中奖任务执行时的金色骰面及各跳真实端点闪核 |
| B 主体 | 六点骰面 + 按原 `nearest()` 顺序相接的六段黄金闪电 |
| C 材质 | 深描边、白金导电内芯、6 节折线和短分支；六点表示六目标上限，不额外随机掷骰 |
| D 场景响应 | 每段保存真实 previous/target 坐标，末端落在实际受伤砖；不足六个目标时只生成实际命中段 |

骰面 **0.56s**，每跳 **0.48s**，首次命中后的完整序列约 **0.63s**。reduced：折线 6 节减为 3 节，取消分支和时间抖动；保持六点与全部实际跳电关系。失败概率分支完全没有中奖演出。

## 事件契约、预算和性能

- 复用 `fx.skill_events` 的 **64 条全局共享快照上限**，不是四个家族各生成 64 条；满时淘汰最旧视觉事件。
- 每家族预分配 64 个 MultiMesh 槽，实际绘制实例总数受共享队列限制；四家族最多增加 **4 个合批提交**，不随单次命中创建节点、材质或网格。
- 一次发射最多 8 条蜂群事件；轨道炮一次出膛 1 条、一次有效命中 1 条；冰火命中和实际爆炸各 1 条；雷霆中奖 1 条骰面 + 最多 6 条真实跳电。
- GPU 网格顶点预算：

| 家族 | 完整顶点/事件 | reduced 顶点/事件 |
| --- | ---: | ---: |
| swarmqueen | 20 | 16 |
| railgun | 40 | 24 |
| frostfire | 36 | 20 |
| thunderlottery | 30 | 20 |

- 新事件不额外调用 CPU 粒子 burst；冰火复用现有最多 16 个 GPU 火团池及其合批火星，持续冰层继续走既有 frost 池。
- shader 按技能家族专用编译；网格按家族/reduced 缓存共享，播放中仅更新实例 transform/custom data/color。
- 所有动画只依赖 `fx.visual_time` 和快照 seed；不调用玩法 RNG，不上传动态 CPU 贴图。
- `strength=0.55` 用作出膛/冷态/骰面阶段标识，`1.0` 用作命中/热态/跳电；只是渲染角色，不回写伤害。
- 雷霆的实例 bounds 包含真实终点，离屏源点不会让入屏电弧被错误裁掉。
- 已移除这四个技能的普通命中旧 signature 调用；雷霆跳电不叠旧 bolt；冰火爆炸不叠旧固定半径闭合圈。
- 预热仍在独立 viewport、独立模拟中真实绘制，full/reduced 都经过；不消耗玩家 RNG 或先播放一次玩家技能。

## 真实测试结果

执行环境：Godot 4.7.2 stable，GUI 使用 `xvfb-run`、OpenGL Compatibility、Mesa llvmpipe。

```bash
godot --headless --path godot --script res://tests/native_skill_batch_nine_test.gd
# Native skill batch nine: 222 checks, 0 failures

xvfb-run -a godot --path godot --audio-driver Dummy \
  --script res://tests/native_skill_batch_nine_test.gd
# Native skill batch nine: 247 checks, 0 failures

git diff --check
# 无输出，成功
```

覆盖：八箭数值/角度/homing 与容量截断、轨道炮真实出膛/命中及伤害、冰火冻结半径/延迟前后 HP/独立冰层、20 个种子下雷霆成功和失败分支/恰好一次 RNG 抽取/六段目标顺序和伤害、雷霆首跳触发电弧砖连锁后跳过已销毁目标的视觉事件、预算拒绝任务、64 条淘汰、视觉时钟、过期、reset、共享网格、reduced 顶点减少，以及真实 16 帧预热。

GUI 对真实钩子夹具生成的 GPU 家族做可见/隐藏像素差分；不是只检查节点存在，也不把 HP 变化当成该家族的视觉贡献：

| 家族 | 浅色完整变化像素 | 深色 reduced 变化像素 |
| --- | ---: | ---: |
| swarmqueen | 1125 | 948 |
| railgun | 806 | 734 |
| frostfire | 1101 | 615 |
| thunderlottery | 3668 | 3674 |

八个组合均检查 1.8s 时 GPU 家族实例为 0。reduced 像素量不必更少：分节减少、几何更直、主题反差变化不影响真实提交/顶点预算下降。

日志：
- `agent-tmp/godot/effect-gifs/batch-nine-native.log`
- `agent-tmp/godot/effect-gifs/batch-nine-gui.log`

## GIF 交付与人工检查

```bash
python3 godot/tools/preview_effects.py --skills swarmqueen railgun frostfire thunderlottery
python3 godot/tools/preview_effects.py --skills swarmqueen railgun frostfire thunderlottery --theme dark --reduced
```

两套均为实际 Board / GPU shader 渲染，**56 个采集帧、25 fps、1×、2.24s、无限循环**。GIF 编码器合并重复静止帧，实际编码帧数为浅色 52、深色 reduced 40，完整时间不变。

- [浅色完整四技能 GIF](../agent-tmp/godot/effect-gifs/swarmqueen-railgun-frostfire-thunderlottery-light.gif)
- [深色 reduced 四技能 GIF](../agent-tmp/godot/effect-gifs/swarmqueen-railgun-frostfire-thunderlottery-dark-reduced.gif)

绝对路径：

```text
/home/apricityx/workspaces/slingbreak/agent-tmp/godot/effect-gifs/swarmqueen-railgun-frostfire-thunderlottery-light.gif
/home/apricityx/workspaces/slingbreak/agent-tmp/godot/effect-gifs/swarmqueen-railgun-frostfire-thunderlottery-dark-reduced.gif
```

已打开两份 GIF，并抽取 **0.16s 峰值 / 0.40s 衰减 / 1.80s 尾段**检查：蜂群八条方向可分辨；轨道炮只留下短促局部轨迹；冰火先冷后热、受影响砖块冰层独立持续、血量可读；骰面和跳电可区分、六段端点落在真实砖块；瞬时尾段无停住的闭合环、方形裁切或悬空箭。夹具使用稳定高 HP 密集砖群，并在采集后恢复原发射器位置，避免放大的弹弓挡住特效。

检查图：`agent-tmp/godot/effect-gifs/batch-nine-light-inspection.png` 和 `batch-nine-dark-reduced-inspection.png`。这些 PNG 是峰值/尾段核对辅助，正式交付为上面的循环 GIF。

## 集成注意

- 本批无需修改 `Effects.skill_event()` 接口和既有全局容量；使用 `SkillBatchNine.IDS` 的独立 GPU 路由。
- `run_checks.py` 与总清单由主代理维护：纳入 `native_skill_batch_nine_test.gd` 的 native/GUI 检查，以及四个技能的完成状态和本文链接。
- 共享文件只做局部补丁；本批专属渲染、shader、测试、夹具和本文独立存放。未提交 commit。
