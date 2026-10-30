# 第五批：齐射、毒伤、破阵与饮血

2026-10-29。范围仅 `legion`、`poison`、`ambush`、`siphon` 四个 white 技能。采用独立 `godot/src/render/skill_batch_five.gd` 的程序化 CanvasItem 动态几何，无运行时贴图、静态图标或新增节点池。Board 只增加专用预加载和分派。

## 设计与真实触发

| 技能 | 触发 | 冲击 / 主体 / 材质 / 场景关系 | 节奏与 reduced |
| --- | --- | --- | --- |
| `legion` 万箭归宗 | `on_shoot` 每第三次实际发射，原 `fan(...,6)` 成功生成额外箭后 | 起点闪核；六条与真实扇形 ±0.1/0.2/0.3 弧度一致的箭道；双色刃尖和短尾；沿主箭方向向前生成、伸展、缩短消失 | 0.58s，主体约 0.1s；简化模式保留六路，取消尾屑并降低移动。箭容量满导致没有额外箭时无假触发 |
| `poison` 蚀骨剧毒 | 命中后原有 0.15/0.30/0.45s 延迟回调，只在目标仍存在且真正结算毒伤时发出 | 边缘亮点；不规则蚀孔、下落小滴和溶解边；中央留空维持血量可读；每次伤害独立蚀刻而非持续转圈 | 每 tick 0.32s，最后一段约 0.77s 结束；6 孔减至 3 孔，滴落位移降为 30%。死目标无毒伤视觉 |
| `ambush` 破阵先锋 | `projectile_hit` 原满血三倍伤害分支 | 短白闪；向两侧裂开的甲片和前冲矛尖；明暗断口与短碎屑；沿本次箭矢方向破开目标防线 | 0.42s；简化模式保留甲片分裂，减少位移并取消外围碎片；残血命中不触发 |
| `siphon` 饮血长箭 | 真正击碎且 `arrow.take("siphon",8)` 成功、加穿透与伤害后 | 被击碎位置向内汇聚血屑；碎屑曲线收束到箭锋，形成短充能亮边；存源箭位置快照，端点距离限 36px 避免跨屏长线 | 0.56s；6 屑减至 3 屑，减少弯曲和位移。每箭最多 8 次，未击碎不触发 |

所有玩法伤害、箭数量、穿透成长、毒伤时间和原有调度预算保持原规则。原四项通用 signature/毒伤 ring 的调用由对应 V2 事件替代；通用 effect/signature 实现与共享事件 schema 未修改。毒伤原 `markUntil` 状态提示仍按玩法存在，独立于短蚀孔冲击。

## 生命周期与预算

- 复用 `fx.skill_events`，最多 64 个事件，溢出淘汰最旧事件；所有四项在 `fx.visual_time` 上生长并过期。
- 单事件最多六路／六孔／两片甲／六屑；无实体引用、无玩法 RNG 调用、无每帧随机数、无 per-event Node。
- 配色取事件的技能色与 accent，浅色使用深轮廓、深色使用亮轮廓；HP 中央区域尽量留空。
- `reduced` 同时覆盖 reduced motion 与 performance mode，保留箭道数量、破阵方向、毒伤位置和饮血归拢信息。
- `reset()` 使用既有事件清空路径；独立视觉快照可以在目标被击碎后自然消散。

## 验证记录

`godot/tests/native_skill_batch_five_test.gd`：

- Headless：**45 checks，0 failures**。真实第一／第二／第三射、额外箭数量与满容量拒绝、满血／残血破阵与伤害倍率、真实三次 DOT 的时间和伤害、死亡目标不产生幽灵 tick、饮血八次上限及各箭独立性、原穿透及伤害成长、四技能逐项队列上限／淘汰／视觉时钟／过期／reset／RNG 隔离。
- GUI：**61 checks，0 failures**。上述全部，加浅／深 × 完整／简化四组真实组合触发，在密集砖阵同屏绘制全部四项，比较峰值／消散图像、事件清空及渲染不修改伤害或 RNG。
- 命令：`python3 godot/tools/run_checks.py --godot godot --test native_skill_batch_five_test`；图形检查加 `--gui`。
- 组合帧在 `agent-tmp/godot/skill-batch-five/overlap-{light,dark}-{full,reduced}.png`；测试日志 `agent-tmp/godot/checks/native_skill_batch_five_test.log`（最后为 GUI 结果）。
- `git diff --check` 通过。整套 gate 由主代理集成时执行。
- 主代理复查：饮血箭锋在充能接近零时跳过三角面，避免末段零面积几何；修正后 GUI 61 项通过，两套 GIF 重新生成并检查。

## 真实渲染 GIF 交付

四技能注册 `skill_batch_five` 唯一夹具 kind；独立 helper `godot/tools/preview_skill_batch_five.gd` 调用真实 `shoot` / `projectile_hit` / 延迟毒伤回调，并固定视觉时钟采集。夹具隐藏飞行箭、保留实际 Board 与砖阵，专门检查材质冲击，不冒充完整玩法录像。

```bash
python3 godot/tools/preview_effects.py --skills legion poison ambush siphon --out agent-tmp/godot/effect-gifs/skill-batch-five-light.gif
python3 godot/tools/preview_effects.py --skills legion poison ambush siphon --theme dark --reduced --out agent-tmp/godot/effect-gifs/skill-batch-five-dark-reduced.gif
```

- [浅色完整 GIF](../agent-tmp/godot/effect-gifs/skill-batch-five-light.gif)
- [深色简化 GIF](../agent-tmp/godot/effect-gifs/skill-batch-five-dark-reduced.gif)
- Godot 4.7.2 stable + 实际图形驱动，25 fps、原速、各 56 采集帧、2.24s 循环（GIF 合并重复帧，时间保持）。同目录有 `.log` / `.json`。
- 已检查 0.20 / 0.32 / 0.48 / 0.68 / 0.96 / 1.60s 的生成、峰值、三毒伤重叠与收尾：箭锋有前进后缩短、甲片打开后淡出、血屑收拢后充能消散；最后只剩原砖阵／发射器状态，标签及血量可读。两个 GIF 均已通过 `file.open` 打开交付。
