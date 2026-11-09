# 技能特效升级清单

按 `docs/godot-v2-effects-guidelines.md` 维护 Godot 原生技能特效升级进度。清单中的“已升级”表示：玩法触发点已接入独立视觉事件，主体绘制遵循 V2 分层规范，并有生命周期、预算或 reset 回归覆盖。

## 技能共用爆炸统一新版（2026-11-08）

- [x] `blast`、`aftershock`、`doubletap`、`minefield`、`frostfire`、`cascade`、`orbital`、`stormfront`、`undertow`、`starforge`、`siegebreaker`、`supernova` 的爆炸统一接入 `Effects.bomb_blast()` / `bomb_batch.gd`，与爆炸砖共用新版冲击环、火球团、火舌、白热核、弹壳、火星和烟团；技能不再产生旧 `explosions` 火团事件。
- [x] 保持原命中点、伤害半径、强度、延迟、伤害和音效；新版火团尾段为 1.1s。`aftershock` 保留裂隙，`frostfire` 保留即时冰晶和持续冰层，`supernova` 保留 180px 局部核心与全局目标热印，`shatter` 保持冰晶冲击。去掉共用引爆路径叠加的旧 ring；`undertow` 的三次回卷环保留。
- [x] 爆炸砖和技能共用最多 16 个事件、同一个固定 GPU mesh；简化模式沿用新版 shader 的火舌／碎块／火星裁减与无场景位移行为。预热改为新版爆炸。
- [x] `native_explosion_test` 覆盖 12 技能真实 shoot / hit / wall / 延迟任务、爆炸次数与半径、完整／简化玩法一致性、混合预算、视觉时钟、过期、reset；图形模式验证浅／深主题、简化模式真实可见像素、冰层覆盖顺序和 GPU 清空。已纳入默认原生／GUI 检查。
- [x] 新增 9 个缺失的技能 GIF 注册，并将 `aftershock` 改为真实爆炸砖 → 延迟余震夹具；相关预览使用宽画幅，覆盖冲击峰值和完整烟团尾段。复用既有 `frostfire` / `supernova` 真实玩法夹具。
- [x] 验证：全套原生 **41/41** 通过，包含 18,000 帧模拟；图形专项 **6/6** 通过，包含通用渲染 572 帧；追加真实伤害边界覆盖后，爆炸 GUI 专项 **210 项 / 0 失败**。`git diff --check` 通过。
- [x] 已生成并打开真实渲染 GIF，逐帧复查峰值与收尾：`agent-tmp/godot/effect-gifs/skill-blasts-v2-{light,dark,light-reduced,dark-reduced}.gif`，以及 `skill-blasts-v2-{chains,large}-{light,dark-reduced}.gif`。三组覆盖全部 12 技能；天幕裁决预览独立缩小取景以完整容纳 360px 连爆，不修改游戏内大小。图形环境为 Xvfb / Mesa llvmpipe，未据此声称移动设备性能。
- 本轮仅统一共用爆炸材质，不将尚缺独立主体设计的技能标为完整 V2 升级；后续全量进度仍按下表维护。

## 普通砖碎裂 V2：GPU 网格碎块 / 分层碎裂音（2026-11-01）

- [x] 视觉：`shatter_batch.gd` + `brick_shatter.gdshader`，每块砖一个 MultiMesh 实例（16 个四边形：冲击弧、白热轮廓闪、按 4×2 格切出的 8 块不规则碎块、6 道火星），所有普通砖碎裂合成一次绘制。碎块带击打方向偏置、阻力和重力，0.5 s 收尾；浅色主题用深色描边和琥珀火星保证对比度。
- [x] 性能：普通砖击碎不再产生 CPU 粒子和 ring，`normal_breaks` 上限 72。邻砖震动只取 0.16 s 内最多 8 个事件，reduced 下关闭；reduced 下碎块和火星数减半，冲击弧减弱。
- [x] 音效：`brick-shatter-1…4.vorbis`（重拳+玻璃+碎石三层预混，单声部），连杀时音高小幅上扬，见 `docs/audio-sources.md`。
- [x] 注册 `brick_normal` / `brick_chain`，由真实 `simulation.hit` 驱动；浅色、深色、reduced GIF 已生成，峰值和收尾已检查。
- [x] `native_explosion_test` / `native_audio_test` 覆盖事件预算、无 CPU 粒子、尺寸与方向、四变体轮换和音高范围；`effect_warmup.gd` 预编译该 shader。
- [ ] 目标手机上的手感和音量待人工验收。

