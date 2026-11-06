# 第七批：三叉齐射、流星雨、追猎蜂群、疾风快弦

2026-10-30。四项金色技能，Godot **4.7.2 stable** 原生实现。专用 renderer：`godot/src/render/skill_batch_seven.gd`。使用短生命周期 CanvasItem 程序化几何与已有 `skill_events` 快照队列；没有新增贴图、逐箭节点或逐帧上传。

## 真实入口、四层与时序

| 技能 | 真实触发 | A 冲击核心 | B 主体形状 | C 材质细节 | D 场景响应 | 时长 / reduced |
| --- | --- | --- | --- | --- | --- | --- |
| `trident` 三叉齐射 | `mechanics.gd::trident_fan()` 包装原 `fan(angle,speed,5)`，首发与 echo 的 0.24s 回声均调用；只为成功创建的额外箭生成事件 | 发射喉部短白闪 | 沿每支真实额外箭的方向推出收尖金属刃，形成扇面 | 深/浅双色刃缘、内芯、两侧开放压力切片 | 发射切片向外打开并缩短；方向与真实扇角一致 | 单事件 0.46s；扇面全部保留，尾段漂移和侧向压力位移降至 30% |
| `meteor` 流星雨 | 原 shuffle 选最多 6 砖；`later(index*0.04)` 中成功 `launch()` 后入场；带 `meteorFx` 的箭在 `projectile_hit()` 中撞击 | 入场白热尖端；命中横向短白闪 | 沿实际速度方向形成熔融尖体；撞击后局部侧向溅开 | 双层热壳、亮芯、短余烬；撞击碎块的双色边缘 | 撞击位置取真实砖中心，碎屑沿入射反方向溅射并轻微下坠 | 入场 0.58s、撞击 0.48s；余烬 5→2、溅射 7→3，额外位移/下坠降至 30% |
| `hunters` 追猎蜂群 | 原左右 ±36 起点、±0.25rad 的四次 homing `launch()`；成功箭标记 `hunterFx`；仅这些箭的真实 `projectile_hit()` 发出刺击 | 出巢点短闪；接触点横向闪切 | 两对错位展开翼片与中轴针体；接触时收紧成蜂刺与开放双括片 | 翼膜分面、双亮边与细翼脉；事件 seed 只控制轻微横向错位 | 实际箭仍通过原 `guide()` 追踪，刺击方向取碰撞时速度；括片短距离回弹 | 发射 0.50s、刺击 0.38s；两对翼减为一对，外移降至 30%，保持两个接触括片 |
| `rapid` 疾风快弦 | 成功 `shoot()` 后的原 `on_shoot()` 冷却分支；提前或被拒发射不会发事件 | 弹弓释放点白闪 | 13 点弓身曲线与三点弓弦在 0.18s 内回弹完成 | 双层弓缘、亮弦、开放风切尾 | 弓弦直接覆在真实弹弓原点，风切向发射方向散开；前景绘制避免被底盘遮挡 | 总 0.36s；风切 4→2，无循环振动，保留冷却回弹时序与轮廓 |

所有事件峰值集中在 0–0.10s，采用指数快起与 smoothstep 尾段淡出。没有新增闭合圆环、跨板长射线或持续假轨道。技能主色和 accent 来自已有内容配置，浅色用深边，深色用亮边。动态动画仅读取 `fx.visual_time`，不随墙钟或 renderer 改变玩法。

### 绘制层级

- 三叉、流星、蜂群由 Board 的 `_draw_skill_events()` 分派到专用 renderer。
- 疾风必须在 `_draw_foreground()` 的 `_sling()` **之后**通过 `draw_on` 绘制；背景分派明确跳过 rapid，避免重复绘制。
- GUI 检查发现并修复了最初版本弓弦被弹弓不透明底盘遮住的问题；现有测试包含真实 Board 的局部像素差回归，而非只检查 renderer 独立画布。

## 玩法、RNG 与高频路径

- 三叉仍是 **主箭 + 5 额外箭**，原扇角依次 `+0.1/-0.1/+0.2/-0.2/+0.3`。没有因技能名称将数值改成三箭；64 箭上限部分接受时，只为实际接受的额外箭显示发射刃。
- 流星仍按原 shuffle 顺序选择最多 6 砖，起点 `y=142`，每 0.04s 发射；速度 `Vector2(rng.randf_range(-9,9),18)`、伤害 `2 × damage()`、2 穿透、原颜色均保持。视觉事件在成功 launch 后才生成，未新增 RNG 调用或伤害范围。
- 蜂群仍有四支追踪箭，两侧各两支，伤害、穿透、初始速度和 homing 判定保持。普通主箭不能冒充蜂群刺击。仅新增不参与物理的 `hunterFx` / `meteorFx` 归属标志。
- 疾风仍是 `min(next_shot_at, time + 0.18)`，没有改变可发射时点。
- renderer 不持有砖块或箭矢对象，不消费玩法 RNG；事件 seed 来自已有序号。
- 沿用已有普通箭、碎片、拖尾的高频 GPU 合批和预热结构，未修改 `skill_batch.gd`、合批 shader 或启动预热路径。

