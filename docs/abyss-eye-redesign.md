# 深渊之眼：V5 遗物之眼 / 十二晶结界

V5（2026-11-01）全面重做造型、玩法与演出，覆盖下文 V4 星云裂隙／猩红侵染。固定约束不变：本体 GPU 承载面 **360×168**；中心 **(390,92)**；护盾半径 **57**、暴露瞳孔半径 **43**；幻瞳 **(170,92)/(610,92)**；阶段动画 `size=1`，不推镜、不放大；首行砖 y=170，不移动、缩放或裁切棋盘；不强调压迫感。

## V5 当前版本（2026-11-01）

### 造型

- `abyss_eye.gdshader` 重写为遗物之眼：黑曜石杏仁眼窝（转相时上下分开并露出发光缝）、7＋5 根鎏金尖刺、金色眼睑描边；珍珠眼白带血丝（随热度与阶段伤害增强）；金芯、紫色基质、青色环与暗色角膜缘的分层虹膜；瞳孔由竖缝扩张为圆瞳，内部是星空。
- 结界直接画在真实 57px 碰撞圈上，由 12 颗菱形晶体组成；点亮数量等于结界值，熄灭的晶体只保留轮廓，碎盾时闪白。阶段配色：紫 → 品红 → 暖金橙；累计伤害达到 30%／62% 时出现固定裂痕。
- 世界层（`abyss_art.gd`）不再画结界弧线；凝视有完整扫射扇区、方向箭头和收缩到瞳孔的反击圈，星泪有落点、轨道、尾迹和倒计时。

### 玩法

- **碎盾**：每次直接命中结界都会熄灭一颗晶体（丢弃半再生部分），并造成少量伤害；单箭最多 4 次。任何削盾都会让锚砖回盾暂停 1.8s。锚砖、观察者和星泪仍然可以削盾。结界归零后失神 4s，瞳孔受到 ×3 伤害。
- **视界审判（gaze）**：先锁定蓄力 2.2s，第 0.35s 起瞳孔张开，这时直击瞳孔会立即打断施法并让巨眼失神。没有打断就进行一次 1.6s、±0.92rad 的扫射，最多把 6 块普通砖石化成九头砖（保持几何，HP×1.4）并烧毁光束中的箭，随后 0.6s 恢复。光束在 y=760 和左右墙截止。
- **陨星之泪（tear）**：3 滴泪各占一条车道，依次落下。击碎一滴削减 34 结界，击碎第三滴必定破盾；落地一滴回盾 12 并生成 2 块九头砖。
- 结晶环、虚空孵化、镜界双瞳、终焉三击保持原有规则。阶段顺序：一阶段 结晶环 → 星泪；二阶段 凝视 → 镜界 → 孵化；三阶段 凝视 → 终焉 → 结晶环 → 终焉。
- 存档写入 `encounterVersion=5`。V3、V4 以及未版本化的存档恢复时迁移到 V5 招式池，保留阶段、HP、结界和顺序游标；进行中的施法不会存档。

### 验证

- `tests/native_eye_test.gd`（137 项）用真实发射器验证：碎盾、迎瞳打断、扫射石化范围与几何、光束截止、烧箭、星泪接住与落地、V4→V5 迁移、暂停／转相／死亡取消、采样音频。原 `native_gaze_test` 和 `native_infection_test` 已移到 `agent-tmp/godot/eye-redesign/retired-tests/`。
- 预览 fixture：`eye_ward`（新增）、`eye_gaze_counter`、`eye_gaze_failure`、`eye_tear` 等。GIF 在 `agent-tmp/godot/eye-redesign/v5-*.gif`，改版前基线为 `before.gif`。

---

# 历史：星云裂隙与猩红侵染（V4，已被 V5 取代）

最新用户反馈覆盖此前的「蚀月遗像」主形：**撕开一道裂缝，星云中弹出一只眼睛，整体更华丽**；凝视改为**眼睛变红、带采样音效的激光逐块感染，完成一块立即换下一块**。之前确认的 **大小不能改，暂不强调压迫感** 继续有效。