## 星渊巨蟒 V2：星河巨蟒 / 逆鳞碎甲（2026-11-01）

- [x] 本体：`serpent_surface.gd` 每帧按蛇身节点重建带状网格，用 `serpent_body.gdshader` 着色（柱面光、错位鳞板、鳞间星光、背脊脉冲光带、腹线、深色描边、阴影）。星河背景、星门、逆鳞、星丝、盘击瞄准线和蛇首由 `serpent_art.gd` 按碰撞体绘制，蛇首颌部可开合。蛇身和这些绘制共用 `SerpentSurface.pose()` 包络。
- [x] 玩法：护甲表，鳞板弹箭，逆鳞抽空护甲，倒地伤害 ×3，护甲从蛇首到蛇尾重新覆上。盘击、潜渊、吞星、星蚀、坠星、双生各有一个反击点，失败时回复护甲。
- [x] 演出：入场从星门涌出；招式有倒计时环和瞄准线；星蚀全场变暗；双生星丝；转阶段时旧蛇钻门成残影、新蛇从另一个星门破出；死亡时从尾部溶解后爆散。
- [x] 注册 `serpent_intro` / `serpent_break` / `serpent_coil` / `serpent_dive` / `serpent_devour` / `serpent_eclipse` / `serpent_twin` / `serpent_phase` / `serpent_death`，由 `tools/preview_serpent.gd` 用生产 60 Hz 控制器和真实箭矢接触驱动；深色 GIF 已生成，峰值和收尾已检查。
- [x] `tests/native_serpent_test.gd`（34 项）覆盖：鳞板弹箭、逆鳞抽甲与倒地、护甲重新覆上、盘击打断与失败、潜渊拽出、吞星／星蚀计数、双生斩丝、换相残影、存档恢复。
- [ ] 尚未生成浅色和 reduced 模式的 GIF；人工手感、触屏和目标硬件验收待完成。

## 熔炉巨像 V2：铸铁巨像 / 炉温开炉（2026-11-01）

- [x] 本体改为 `forge_surface.gd` + `forge_body.gdshader` 单块常驻着色器（基座、梯形躯干、双臂、肩甲、倾转坩埚头，自下而上点火）；炉门、铁拳、风箱嘴、熔团、坩埚嘴与掌心由 `forge_art.gd` 按碰撞体绘制，与本体共用 `ForgeSurface.pose()` 包络。
- [x] 玩法：本体区域清空，两侧熔岩燃料砖（一阶段 2、三阶段 4）击碎 +24 炉温并在原槽重生；炉门封闭时弹箭不加温，满 100 开炉 4 秒伤害 ×3，之后封炉回落到 0。每招一个反击点：锻锤打抬起的铁拳、喷火击落全部熔团、风箱射入张开的肩嘴（风向推箭）、铁掌三击掌心（指节挡箭）、倾倒射坩埚嘴断流、熔毁只计亮起心跳（三击开炉 5.5 秒）；失败降温并铺铁甲／熔渣。
- [x] 演出：入场自下而上点火、双拳落座；开炉炉栅张开与倒计时环；换相肋舱亮起、三阶段裂纹；死亡龟裂熄火、碎片坠落。
- [x] 注册 `forge_intro` / `forge_overheat` / `forge_slam` / `forge_meteor` / `forge_bellows` / `forge_palm` / `forge_pour` / `forge_meltdown` / `forge_phase` / `forge_death`，由 `tools/preview_forge.gd` 以生产 60 Hz 控制器和真实箭矢接触驱动；深色／浅色／reduced GIF 已生成并检查峰值与收尾。
- [x] `tests/native_forge_test.gd`（30 项）覆盖净空轮廓、燃料数、封门弹箭、加温开炉、回落、六招反击与失败、燃料重生与存档恢复。
- [x] 采样配乐：`forge_music.gd` 四轨（炉床 + 余烬／鼓与提琴／交响金属，均 CC0、D 小调），按点火、炉温、开炉、熔毁、转相、死亡混音并驱动低通；`native_forge_test` 覆盖，51 秒音画预览由 `tools/preview_forge_av.gd` 录制，来源见 `docs/audio-sources.md`。
- [ ] 熔炉仍未加入自然 Boss 牌组（仅 `bossOverride` 可进）；人工手感、触屏和目标硬件验收待完成。

