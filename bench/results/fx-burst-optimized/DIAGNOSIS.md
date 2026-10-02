# 剩余卡顿诊断

## 本轮探针

新增的 `bench/fx-diagnose.js` / `bench/fx-diagnose.mjs` 只在测试服务器响应中注入，生产文件不会加载。它记录调用树、self/total 时间、强制布局、Canvas 操作、音频、`localStorage`、长任务和 Chromium Timeline；`--trace=1` 另保存 `trace.json`。

```sh
node bench/fx-run.mjs '--filter=^board-burst/chain:special-50$' \
  --board-count=240 --board-repeats=3 --diagnose=1 --trace=1 \
  --out=agent-tmp/stutter-diagnose
```

探针有明显测量开销，不能拿它的绝对时间当 FPS；只用来确认调用归属。`agent-tmp/stutter-diagnose/` 保留原始 JSON、诊断树和 Chromium trace。

## 已确认的原因

### 1. 游戏逻辑的同步击碎链仍是第一类真实热点

- 240 块 / 50% 特殊砖 / 四技能案中，单次测试出现约 985 次 `Game.hit`（包含递归与技能包装），并创建约 144 支箭；每次特殊砖仍会同步触发奖励、成就、技能回调、Matter 移除和反馈创建。
- 未插桩的主体复跑中，该案改造后事件中位约 34.7ms；同一机器的多次结果仍受调度影响，不能把一次 114ms 当作稳定值。
- 插桩调用树显示 `game.js/hit` 的总时间主要是子调用，不是 `hit` 自身；因此“把 hit 函数改成更短”不会自动解决问题。应继续按 `projectileHit → 特殊递归 → Matter remove/addArrow → 成就/技能回调` 分段优化。

### 2. 旧的重复工作已被准确定位并处理

- 原 CPU profile 的 `G.fmt` 曾是击碎子树第一热点（约 80.9ms 采样自身）；缓存 `Intl.NumberFormat` 后不再进入 after 前列。
- `activeSkills()` 原来在一个击碎链中重复构建短数组；现在按技能对象身份缓存。诊断样本从约 17ms 降到约 4ms 的采样自身成本，且所有 328 项 Node 测试通过。
- 成就 `replay()` 原来每次 `void offsetWidth` 强制布局；现在同一帧按元素/类名合并，生产 burst 中强制布局调用从约 15 次降到约 5 次。动画仍在下一绘制帧重启，颜色、类名和时序身份没有删除。

## 不是生产逻辑的卡顿

- 同步 benchmark 的每帧 `getImageData(0,0,1,1)` 是人为读回，会在现代软件光栅上出现 20–68ms 的单次尖峰；真实游戏没有这条读回。
- 之前出现的 1552.3ms `updateMs` 没有在相应诊断 trace 中找到相同长度的 JavaScript task，且正常复跑三次只到 10ms；主机负载/浏览器调度或读回阻塞是更可能的解释，但没有证据把它归因给某个生产函数。报告仍保留该异常，不剔除。
- 真实 Chromium 89 整板、全特效 1,108 案、现代兼容门禁和 DOM smoke 均无脚本异常；这不能替代 Android X5 真机帧时间。

## 下一步优化优先级

1. **先做空间索引**：为存活砖维护按行/列的轻量网格，让 bomb/frost/area 和 lightning top-k 不再每次扫描完整 `G.bricks`。必须保持旧数组顺序、同距稳定顺序和特殊砖递归顺序，先用现有全毁/收益测试锁定等价性。
2. **拆分 Matter 结构成本**：对 240 案记录 `Composite.remove`、`addArrow`、body 顶点更新和递归层级；若确认 Matter remove 占主要比例，可批量标记后在同步事件末尾统一移除，但仍要让每个 `hit` 在逻辑上立即从可命中集合消失，不能改变递归结果。
3. **继续压低首绘冷点**：当前 idle 预热只覆盖常用技能、75 半径、impact 姿态；真实 burst 仍可能首次遇到 force/hero、aura 或大半径贴图。可在“就绪且无箭”时按当前技能实际半径预热少量关键姿态，必须保持 16 MiB/384 张预算，不能在游戏中同步建整套 atlas。
4. **最后处理音频设备**：在真实解锁音频的设备上单独测 `ensure`、source 创建和调度；如果占比高，只合并相同时间窗的普通 break/tap 声，不合并特殊砖、Boss、核心等决定性反馈。
5. **真机闭环**：在 Android X5 上分别记录击碎事件前后、Canvas 绘制、温升和音频延迟；桌面软件光栅数据只用于排序热点，不能作为 60 FPS 结论。

## 当前结论

已经能安全继续优化，但不建议把 1552ms 单点直接当作某一段业务代码修复。最有把握的下一项是“空间索引 + Matter 移除分段采样”；两者都必须以完整特殊砖、81 技能、四 Boss 和收益一致性为门禁。 