固定约束：本体 GPU 承载面仍为 **360×168** 世界单位；中心 **(390,92)**；护盾半径 **57**、暴露瞳孔半径 **43**；幻瞳位置仍为 **(170,92)/(610,92)**。阶段动画始终保持 `size=1`，不做镜头推近或本体放大。砖块首行仍为 y=170，保存、恢复与转相都不移动、缩放或裁掉上方砖块。

## V4 当前样板：星云显瞳 / 激光感染（2026-10-31）

### 造型与动画

- `abyss_eye.gdshader` 已替换石质主形。裂口先横向撕开，再撑开上下锯齿边缘；内部双层流动星云、远近星点、紫粉／青色发光薄膜先出现，眼睛随后从深处显现。
- 眼面使用球面明暗、眼睑遮光、径向虹膜纤维、竖瞳和弧形玻璃高光。眼睛内部有短促的显现回弹，承载面、碰撞、棋盘、镜头保持固定。
- 锁定时虹膜和眼面转红，眼球追踪目标；每次激光起射有局部脉冲。激光始终准确连到当前砖表面，只有眼球有 100ms 的追视插值，避免换靶时光束与落点不一致。
- reduced motion 冻结装饰流动、减少火星和局部光照，保留裂口显现、红眼、目标框、感染进度及转化结果。

### 当前玩法

- 新战斗写入 `encounterVersion=4`。V3 保存继续执行固定方向刻印，未版本化的保存继续执行原扫射；保留已有顺序游标和恢复策略。
- 红眼预警 **2.4s**，每块照射 **0.9s**，单次最多 **4 块**，最后 **0.6s** 恢复。只选择现有普通砖，优先前排并交替左右。
- 当前目标使用红色四角框、下沿进度、紫色爬边；白热芯／猩红外层激光终止在该砖表面，感染完成有独立紫色碎裂冠和确认音，随即换目标。
- 转化原子写入 `brick.type="void"`，保留对象 ID、位置、尺寸、当前／最大 HP；不额外生成新砖，仍走生产破坏／奖励路径。
- 击碎红框砖，或从任意方向真实击中红瞳，立即中断并获得 **4 秒失神、伤害 ×3**。进行中的副眼不干扰射线；不会因感染转化排入延迟补砖。
- 暂停冻结照射进度，阶段／死亡取消目标与持续声；存档只保留已转化的砖及版本／顺序，不重播临时激光或感染事件。

### 音频与复现

新增锁定、激光和感染完成三个 Kenney CC0 采样音，48kHz、Vorbis q7。激光由激光瞬态和力场主体分层剪辑；真实发射、每次换靶与实际转化分别发声。来源、许可及哈希在 `godot/assets/audio/eye-laser-credits.json`，制作流程见 `docs/audio-sources.md`。

```sh
python3 godot/tools/preview_effects.py --skills eye_nebula --theme dark --seconds 4.8 --fps 25
python3 godot/tools/preview_effects.py --skills eye_gaze_failure eye_gaze_counter --theme dark --seconds 9 --fps 25
python3 godot/tools/preview_effects.py --skills eye_gaze_failure eye_gaze_counter --theme light --seconds 9 --fps 25
python3 godot/tools/preview_effects.py --skills eye_nebula eye_gaze_failure --theme dark --reduced --seconds 7.8 --fps 25
xvfb-run -a godot --path godot --audio-driver Dummy --disable-vsync --write-movie ../agent-tmp/godot/eye-nebula/infection-slice.avi --fixed-fps 30 --script res://tools/preview_gaze_av.gd
python3 godot/tools/run_checks.py --godot godot
python3 godot/tools/run_checks.py --godot godot --gui --test native_abyss_render_test --test native_render_test
```

`eye_nebula` 独立展示裂隙与显瞳；`eye_gaze_failure`／`eye_gaze_counter` 已改为 V4，均运行固定 60Hz 生产模拟，反制使用真实 `shoot()`，没有直接放置命中箭。视频依次展示显瞳、四次感染、实际射击中断，长 **21 秒**。近景仅改变采集取景，完整棋盘按约 0.5 倍世界尺寸采集。