## 预算、生命周期与 reset

- 复用 `skill_events` 的 **64 项**共享有界队列，溢出淘汰最旧视觉事件；无新增队列和逐事件节点。
- 单个三叉事件：1 刃体、1 边缘折线、1 亮芯、2 压力切线、1 短闪。标准首发最多 5 个事件；回声仅在原任务实际执行时再生成。
- 单个流星入场：2 壳面、1 边缘折线、1 芯线、1 热点和最多 5 余烬；撞击：1 接触面、1 短闪和最多 7 双色短碎片。每支真实流星只在实际撞击时生成冲击。
- 单个蜂群入场：最多 4 翼片及翼缘/翼脉、2 中轴线和短闪；刺击：2 中轴线、2 开放括片及短闪。
- 单个疾风事件：13 点弓身的双色折线、三点弓弦、1 短闪和最多 4 风切折线。没有常驻循环。
- 最长单事件 0.58s；射箭碰撞的原有碎片可以继续自然消散，采集注册的 `tail=1.7` 覆盖真实夹具整段动作。
- 生命周期由 `fx.advance_visual()` 回收，`fx.reset()` 清空快照和视觉时钟；玩法时钟的 `fx.update()` 不提前清掉事件。

## 真实预览夹具

`godot/tools/preview_skill_batch_seven.gd` 的 `setup()` 为密集砖阵设置镜头与发射原点；`step()` 调用生产 `g.shoot(0,100)`，再以固定 **60Hz** 调用 `g.tick()`。完整经过原有延迟任务、homing、重力积分、sweep 碰撞、伤害和箭矢回收；没有把落点编造成通用 `skill_event` 模板，也没有手动替代碰撞。

`effect_previews.json` 注册四项 `skill_batch_seven` 类型。共用采集器只增加本批分派、初始化和可选 `crop`，使用真实 Board / CanvasItem / GPU 帧；展示依然以 25fps 采样固定步长玩法。

## 定向测试：实际结果

```bash
python3 godot/tools/run_checks.py --godot godot --test native_skill_batch_seven_test
python3 godot/tools/run_checks.py --godot godot --gui --test native_skill_batch_seven_test
python3 godot/tools/preview_effects.py --skills trident meteor hunters rapid --out agent-tmp/godot/effect-gifs/batch-seven-light.gif
python3 godot/tools/preview_effects.py --skills trident meteor hunters rapid --theme dark --reduced --out agent-tmp/godot/effect-gifs/batch-seven-dark-reduced.gif
git diff --check
```

- **Headless：105 checks，0 failures**。真实发射、额外箭角度/参数、echo 组合、部分/完全上限、拒发负例、0.18s 冷却边界、原 homing、真实接触归属、流星 0.04s 任务序列、原 shuffle 与六次随机速度的精确 RNG 状态、空板、队列上限/淘汰、视觉时钟和 reset 全部通过。
- 每技能完整/ reduced 双模拟比较 **60 个逐帧 60Hz 轨迹样本**，箭矢位置/速度、最终砖血量和玩法 RNG 完全一致。
- **GUI：155 checks，0 failures**。包含以上原生检查，加浅/深 × 完整/reduced、流星/蜂群双阶段的真实 GPU 峰值像素和寿命后透明检查，以及真实 Board 的 rapid 弹弓前景可见性检查。Linux Xvfb，Mesa llvmpipe OpenGL Compatibility 实际绘制。
- 两套 GIF 各 **56 原始捕获帧、25fps、1×、2.24s 循环**；编码合并静止重复帧后各 30 帧。原始 GIF、峰值图与 0.08 / 0.20 / 0.52 / 1.80s 检查联系表均已打开检查。
- 峰值：三叉方向扇面、流星错时入场及实砖撞击、双侧蜂群和弹弓弦身均可辨。收尾：1.80s 无本批特效残留，原始伤害造成的砖血量/缺口保留；密集砖块数字在峰后可读。
- 最终 `git diff --check` 通过。本批使用小范围共享文件补丁；全量门禁、总清单与测试列表由主代理集成。

日志：

- `agent-tmp/godot/checks/native_skill_batch_seven_headless.log`
- `agent-tmp/godot/checks/native_skill_batch_seven_gui.log`
- GIF 同名 `.log` / `.json`（真实引擎版本、捕获参数与注册内容）。

## 动图交付

- [浅色完整 · 四技能 GIF](../agent-tmp/godot/effect-gifs/batch-seven-light.gif)
- [深色 reduced · 四技能 GIF](../agent-tmp/godot/effect-gifs/batch-seven-dark-reduced.gif)

绝对路径：

- `/home/apricityx/workspaces/slingbreak/agent-tmp/godot/effect-gifs/batch-seven-light.gif`
- `/home/apricityx/workspaces/slingbreak/agent-tmp/godot/effect-gifs/batch-seven-dark-reduced.gif`

检查联系表为同目录 `batch-seven-light-inspection.png` / `batch-seven-dark-reduced-inspection.png`。动图及检查产物保留在忽略目录，不加入 Git。
