# 当前工作区粒子与特效性能压力测试

测试时间：2026-10-01T04:10:05.992Z。版本：`a192a479b90fee4c00695c10d2408f9d4900a88a` **加当前未提交修改**。没有修改游戏逻辑或清除用户存档。

## 结论先读

- **普通碎屑不是当前主要瓶颈**：游戏上限 300 个，总绘制成本 1.90ms，空棋盘 1.50ms，增量约 0.40ms。
- **复杂图案 + shadowBlur 是最明确的热点**：暴风雪 hero ×12 为 30.80ms；×23 为 56.80ms；×24 因关闭模糊反降为 18.90ms。无读回 rAF 复核亦保留这一门槛效应。
- **箭雨压力上界需要降级**：暴风雪拖尾 ×64 为 20.00ms；连击热拖尾 ×64 为 30.10ms；火轮 ×12 为 12.20ms。
- **无上限扩散环比普通碎屑危险得多**：环 ×100 为 12.00ms，×300 为 33.50ms；300 电弧为 15.10ms。极端档位不代表日常自然同屏数。
- **Boss 重点是巨蟒的大面积渐变/背景、传送门和日蚀光源**。碎片、尘点、线状星芒相对轻；不能因为合成 300 枚熔炉陨火很慢，就认定正常只发 3–4 枚的场景有严重问题。
- **性能模式有效，但不是彻底解决**：实际会同时把 Canvas DPR 上限降到 1、关闭部分模糊/动画；拖尾和多数图案数量不变，仍应做按绘制预算降级。

## 方法与适用范围

- CPU：Intel(R) Xeon(R) CPU E5-2682 v4 @ 2.50GHz；Chromium：Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/153.0.0.0 Safari/537.36。
- 视口 412 × 915；DPR=2；游戏 Canvas 824 × 1144。禁用 GPU，使用软件光栅。
- 扫描全部 81 个技能视觉配置，与 81 个技能目录逐项对应，缺失 0 个。普通命中特效 1/12/56，强制主特效 1/12/23/24/56，拖尾 1/12/64。
- 正常模式 1084 个案例；性能模式 1084 个案例。
- 加载完整 index.html、真实绘制代码和真实 HUD。仅在测试服务器响应中插入私有数组访问钩子；源文件不改写。
- 性能模式主表对照的是 Canvas DPR 上限与 JS 绘制降级；不是整套 DOM 动画节省量的 A/B。DOM 粒子另在正常模式复核。
- 冻结时间与模拟，保持可见年龄分布，每案例预热 3 帧，计时窗口至少 120ms、至少 12 次。记录提交耗时与“绘制 + 同步 1px 读回”耗时。读回确保 Canvas 光栅工作完成，避免只测到命令入队。
- **表格是同步光栅压力成本，不是游戏实测 FPS**。读回本身有成本；绝对值不能外推手机 GPU/WebView。16.67ms/33.33ms 只作为 60/30Hz 绘制预算参照，不保证帧率。物理、连锁逻辑和音频开销不计入这些表。
- Boss 单粒子表使用相同 Canvas 尺寸，调用真实私有绘制器，独立于整个游戏场景；不能直接和“完整画面”表相减。Boss 场景另用生产棋盘生成与实际技能启动器测试。
- 超过硬上限的档位仅用于定位增长趋势。无硬上限不表示实际能达到 300/1000 个；触发频率和生命期仍限制实际数量。
- hero 压力样本为每个图案强制打开发光，用于定位最坏代价；并非每个技能正常命中都会进入 hero。单技能普通特效受 85ms 冷却/生命期限制，通常远低于 56 个。64 火轮也是假设性同屏上界：自然流程只给主箭装备火轮。
- 熔炉陨火每次实际发射 3–4 枚，70/300 枚仅为合成压力；开场始终是 60 碎片，4/16 份场景也是合成压力。完整限制说明见 `bench/FX-README.md`。
- 完整画面基线 1.50ms；独立空画布基线 0.20ms。

## 最重的技能特效（容量范围内的压力上界，前 20）

| 类型 / 特效 | 同屏数 | 中位 ms | p95 ms | 性能模式 ms |
|---|---:|---:|---:|---:|
| hero / 绝对零度 (blizzard) | 23 | 56.80 | 58.30 | 14.70 |
| hero / 冰河冲击 (snowburst) | 23 | 51.50 | 61.50 | 10.80 |
| impact / 绝对零度 (blizzard) | 56 | 42.50 | 46.00 | 48.80 |
| hero / 绝对零度 (blizzard) | 56 | 42.50 | 48.00 | 34.30 |
| hero / 超新星爆发 (supernova) | 23 | 39.70 | 44.00 | 8.00 |
| hero / 吞星熔炉 (starforge) | 23 | 39.30 | 41.90 | 8.10 |
| hero / 末日脉冲 (pulse) | 23 | 38.50 | 44.50 | 6.80 |
| hero / 冰河冲击 (snowburst) | 56 | 37.50 | 47.90 | 26.40 |
| hero / 行刑锯盘 (buzzsaw) | 23 | 36.80 | 39.30 | 6.40 |
| impact / 幽界漫游 (spectral) | 56 | 35.60 | 42.40 | 20.50 |
| hero / 天幕裁决 (stormfront) | 23 | 34.50 | 55.90 | 2.90 |
| impact / 冰河冲击 (snowburst) | 56 | 34.00 | 42.60 | 27.40 |
| hero / 黄金时代 (mint) | 23 | 33.90 | 34.40 | 5.80 |
| hero / 幽界漫游 (spectral) | 23 | 33.00 | 35.10 | 8.80 |
| hero / 寄生花园 (infection) | 23 | 32.00 | 32.60 | 6.50 |
| hero / 幽界漫游 (spectral) | 56 | 30.90 | 32.80 | 20.20 |
| hero / 绝对零度 (blizzard) | 12 | 30.80 | 31.90 | 8.00 |
| hero / 冰火连爆 (frostfire) | 23 | 30.50 | 48.60 | 4.50 |
| impact / 吞星熔炉 (starforge) | 56 | 29.40 | 31.00 | 18.80 |
| hero / 蜂群女王 (swarmqueen) | 23 | 29.30 | 37.30 | 7.00 |

## 12 个同时触发的发光压力：最重的主特效