工程检查与动图交付记录见 `docs/skill-effects-upgrade-checklist.md`。本轮仍是用户反馈驱动的质量样板修订；全招式扩展、差异化转场、人工可读性与目标设备性能继续沿用原计划门槛。

本轮原生门禁 **28/28**；最终感染专项 **109** 项，采样音频 **98** 项，深渊 GPU **104** 项与通用渲染 **570** 帧通过。GPU 检查包括真实红瞳像素、光束与砖表面一致、目标之后的发射区无光束、暂停和尾迹清理。最后补充 session reset 的激光声退场后，音频／感染专项复测通过。视频为 Godot 原生混音，48kHz 双声道、峰值约 0.232，无削波；全套 GIF 已打开并抽查峰值／收尾。

当前交付：

- `agent-tmp/godot/effect-gifs/eye-nebula-emergence.gif`：4.8 秒裂缝显瞳近景。
- `agent-tmp/godot/effect-gifs/eye-infection-dark.gif`：深色连续感染与真实发射打断，9 秒。
- `agent-tmp/godot/effect-gifs/eye-infection-light.gif`：同一真实模拟的浅色检查，9 秒。
- `agent-tmp/godot/effect-gifs/eye-nebula-reduced.gif`：简化动效的显瞳及连续感染，7.8 秒。
- `agent-tmp/godot/eye-nebula/infection-slice.mp4`：21 秒原生音画，完整 412×680 构图；不在 Movie Maker 开始录制后修改视口。

所有 GIF 以相同全局色表无损重封装，逐帧解码像素、各帧时长与循环设置保持一致；没有用插帧或新绘图替代 Godot 渲染。预重做代码快照仍在 `agent-tmp/godot/eye-nebula/pre-nebula.tar.gz`。

---

以下章节保留 V2/V3 历史实现与验收记录；涉及石质造型和凝视刻印的内容由上面的 V4 说明覆盖。

## 战斗编排

- **结界**：碎星结界与陨星之泪。先教会玩家打金色晶心、断锚链、拦截晶泪，换取 4 秒失神、三倍伤害。
- **幻瞳**：视界切割、镜界双瞳、虚空孵化。凝视先锁定方向 1.25 秒，再按真实光束角度扫射；逆光入瞳可打断。只有真瞳追踪准星，假瞳保持静止。法阵闭合前可击破。
- **终焉**：凝视／晶环与终焉交替。终焉有三枚命中印记与倒计时；三击打断获得 5.5 秒失神，失败重生砖块并恢复结界。

新战斗使用固定阶段技能池，池内变化仍由既有 RNG 决定。恢复旧存档保留其技能池。无需修改存档格式。

## 原生表现

- `abyss_eye.gdshader`：宽石片眼睑、浅倒角、低强度颗粒、刻缝、少量面状虹膜、菱形瞳孔与小高光。颜色直接取当前主题的 `obstacle`、`brick`、`brickInk` 和 `rift` palette。
- `abyss_art.gd`：护盾标记、连接石质眼睑的锚链、晶心指示、虚线预警、扫射内芯、终焉吸入粒子与短距离解封碎片。
- `abyss_surface.gd`：固定两个 Polygon2D，读真实 Boss 坐标；幻瞳退场时假瞳渐隐、真瞳归位，尺寸不变。无屏幕复制或 CPU 纹理上传。
- `abyss_rig.gd`：统一采样入场、转相、失神和死亡；所有阶段用模拟展示时间，暂停后不会自行播放。
- reduced motion 固定悬石运动，降低局部亮度反馈并减少碎片，保留闭眼、解封、睁眼与所有玩法提示。
- 视觉不消耗玩法 RNG，不改写碰撞或砖块数据。

## 战斗特效与演出加层

