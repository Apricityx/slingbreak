# 技能特效升级清单

按 `docs/godot-v2-effects-guidelines.md` 维护 Godot 原生技能特效升级进度。清单中的“已升级”表示：玩法触发点已接入独立视觉事件，主体绘制遵循 V2 分层规范，并有生命周期、预算或 reset 回归覆盖。

## 第一批：普通等级样板

本批次选择技能表中前四个 `white` 普通等级技能，覆盖四种常用的箭矢反馈语言。特效均通过 `Effects.skill_event()` 进入动态层，不修改物理、伤害或存档状态。

| 状态 | 技能 | 设计 | 触发点 | 节奏 |
| --- | --- | --- | --- | --- |
| [x] | `echo` 回响齐射 | 回响箭影、错位箭头、短弧回声；主体向后拉开，表现“重放”而非重复闪光 | 复射箭生成时 | 0.58s |
| [x] | `piercer` 贯星长矛 | 穿透轴线、白热尖核、短距离碎屑；以命中点为中心，不使用贯穿全屏的长线 | 命中砖块时 | 0.34s |
| [x] | `seeking` 必中引导 | 目标锁定框、短引导线、白色锁定点；只在轨迹实际修正时出现 | 引导预测修正时 | 0.42s |
| [x] | `ricochet` 动能回收 | 折角冲击线、反弹火花、局部白闪；沿反射方向展开 | 墙面或边界反弹时 | 0.38s |

### 四层验收记录

| 技能 | 冲击核心 | 主体形状 | 材质细节 | 场景响应 |
| --- | --- | --- | --- | --- |
| `echo` | 回响起始白闪 | 三支错位箭影 | 逐层衰减的青紫边缘与回声弧 | 残影沿射击方向后撤 |
| `piercer` | 命中点白热尖核 | 穿透轴线与箭头 | 青色外辉、浅金尖端、短碎屑 | 命中砖前后保留局部可读空间 |
| `seeking` | 锁定点白闪 | 目标四角准星 | 青色引导线与双色边框 | 只在实际转向时显示目标关系 |
| `ricochet` | 反弹中心白闪 | 折角冲击线 | 浅金内芯、青绿外层、短火花 | 反射方向决定火花展开方向 |

## 第二批：普通等级冲击特效

2026-10-29：沿普通等级目录顺序升级以下四项。使用程序化 CanvasItem 几何、分面与时间包络，无贴图、无 CPU 纹理上传。连续体后续优先使用程序化 shader；不以静态图标缩放代替特效。

| 状态 | 技能 | 冲击核心 / 主体 / 材质 / 场景关系 | 触发与节奏 | reduced 行为 |
| --- | --- | --- | --- | --- |
| [x] | `shatter` 碎冰风暴 | 白蓝闪核、外弹晶冠、双色晶面、短距离旋转下坠；用冰晶替换此前通用火团 | 冻结块碎裂后 0.09s 冰震，同步原有伤害；0.56s 收尾，每箭最多 6 次 | 8 片减至 4 片，位移与旋转降至 30% |
| [x] | `execute` 斩灭法则 | 白热切点、两刃交错合拢、紫色刃面与亮刃口、沿命中方向切开后缩短消散 | 满足原有处决判定且目标已击碎时；0.40s | 减少斩痕分离距离 |
| [x] | `rage` 连击狂热 | 金白闪核、三道升温焰舌、摆动亮芯与上扬余烬、强度随该箭连击档位增长 | 每箭第 3/6/9/12/15/18 次击碎，含归属该箭的连锁击碎；0.48s | 取消余烬，减少摆动与上升距离 |
| [x] | `aftershock` 地裂余震 | 二次冲击闪核、分叉断裂纹、暖色裂隙内芯与碎屑、裂隙从内向外消退；保留已有爆炸场景响应 | 爆破砖后 0.16s 的余震伤害时；裂隙 0.62s，原爆炸尾烟独立结束 | 6 支裂纹减至 4 支，碎屑位移降至 30% |

### 本批次验证与预算