| 类型 / 特效 | 同屏数 | 中位 ms | p95 ms | 性能模式 ms |
|---|---:|---:|---:|---:|
| hero / 绝对零度 (blizzard) | 12 | 30.80 | 31.90 | 8.00 |
| hero / 冰河冲击 (snowburst) | 12 | 26.60 | 27.30 | 6.30 |
| hero / 吞星熔炉 (starforge) | 12 | 21.60 | 23.80 | 4.50 |
| hero / 末日脉冲 (pulse) | 12 | 21.30 | 22.00 | 3.90 |
| hero / 超新星爆发 (supernova) | 12 | 21.00 | 21.50 | 4.50 |
| hero / 行刑锯盘 (buzzsaw) | 12 | 20.00 | 20.50 | 3.70 |
| hero / 幽界漫游 (spectral) | 12 | 18.60 | 19.00 | 5.10 |
| hero / 黄金时代 (mint) | 12 | 18.50 | 21.10 | 3.50 |
| hero / 寄生花园 (infection) | 12 | 17.40 | 17.80 | 3.70 |
| hero / 蜂群女王 (swarmqueen) | 12 | 16.50 | 22.80 | 4.10 |
| hero / 天幕裁决 (stormfront) | 12 | 15.30 | 31.30 | 1.80 |
| hero / 潮汐回卷 (undertow) | 12 | 15.30 | 15.70 | 2.50 |
| hero / 脉冲雷区 (minefield) | 12 | 14.70 | 15.20 | 2.90 |
| hero / 冰火连爆 (frostfire) | 12 | 14.20 | 15.10 | 2.70 |
| hero / 日轮护航 (firewheel) | 12 | 14.10 | 14.70 | 2.50 |

## 64 支箭的拖尾压力：前 15

| 类型 / 特效 | 同屏数 | 中位 ms | p95 ms | 性能模式 ms |
|---|---:|---:|---:|---:|
| trail / 蜂群女王 (swarmqueen) | 64 | 21.80 | 39.70 | 11.90 |
| trail / 绝对零度 (blizzard) | 64 | 20.00 | 25.10 | 15.50 |
| trail / 镜像夹击 (mirror) | 64 | 16.90 | 17.20 | 9.50 |
| trail / 冰河冲击 (snowburst) | 64 | 16.80 | 19.80 | 11.00 |
| trail / 折跃猎手 (wormhole) | 64 | 16.40 | 18.20 | 9.10 |
| trail / 回响齐射 (echo) | 64 | 16.00 | 16.30 | 8.70 |
| trail / 伤痕重映 (chronicle) | 64 | 16.00 | 17.00 | 8.50 |
| trail / 连锁电容 (lightning) | 64 | 15.70 | 20.00 | 7.60 |
| trail / 歼星轨道炮 (railgun) | 64 | 15.40 | 30.00 | 8.70 |
| trail / 行刑锯盘 (buzzsaw) | 64 | 15.10 | 21.80 | 8.10 |
| trail / 越战越勇 (growing) | 64 | 14.60 | 51.10 | 9.00 |
| trail / 天际贯穿 (lance) | 64 | 14.60 | 18.10 | 9.00 |
| trail / 破壳礼炮 (nailburst) | 64 | 14.50 | 15.70 | 7.90 |
| trail / 轨道轰炸 (orbital) | 64 | 14.40 | 16.00 | 9.00 |
| trail / 万箭归宗 (legion) | 64 | 14.10 | 15.10 | 8.70 |

## 通用粒子与相邻发光效果

| 类型 / 特效 | 同屏数 | 中位 ms | p95 ms | 性能模式 ms |
|---|---:|---:|---:|---:|
| core / plain-trail | 1 | 1.40 | 1.50 | 0.60 |
| core / overdrive-glow | 1 | 1.70 | 1.90 | 0.70 |
| core / 日轮护航 (firewheel) | 1 | 2.50 | 2.60 | 1.30 |
| core / plain-trail | 12 | 2.30 | 2.60 | 1.40 |
| core / overdrive-glow | 12 | 6.60 | 7.00 | 1.90 |
| core / 日轮护航 (firewheel) | 12 | 12.20 | 12.50 | 6.90 |
| core / plain-trail | 64 | 6.40 | 6.70 | 4.80 |
| core / overdrive-glow | 64 | 30.10 | 30.50 | 7.30 |
| core / 日轮护航 (firewheel) | 64 | 50.10 | 70.80 | 28.00 |
| core / square-particles | 0 | 1.30 | 1.50 | 0.50 |
| core / square-particles | 100 | 1.60 | 1.80 | 0.80 |
| core / square-particles | 300 | 1.90 | 2.00 | 1.00 |
| core / square-particles | 1000 | 3.00 | 3.30 | 1.90 |
| core / square-particles | 3000 | 6.00 | 8.00 | 4.30 |
| core / square-particles | 8000 | 13.80 | 14.20 | 10.60 |
| core / rings | 1 | 1.40 | 1.50 | 0.60 |
| core / bolts | 1 | 1.40 | 1.50 | 0.60 |
| core / floating-text | 1 | 1.30 | 1.40 | 0.60 |
| core / rings | 30 | 4.40 | 4.50 | 2.30 |
| core / bolts | 30 | 2.60 | 2.80 | 1.40 |
| core / floating-text | 30 | 1.50 | 1.60 | 0.70 |
| core / rings | 100 | 12.00 | 12.70 | 6.30 |
| core / bolts | 100 | 5.70 | 6.00 | 3.20 |
| core / floating-text | 100 | 1.90 | 2.00 | 1.00 |
| core / rings | 300 | 33.50 | 47.40 | 17.80 |
| core / bolts | 300 | 15.10 | 15.60 | 8.40 |
| core / floating-text | 300 | 3.00 | 3.10 | 1.70 |
| core / rings | 1000 | 108.20 | 116.10 | 58.80 |
| core / bolts | 1000 | 46.80 | 53.30 | 27.40 |
| core / floating-text | 1000 | 6.30 | 6.50 | 4.70 |
| core / income-tallies | 1 | 1.40 | 1.50 | 0.60 |
| core / income-tallies | 8 | 1.60 | 1.70 | 0.80 |
| adjacent / aim-glow | 1 | 2.60 | 2.70 | 1.50 |
| adjacent / core-cached-glow | 1 | 1.60 | 1.80 | 0.60 |
| adjacent / core-drifting-glow | 1 | 1.70 | 1.80 | 0.60 |

