# 优化后结果索引

- `REPORT.md`：优化前后对照、81 项技能表、视觉取舍和未改善场景。
- `comparison.csv`：正常 / 性能模式的全部逐案例对照。
- `fx-dpr2-normal.json`、`fx-dpr2-reduced.json`：最后一次完整扫描。
- `animation/`：动态姿态、四技能混合与冷缓存复核，以及实际 Canvas 截图。
- `raf/`：无同步像素读回的浏览器绘制调度复核。
- `dom/`：飞金币、成就火花、收益飞片的实际节点数与动画成本。
- `visual/`：技能、热箭、火轮以及眼 / 熔炉 / 时钟场景的实际 Canvas 截图。
- `validation.txt`：Node 回归测试输出。
- `first/`：第一批实现的探索性局部压测，**不是最终实现**，不用于最终收益结论。

巨蟒最终战斗态截图在 `animation/boss-scene-serpent-live-body-1.png`；
`visual/boss-scene-serpent-live-body-1.png` 是较早的视觉检查快照，姿态不同，
不能把这两张图当成严格视觉 / 性能 A/B。

PNG 是透明的游戏 Canvas，不包括 CSS 背景、HUD 与 DOM 动画；图片查看器的
黑底不等于游戏浅色主题的实际背景。截图输入是压力构筑，不是自然战斗的统计平均。
原始、优化前的审计保持在 `../fx-audit/`。