## 时之君主 V2：珐琅表盘 / 正点抽空（2026-11-01）

- [x] 表盘改为 `clock_surface.gd` + `clock_dial.gdshader` 单块常驻着色器（斜面黄铜表圈、滚花、星盘外环、扭索纹珐琅、60 刻度、副表盘）；指针、晶核、齿轮与招式道具由 `clock_art.gd` 按碰撞体绘制，与表盘共用 `ClockSurface.pose()` 包络。
- [x] 玩法：表盘区域清空，只保留四角砖；时针指向的亮起刻度每击抽空 20 发条，击碎 30，抽空即停摆 ×3；亮刻度被毁 1.6 秒后重生；停摆时指针张成上方 V 形，让出发射通道；钟摆摆杆成为挡箭碰撞体。
- [x] 演出：入场表圈描画 + 指针倒转归位 + 晶核点火；换相指针狂转；停摆花瓣展开与倒计时环；死亡表盘龟裂、指针坠落、刻度随表盘同步碎裂。
- [x] 注册 `clock_intro` / `clock_stall` / `clock_pendulum` / `clock_stop` / `clock_toll` / `clock_rewind` / `clock_haste` / `clock_midnight` / `clock_phase` / `clock_death`，由 `tools/preview_clock.gd` 以生产 60 Hz 控制器和真实箭矢接触驱动；深色／浅色／reduced GIF 已生成并检查峰值与收尾。
- [x] `tests/native_clock_test.gd`（21 项）覆盖开放表盘、亮刻度抽空、停摆姿态、摆杆挡箭、亮刻度重生与存档恢复。

## 深渊之眼 V5：遗物之眼 / 十二晶结界（2026-11-01）

- [x] 着色器重做：黑曜石杏仁眼窝、鎏金尖刺、珍珠眼白、分层虹膜、星空瞳孔可开合；12 颗晶体结界画在真实 57px 碰撞圈上；承载面、位置和碰撞半径不变。
- [x] `eye_ward`（新增）：真实发射器连续命中，每次熄灭一颗晶体，归零后破盾并失神 ×3。
- [x] `eye_gaze_counter`：锁定蓄力时瞳孔张开，真实发射命中瞳孔后打断审判。`eye_gaze_failure`：带扇区、方向箭头、反击圈的预警；1.6s 扫射最多石化 6 块砖，光束在发射通道之上截止。
- [x] `eye_tear`：3 滴星泪各占车道，带尾迹和倒计时；落地回盾并生成九头砖，接住 3 滴必定破盾。
- [x] 深色／浅色／reduced 真渲染循环 GIF 已生成并检查峰值与收尾；`native_eye_test` 137 项、深渊 63 项、深渊 GPU 104 项；原生门禁通过。
- [ ] 用户评审；触屏与目标硬件人工验收。

## 深渊之眼 V4：星云裂隙 / 激光感染（2026-10-31）

- [x] `eye_nebula`：横向撕裂、紫粉青星云、分层星点、眼睛从内部显现；球面明暗、虹膜纤维与玻璃高光。保持原 360×168 承载面、位置及碰撞半径。
- [x] `eye_gaze_failure`：2.4 秒红眼预警、明确红框及进度、有限长度猩红激光；每块 0.9 秒，最多四块现有普通砖转为深渊砖，立即换靶。
- [x] `eye_gaze_counter`：真实发射击碎锁定砖，或击中红瞳立即撤销感染，完整 4 秒失神／三倍伤害；没有延迟转化与补砖。
- [x] Kenney CC0 锁定／激光／感染采样，48kHz Vorbis q7；保留源／成品哈希与制作脚本，打断及转相停止持续声。
- [x] 浅色／深色／reduced 真渲染循环 GIF、显瞳近景与 21 秒原生采样混音视频已生成并打开；检查显现、照射峰值、换靶、转化、真实打断及收尾。GIF 无损重封装保留逐帧像素、时长和无限循环。
- [x] 原生门禁 28/28；感染专项最终 109 项、采样音频 98 项、深渊 GPU 104 项、通用渲染 570 帧通过，`git diff --check` 通过。音画成片 48kHz 双声道，无削波；暂停／阶段／死亡／session reset 不遗留持续激光声。
- [ ] 用户评审本轮样板后继续其余招式与阶段；人工可读性、触屏和目标硬件验收待完成。