- 共用 `skill_events` 队列，上限 64；溢出淘汰最旧事件。爆炸沿用最多 16 个 GPU 实例。
- 事件只存位置、方向和 seed 等快照，使用 `fx.visual_time`；不持有目标实体，不消耗玩法 RNG。
- `godot/src/render/skill_impacts.gd`：独立程序化绘制入口，由 Board 动态层调用。
- `godot/tests/native_skill_batch_two_test.gd`：实际技能触发、延迟、伤害次数、六次碎冰上限、各箭独立连击、事件淘汰、过期与 reset；GUI 模式额外生成浅/深主题、完整/简化模式和同屏叠加的多时刻预览。
- 预览目录：`agent-tmp/godot/skill-batch-two/`（忽略的临时产物）。
- 运行：`python3 godot/tools/run_checks.py --godot godot --test native_skill_batch_two_test`；图形检查加 `--gui`。

## 第三批：普通等级元素与奖励特效

2026-10-29：继续沿普通等级目录顺序升级四项。全部采用程序化 CanvasItem 几何，不新增贴图；事件从真实特殊砖连锁、冰冻扩散、分裂生成和金币结算路径产生。

| 状态 | 技能 | 冲击核心 / 主体 / 材质 / 场景关系 | 触发与节奏 | reduced 行为 |
| --- | --- | --- | --- | --- |
| [x] | `storm` 雷神降临 | 白热跳电核、逐跳折线电弧、蓝白内芯与短分叉；每一跳保存起点和目标，不拉全屏 beam | 电弧砖连锁每个跳点；0.50s/跳 | 保留主弧，减少折点和外辉 |
| [x] | `blizzard` 绝对零度 | 白蓝冰核、分枝冰脉、旋转外弹晶片；原目标冰层继续从冰砖方向生长，不使用圆环 | 冰晶砖碎裂并开始冻结扩散；0.72s | 冰脉和晶片减半，旋转与下坠降低 |
| [x] | `prism` 万华棱镜 | 白闪棱心、转动并收缩的棱面、向外飞出的分裂箭道 | 分裂砖生成六支真实箭矢时；0.52s | 视觉箭道减至三条，真实箭矢仍为六支 |
| [x] | `alchemist` 点石成金 | 金币核心、程序化币面、金色菱形碎片上扬；奖励数字和砖块仍可读 | 金矿砖结算时；0.64s | 碎片减至 3 个，保留金币轮廓 |

### 本批次验证

- `godot/tests/native_skill_batch_three_test.gd` 覆盖四个真实玩法触发点、事件端点、分裂箭保留、金币收益、64 事件上限、视觉 RNG 隔离、过期和 reset。
- GIF 夹具已注册：`storm`、`blizzard`、`prism`、`alchemist`。
- 预览命令：`python3 godot/tools/preview_effects.py --skills storm blizzard prism alchemist`。

## 特殊砖与共用碎片性能验收

2026-10-29：不新增玩法或减少默认特效数量；将已定位的电弧、金币、冰晶和爆炸碎片热点改为共享网格 + 有界 MultiMesh。原有火团与持续冰层 shader 保持不变，电弧八次中心闪核叠加保留。

| 状态 | GIF 夹具 | 保留的视觉内容 | 预算 / 生命周期 |
| --- | --- | --- | --- |
| [x] | `brick_lightning` | 8 条多层电弧、4 处分叉、原中心闪核叠加；只跳过 alpha 已为 0 的尾段 | 最多 48 事件；原 0.42s 事件时长 |
| [x] | `brick_gold` | 硬币面/边缘、真实 ¥ 字体、4 处闪芒、10 个菱形碎片 | 最多 48 事件；原 0.58s 事件时长 |
| [x] | `brick_frost` | 原冰冻波与持续冰层、10 片旋转冰晶；既有 reduced 为 4 片 | 最多 48 特殊事件；冰晶 0.58s / reduced 0.38s |
| [x] | `brick_bomb` | 原火团/烟尘 shader 与 18 片弹道火星；既有 reduced 为 6 片 | 最多 16 事件；火团 1.4s、碎片 1.2s |