## 实际使用的技能变体（大范围新星、横纵光束、标记）

| 类型 / 特效 | 同屏数 | 中位 ms | p95 ms | 性能模式 ms |
|---|---:|---:|---:|---:|
| variant / supernova:nova | 1 | 4.10 | 4.30 | 1.40 |
| variant / supernova:nova | 12 | 50.50 | 59.40 | 7.30 |
| variant / supernova:nova | 23 | 105.30 | 111.60 | 13.50 |
| variant / roulette:nova | 1 | 3.90 | 4.00 | 1.10 |
| variant / roulette:nova | 12 | 34.70 | 35.10 | 5.30 |
| variant / roulette:nova | 23 | 64.80 | 70.10 | 9.80 |
| variant / pulse:nova | 1 | 5.90 | 6.00 | 1.30 |
| variant / pulse:nova | 12 | 77.00 | 77.90 | 7.40 |
| variant / pulse:nova | 23 | 143.20 | 145.50 | 14.00 |
| variant / orbital:mark | 1 | 3.20 | 3.50 | 1.00 |
| variant / orbital:mark | 12 | 23.20 | 23.40 | 3.80 |
| variant / orbital:mark | 23 | 43.00 | 43.80 | 6.60 |
| variant / sharpshooter:power | 1 | 2.70 | 2.80 | 0.80 |
| variant / sharpshooter:power | 12 | 18.40 | 18.90 | 2.60 |
| variant / sharpshooter:power | 23 | 34.90 | 39.40 | 4.30 |
| variant / legion:split | 1 | 2.60 | 2.80 | 0.90 |
| variant / legion:split | 12 | 17.00 | 20.80 | 2.70 |
| variant / legion:split | 23 | 31.50 | 32.00 | 4.40 |
| variant / sweep:beam | 1 | 1.90 | 2.40 | 0.60 |
| variant / sweep:beam | 12 | 6.10 | 6.70 | 1.10 |
| variant / sweep:beam | 23 | 10.10 | 10.60 | 1.60 |
| variant / lance:beam | 1 | 2.20 | 2.30 | 0.80 |
| variant / lance:beam | 12 | 11.40 | 11.90 | 2.30 |
| variant / lance:beam | 23 | 21.20 | 22.10 | 3.70 |
| variant / crossfire:beam | 1 | 1.90 | 2.40 | 0.70 |
| variant / crossfire:beam | 12 | 7.30 | 8.50 | 1.60 |
| variant / crossfire:beam | 23 | 12.80 | 13.80 | 2.50 |
| variant / stormfront:beam | 1 | 2.20 | 2.30 | 0.80 |
| variant / stormfront:beam | 12 | 10.50 | 10.90 | 2.10 |
| variant / stormfront:beam | 23 | 19.50 | 20.10 | 3.40 |

## 扩展技能机械特效（信号、锯盘、持续场）

| 类型 / 特效 | 同屏数 | 中位 ms | p95 ms | 性能模式 ms |
|---|---:|---:|---:|---:|
| mechanic / wormhole:portal | 1 | 2.00 | 2.10 | 1.00 |
| mechanic / wormhole:portal | 12 | 9.70 | 13.60 | 5.50 |
| mechanic / wormhole:portal | 80 | 63.10 | 69.20 | 39.20 |
| mechanic / siegebreaker:rubble | 1 | 1.40 | 1.60 | 0.60 |
| mechanic / siegebreaker:rubble | 12 | 2.80 | 3.70 | 1.50 |
| mechanic / siegebreaker:rubble | 80 | 11.90 | 12.40 | 6.30 |
| mechanic / threadweaver:cut | 1 | 1.40 | 1.50 | 0.60 |
| mechanic / threadweaver:cut | 12 | 2.80 | 3.00 | 1.20 |
| mechanic / threadweaver:cut | 80 | 11.70 | 12.40 | 4.90 |
| mechanic / infection:seed | 1 | 1.60 | 1.70 | 0.80 |
| mechanic / infection:seed | 12 | 4.50 | 4.70 | 2.70 |
| mechanic / infection:seed | 80 | 24.40 | 27.70 | 18.30 |
| mechanic / infection:root | 1 | 1.30 | 1.50 | 0.60 |
| mechanic / infection:root | 12 | 1.80 | 1.90 | 0.90 |
| mechanic / infection:root | 80 | 4.60 | 5.60 | 2.30 |
| mechanic / transmute:transform | 1 | 1.40 | 1.60 | 0.60 |
| mechanic / transmute:transform | 12 | 2.60 | 3.00 | 1.50 |
| mechanic / transmute:transform | 80 | 10.70 | 12.40 | 6.20 |
| mechanic / spectral:phase | 1 | 1.70 | 1.90 | 0.90 |
| mechanic / spectral:phase | 12 | 5.40 | 10.30 | 4.00 |
| mechanic / spectral:phase | 80 | 29.70 | 31.20 | 24.00 |
| mechanic / fusepath:signal | 1 | 1.40 | 1.50 | 0.60 |
| mechanic / fusepath:signal | 12 | 2.00 | 2.10 | 1.00 |
| mechanic / fusepath:signal | 96 | 7.20 | 7.50 | 3.60 |
| mechanic / reboundaim:signal | 1 | 1.50 | 1.70 | 0.80 |
| mechanic / reboundaim:signal | 12 | 4.10 | 4.30 | 2.90 |
| mechanic / reboundaim:signal | 96 | 25.60 | 26.40 | 20.10 |
| mechanic / overkill:signal | 1 | 1.40 | 1.50 | 0.60 |
| mechanic / overkill:signal | 12 | 2.00 | 2.10 | 1.00 |
| mechanic / overkill:signal | 96 | 6.90 | 7.40 | 3.70 |
| mechanic / chronicle:signal | 1 | 1.50 | 1.60 | 0.70 |
| mechanic / chronicle:signal | 12 | 3.20 | 3.70 | 1.70 |
| mechanic / chronicle:signal | 96 | 19.00 | 39.40 | 8.60 |
| mechanic / worldfold:signal | 1 | 1.60 | 2.30 | 0.70 |
| mechanic / worldfold:signal | 12 | 4.30 | 6.20 | 1.80 |
| mechanic / worldfold:signal | 96 | 25.80 | 50.60 | 11.20 |
| mechanic / starforge:signal | 1 | 1.40 | 1.80 | 0.60 |
| mechanic / starforge:signal | 12 | 2.00 | 2.20 | 0.90 |
| mechanic / starforge:signal | 96 | 6.90 | 12.60 | 3.40 |
| mechanic / buzzsaw:disc | 1 | 1.70 | 1.90 | 0.80 |
| mechanic / buzzsaw:disc | 6 | 3.60 | 3.80 | 2.00 |
| mechanic / teslanet:field | 1 | 1.40 | 1.50 | 0.70 |
| mechanic / teslanet:field | 8 | 3.00 | 3.20 | 1.60 |
| mechanic / teslanet:field | 32 | 9.00 | 11.20 | 4.70 |
| mechanic / undertow:field | 1 | 1.70 | 1.80 | 0.80 |
| mechanic / undertow:field | 8 | 4.30 | 5.00 | 2.20 |
| mechanic / undertow:field | 32 | 13.30 | 14.50 | 7.20 |
| mechanic / worldfold:field | 1 | 1.70 | 2.00 | 0.90 |
| mechanic / worldfold:field | 8 | 4.90 | 5.70 | 2.70 |
| mechanic / worldfold:field | 32 | 16.50 | 25.10 | 9.30 |
| mechanic / starforge:field | 1 | 1.80 | 2.10 | 0.90 |
| mechanic / starforge:field | 8 | 6.50 | 9.80 | 3.40 |
| mechanic / starforge:field | 32 | 23.60 | 30.90 | 12.10 |