## 深渊之眼 V3：历史凝视样板（2026-10-31，已被 V4 修订）

- [x] `eye_gaze_counter`：实际 `shoot()`／`update()`、固定反击入口、方向性破盾、完整 4 秒失神；六姿态、接触侧裂痕和固定文字层。
- [x] `eye_gaze_failure`：至少 2.4 秒预警、80ms 楔形释放、最多三个预印格依次孵化、0.6 秒恢复；取消随机远端补砖。
- [x] 浅色／深色／reduced 真渲染循环 GIF 已生成并打开，峰值与收尾检查；16.5 秒原生混音视频、同种子 A/B、六姿态灰度和关键帧已交付。路径见 `docs/abyss-eye-redesign.md`。
- [x] 37 项凝视专项、60 项既有深渊逻辑、92 项 GUI 检查；有界 24 事件、12 体积＋1 光束，新增一个固定无材质指引 Label。
- [ ] 样板经用户评审后扩展其余五招、差异化转场与死亡；完成全构筑／触屏／人工可读性及硬件验收。

## 碎砖收入反馈（Web 对齐）

- [x] `brick_income`：实际击碎路径显式传入实付金额；每箭累加、显示块数、按连击上限升温、平滑追随最近命中点、连续缩放弹跳，最后 0.5 秒上浮淡出；每次击碎续期到 1.25 秒。
- [x] 性能预算：最多 8 组收入；超额并入末组保留金额；只保存箭 ID，不持有箭对象；无逐砖 Label/Tween、无新增粒子；固定字号字形缓存，文字变动才重算宽度。reduced 取消命中缩放弹跳。
- [x] `native_income_test` 覆盖真实结算、独立奖金隔离、四档颜色阈值、30/120 Hz 跟随一致性、生命周期/reset 和 10,000 次收入事件预算；完整原生回归与实际图形渲染回归通过。
- [x] 独立无材质文字层绕开 FX stroke-mesh shader，避免字体 atlas 被当作程序化几何而隐藏；`native_income_render_test` 用浅/深色真实 GPU 像素差验证金额与块数确实可见。
- [x] 真实渲染预览：`python3 godot/tools/preview_effects.py --skills brick_income --seconds 3 --fps 50`；深色与 reduced 使用同一 fixture，不改玩法数值。

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

## 爆炸砖 V2：GPU 爆炸 / 分层采样爆炸音（2026-11-01）

- [x] 视觉：`bomb_batch.gd` + `bomb_blast.gdshader`，每次爆炸一个 MultiMesh 实例（39 个四边形：烟团、冲击环、7 个火球团、6 道火舌、白热核、6 块弹壳碎块、12 道火星），全部爆炸合成一次绘制。冲击环约 0.2 s 落在真实伤害半径 132；火团冷却成烟，1.1 s 收尾；过期部件塌缩为零面积。
- [x] 性能：爆炸砖不再产生 CPU 粒子、ring 和合成 `boom`；邻砖按冲击到达时间受热、震动（reduced 下关闭震动，并减少火舌、碎块和火星）。
- [x] 音效：`brick-bomb-1…4.vorbis`（火箭/低频爆炸+爆裂+碎石+落石四层 CC0 采样预混，单声部），连爆音高逐级上扬，见 `docs/audio-sources.md`。
- [x] 注册 `brick_bomb` / `brick_bomb_chain`（宽画幅），由真实 `simulation.hit` 驱动；浅色、深色、reduced GIF 已生成，峰值和收尾已检查。
- [x] `native_explosion_test` / `native_audio_test` 覆盖事件预算、过期、无 ring/粒子、连爆强度、四变体轮换和音高范围；`effect_warmup.gd` 预编译该 shader。
- [ ] 目标手机上的手感和音量待人工验收。

