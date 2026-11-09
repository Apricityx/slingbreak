# 第八批 · 金色技能 V2 特效

范围：`nova` 碎星新生、`crossfire` 十字审判、`jackpot` 幸运暴富、`supernova` 超新星爆发。Godot 4.7.2 stable，真实玩法入口与生产 Board / GPU renderer。

2026-11-08 更新：以下为首批设计记录；超新星的旧火团已统一换为 `bomb_batch.gd` 新版爆炸，保留 180px 局部核心、0.18s 延迟、全局伤害及星芒，爆炸尾段由 1.4s 改为 1.1s。与爆炸砖和其他技能共用 16 事件预算，见[统一升级记录](skill-effects-upgrade-checklist.md#技能共用爆炸统一新版2026-11-08)。

## 四层设计与真实触发

| 技能 | A 冲击核心 | B 主体形状 | C 材质细节 | D 场景响应／真实入口 | 时长 |
| --- | --- | --- | --- | --- | --- |
| 碎星新生 | 击碎点短白热星核 | 三枚分离的尖星向上扇形新生，方向严格匹配 -0.8 / 0 / +0.8 弧度的新箭 | 深色切边、明亮中脊、短途菱形碎片 | `Mechanics.destroyed()` 延迟 0.08s 后，只有 `launch()` 实际成功才发事件；满 64 箭无假闪，部分成功只画成功数量；每轮仍限 8 次 | 0.62s，主峰约 0.06–0.15s |
| 十字审判 | 行列交点短闪 | 四向锥形刀光快速切开十字 | 刀脊白芯、主题色刃面、硬边和断片 | `projectile_hit()` 每箭一次 → 延迟 0.08s → `line_damage()`；受击行列砖块的外围短烙印逐目标对应，中心保留 HP | 0.48s，主体快速衰减 |
| 幸运暴富 | 奖励点白金闪击 | 可辨识的 ¥ 金币徽章；10×大币和金币喷发，1.5×小币和 3 枚碎币 | 明暗币缘、内圈、真正的程序化 ¥ 笔画、金币翻面与短弹道 | `Simulation.reward(..., point)` 使用原来的同一次 25% 掷骰；`_award()` 的无来源／箭归属奖励及 `BossDirector.pay()` 均传真实位置；无支付点的数值计算不发事件 | 0.72s，峰值约 0.08–0.2s |
| 超新星爆发 | 白热火团与热核闪燃 | 原有 GPU 火团配八瓣断裂星芒冠，不用停住的大圆环 | 现有程序化火焰材质、亮脊与冷暗碎片 | 第四次真实 `shoot()` → 延迟 0.18s → `global_damage()`；全局受击目标边缘短热印，与中心爆发分离；保持全屏 5×伤害 | 星芒 0.96s，火团 1.4s |

超新星中心火团的视觉半径为 180 世界单位，伤害仍然遍历全体砖块；外围响应准确标记受击砖块。不会用不透明全屏火焰盖住棋盘。十字刀光局限在交点附近，远处行列目标靠真实目标快照确认，不画持续贯穿棋盘的长 beam。

## 时间、状态与兼容性

- 一次性事件统一使用 `fx.visual_time`，保存位置、受击目标位置／新箭方向和暴富结果快照。删除砖块后仍可完成收尾；事件不持有砖块和箭对象。
- 新增 `Effects.skill_batch_eight()` 复用 64 项技能事件队列，溢出淘汰最旧事件；每项最多 48 个位置，复制后与调用方数组独立。
- `nova`、`crossfire`、`supernova` 不再走对应旧 signature / beam / 大环路径。其他技能 GPU 合批及特殊砖预热保持接入。
- 不修改伤害值、碰撞体、行列判定宽度、生成数量、延迟、原始箭源和 RNG 次序。Jackpot 仅把原掷骰结果保存到视觉事件；不追加 RNG 掷骰。

## GPU 与 reduced 预算

- `skill_batch_eight.gd` + `skill_batch_eight.gdshader`：四个按技能预编译专化的 MultiMesh，每族一次合批、128 个固定实例，主轮廓优先，剩余槽位显示目标边缘响应。构造时缓存完整／reduced 不可变网格，不在每帧重建顶点或上传纹理。
- 单个完整实例最多 23 个四边形（超新星 1 核 + 8 星芒 + 10 碎片 + 4 目标边缘）；reduced 减少为 17 个。每族至多 128 × 46 个三角形，shader 将非当前角色的几何折叠为零面积。
- reduced 将碎片由 10 减至 4，金币普通结果保留 3 枚；关闭金币翻转，碎片旋转和弹道位移缩至 30%。保留新生真实箭数、四向十字、¥ 主币／中奖差别和快照中的受击目标边缘。场景震动由既有 Board reduced 开关禁止。
- `effect_warmup.gd` 在独立 viewport 中触发四族的 full/reduced 网格，真实绘制预热；不向用户运行时注入事件。
- 没有额外节点/粒子分配；复用超新星火团的原有 16 实例上限与合批火星。

## 测试与动图

独立回归：`godot/tests/native_skill_batch_eight_test.gd`。

覆盖真实击碎、首次命中、第四次发射、两种暴富掷骰、Boss 支付、回合限制、箭容量零／部分成功、延迟来源归属、精确行列伤害、视觉快照独立性、64 事件／48 目标／128 GPU 实例上限、独立视觉时间、过期和 reset。

GUI 对浅／深 × full/reduced × 四技能逐个渲染；比较隐藏本技能 GPU batch 前后的真实像素，避免其他碎片造成误判，并验证消散尾段和渲染不修改伤害/RNG。

```sh
godot --headless --path godot --script res://tests/native_skill_batch_eight_test.gd
xvfb-run -a godot --path godot --audio-driver Dummy --script res://tests/native_skill_batch_eight_test.gd
python3 godot/tools/preview_effects.py --skills nova crossfire jackpot supernova
python3 godot/tools/preview_effects.py --skills nova crossfire jackpot supernova --theme dark --reduced
git diff --check
```

预览类型 `skill_batch_eight` 由 `preview_skill_batch_eight.gd` 调用真实技能入口并推进延迟任务。Jackpot 预览先演示真实中奖 10×，0.88s 后演示 1.5×；测试专用种子通过独立 probe 搜索，不改变生产 RNG。捕获期间不留下静止的假箭；碎星轮廓保留实际生成方向。

### 实测结果（2026-10-30）

| 检查 | 结果 |
| --- | --- |
| 第八批原生测试 | **56 checks, 0 failures** |
| 第八批 Xvfb / llvmpipe 真图形测试 | **152 checks, 0 failures**；含 16 组单技能像素验证、4 组四技能真实连锁 |
| `native_effect_startup_test.gd` 真图形预热检查 | **7 checks, 0 failures** |
| `node godot/tools/capture-rules.cjs` + `native_reference_test.gd` | **12661 checks, 0 failures**；85 种技能构建、1800 个 Matter 数值采样 |
| `git diff --check` | 通过 |

首次 reference 检查缺少本地 `reference-rules.json`；用现有工具生成到 ignored `agent-tmp/` 后重跑通过。首次共享 Board 编译曾被另一批未完成的类型声明阻断；该代理修复后，本批原生／图形／GIF 全部重跑，无 SCRIPT ERROR / ERROR。

### 已交付的真实渲染 GIF

- [浅色完整 · 四技能](../agent-tmp/godot/effect-gifs/nova-crossfire-jackpot-supernova-light.gif)
- [深色 reduced · 四技能](../agent-tmp/godot/effect-gifs/nova-crossfire-jackpot-supernova-dark-reduced.gif)

两份均为 25fps、原速、2.24 秒（56 个捕获帧，GIF 会合并相同静止帧），包括触发前停顿及完整尾段。已用 `file.open` 打开最终 GIF，并抽取 **0.32 / 0.48 / 1.24 / 2.12 秒**检查：前三向尖星可读；十字目标响应准确匹配 HP 变化；10×金币明显大于后续 1.5×；超新星中期火焰覆盖局部而非全屏，烟尾消散后全部目标数字清楚；最终 2.12 秒均无残留技能几何。

复查图保存在同目录 `*-review.png`；密集四技能重叠的真实图形截图保存在 `agent-tmp/godot/skill-batch-eight/overlap-{light,dark}-{full,reduced}.png`。这些产物均在 ignored 目录。

## 集成文件

- 新增：`godot/src/render/skill_batch_eight.gd`、`godot/src/render/skill_batch_eight.gdshader`、`godot/tests/native_skill_batch_eight_test.gd`、`godot/tools/preview_skill_batch_eight.gd`、本文档。
- 窄修改：`godot/src/effects/effects.gd`、`godot/src/skills/mechanics.gd`、`godot/src/core/simulation.gd`、`godot/src/bosses/director.gd`、`godot/src/render/board.gd`、`godot/src/render/effect_warmup.gd`、`godot/tools/effect_previews.json`、`godot/tools/preview_effects.gd`。
- 总清单与 `run_checks.py` 由主代理登记；本批不改动它们。
