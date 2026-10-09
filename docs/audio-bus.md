# 音频总线与 Android 桥协议

## 模块职责

- `game/src/audio/audio-recipes.js` 定义音效配方；`audio.js` 处理游戏音量、解锁和游戏/UI 路由。
- `game/src/audio/audio-music.js` 只做离线乐器合成，返回单声道 Float32 little-endian PCM 的 Base64。
- `game/src/audio/audio-native.js` 协商宿主能力，管理会话、异步合成取消、样本缓存、上传和调度。
- `game/src/bosses/boss-music.js` 选择乐谱、阶段、情绪并生成音符；不负责 Android 输出设备或 PCM 编码。
- Android `NativeAudio` 校验协议、持有样本、管理音频焦点和 AudioTrack；`AudioMixer` 负责声部、混音和尾音。

正式宿主声明 `version:2, gain:true, ui:true, music:true, batch:true`。版本 2 的音效和 UI 输出只使用原生端；
`music:true` 单独声明音乐协议，只有完整支持对应方法时才能声明。旧版宿主、没有音乐能力的宿主和
普通浏览器保留各自原有的 Web Audio 路径。版本 2 原生接口失败时停止该会话并记录诊断。

## 总线策略

| 总线 | 声部上限 | 游戏暂停 | 混音 |
| --- | ---: | --- | --- |
| `effects` | 64 | 清空声部和效果回声，拒绝新声部 | 声像、105 ms 回声、用户增益 |
| `ui` | 16 | 保留播放和尾音 | 独立声部及 105 ms 回声、用户增益 |
| `music` | 48 | 清空声部、340 ms 回声及滤波尾音 | 乐器层增益、低通、回声、整体淡出、用户增益 |

三个上限相互独立。普通批次容量不足时整批拒绝；优先音效只在自己的总线淘汰普通声部，
可淘汰数量不足时整批拒绝，不能部分淘汰后再失败。暂停期间 UI 仍受音量、页面可见性和音频焦点约束。
后台、窗口失焦或音频焦点丢失时全部声部清空，AudioTrack 暂停并 flush，写线程休眠。
用户静音/音量归零、页面结束或退出时释放原生会话；同一页面恢复时复用网页中的样本，重新上传。
页面结束时清空网页缓存；设备采样率变化时旧缓存失效。

音乐乐器层固定为 `pad`、`bass`、`drums`、`arp`、`lead`、`bell`、`fx`。
层级增益平滑过渡；回声发送保留原配乐中独立于干声层级的行为。原生整体低通使用一阶滤波，
各总线共用软限幅，音色配方保留离线 Web Audio 合成；这与浏览器的二阶整体低通和音乐压缩器并不完全等价。

## 会话与调用顺序

1. `capabilities()` 发现能力；`begin()` 分配新的非零会话 token 和设备采样率，返回的握手格式版本为 `1`。
2. 按该采样率离线准备音效，经 `upload(token,id,pcm)` 上传，再 `commit(token)` 创建原生输出。
3. `setState(token,volume,silent,gamePaused)` 同步 0–1 用户增益、静音与游戏暂停。
4. `play(token,json)` 提交同一总线的音效批次；JSON 的 `ui` 选择 UI，`priority` 选择优先策略，
   `voices` 包含 `id`、秒单位 `delay`、`pan`、`wet`。`1` 表示接收，`0` 表示容量/暂停/静音拒绝，负数表示协议错误。
5. 音乐按需 `uploadMusic(token,id,pcm)`，使用 `playMusic(token,id,delay,pan,volume,instrument,wet)` 播放。
   `-2` 表示样本已被 LRU 淘汰，可重新上传后重试；其他负数停止会话，`0` 不重排旧音符。
6. `musicState(token,levelsJson,cutoff,stop)` 设置所有乐器层目标增益及整体低通；未给出的层为 0。
   `stop` 清空音乐声部和尾音。`musicFade(token,target,seconds)` 设置音乐整体线性淡出/恢复。
7. `release(token)` 释放设备和样本。旧 token 的上传、状态和播放请求均被拒绝。

声明 `batch:true` 的宿主支持 `playBatch(token,jsonArray)`：同一事件循环内的音效/UI/音乐请求在下一任务
合并成一次桥调用。最多 96 个独立请求、131072 个 JSON 字符；单个音效配方仍最多 16 声部。
每项使用 `play` 的 `ui/priority/voices`，或 `music:true,id,delay,pan,volume,bus,wet`。返回等长整数数组，
每项沿用单条方法的结果语义。容量拒绝不会撤销其他项，音效配方的容量原子性仍由混音器保证。
未声明能力的旧宿主继续单条调用。网页按实际等待时间扣减 delay，丢弃迟到音乐和过期音效，
暂停/后台/停止/会话重建清除对应待发项；队列已满时优先请求只能替换同总线的普通效果请求。