| 状态 | GIF 夹具 | 保留的视觉内容 | 预算 / 生命周期 |
| --- | --- | --- | --- |
| [x] | `brick_lightning` | 2026-10-30 改为复用 `storm` 雷神降临逐跳主弧、内芯、闪核与短分叉；旧放射电弧和重复细线已删除 | 共用 64 个 skill event；每跳 0.5s；普通 5 目标、强化 7 目标不变 |
| [x] | `brick_gold` | 硬币面/边缘、真实 ¥ 字体、4 处闪芒、10 个菱形碎片；单面 shader 合成轮廓 | 最多 48 事件；原 0.58s 事件时长；101 顶点共享模板 |
| [x] | `brick_frost` | 原冰冻波与持续冰层、10 片旋转冰晶；既有 reduced 为 4 片 | 最多 48 特殊事件；冰晶 0.58s / reduced 0.38s |
| [x] | `brick_bomb` / `brick_bomb_chain` | 2026-11-01 改为 `bomb_batch.gd` GPU 爆炸：冲击环、火球团、火舌、白热核、弹壳碎块、火星、烟团；真实连爆链 | 最多 16 事件、每事件 39 四边形一次绘制；1.1s 收尾 |

- `native_effect_batch_test.gd` 覆盖容量、过期、reset、共享模板、半精度 seed 编码、reduced 参数、真实渲染可见性、屏外发射点与前景遮挡顺序；已接入默认原生和 GUI gate。
- 浅/深色及 reduced 的真实渲染 GIF 使用上述四个夹具生成，检查峰值和收尾。收益、视觉差异与软件渲染限制见 `docs/godot-effects-performance.md`。
- 本表的特殊砖夹具不代表同名技能已完成 V2 升级；技能进度仍以下表为准。

### 第二轮紧凑实现（2026-10-30）

- 电弧砖与雷神降临只保留 `skill_impacts.gd` 的 `storm` 视觉。`simulation.gd` 在原连锁循环中无条件生成真实 hop endpoint；不再生成 lightning special 或 legacy bolt。删除电弧专用 shader/UID/Board 节点，原 special batch 收窄并改名为 `coin_batch.gd`。
- `brick_lightning` / `storm` GIF 均由实际 `Simulation.hit()` 触发，分别验证 5／7 目标，而非直接调用没有终点的 special event。孤立电弧砖不生成虚构目标。
- 金币 101 顶点，冰晶 40 顶点，火星 72 顶点；保留 10／18 片及原 reduced 4／6 片设置。火团载体改包围有效范围的 12 边形；火团／冰层用多项式 hash，时间包络移至 vertex，冰层复用晶体场生成纹理裂纹。允许噪声细节、边缘及局部重叠有轻微变化。
- 新增普通／技能强化、完整／reduced 电弧连锁回归：真实端点、目标数、伤害倍率、原箭矢击杀归属、无重复绘制、64 队列、视觉时钟过期与活动 reset；见 `native_special_brick_test.gd`。
- 最终原生 15/15、GUI 18/18、特殊砖／爆炸／冰冻专项 3/3 通过；电弧真实连锁回归 115 项。8／12 个五跳电弧砖的 llvmpipe 峰值 p50 约降低 24%／26%，单砖持平；持续混播长尾仍未达标。完整对照与混播队列差异见性能记录，不将软件渲染收益外推为 Android FPS。

### 第三轮高频技能与长尾（2026-10-30）

- `echo/piercer/seeking/ricochet/storm` 改用 `skill_batch.gd` / `skill_batch.gdshader` 的共享不可变几何和有界 MultiMesh；删除对应旧 CPU 绘制分支。每种技能编译期特化，保留事件端点、原始时长、64 共享队列、普通／强化 Storm 唯一视觉路径与 reduced 元素数，不主动降级。
- 爆炸火团改为固定 16 实例池，不在首次命中创建 Polygon2D／材质；年龄相关载体保留火团、烟尘、冲击波和微光收尾，18／6 片火星不变。
- 首次可操作前通过 `effect_warmup.gd` 的 128×128 独立 viewport 真实渲染 16 帧，缓解首用 GL／JIT 尖峰；准备阶段显示提示、不推进真实游戏时钟，完成即释放，每进程一次。启动耗时另报，不能把预热成本从报告中隐去。
- 新增 `native_skill_batch_test.gd` 与 `native_effect_startup_test.gd`，接入默认原生／GUI gate；覆盖模板、容量、像素、端点、过期／reset、玩法 RNG、预热隔离与资源释放、真实非测试启动门禁。持续测试与逐帧探针共用 `effects_stress_fixture.gd`，统一源码指纹。
- 浅／深色完整与 reduced GIF 均使用既有真实 Board 夹具，不新增伪事件。A/B 检查修正 Echo 的世界角度镜像与反弹／Storm 分叉旋转符号；线头、抗锯齿及跨类局部遮挡允许轻微变化。最终数据与剩余限制见 `docs/godot-effects-performance.md` 第三轮。