- `native_effect_batch_test.gd` 覆盖容量、过期、reset、共享模板、半精度 seed 编码、reduced 参数、真实渲染可见性、屏外发射点与前景遮挡顺序；已接入默认原生和 GUI gate。
- 浅/深色及 reduced 的真实渲染 GIF 使用上述四个夹具生成，检查峰值和收尾。收益、视觉差异与软件渲染限制见 `docs/godot-effects-performance.md`。
- 本表的特殊砖夹具不代表同名技能已完成 V2 升级；技能进度仍以下表为准。

## 全量进度

以下条目按 `godot/assets/skills.json` 的技能目录维护。新增技能时同时补入本表，并在完成后勾选、填写对应设计记录和测试。

### 第四至第六批集成验收（2026-10-29）

- 三个并行代理各完成四项，共新增 12 项；累计 24 项已升级、57 项待升级。完成条目无重复，24 项均有 GIF 注册。
- `python3 godot/tools/run_checks.py --godot godot`：15/15 通过，包括 18,000 帧模拟与全部六批技能测试。
- `python3 godot/tools/run_checks.py --godot godot --gui`：18/18 通过，包括 566 帧渲染、972 个描边夹具及第四／五／六批 61／61／74 项检查。全部技能批次测试已纳入默认原生和 GUI 门禁。
- 图形环境为 X11 + llvmpipe 软件渲染；上述结果为正确性验收，不代表移动设备帧率达标。
- 三批浅色完整、深色 reduced GIF 均已生成并复查峰值与收尾；商店购买前景另有 GUI 覆盖。动图及设计见 [第四批](skill-effects-batch-four.md)、[第五批](skill-effects-batch-five.md)、[第六批](skill-effects-batch-six.md)。
- 集成复查修正饮血箭锋末段退化三角面；重新生成第五批两套 GIF，GUI 验证通过。`git diff --check` 通过。

### 已升级

- [x] `echo` 回响齐射（white）
- [x] `piercer` 贯星长矛（white）
- [x] `seeking` 必中引导（white）
- [x] `ricochet` 动能回收（white）
- [x] `shatter` 碎冰风暴（white）
- [x] `execute` 斩灭法则（white）
- [x] `rage` 连击狂热（white）
- [x] `aftershock` 地裂余震（white）
- [x] `storm` 雷神降临（white）
- [x] `blizzard` 绝对零度（white）
- [x] `prism` 万华棱镜（white）
- [x] `alchemist` 点石成金（white）
- [x] `treasury` 核心宝库（white）— 核心奖金结算 / 开裂宝库与下落碎金，0.72s；[第四批设计与验证](skill-effects-batch-four.md)
- [x] `bargain` 超频工坊（white）— 成功折扣购买 / 对向锻压轨与上扬火屑，0.60s；[第四批设计与验证](skill-effects-batch-four.md)
- [x] `resonance` 核心共振（white）— 核心实际显现 / 四瓣内聚谐振，0.68s；[第四批设计与验证](skill-effects-batch-four.md)
- [x] `corehunter` 终焉引力（white）— 实际核心转向 / 局部弯曲流线与目标夹角，0.46s；[第四批设计与验证](skill-effects-batch-four.md)
- [x] `legion` 万箭归宗（white）：第三次齐射六路程序化箭锋，0.58s；[第五批设计与验证](skill-effects-batch-five.md)
- [x] `poison` 蚀骨剧毒（white）：真实毒伤逐次蚀刻／滴落，0.32s × 3；[第五批设计与验证](skill-effects-batch-five.md)
- [x] `ambush` 破阵先锋（white）：满血命中劈开甲片与穿锋，0.42s；[第五批设计与验证](skill-effects-batch-five.md)
- [x] `siphon` 饮血长箭（white）：击碎后血屑汇聚、充能箭锋，0.56s；[第五批设计与验证](skill-effects-batch-five.md)
- [x] `opportunist` 穷追猛打（white）— 残血命中追击楔痕，0.42s；[第六批设计与验证](skill-effects-batch-six.md)
- [x] `bounty` 连杀赏金（white）— 真实连杀结算递增金片，0.62s；[第六批设计与验证](skill-effects-batch-six.md)
- [x] `nailburst` 破壳礼炮（white）— 首次主箭命中三向破壳，0.56s；[第六批设计与验证](skill-effects-batch-six.md)
- [x] `fusepath` 燃线速递（white）— 四点燃线预热与真实延迟烧断，0.25s + 0.44s；[第六批设计与验证](skill-effects-batch-six.md)

