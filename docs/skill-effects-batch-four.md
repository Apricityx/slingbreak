# 第四批：核心与经济技能动态特效

2026-10-29，Godot 4.7.2 stable。范围仅 `treasury`、`bargain`、`resonance`、`corehunter` 四个 white 技能。

## 设计与真实触发

| 技能 | 冲击 / 主体 / 材质 / 场景关系 | 真实入口 | 生命周期与 reduced |
| --- | --- | --- | --- |
| treasury 核心宝库 | 金白裂缝、两侧宝库壁张开、双色菱形碎金向下扇出并下坠；从奖金结算时核心位置发出，核心删除后继续完成 | `Simulation.clear()` 实际结算原有三倍核心奖金后；重复 clear 不重复播放 | 0.72s；9 片降至 4 片，位移/重力降至 30% |
| bargain 超频工坊 | 短闪锻缝、两侧齿形压轨向内合拢、升温亮芯与向上火屑；在发射器上方表示升级装备 | `Simulation.buy()` 校验成功并支付原有六折价格后；失败/暂停/不可购买不产生事件 | 0.60s；6 火屑降至 3，运动降至 30% |
| resonance 核心共振 | 中心瞬闪、四瓣开放谐振轮廓向核心内聚、短亮刻线；核心实体仍可辨认，没有固定闭合圆环 | `Simulation.spawn_core()` 非 quiet 的真实显现路径；存档恢复静默，不重复显现 | 0.68s；保留四瓣，移除 4 颗内聚火屑，运动降至 30% |
| corehunter 终焉引力 | 箭头附近短闪、局部曲线流、双色内芯、核心两侧内收夹角；记录真实起点和目标，流线长度最多 78 世界像素 | `Simulation.guide()` 核心在 320 范围内且实际修正角度 >0.01；预测路径不播放，不再以普通砖命中图章代替引力 | 0.46s；每箭 visual_time 冷却 0.18s；3 流线降至 2，弯曲降低 |

全部为 `CanvasItem` 程序化动态几何，无新增贴图、图标或 GPU 实例。快起包络 `1-exp(-age*25)`，短闪 `exp(-age*35)`，主轮廓和碎屑随生命周期衰减。技能内容颜色与 accent 沿用现有 palette，外轮廓按浅/深主题选择深墨/亮灰。

## 文件与接口

- `godot/src/render/skill_batch_four.gd`：独立绘制器；只读取事件快照。
- `godot/src/render/bargain_feedback.gd`：商店前景适配器，复用同一购买事件及视觉时间；`godot/src/main.gd` 仅在成功购买 bargain 时调用，使反馈位于实际购买按钮旁、不被商店面板遮挡。
- `godot/src/core/simulation.gd`：四处真实入口，仅增加视觉事件与引力视觉冷却。
- `godot/src/skills/mechanics.gd`：只跳过 corehunter 原通用命中图章。
- `godot/src/render/board.gd`：专用预加载和四个 ID 分派。
- `godot/tests/native_skill_batch_four_test.gd`：定向原生验证。
- `godot/tools/preview_skill_batch_four.gd`：独立真实入口预览夹具。
- `godot/tools/preview_effects.gd` / `effect_previews.json`：唯一 `batch_four_live` 分派和四项注册。

## 预算、时间与玩法隔离

- 复用现有 `skill_events` 64 事件上限，溢出淘汰最旧快照；未改公共 schema 或生命周期处理。
- 单事件最多 9 碎金、6 火屑、4×9 点谐振瓣、3×9 点吸引曲线；不分配持久节点或实体引用。
- 商店前景短时节点最多 8 个，溢出删除最旧节点；共享事件过期、队列淘汰或 reset 后释放。
- 使用 `fx.visual_time`，不使用系统时间；过期与 reset 沿用 Effects。
- 无玩法 RNG 消耗。金币、升级、门槛、转向、穿透均继续由原有玩法计算。
- 引力原有 +4 穿透仍只给一次；预测不授予奖励或输出特效。

## 验证记录

```bash
python3 godot/tools/run_checks.py --godot godot --test native_skill_batch_four_test
python3 godot/tools/run_checks.py --godot godot --test native_skill_batch_four_test --gui
python3 godot/tools/preview_effects.py --skills treasury bargain resonance corehunter --out agent-tmp/godot/effect-gifs/batch-four-light.gif
python3 godot/tools/preview_effects.py --skills treasury bargain resonance corehunter --theme dark --reduced --out agent-tmp/godot/effect-gifs/batch-four-dark-reduced.gif
```

- 定向原生检查：**57 checks, 0 failures**，覆盖完整与 reduced 两种真实玩法、箭矢命中核心、三倍奖金、六折购买、失败购买、9/20 提前核心阈值、quiet 恢复、预测隔离、真实引导与冷却、范围和角度不触发、队列淘汰、视觉时间过期、reset 和无技能不误触发。
- GUI 原生检查：**61 checks, 0 failures**；额外覆盖真实商店购买按钮前景、8 节点预算、共享事件时间、过期与 reset；实机渲染 `agent-tmp/godot/skill-batch-four/bargain-shop-peak.png` 确认特效显示在购买按钮左侧、价格保持可读。
- 两套实际 GPU/CanvasItem GIF：每套 56 个采集帧、25 fps、1×、2.24 秒循环，包含全部四技能与密集普通砖背景。静态尾段由 GIF 编码合并为长停留帧。
- 检查 0.28s / 0.40s 峰值、0.64s 衰减、1.04s / 2.0s 收尾：几何无硬裁切；砖数字可读；技能流线全部消失，核心本体正常保留。
- 独立夹具调用真实 `clear/buy/spawn_core/guide`，随后把事件快照平移至统一近景，去除通用清场/显现烟花、恢复密集砖背景；因此 GIF 是技能独立预览，并非商店或清场完整 UI 录像。
- 原生日志：`agent-tmp/godot/checks/native_skill_batch_four_test.log`。GIF 同名 `.log` 和 `.json` 保留实际引擎与参数。

## 动图交付

- [浅色完整 · 四技能](../agent-tmp/godot/effect-gifs/batch-four-light.gif)
- [深色 reduced · 四技能](../agent-tmp/godot/effect-gifs/batch-four-dark-reduced.gif)

动图与峰值/尾段检查图放在忽略的 `agent-tmp/`，不提交二进制临时产物。商店遮挡关系由上述实际 UI GUI 检查补充验证。