## 加载与预热

`game/src/ui/audio-loading.js` 在脚本加载完成后调用 `Game.audio.preload()`，不阻塞开场动画或跳过按钮。
X5 准备使用 120 秒无进展超时，每个成功上传会重置计时，隐藏时暂停计时，返回前台后重新计时。
低端设备的离线合成和 bridge 上传可能明显慢于桌面浏览器；超时仍停止会话并记录 `lastError`。
原生客户端分批离线生成并上传全部 180 个音效及当前各 Boss 开场的常用配乐（目前 33 个形状，48 kHz
约 32 MiB PCM）；直到首次用户交互，原生输出保持静音，写线程等待，不抢占音频焦点。
开场和设置面板显示真实样本计数/准备阶段；静音保存不启动预热。普通浏览器保留 Web Audio 路径。

Boss 定义加载后复用同一套乐器配方收集形状，进入/恢复 Boss 和阶段转换时准备对应开场与转场声音，
战斗中按半小节推进、滚动预热未来一小节，覆盖阶段、情绪和双蛇变体。不会生成完整乐谱的全部
速度组合，也不承诺每个冷音符都已缓存。单次只合成一个音乐样本；待合成队列和样本缓存有界，
新预热计划取消旧计划，实际播放请求优先。Float32 little-endian 编码和 Base64 转换按块让出主线程，
每块字节数为 3 的倍数，保证拼接后的 Base64 仍是同一 PCM 数据。

音效缓存上限为 32 MiB、单样本 1 MiB；音乐原生缓存上限为 128 项、64 MiB、单样本 8 MiB。
网页音乐缓存也按 128 项和约 64 MiB PCM 大小限额淘汰，保留 Base64 以支持原生端淘汰后的重传；
Base64 字符串、正在离线合成的缓冲以及仍在播放的样本会占用额外内存，缓存限额不是进程总内存限额。

## 时间基准与取消

Boss 调度器沿用 40 ms 检查和 140 ms 前瞻，网页侧音符目标时间使用 `performance.now()` 毫秒。
合成完成并上传后，重新计算相对延迟，原生转换为混音帧偏移；不跨会话复用原生帧位置。
迟到超过 200 ms 的音符丢弃，避免冷合成或卡顿后的旧音符突发播放。首次遇到新音色时可能丢弃冷音符，
其缓存仍可供之后使用；加载和滚动预热减少冷音符，不代表完整乐谱预渲染或扬声器延迟测量。

暂停、隐藏、停止配乐和会话释放推进音乐 epoch。每个异步合成任务捕获会话 generation 和音乐 epoch，
完成时必须同时匹配且页面仍可播放，才能上传/调度。缓存形状键不包含声像、音量和回声发送，
同一音色可在不同乐器层复用。恢复时 Boss 调度器重同步混音状态，不重放已发生的阶段/情绪转场。

## 维护与验证

新增音效应更新配方目录，保证启动预热覆盖所有合法参数组合。新增乐器层需要同时更新 Boss 调度、
原生协议校验和混音层索引；新增宿主方法需要明确能力字段，并保留旧宿主路径。

`Game.audio.diagnosticSnapshot()` 包含会话状态、缓存大小、原生总线声部数、接收/拒绝批次数、
用户增益、音乐增益/截止频率、渲染帧数及 AudioTrack underrun，还包含加载进度、待合成/待发数量、
批量能力和最近失败原因 `lastError`（无需开启高频诊断也可读取）。`dropped` 同时包含容量、暂停和失焦拒绝，
不能单独用来断言声部过载；帧数停止增长才是后台写线程停止的验证依据。

```sh
node --test tests/*.test.cjs bench/*.test.mjs
android/gradlew --project-dir android :app:testReleaseUnitTest :app:lintRelease :app:assembleDebug :app:distributeRelease :app:assembleReleaseAndroidTest
CHROME89_PUPPETEER="$PWD/agent-tmp/chrome89-tools/node_modules/puppeteer" node bench/chrome89.mjs
```

release instrumentation 的 `NativeAudioTest` 通过 shell 启动真实 Activity 并等待窗口焦点，
避免设备 ROM 拦截 app 发起的后台 Activity；测试不修改游戏存档。真机验收同时需要检查实际 X5、
全部配乐、部分音量、暂停 UI、前后台和静音后新会话，不能用桌面浏览器代替。