## 全量进度

以下条目按 `godot/assets/skills.json` 的技能目录维护。新增技能时同时补入本表，并在完成后勾选、填写对应设计记录和测试。

### 第四至第六批集成验收（2026-10-29）

- 三个并行代理各完成四项，共新增 12 项；累计 24 项已升级、57 项待升级。完成条目无重复，24 项均有 GIF 注册。
- `python3 godot/tools/run_checks.py --godot godot`：15/15 通过，包括 18,000 帧模拟与全部六批技能测试。
- `python3 godot/tools/run_checks.py --godot godot --gui`：18/18 通过，包括 566 帧渲染、972 个描边夹具及第四／五／六批 61／61／74 项检查。全部技能批次测试已纳入默认原生和 GUI 门禁。
- 图形环境为 X11 + llvmpipe 软件渲染；上述结果为正确性验收，不代表移动设备帧率达标。
- 三批浅色完整、深色 reduced GIF 均已生成并复查峰值与收尾；商店购买前景另有 GUI 覆盖。动图及设计见 [第四批](skill-effects-batch-four.md)、[第五批](skill-effects-batch-five.md)、[第六批](skill-effects-batch-six.md)。
- 集成复查修正饮血箭锋末段退化三角面；重新生成第五批两套 GIF，GUI 验证通过。`git diff --check` 通过。

### 第七至第九批：12 项金色技能集成（2026-10-30）

- 三个并行子代理各完成四项，依技能目录选择前 12 项待升级 gold 技能。累计 **36 项已升级、45 项待升级**；81 项目录全覆盖、无重复，新增 12 项全部保持 gold 等级并有真实玩法 GIF 注册。
- 分组设计、事件入口、时长、四层表现、reduced 与预算分别记录于 [第七批](skill-effects-batch-seven.md)、[第八批](skill-effects-batch-eight.md)、[第九批](skill-effects-batch-nine.md)。各组均交付浅色完整和深色 reduced 循环 GIF，复查了峰值、收尾与数字可读性。
- 新增三个批次测试与 `native_skill_gold_integration_test.gd`，接入默认原生／GUI 门禁。混合测试将 12 个金色技能与 5 个既有 GPU 技能交错填满共享 64 事件队列，检查淘汰、所有 13 个 GPU 家族分派、过期、活动 reset、复位后画面和玩法 RNG；另以 180 个真实 60Hz tick 对比 12 技能同时装备时完整／reduced 的弹道、血量、奖励和 RNG。
- 原生首轮 **20/21**；唯一失败为音频测试退出时未释放模拟产生的 ObjectDB 警告，89 项断言均通过。补充 `session.finish_save()` / `session.runtime.dispose()` 清理后，音频与最新混合测试定向 **2/2** 通过（89 / 212 checks），全套原生各项均已通过。
- 第七／八／九批原生分别 **105／56／222 checks**；第八批独立数值 reference **12661 checks** 通过。原生全套包含 18,000 帧模拟。
- 图形环境为 Xvfb / Mesa llvmpipe，结果用于正确性验收；动图位于 ignored `agent-tmp/godot/effect-gifs/`，混合场景截图位于 `agent-tmp/godot/skill-gold-integration/`。

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
- [x] `trident` 三叉齐射（gold）— 成功生成的五路扇箭与回声发射刃，0.46s；[第七批设计与验证](skill-effects-batch-seven.md)
- [x] `meteor` 流星雨（gold）— 真实延迟流星入场与碰撞热溅，0.58s / 0.48s；[第七批设计与验证](skill-effects-batch-seven.md)
- [x] `hunters` 追猎蜂群（gold）— 双侧蜂翼出巢与真实命中蜂刺，0.50s / 0.38s；[第七批设计与验证](skill-effects-batch-seven.md)
- [x] `rapid` 疾风快弦（gold）— 弹弓前景回弦与风切，0.18s 回弹、0.36s 收尾；[第七批设计与验证](skill-effects-batch-seven.md)
- [x] `nova` 碎星新生（gold）— 真实成功子箭的扇形尖星新生，0.62s；[第八批设计与验证](skill-effects-batch-eight.md)
- [x] `crossfire` 十字审判（gold）— 四向刀光与真实行列目标烙印，0.48s；[第八批设计与验证](skill-effects-batch-eight.md)
- [x] `jackpot` 幸运暴富（gold）— 原奖励掷骰的大小 ¥ 金币与喷发，0.72s；[第八批设计与验证](skill-effects-batch-eight.md)
- [x] `supernova` 超新星爆发（gold）— 第四次齐射的局部新版爆炸、星芒与全局目标热印，0.96s / 1.1s；[第八批设计与验证](skill-effects-batch-eight.md)
- [x] `swarmqueen` 蜂群女王（gold）— 八路真实成功弹道的金黑蜂体与晶翼，0.54s；[第九批设计与验证](skill-effects-batch-nine.md)
- [x] `railgun` 歼星轨道炮（gold）— 出膛双轨与真实穿透点白热冲击，0.40s / 0.42s；[第九批设计与验证](skill-effects-batch-nine.md)
- [x] `frostfire` 冰火连爆（gold）— 即时晶片、独立冰层与 0.09s 延迟新版爆炸，瞬时尾段 1.19s；[第九批设计与验证](skill-effects-batch-nine.md)
- [x] `thunderlottery` 雷霆骰子（gold）— 原中奖分支的六点骰面与实际端点金色跳电，0.56s / 0.48s；[第九批设计与验证](skill-effects-batch-nine.md)