## Boss 粒子（独立绘制压力）

| 类型 / 特效 | 同屏数 | 中位 ms | p95 ms | 性能模式 ms |
|---|---:|---:|---:|---:|
| boss-particle / eye:well | 1 | 1.10 | 1.30 | 0.40 |
| boss-particle / eye:well | 4 | 3.80 | 8.40 | 1.30 |
| boss-particle / eye:well | 32 | 25.90 | 28.20 | 9.20 |
| boss-particle / eye:beam | 1 | 0.40 | 0.50 | 0.20 |
| boss-particle / eye:shards | 1 | 0.30 | 0.40 | 0.10 |
| boss-particle / clock:shards | 1 | 0.30 | 0.40 | 0.10 |
| boss-particle / serpent:flare | 1 | 0.90 | 0.90 | 0.30 |
| boss-particle / serpent:wave | 1 | 0.40 | 0.50 | 0.20 |
| boss-particle / serpent:streak | 1 | 0.40 | 0.50 | 0.20 |
| boss-particle / forge:embers | 1 | 0.50 | 0.60 | 0.20 |
| boss-particle / forge:meteors | 1 | 0.80 | 0.90 | 0.30 |
| boss-particle / serpent:dust | 1 | 0.30 | 0.40 | 0.10 |
| boss-particle / serpent:ghosts | 1 | 0.30 | 0.40 | 0.10 |
| boss-particle / serpent:sparks | 1 | 0.50 | 0.50 | 0.20 |
| boss-particle / serpent:portals | 1 | 1.60 | 1.70 | 0.80 |
| boss-particle / eye:beam | 12 | 1.70 | 1.80 | 0.90 |
| boss-particle / eye:shards | 12 | 0.50 | 0.60 | 0.20 |
| boss-particle / clock:shards | 12 | 0.50 | 0.60 | 0.20 |
| boss-particle / serpent:flare | 12 | 7.30 | 8.30 | 2.30 |
| boss-particle / serpent:wave | 12 | 2.00 | 3.70 | 1.10 |
| boss-particle / serpent:streak | 12 | 1.50 | 4.20 | 0.90 |
| boss-particle / forge:embers | 12 | 0.90 | 1.20 | 0.40 |
| boss-particle / forge:meteors | 12 | 3.70 | 6.90 | 1.30 |
| boss-particle / serpent:dust | 12 | 0.30 | 0.40 | 0.10 |
| boss-particle / serpent:ghosts | 12 | 0.60 | 0.70 | 0.30 |
| boss-particle / serpent:sparks | 12 | 2.00 | 2.10 | 1.20 |
| boss-particle / serpent:portals | 12 | 14.90 | 15.20 | 8.20 |
| boss-particle / eye:beam | 70 | 8.60 | 9.00 | 4.70 |
| boss-particle / eye:shards | 70 | 1.40 | 1.50 | 0.60 |
| boss-particle / clock:shards | 70 | 1.60 | 1.80 | 0.60 |
| boss-particle / serpent:flare | 70 | 41.70 | 45.00 | 13.10 |
| boss-particle / serpent:wave | 70 | 10.30 | 10.50 | 5.80 |
| boss-particle / serpent:streak | 70 | 6.40 | 6.60 | 4.50 |
| boss-particle / forge:embers | 70 | 2.30 | 2.40 | 1.30 |
| boss-particle / forge:meteors | 70 | 18.20 | 19.20 | 6.00 |
| boss-particle / serpent:dust | 70 | 0.30 | 0.40 | 0.20 |
| boss-particle / serpent:ghosts | 70 | 2.00 | 2.10 | 1.10 |
| boss-particle / serpent:sparks | 70 | 9.50 | 10.10 | 6.10 |
| boss-particle / serpent:portals | 70 | 91.70 | 98.00 | 47.90 |
| boss-particle / eye:beam | 300 | 38.20 | 61.60 | 20.10 |
| boss-particle / eye:shards | 300 | 5.30 | 8.80 | 2.20 |
| boss-particle / clock:shards | 300 | 6.10 | 10.60 | 2.30 |
| boss-particle / serpent:flare | 300 | 181.50 | 195.40 | 62.40 |
| boss-particle / serpent:wave | 300 | 43.20 | 44.10 | 27.20 |
| boss-particle / serpent:streak | 300 | 25.50 | 29.30 | 20.40 |
| boss-particle / forge:embers | 300 | 7.90 | 9.40 | 4.90 |
| boss-particle / forge:meteors | 300 | 74.40 | 85.50 | 26.40 |
| boss-particle / serpent:dust | 300 | 0.60 | 0.70 | 0.40 |
| boss-particle / serpent:ghosts | 300 | 7.90 | 8.40 | 4.40 |
| boss-particle / serpent:sparks | 300 | 45.70 | 59.20 | 26.70 |
| boss-particle / serpent:portals | 300 | 407.30 | 433.10 | 224.40 |
| boss-particle / serpent:eclipse-lights | 1 | 6.00 | 11.30 | 2.50 |
| boss-particle / serpent:eclipse-lights | 12 | 7.10 | 7.30 | 4.20 |
| boss-particle / serpent:eclipse-lights | 64 | 12.70 | 13.10 | 8.90 |

