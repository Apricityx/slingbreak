# 第六批：追击、赏金、破壳与燃线

2026-10-29。四项均为 white 技能；Godot 4.7.2 stable 原生实现。独立动态几何 renderer 为 `godot/src/render/skill_batch_six.gd`，由 Board 专用分派调用。全部使用 CanvasItem 程序化几何，无贴图、静态图标、CPU 纹理上传或逐事件节点。

## 设计与真实触发

| 技能 | 真实触发入口 | 核心 / 主体 / 材质 / 场景关系 | 时间与 reduced |
| --- | --- | --- | --- |
| `opportunist` 穷追猛打 | `mechanics.gd::projectile_hit()`，`hp < max_hp` 的三倍伤害分支 | 极短切点闪光；错时追击楔片从箭矢来向压入既有伤口；双色硬边；命中后侧向分离，保留砖块数字 | 0.42s；3 楔片减至 2，侧移为 30% |
| `bounty` 连杀赏金 | `simulation.gd::_award()`，归属箭矢第 2 次及以后击杀；包括归属该箭的延迟/连锁 | 底部金白闪击；错时铸出的上扬金属条片；深浅轮廓和亮芯；从真实奖励砖位置上扬，强度随原赏金档位增长、封顶 | 0.62s；5 片减至 3，上升为 30% |
| `nailburst` 破壳礼炮 | `mechanics.gd::projectile_hit()`，主箭首次命中、原 `arrow.take()` 限额 | 白热破壳点；三条与真实子箭一致的 ±0.38/0 弧度箭道；分面外弹壳片；短距离下坠、旋转、自然消散 | 0.56s；三箭道始终保留，壳片 6→2，旋转/位移为 30% |
| `fusepath` 燃线速递 | `projectile_hit()` 记录相邻不同砖点；`segment_damage()` 实际延迟伤害时第二次事件 | 预热暗线与沿线火头；0.25s 后换成开放的熔断分节；亮芯、余烬与末端闪点；严格保存每段实际起终点 | 预热 0.25s，伤害烧断 0.44s；熔断节 8→4，取消旁侧火星、侧移为 30% |

全部事件使用 `fx.visual_time`，从已有 `skill_event()` 保存位置、方向、目标、强度及 seed 快照。`fusepath` 复用已有 strength 字段区分预热（0.55）和烧断（1.2），没有新增公共 schema 字段。主题技能色与 accent 来自已有内容配置，浅色用深轮廓、深色用亮轮廓。

## 玩法保持

- 穷追猛打仅残血时乘三；满血没有追击事件。
- 连杀赏金保持每击杀原奖励公式、achievement tally 和三倍上限；新箭独立从首杀开始。
- 破壳礼炮仍生成三支 `0.9 × g.damage()`、2 穿透子箭，保持起始砖 hit/overlap 免疫；重复命中和子箭不再触发礼炮。用专用破壳几何替换原通用火球。
- 燃线仍最多四个不同砖点、三段延迟任务，仍在 0.25s 按原 sweep 宽度 12 和 `1.5 × g.damage()` 伤害；重复砖不增段。只替换其专属通用 beam/signature。
- renderer 不持有实体、不修改 hp、物理边界或玩法时间，不消费玩法 RNG。

## 预算与生命周期

- 共用现有 `skill_events` 64 项有界队列，溢出淘汰最旧视觉事件；没有额外队列、节点或纹理。
- 单事件上限：追击 3 楔片；赏金 5 金片；礼炮 3 箭道 + 6 壳片；燃线 8 分节 + 8 短火星。
- 事件最长 0.62s；燃线两阶段合计 0.69s。真实 delayed job 由玩法时钟触发，触发后的绘制/回收归属视觉时钟。
- 所有几何快起、峰值前置、按 alpha/长度渐退，无固定半径圆环或永久 beam。沿线范围只取真实伤害端点。

## 定向验证

运行：

```bash
python3 godot/tools/run_checks.py --godot godot --test native_skill_batch_six_test
python3 godot/tools/preview_effects.py --skills opportunist bounty nailburst fusepath --out agent-tmp/godot/effect-gifs/batch-six-light.gif
python3 godot/tools/preview_effects.py --skills opportunist bounty nailburst fusepath --theme dark --reduced --out agent-tmp/godot/effect-gifs/batch-six-dark-reduced.gif
git diff --check
```

- `native_skill_batch_six_test.gd`：**74 checks，0 failures**。真实技能触发、满血/重复触发负例、奖励与子箭参数、起始砖免疫、延迟前后伤害、四点三段限额、64 队列淘汰、玩法 RNG 隔离、视觉时钟过期和 reset 均通过。
- 实际 GUI 捕获：两套各 56 原始帧、25fps、原速、2.24 秒循环；GIF 编码合并重复静止帧，编码帧数分别 28 和 31。
- 独立 `preview_skill_batch_six.gd` 夹具调用生产 `projectile_hit()` / `hit()`，燃线按捕获时钟推进真实 delayed jobs；未把持续/延迟效果伪装成通用单事件模板。展示夹具移除未模拟的箭矢，真实子箭生成另由原生测试验证。
- 已检查浅色完整、深色 reduced 的 -0.2/0.08/0.16/0.28/0.44/0.68/1.20/2.00s：密集砖块中轮廓可辨，燃线伤害峰值与预热分离，尾段无特效残留，数字可读。真实伤害造成的砖块缺口/血量降低在展示尾段保留。
- 日志：`agent-tmp/godot/checks/native_skill_batch_six_test.log`，以及 GIF 同名 `.log` / `.json`。
- 本批未运行全套门禁，由主代理统一执行。

## 动图交付

- [浅色完整 · 四技能 GIF](../agent-tmp/godot/effect-gifs/batch-six-light.gif)
- [深色 reduced · 四技能 GIF](../agent-tmp/godot/effect-gifs/batch-six-dark-reduced.gif)

以上均为忽略目录中的真实渲染产物，不加入 Git。检查联系表为同目录 `batch-six-light-inspection.png` 和 `batch-six-dark-reduced-inspection.png`，仅用于峰值/收尾检查，不替代 GIF。