### 待升级

- [ ] `titan` 泰坦之力（blue）
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
- [ ] `heavy` 破城重弩（blue）
- [ ] `growing` 越战越勇（blue）
- [ ] `doubletap` 延迟引爆（blue）
- [ ] `snowburst` 冰河冲击（blue）
- [ ] `sharpshooter` 满弓狙击（blue）
- [ ] `bankshot` 弹射工厂（blue）
- [ ] `minefield` 脉冲雷区（blue）
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
## 深渊之眼 · 蚀月遗像

- [x] 保持原 360×168 承载面、(390,92) 中心和 57/43 碰撞半径；不放大本体、不改变砖块位置或尺寸。
- [x] 使用游戏原有石色和紫色 palette：分面石片、浅倒角、刻缝、菱形瞳孔、少量微光，替代写实金属模型。
- [x] 3.4 秒真实转相：闭眼、短距离解封、睁眼、棋盘入场；与输入锁定、暂停、采样音乐及揭幕音同步。
- [x] 凝视锁定预警、真假瞳追踪差异、终焉三击打断与破盾收尾。
- [x] 三层采样 BGM、八种采样音效、暂停／静音／打断生命周期。
- [x] 注册 `eye_intro` / `eye_gaze` / `eye_mirage` / `eye_doom` 真实渲染预览。
- [x] 新增 `eye_phase` / `eye_final_phase` / `eye_phase_close` / `eye_death`，真实 Director 驱动；GPU 像素回归覆盖浅深主题、简化动效、闭眼、双转相和死亡。
- [x] 战斗特效加层：刻缝聚能、杏仁形解封轨迹、旧阵裂解汇印、新砖反光；分层扫射、六符召唤及分面余波、晶泪尾迹、晶环拖尾、分瞳残影和终焉三击反馈。
- [x] `abyss_events` 接入真实施法／接触／打断／死亡；24 事件预算、45ms 命中合并、固定 12 局部面片 + 1 光束、96 个值类型旧砖快照，暂停与 RNG 独立；逻辑和真实 GPU 回归覆盖。
- [x] 注册 `eye_summon` / `eye_tear` / `eye_orbit` / `eye_impact`；终焉与命中 fixture 使用真实箭矢碰撞，不直接设置命中次数。
- 验证及交付记录：`docs/abyss-eye-redesign.md`。