## Boss 完整场景

| 类型 / 特效 | 同屏数 | 中位 ms | p95 ms | 性能模式 ms |
|---|---:|---:|---:|---:|
| boss-scene / eye:idle | 1 | 7.20 | 7.50 | 3.50 |
| boss-scene / eye:orbit | 1 | 7.70 | 20.70 | 3.80 |
| boss-scene / eye:summon | 1 | 7.00 | 8.60 | 3.40 |
| boss-scene / eye:tear | 1 | 7.10 | 7.70 | 3.40 |
| boss-scene / eye:gaze | 1 | 6.90 | 7.10 | 3.50 |
| boss-scene / eye:mirage | 1 | 8.00 | 8.50 | 3.90 |
| boss-scene / eye:doom | 1 | 7.00 | 8.50 | 3.30 |
| boss-scene / forge:idle | 1 | 3.80 | 3.90 | 1.60 |
| boss-scene / serpent:idle | 1 | 22.30 | 22.90 | 13.00 |
| boss-scene / clock:idle | 1 | 8.00 | 9.40 | 3.80 |
| boss-scene / clock:stop | 1 | 7.90 | 9.30 | 3.70 |
| boss-scene / clock:toll | 1 | 7.90 | 8.30 | 3.80 |
| boss-scene / clock:pendulum | 1 | 7.80 | 8.30 | 3.80 |
| boss-scene / clock:rewind | 1 | 8.10 | 12.70 | 3.70 |
| boss-scene / clock:haste | 1 | 7.50 | 7.70 | 3.60 |
| boss-scene / clock:midnight | 1 | 8.00 | 8.40 | 3.80 |

## 每个技能的测试结果（81 项，不遗漏轻量技能）