### 待升级

- [ ] `trident` 三叉齐射（gold）
- [ ] `titan` 泰坦之力（blue）
- [ ] `meteor` 流星雨（gold）
- [ ] `hunters` 追猎蜂群（gold）
- [ ] `blast` 爆裂箭头（blue）
- [ ] `lightning` 连锁电容（blue）
- [ ] `ice` 永冻箭簇（blue）
- [ ] `critical` 致命准星（blue）
- [ ] `sweep` 横扫千军（blue）
- [ ] `lance` 天际贯穿（blue）
- [ ] `pulse` 末日脉冲（blue）
- [ ] `mint` 黄金时代（blue）
- [ ] `forge` 神匠赐福（blue）
- [ ] `decay` 衰弱领域（blue）
- [ ] `rapid` 疾风快弦（gold）
- [ ] `heavy` 破城重弩（blue）
- [ ] `growing` 越战越勇（blue）
- [ ] `doubletap` 延迟引爆（blue）
- [ ] `nova` 碎星新生（gold）
- [ ] `crossfire` 十字审判（gold）
- [ ] `jackpot` 幸运暴富（gold）
- [ ] `snowburst` 冰河冲击（blue）
- [ ] `supernova` 超新星爆发（gold）
- [ ] `swarmqueen` 蜂群女王（gold）
- [ ] `railgun` 歼星轨道炮（gold）
- [ ] `sharpshooter` 满弓狙击（blue）
- [ ] `bankshot` 弹射工厂（blue）
- [ ] `minefield` 脉冲雷区（blue）
- [ ] `frostfire` 冰火连爆（gold）
- [ ] `thunderlottery` 雷霆骰子（gold）
- [ ] `mirror` 镜像夹击（blue）
- [ ] `specialist` 异能收割（blue）
- [ ] `reaper` 死神点名（gold）
- [ ] `cascade` 连环殉爆（gold）
- [ ] `orbital` 轨道轰炸（gold）
- [ ] `roulette` 命运轮盘（gold）
- [ ] `stormfront` 天幕裁决（gold）
- [ ] `boomerang` 回旋天轮（blue）
- [ ] `wormhole` 折跃猎手（gold）
- [ ] `buzzsaw` 行刑锯盘（gold）
- [ ] `siegebreaker` 城墙粉碎机（blue）
- [ ] `spectral` 幽界漫游（gold）
- [ ] `transmute` 万物炼成（blue）
- [ ] `threadweaver` 缝天之线（gold）
- [ ] `infection` 寄生花园（gold）
- [ ] `contract` 猎金契约（blue）
- [ ] `timeslip` 弦上时停（gold）
- [ ] `rhythm` 三拍重音（blue）
- [ ] `reboundaim` 撞墙开窍（white）
- [ ] `overkill` 余力借条（white）
- [ ] `pendulum` 左右开弓（white）
- [ ] `teslanet` 三角禁区（gold）
- [ ] `undertow` 潮汐回卷（gold）
- [ ] `chronicle` 伤痕重映（blue）
- [ ] `firewheel` 日轮护航（blue）
- [ ] `worldfold` 天地对折（gold）
- [ ] `starforge` 吞星熔炉（gold）

## 维护规则

1. 先在 `mechanics.gd` 或对应玩法入口记录独立视觉事件，再在 `board.gd` 或专用 renderer 绘制。
2. 每个完成项必须记录触发点、总时长、reduced motion 行为和事件预算。
3. 勾选前至少补一个原生测试，覆盖事件产生、生命周期、队列上限或 reset。
4. 只升级 Godot 实现；浏览器端 `game/` 不属于本清单的目标运行时。
5. 优先程序化 shader 和 CanvasItem 动态几何，尽量避免贴图；主体需有生成、运动和消散过程，不能只播放静态图标。
6. 每批完成后注册 `godot/tools/effect_previews.json` 并运行 `python3 godot/tools/preview_effects.py --skills <技能ID...>`，检查实际渲染的 GIF，打开并向用户附上动图。使用说明见 V2 设计规范的“动图快速工具”。