- **施法起手**：眼睑先收紧，石片刻缝与虹膜符印亮起；聚合菱形符文，在真实 `move.live` 边界触发发射闪击和采样音。
- **视界切割**：锁定括角 → 聚焦 → 分层光束（亮芯、扰动外层、双侧细辉、沿轴流动的能量）→ 0.22 秒退光；扫过的附近砖块得到低强度反光。
- **虚空孵化**：六枚符文聚拢成阵，内层连线与向心短芒持续供能；完成或被拦截时，六瓣分面能量展开并散尽。
- **陨星之泪 / 碎星结界**：下坠晶体有双侧尾迹和小晶屑；晶环有轨道短拖尾、金色晶心标记；落点有独立余波。
- **镜界双瞳 / 终焉坍缩**：分瞳瞬间的横向断续残影、符文分流；终焉向心粒子配合六枚收紧的符印，三次真实碰撞依次亮起命中标记。
- **命中与破盾**：护盾擦击、瞳孔有效命中、终焉印记分别产生短闪与定向碎屑；第三击保留命中和破盾尾迹，立即撤去聚能／扫射。死亡碎片在本体退场后继续收尾。
- **转相衔接**：旧砖阵保留最多 96 个位置／尺寸／类型值快照，淡出时短暂显出裂纹；每五块砖发送一枚汇入本体的印记。四段杏仁形封印轨迹收束后解封，新砖阵按原入场次序逐行得到反光。

`abyss_events.gd` 由真实入场、转相、施法、接触、打断、结算及死亡发出事件：上限 **24**，护盾／普通命中按 **45ms** 合并，最长死亡尾迹 **2.5s**；不保存实体或回调，不进入存档。`abyss_fx.gd` 固定 **12** 个局部 GPU 面片和 **1** 条光束，优先显示较新的命中；无逐粒子节点，无屏幕复制。暂停使用冻结的展示时间，阶段重置清空旧事件，死亡由 Director 继续清理。reduced motion 减少碎片与印记、降低局部光照和位移，保留预警及三击反馈。

## 转阶段动画

两次转相走同一个真实 Director 路径，长度 **3.4 秒**：

1. 0–0.72s：眼睑闭合，音乐压低。
2. 0.5–1.58s：旧阵裂解、印记汇入；石片短距离分离，刻缝与封印轨迹逐渐亮起。
3. 1.58s：一次解封音和轻震；碎裂光弧、石屑及能量短芒释放。
4. 1.6–2.65s：睁眼，第二相符印亮起／第三相瞳色转暖。
5. 2.25–3.4s：原尺寸的新棋盘按既有入场曲线出现，石片归位。

转场期间禁止发射和延迟伤害跳相，结束后恢复控制。障碍与砖块同时淡入；取消中途出现的新锚链和观察眼。死亡为闭合、收束与短碎裂，避免全屏大圆环。

## 采样音频