| 技能 | 普通命中 ×12 / ×56 ms | 发光主特效 ×12 / ×23 / ×24 ms | 拖尾 ×12 / ×64 ms |
|---|---:|---:|---:|
| 三叉齐射 (trident) | 11.90 / 9.70 | 9.20 / 16.40 / 4.80 | 4.30 / 12.50 |
| 回响齐射 (echo) | 2.90 / 8.10 | 7.70 / 14.00 / 4.30 | 5.00 / 16.00 |
| 万箭归宗 (legion) | 3.70 / 11.50 | 10.30 / 19.40 / 5.90 | 5.30 / 14.10 |
| 万华棱镜 (prism) | 3.20 / 9.30 | 10.20 / 19.00 / 4.70 | 4.30 / 13.00 |
| 碎星新生 (nova) | 3.00 / 8.80 | 7.30 / 12.80 / 4.60 | 4.10 / 10.80 |
| 镜像夹击 (mirror) | 3.60 / 11.00 | 8.80 / 16.40 / 5.60 | 5.40 / 16.90 |
| 追猎蜂群 (hunters) | 3.30 / 9.20 | 7.50 / 13.20 / 4.90 | 4.70 / 11.60 |
| 必中引导 (seeking) | 3.50 / 11.30 | 9.20 / 16.50 / 6.00 | 4.90 / 12.50 |
| 蜂群女王 (swarmqueen) | 13.00 / 29.20 | 16.50 / 29.30 / 11.70 | 8.10 / 21.80 |
| 弹射工厂 (bankshot) | 3.90 / 13.40 | 10.40 / 17.70 / 5.00 | 4.90 / 14.00 |
| 泰坦之力 (titan) | 2.60 / 6.80 | 6.70 / 11.20 / 3.60 | 3.60 / 10.00 |
| 贯星长矛 (piercer) | 3.60 / 14.90 | 8.10 / 14.10 / 5.70 | 4.40 / 12.30 |
| 破城重弩 (heavy) | 2.70 / 7.40 | 7.10 / 12.70 / 3.80 | 3.80 / 11.00 |
| 歼星轨道炮 (railgun) | 4.10 / 14.20 | 10.90 / 22.90 / 6.80 | 4.80 / 15.40 |
| 满弓狙击 (sharpshooter) | 3.90 / 11.30 | 10.80 / 19.20 / 5.70 | 4.60 / 11.80 |
| 疾风快弦 (rapid) | 2.60 / 7.10 | 6.60 / 13.70 / 4.30 | 4.00 / 11.70 |
| 越战越勇 (growing) | 3.00 / 10.30 | 11.80 / 24.00 / 5.30 | 5.70 / 14.60 |
| 致命准星 (critical) | 4.10 / 13.00 | 10.90 / 19.20 / 5.60 | 4.00 / 10.10 |
| 斩灭法则 (execute) | 3.20 / 9.40 | 11.00 / 19.50 / 4.60 | 4.00 / 10.80 |
| 连击狂热 (rage) | 4.50 / 16.10 | 12.60 / 21.80 / 6.80 | 4.90 / 13.10 |
| 破阵先锋 (ambush) | 3.20 / 9.00 | 9.30 / 18.30 / 5.20 | 3.90 / 10.40 |
| 穷追猛打 (opportunist) | 2.80 / 8.40 | 8.70 / 15.70 / 4.30 | 3.60 / 10.00 |
| 死神点名 (reaper) | 3.10 / 9.00 | 8.80 / 16.00 / 4.70 | 3.70 / 9.90 |
| 饮血长箭 (siphon) | 3.40 / 10.60 | 8.60 / 15.20 / 5.10 | 4.40 / 12.40 |
| 动能回收 (ricochet) | 3.10 / 9.20 | 9.80 / 17.80 / 4.80 | 4.10 / 11.30 |
| 流星雨 (meteor) | 4.10 / 13.00 | 12.90 / 23.90 / 6.50 | 4.80 / 13.00 |
| 爆裂箭头 (blast) | 4.30 / 14.90 | 12.00 / 22.40 / 7.00 | 4.90 / 11.80 |
| 延迟引爆 (doubletap) | 3.50 / 11.20 | 9.30 / 17.20 / 5.60 | 4.30 / 12.20 |
| 地裂余震 (aftershock) | 3.70 / 11.90 | 9.90 / 18.40 / 5.80 | 4.20 / 11.70 |
| 连环殉爆 (cascade) | 4.40 / 15.20 | 11.40 / 21.50 / 7.20 | 4.70 / 11.50 |
| 轨道轰炸 (orbital) | 4.60 / 15.80 | 13.10 / 22.10 / 7.40 | 5.50 / 14.40 |
| 脉冲雷区 (minefield) | 5.00 / 18.20 | 14.70 / 25.10 / 8.50 | 5.40 / 13.10 |
| 连锁电容 (lightning) | 3.70 / 12.50 | 10.50 / 19.80 / 5.90 | 5.50 / 15.70 |
| 雷神降临 (storm) | 4.20 / 13.30 | 11.30 / 22.50 / 5.90 | 4.10 / 12.30 |
| 雷霆骰子 (thunderlottery) | 4.30 / 17.50 | 10.20 / 24.70 / 9.00 | 16.10 / 12.70 |
| 天幕裁决 (stormfront) | 4.10 / 11.90 | 15.30 / 34.50 / 6.20 | 5.10 / 13.60 |
| 永冻箭簇 (ice) | 4.00 / 14.20 | 12.50 / 22.90 / 6.80 | 4.70 / 11.10 |
| 碎冰风暴 (shatter) | 4.70 / 16.80 | 11.90 / 21.30 / 7.70 | 5.30 / 11.50 |
| 绝对零度 (blizzard) | 10.40 / 42.50 | 30.80 / 56.80 / 18.90 | 10.70 / 20.00 |
| 冰河冲击 (snowburst) | 8.30 / 34.00 | 26.60 / 51.50 / 16.20 | 9.40 / 16.80 |
| 冰火连爆 (frostfire) | 5.00 / 17.70 | 14.20 / 30.50 / 8.00 | 5.70 / 13.80 |
| 蚀骨剧毒 (poison) | 3.60 / 11.00 | 8.30 / 15.10 / 5.60 | 4.20 / 11.40 |
| 衰弱领域 (decay) | 4.70 / 15.80 | 14.00 / 25.70 / 7.90 | 5.00 / 12.70 |
| 横扫千军 (sweep) | 3.60 / 11.90 | 6.90 / 12.00 / 6.10 | 3.70 / 12.20 |
| 天际贯穿 (lance) | 5.10 / 19.20 | 11.40 / 21.30 / 9.40 | 4.60 / 14.60 |
| 十字审判 (crossfire) | 3.70 / 12.30 | 7.10 / 12.40 / 6.20 | 3.70 / 12.00 |
| 末日脉冲 (pulse) | 6.50 / 25.10 | 21.30 / 38.50 / 11.40 | 4.40 / 9.40 |
| 超新星爆发 (supernova) | 7.10 / 28.80 | 21.00 / 39.70 / 12.90 | 5.50 / 12.50 |
| 点石成金 (alchemist) | 2.90 / 8.20 | 8.00 / 14.30 / 4.30 | 3.80 / 10.40 |
| 黄金时代 (mint) | 7.10 / 27.40 | 18.50 / 33.90 / 12.30 | 6.40 / 13.60 |
| 核心宝库 (treasury) | 4.70 / 17.50 | 12.90 / 23.70 / 8.60 | 5.60 / 12.70 |
| 超频工坊 (bargain) | 3.00 / 9.10 | 8.80 / 16.10 / 4.40 | 3.80 / 11.00 |
| 神匠赐福 (forge) | 3.40 / 10.30 | 10.70 / 19.30 / 5.70 | 4.30 / 11.70 |
| 幸运暴富 (jackpot) | 3.90 / 13.10 | 11.20 / 20.60 / 6.30 | 4.70 / 11.30 |
| 连杀赏金 (bounty) | 4.20 / 13.90 | 12.50 / 22.90 / 6.70 | 4.90 / 12.10 |
| 异能收割 (specialist) | 3.70 / 11.10 | 8.10 / 14.90 / 5.70 | 4.40 / 11.20 |
| 核心共振 (resonance) | 4.20 / 14.30 | 11.50 / 21.40 / 7.00 | 3.70 / 8.20 |
| 终焉引力 (corehunter) | 3.20 / 9.80 | 7.80 / 14.50 / 4.90 | 4.40 / 12.50 |
| 命运轮盘 (roulette) | 4.00 / 13.60 | 12.20 / 23.00 / 6.50 | 4.80 / 12.70 |
| 回旋天轮 (boomerang) | 3.40 / 10.70 | 11.30 / 20.60 / 5.30 | 4.10 / 12.10 |
| 折跃猎手 (wormhole) | 4.70 / 16.50 | 13.70 / 24.30 / 8.10 | 5.40 / 16.40 |
| 幽界漫游 (spectral) | 8.20 / 35.60 | 18.60 / 33.00 / 14.70 | 5.40 / 12.00 |
| 弦上时停 (timeslip) | 3.50 / 10.30 | 11.40 / 23.00 / 5.40 | 4.30 / 12.10 |
| 行刑锯盘 (buzzsaw) | 6.60 / 25.70 | 20.00 / 36.80 / 11.70 | 5.90 / 15.10 |
| 城墙粉碎机 (siegebreaker) | 3.50 / 11.60 | 9.70 / 17.90 / 5.50 | 4.10 / 11.70 |
| 缝天之线 (threadweaver) | 4.10 / 14.80 | 12.60 / 24.60 / 6.30 | 4.70 / 13.50 |
| 万物炼成 (transmute) | 2.90 / 8.70 | 7.70 / 13.90 / 4.80 | 4.10 / 11.10 |
| 寄生花园 (infection) | 6.80 / 26.10 | 17.40 / 32.00 / 11.50 | 5.90 / 13.20 |
| 猎金契约 (contract) | 3.10 / 8.90 | 7.90 / 14.20 / 4.60 | 4.00 / 10.90 |
| 破壳礼炮 (nailburst) | 4.40 / 15.90 | 12.50 / 21.80 / 7.40 | 5.60 / 14.50 |
| 左右开弓 (pendulum) | 3.60 / 11.40 | 8.70 / 15.80 / 5.20 | 4.40 / 13.30 |
| 燃线速递 (fusepath) | 2.80 / 8.50 | 8.40 / 14.70 / 4.40 | 4.30 / 13.90 |
| 日轮护航 (firewheel) | 5.00 / 17.60 | 14.10 / 25.00 / 8.00 | 5.10 / 13.40 |
| 三拍重音 (rhythm) | 4.30 / 14.90 | 11.90 / 21.40 / 7.00 | 5.10 / 13.00 |
| 天地对折 (worldfold) | 2.90 / 8.40 | 10.10 / 18.10 / 4.60 | 4.30 / 12.60 |
| 撞墙开窍 (reboundaim) | 2.90 / 7.90 | 8.50 / 14.90 / 4.30 | 3.90 / 11.40 |
| 余力借条 (overkill) | 3.00 / 8.60 | 8.10 / 13.90 / 4.50 | 4.10 / 12.20 |
| 三角禁区 (teslanet) | 4.20 / 14.30 | 10.50 / 19.10 / 6.40 | 4.50 / 11.70 |
| 潮汐回卷 (undertow) | 4.50 / 15.20 | 15.30 / 27.80 / 7.30 | 5.00 / 13.60 |
| 伤痕重映 (chronicle) | 3.70 / 11.80 | 12.20 / 22.10 / 5.90 | 5.00 / 16.00 |
| 吞星熔炉 (starforge) | 7.30 / 29.40 | 21.60 / 39.30 / 13.40 | 5.40 / 12.00 |

## 实现风险与优化优先级

1. **优先解决强制主特效的逐图元 shadowBlur**：`skill-effects.js:224` 在 `hero && effects.length < 24` 时启用 blur=8；整段 signature 的每次 stroke/fill 都会走模糊。复杂雪花/射线图案倍增光栅成本。先缓存光晕精灵或单独绘制一次光晕，避免让所有轮廓分别模糊。
2. **不能只依赖 56 个技能特效上限**：23 个时有模糊、24 个时忽然关闭，最高成本不一定出现在 56 个。应按累计绘制预算降级，而不是仅在一个数量门槛后关闭模糊。
3. **连击 overdrive 热拖尾**：`juice.js:90-96` 给每支热箭执行 shadowBlur=14，最多 64 支箭，无详细特效预算。建议共享精灵/降级前 N 支发光，其余保留清晰线条。
4. **拖尾没有整体降级**：`skill-effects.js:232-257` 每帧为多股曲线创建 map 数组/点对象并多次 stroke；`index < 12` 只限制箭头装饰，不限制 64 支箭的拖尾。雪花/水晶类的装饰需要额外逐点绘制。建议复用点缓冲、批路径、按同屏箭数缩减装饰和曲线股数。
5. **无硬数量预算的共享特效**：`Game.rings`、`Game.bolts`、`Game.texts` 仅按生命期清理，没有同屏上限。大量连锁可堆积；实测大面积环的开销明显高于浮字。建议先限制/合并环，再处理电弧，浮字可按区域合并。
6. **Boss 高面积效果**：巨蟒除了 flare、portal、spark、eclipse，还有 `boss-serpent.js:574-597` 每帧三个大范围星云渐变和 26/48/70px 宽的虚影曲线；背景不是免费成本。日蚀还为每支箭各绘一个 destination-out 渐变洞。熔炉陨火逐点圆形拖尾。建议缓存静态渐变纹理、限制光源孔/陨火数、降低大面积渐变分辨率。
7. **性能模式不是完整的数量削减**：会关闭 shadowBlur/冻结部分动画，普通粒子生成减少、Canvas DPR 上限降到 1，但技能 effect 56 上限和拖尾图案数量不变；原始样本另测，不能认为开启后所有特效都会轻量。

测试错误：normal=0 / 页面异常=0；reduced=0。

完整原始样本见同目录 JSON；所有逐项结果见 `fx-all.csv`。

## 无读回 rAF 复核（绘制循环；无物理模拟）

| 特效 | 同屏数 | 平均帧间隔 ms | p95 ms | rAF FPS |
|---|---:|---:|---:|---:|
| baseline/board | 0 | 2.06 | 3.30 | 484.35 |
| hero/绝对零度 (blizzard) | 1 | 4.48 | 5.40 | 223.11 |
| hero/绝对零度 (blizzard) | 12 | 31.01 | 35.40 | 32.25 |
| hero/绝对零度 (blizzard) | 23 | 57.94 | 62.10 | 17.26 |
| hero/绝对零度 (blizzard) | 24 | 18.47 | 20.40 | 54.14 |
| hero/绝对零度 (blizzard) | 56 | 41.56 | 44.50 | 24.06 |
| hero/冰河冲击 (snowburst) | 1 | 4.00 | 4.60 | 249.87 |
| hero/冰河冲击 (snowburst) | 12 | 25.41 | 29.30 | 39.36 |
| hero/冰河冲击 (snowburst) | 23 | 49.86 | 61.80 | 20.06 |
| hero/冰河冲击 (snowburst) | 24 | 15.99 | 18.50 | 62.55 |
| hero/冰河冲击 (snowburst) | 56 | 35.14 | 42.00 | 28.46 |
| hero/超新星爆发 (supernova) | 1 | 3.39 | 4.60 | 295.19 |
| hero/超新星爆发 (supernova) | 12 | 21.52 | 24.80 | 46.48 |
| hero/超新星爆发 (supernova) | 23 | 40.54 | 43.80 | 24.67 |
| hero/超新星爆发 (supernova) | 24 | 13.39 | 15.40 | 74.71 |
| hero/超新星爆发 (supernova) | 56 | 28.89 | 31.60 | 34.61 |
| core/overdrive-glow | 1 | 2.25 | 2.70 | 445.27 |
| core/日轮护航 (firewheel) | 1 | 2.87 | 3.60 | 348.88 |
| core/overdrive-glow | 12 | 6.33 | 7.10 | 158.04 |
| core/日轮护航 (firewheel) | 12 | 10.85 | 13.50 | 92.13 |
| core/overdrive-glow | 64 | 28.58 | 30.80 | 34.99 |
| core/日轮护航 (firewheel) | 64 | 48.44 | 60.40 | 20.64 |
| core/square-particles | 0 | 1.97 | 2.40 | 508.26 |
| core/square-particles | 100 | 2.27 | 3.10 | 439.59 |
| core/square-particles | 300 | 2.36 | 2.70 | 424.12 |
| core/square-particles | 1000 | 3.33 | 4.30 | 299.91 |
| core/square-particles | 3000 | 5.93 | 6.90 | 168.64 |
| core/square-particles | 8000 | 12.78 | 14.00 | 78.26 |
| baseline/empty-canvas | 0 | 1.22 | 6.00 | 820.09 |