BGM 是原创自适应管弦乐（D 小调、96 BPM、16 小节＝40s），全部由 VSCO-2-CE（CC0）的真实乐团录音渲染，详见 [音频来源](audio-sources.md#abyss-eye-score-orchestral)。五条等长循环分轨放在一个 `AudioStreamSynchronized` 里同步播放：

| 分轨 | 内容 | 进入时机 |
|---|---|---|
| bed | 低音提琴、大提琴、中提琴长音，尼泊尔铃 | 开场随眼睑升起，全程 |
| pulse | 低音提琴／大提琴跳弓 3+3+2，定音鼓、大鼓 | 进入战斗；二、三阶段加强 |
| stars | 小提琴震音、竖琴琶音、钟琴 | 开场与凝视蓄力时突出 |
| theme | 圆号主题，小提琴、长号、大号逐段加入 | 二阶段起，凝视释放后、终焉、三阶段 |
| daze | 下行竖琴、长笛、零星钟琴 | 失神／回盾期 |

凝视蓄力时脉冲变稀，释放前 150ms 至释放后 80ms 压到近乎无声，释放后主题顶上；转相时压低音乐，`eye-shift` 定音鼓滚奏与镲渐强的冲击点对准 `REVEAL_AT=1.58s` 裂瞳帧；崩解时分轨 1.8s 淡出，`eye-finale` 用锣与 D 大调铜管收束。暂停冻结总谱和打击乐，静音或离场时全部停止。专用播放器不会被碎砖音效挤占。旧的三条恐怖氛围织体（eye-ambient／tension／rage）已退役，文件移到 `agent-tmp/godot/retired-eye-music/`。

八种专属采样：苏醒、施法、蓄力、扫射、脉冲、命中、破盾、崩解。破盾／转相／死亡会终止尚在播放的蓄力与扫射音。所有输出经过既有音量、静音、暂停和总线；不叠加旧深渊合成乐谱。

来源、许可、源文件 SHA-256 和编辑时长记录在 `godot/assets/audio/abyss-credits.json`。设置页有素材鸣谢。配乐由 `godot/tools/prepare_eye_music.py` 渲染，来源与哈希记录在 `godot/assets/audio/eye-music-credits.json`。音效制作脚本 `godot/tools/prepare_abyss_audio.py` 使用 numpy、scipy、soundfile、imageio-ffmpeg；输出 48kHz、Vorbis quality 6，素材先做 DC 去除、峰值/RMS 匹配和首尾淡化。

## 验证与预览

```sh
python3 godot/tools/run_checks.py --godot godot
python3 godot/tools/run_checks.py --godot godot --gui --test native_abyss_render_test --test native_render_test
python3 godot/tools/preview_effects.py --skills eye_phase eye_final_phase --theme dark --seconds 6.6 --fps 20
python3 godot/tools/preview_effects.py --skills eye_phase eye_final_phase --theme light --seconds 6.6 --fps 20
python3 godot/tools/preview_effects.py --skills eye_phase --theme dark --reduced --seconds 6.6 --fps 20
python3 godot/tools/preview_effects.py --skills eye_phase eye_gaze --theme dark --seconds 6.6 --fps 25
python3 godot/tools/preview_effects.py --skills eye_summon eye_tear eye_doom eye_impact --theme light --seconds 6.6 --fps 25
python3 godot/tools/preview_effects.py --skills eye_intro eye_mirage eye_orbit eye_death --theme dark --seconds 9.4 --fps 20
```

GIF 使用真实 Board / GPU 渲染。`eye_phase`、`eye_final_phase` 和 `eye_phase_close` 通过清空本相 HP 触发真实 Director，逐步运行其锁定、音效、入场与解锁；没有另写一套转场。`eye_phase_close` 只是近景取景，不改变游戏尺寸。终焉与命中预览会按预设时间创建箭矢并调用真实碰撞路径，检查确有新事件产生；属于确定性演出场景，并非真人操作录像。GIF 本身无声。

专项测试还覆盖转相锁定、闭眼先于解封、单次揭幕音、棋盘延迟入场、暂停冻结、还原后不重播转场，以及原始模型／碰撞／砖块尺寸约束。独立 GUI 测试通过真实像素差检查开闭眼、两次转相、暂停帧、幻瞳和死亡退场，覆盖浅色／深色与 reduced motion。

特效专项新增：10,000 次事件预算、45ms 合并、预测接触无副作用、真实发射边界只触发一次、打断保留余波、旧砖快照不持有实体、暂停／还原／到期清理、死亡后的 Director 清理。GPU 像素差隔离检查旧砖淡出、解封碎片、实际扫射、暂停定帧和尾迹归零，同时验证固定 13 个 FX 节点及 RNG 独立。

本轮验收：完整原生门禁 **25/25**；深渊逻辑 **60** 项；深渊真实 GPU **88** 项（含排队绘制后 reset 的清理时序）；通用 CanvasItem **570** 个 fixture 帧通过。下列动图已打开，并抽取聚能、爆发与收尾帧检查；29.3 秒音画预览无脚本错误，第三次真实碰撞断言通过，成片含 48kHz 双声道采样混音。

交付产物位于忽略的 `agent-tmp/godot/`：

- `effect-gifs/eye-vfx-phase-gaze-dark.gif`：旧阵解封与凝视扫射。
- `effect-gifs/eye-vfx-combat-light.gif`：浅色召唤、晶泪、终焉及命中／破盾。
- `effect-gifs/eye-vfx-rituals-dark.gif`：入场、幻瞳、晶环与死亡。
- `effect-gifs/eye-vfx-reduced.gif`：简化动效的转相与三击破盾。
- `abyss-audio/eye-vfx-preview.mp4`：带采样音乐和音效的连续演出。

带音频展示使用 `preview_abyss_av.gd`，通过 Godot Movie Maker 原生音频混音器录制约 29 秒的入场、两次转相、幻瞳、凝视扫射、三击破盾与死亡场景：

```sh
xvfb-run -a godot --path godot --audio-driver Dummy --disable-vsync --write-movie ../agent-tmp/godot/abyss-audio/abyss-preview.avi --fixed-fps 30 --script res://tools/preview_abyss_av.gd
```

## V3 第一里程碑：凝视裁印可玩样板

### 基线与关键姿态

现版代码快照保存在忽略目录 `agent-tmp/godot/eye-v3/pre-v3.tar.gz`；记录了当时工作区状态，未提交或覆盖其他工作。A/B 使用同一种子 9128、同一原尺寸视口、同一开始时间：

- V2 起手约 0–1.25s：通用聚符与眼睑微收，缺少独立的锁定／压缩姿态。
- V2 释放后：扫射方向持续改变，反击入口随其转动；孵化抽随机数，到期又在其他位置补砖。
- V2 破盾：通用径向闪击，失神期间没有持续的接触侧伤口。

V3 的六姿态为静观、锁定、压缩、释放、断印、失神。上／下眼睑错拍，内层收紧，发射后快速打开；从真实接触方向传播裂口，六片石板依次脱开，裂痕保持到恢复。全部在原承载面内完成。形状词典为**刻印楔面、双缺口反击口、接触侧裂解**；折射词典的完整招式动画留在样板评审之后。

关键帧由 `preview_gaze_poses.gd` 在真实发射片段中采样，包含六姿态原色／灰度图、四张凝视关键帧和三张破盾关键帧。以约 0.5 倍世界尺寸检查，近景不替代手机尺度。

### 已落地的规则

- 新增 `bosses/eye_pattern.gd`：独立于其他 Boss 的顺序配置，第一相 orbit→tear，第二相 gaze→mirage→summon，第三相 gaze→doom→orbit→doom。不可达凝视不消费顺序，间隔 2 秒重新检查，期间可清砖／断链。
- 凝视先用共享积分与墙面反射做有界静态弹道检查：最多 61 个拉弓方向、每条最多 180 个 60Hz 步；明确消耗穿透。它是保守的施法准入检查，不代替动态构筑／所有技能的实测。
- 预警至少 **2.4s**，并覆盖剩余拉弦冷却＋0.65s 识别瞄准＋预计飞行＋0.2s 余量。方向锁定后不再扫动；0.35s 起允许沿双缺口击瞳。有效期延续到释放后 2.2s，随后 0.6s 收尾。
- 最多预告三个合法格子，沿刻印方向选择；排除会堵住准入弹道的格子。到期只在这些位置孵化，已占用则跳过。取消凝视的通用随机补砖；中断后没有延迟孵化任务。
- 为保证固定反击方向的承诺，已有引力井消退前延后凝视；凝视中虚空砖破坏不再生成新引力井。副眼在这段交互中停用碰撞并同时退场，避免两个主动机制争夺射线。
- 保留 57／43 碰撞半径。错误方向仍擦盾；正确方向立即撤销攻击并给出完整 **4 秒、三倍伤害**。破盾短顿改为 70ms，reduced 保留姿态／裂痕／提示。
- 新战斗不使用旧的按时间压制伤害机制，高伤害构筑可正常推进。旧存档仍用原抗性。V3 不保留无用途的历史伤害队列。
- 阶段设置和恢复不再删除副眼位置附近的砖；只有该位置本来空闲时才建立副眼。

### 存档与声音

`fight.data.encounterVersion=3` 和 `sequence` 保存已接受的招式顺序，`Progress.valid_boss` 校验版本／阶段键／游标。JSON 往返后阶段数可能为浮点数，顺序键统一经过 `int()` 再转字符串，避免把 `"2"` 误读为 `"2.0"`。无版本的存档保留旧机制及技能池。进行中的招式沿用原恢复策略，取消临时状态后进入安全准备时间；视觉事件、路线采样、碎片及声音状态不入存档。

沿用已登记的采样素材，发射音与真实 `live` 同步；释放前 150ms 至释放后 80ms 快速压低音乐，给瞬态留空间。打断立即停掉持续施法／光束声，失神降低张力层。棋盘中文指引使用一个固定、无 FX 材质的 Label，避免字体图集被描边网格 shader 吞掉。

### 真实输入验证与交付

`native_gaze_test.gd` 覆盖低／高配置、稀疏／密集棋盘的准入及真实 `shoot()`、错误方向擦盾、含剩余冷却的窗口、仅预印位置孵化、直接伤害、顺序推进、JSON 恢复及旧版本兼容。最低稀疏配置从发射点约 **0.667s** 命中，高配置约 **0.433s**；密集低穿透配置延后施法，高配置实测能穿过砖阵反制。这些是确定性测试数据，不代表全部构筑的可达性。

- 全套原生回归本轮通过 **27/27**；最新凝视专项 **37** 项、既有深渊专项 **60** 项。后续局部修改运行对应专项。
- 深渊 GUI **92** 项检查覆盖真实材质、暂停、入场、事件池、reset 与无材质文字；通用 CanvasItem **570** 个 fixture 帧通过。
- 每条新 GIF 均从 `Simulation.shoot()` 和 `Simulation.update()` 驱动，保留真实穿透、引力井规则、命中短顿和输出窗口；它们是**脚本操作的真实模拟录像**，不是人工玩家录像。展示构筑为拉力 30、箭 24、轨道炮；Boss HP 按该构筑的生产公式配置。
- 16.5 秒 MP4 包含同棋盘失败与成功两条路径，使用 Godot Movie Maker 的 48kHz 双声道采样混音。
- A/B 中副眼附近原有的裁砖行为已移除，所以这些格子会有可解释的布局差异；种子、格距、尺寸、相位与取景相同。基线属于 V2，不能用于声称 V3 的性能收益。

交付文件：

- `agent-tmp/godot/effect-gifs/eye-v3-dark.gif`
- `agent-tmp/godot/effect-gifs/eye-v3-light.gif`
- `agent-tmp/godot/effect-gifs/eye-v3-reduced.gif`
- `agent-tmp/godot/effect-gifs/eye-v3-ab.gif`
- `agent-tmp/godot/eye-v3/gaze-slice.mp4`
- `agent-tmp/godot/eye-v3/poses-six.png`、`poses-six-gray.png`、`gaze-four.png`、`break-three.png`

复现：

```sh
python3 godot/tools/preview_effects.py --skills eye_gaze_counter eye_gaze_failure --theme dark --seconds 9 --fps 25
xvfb-run -a godot --path godot --audio-driver Dummy --script res://tools/preview_gaze_poses.gd
xvfb-run -a godot --path godot --audio-driver Dummy --write-movie ../agent-tmp/godot/eye-v3/gaze-slice.avi --fixed-fps 30 --script res://tools/preview_gaze_av.gd
python3 godot/tools/run_checks.py --godot godot --test native_gaze_test --test native_abyss_test
python3 godot/tools/run_checks.py --godot godot --gui --test native_abyss_render_test
```

**下一门槛**：用户评审该样板的主形、可读性与破盾释放感。之后扩展另五招、差异化转场与死亡；三阶段全技能可达性、触屏真假线索、人工可读性和目标硬件性能均仍需完成。共享计划仅勾选“质量基线”和“质量样板”，不把凝视专项当成整个三阶段灰盒完成。