本轮禁用垂直同步，不把此 FPS 当作真实手机帧率；用于检查同步读回排名是否在正常浏览器绘制调度中仍然显著。

## Boss 分层复核（正常模式）

| 场景 / 层 | 同步成本中位 ms | 无读回 rAF 均帧 ms |
|---|---:|---:|
| boss-layer/eye:back | 4.00 | 4.07 |
| boss-layer/eye:field | 3.00 | 3.23 |
| boss-layer/eye:front | 0.30 | 1.50 |
| boss-layer/forge:back | 2.70 | 3.00 |
| boss-layer/forge:field | 0.60 | 1.63 |
| boss-layer/forge:front | 0.30 | 1.96 |
| boss-scene/serpent:idle | 24.50 | 22.56 |
| boss-layer/serpent:back | 10.60 | 10.55 |
| boss-layer/serpent:field | 0.80 | 1.56 |
| boss-layer/serpent:front | 7.20 | 8.10 |
| boss-layer/clock:back | 5.20 | 5.82 |
| boss-layer/clock:field | 1.90 | 2.49 |
| boss-layer/clock:front | 0.30 | 1.59 |

back=背景，field=主体/场内粒子，front=前景。各层独立绘制，不含其余画面；分层之和不保证等于全场景。`serpent:idle` 是生成后固定的 emerge 快照，并非完整战斗各阶段的平均值。

## DOM 粒子（真实 rAF + 原生产 WAAPI 动画）

| 类型 | 发射份数 | 实际节点 | 生成 ms | rAF 均帧 ms | p95 ms |
|---|---:|---:|---:|---:|---:|
| baseline | 0 | 0 | 0.10 | 2.19 | 3.00 |
| coins | 1 | 14 | 2.50 | 2.21 | 3.80 |
| coins | 4 | 56 | 5.30 | 2.70 | 3.90 |
| coins | 16 | 224 | 28.00 | 6.10 | 15.80 |
| sparks | 1 | 6 | 2.40 | 1.96 | 2.40 |
| sparks | 4 | 6 | 2.20 | 2.05 | 3.00 |
| sparks | 16 | 6 | 1.80 | 1.76 | 1.90 |
| payout | 1 | 1 | 0.90 | 1.93 | 2.50 |
| payout | 4 | 4 | 1.90 | 2.04 | 2.70 |
| payout | 16 | 16 | 5.50 | 2.37 | 3.90 |

自然单次金币飞行 14 节点、成就火花最多 6 节点；强行重复 16 份金币为 224 节点，会出现较大的创建瞬时开销，但不是正常单次结算。成就火花超额请求仍被 6 节点上限挡住。本轮正常同屏数量下未发现持续帧开销严重增加。

## 补充：吞噬碎块、断链、眼拖尾与巨蟒战斗态

| 场景 / 特效 | 数量 | 正常 ms | 性能模式 ms |
|---|---:|---:|---:|
| boss-particle/serpent:debris | 1 | 0.30 | 0.10 |
| boss-particle/eye:chain-snap | 1 | 0.30 | 0.20 |
| boss-particle/serpent:debris | 12 | 0.50 | 0.20 |
| boss-particle/eye:chain-snap | 12 | 0.80 | 0.50 |
| boss-particle/serpent:debris | 70 | 1.20 | 0.70 |
| boss-particle/eye:chain-snap | 70 | 2.90 | 2.00 |
| boss-particle/serpent:debris | 300 | 3.80 | 2.60 |
| boss-particle/eye:chain-snap | 300 | 10.80 | 7.90 |
| boss-particle/serpent:eye-trails | 1 | 0.40 | 0.20 |
| boss-particle/serpent:eye-trails | 2 | 0.50 | 0.10 |
| boss-particle/serpent:eye-trails | 16 | 2.20 | 0.10 |
| boss-scene/serpent:live-body | 1 | 41.60 | 17.20 |

巨蟒 live-body 无读回复核均帧 33.56ms。此案例为第四阶段全能力同时启用的压力构筑，生成后通过真实 Game.tick 推进至身体出现，**不是自然每关随机只抽取部分能力的常态**。冻结取样的姿态、活鳞数量与日蚀状态可从 JSON 的 snapshot 复核；两种模式实际姿态有差异，不把本行当作严格同姿态 A/B。

## 仅更新成本（不含绘制）

| 类型 | 数量 | 每次 Game.tick 中位 ms |
|---|---:|---:|
| board | 0 | 0.0020 |
| square-particles | 0 | 0.0020 |
| square-particles | 100 | 0.0040 |
| square-particles | 300 | 0.0080 |
| square-particles | 1000 | 0.0160 |
| square-particles | 3000 | 0.0430 |
| square-particles | 8000 | 0.1070 |
| rings | 1 | 0.0040 |
| bolts | 1 | 0.0030 |
| floating-text | 1 | 0.0030 |
| rings | 30 | 0.0050 |
| bolts | 30 | 0.0030 |
| floating-text | 30 | 0.0020 |
| rings | 100 | 0.0030 |
| bolts | 100 | 0.0030 |
| floating-text | 100 | 0.0030 |
| rings | 300 | 0.0040 |
| bolts | 300 | 0.0040 |
| floating-text | 300 | 0.0040 |
| rings | 1000 | 0.0090 |
| bolts | 1000 | 0.0090 |
| floating-text | 1000 | 0.0100 |

每档 12 组 ×100 次 tick，前两组预热丢弃，保持粒子生命期足够长。此处不包含箭矢飞行、命中连锁或音频，低于计时分辨率的微秒差值不作精细排名。
