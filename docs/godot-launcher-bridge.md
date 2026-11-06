# Godot 启动器模式：进度、就绪和启动按钮

Godot 原生版本直接提供启动器模式；不依赖 WebView、JavaScript，也不需要在导出时注入 `prototype.gd`。现有游戏、音频和存档规则仍由原模块负责。

## 入口与界面

- `godot/src/core/launcher.gd`：发现可选 Android 单例、读取真实进度/ready、请求进入并执行保存确认。
- `godot/src/ui/launcher_dock.gd`：0.0.3 改为棋盘左下方的圆环启动控件，与右侧市场按钮同高度、同直径、同底色。加载时显示百分比；真实 ready 后圆环补满，再过渡到带 play 图标的“启动”。不再占用顶部标题栏或底部收益区，顶部品牌恢复显示。
- `godot/src/ui/hud_action_layout.gd`：左右按钮共享几何约定，412px 舞台中市场位于 `(350,722)`、启动位于 `(16,722)`，均为 `46×46`，中心分别为 `(373,745)` 与 `(39,745)`，以舞台中线镜像对称。辉光可超出外框，但实际圆形点击范围与市场外框同尺寸，不拦截透明四角。
- `godot/src/ui/launcher_ring.gdshader`：抗锯齿圆弧、柔和辉光、沿圆弧移动的高光、进度端点、就绪时单次扩散波纹，以及保存中的旋转提示。进度使用 .55s 缓出补间，启动文字在圆环补满时淡入；低动态模式直接呈现最终状态，停止装饰动效。颜色跟随浅色/深色主题，保存失败使用琥珀色圆环和“重试”按钮，错误说明显示在右侧。
- `godot/src/main.gd`：组合这两个模块，不在 UI 或桥接中实现游戏规则。

没有兼容宿主时不显示面板，保持独立游戏的原布局；独立 Android 宿主可继续使用保存/返回桥接而不显示主游戏启动面板。不得依据 `OS.has_feature("Android")` 判断是否为启动器模式，因为普通 Android 应用也可单独运行。

## Android 单例协议

当前兼容已验证双包宿主的单例名 `SlingPrototype`，启动器继续负责 Binder 会话、进程隔离和 Activity 切换。单例至少提供以下方法：

```text
get_progress() -> int        当前主游戏启动进度，显示时限制到 0..100
get_message() -> String      当前阶段文字，空串显示默认消息
is_ready() -> bool           是否允许进入；独立于百分比
should_leave() -> bool       宿主要求保存并退出（按钮、返回键或宿主关闭）
report(event: String)        Godot → 宿主的事件
is_launcher_mode() -> bool   建议提供：true=主游戏遮罩，false=独立小游戏
```

前五个方法缺失任意一个时不启用集成。`is_launcher_mode` 缺失时按旧遮罩宿主处理；新宿主应显式实现，以区分双包原型的独立运行入口。

Android Godot 4.7.2 将 `@UsedByGodot` 方法放在 `JNISingleton` 的 Java 方法表，而非 ClassDB；`has_method("get_progress")` 等会返回 false，即使实际调用有效。`launcher.gd.has_bridge_method()` 对普通 Godot 对象使用 `has_method`，对 JNI 单例兼容 `has_java_method`，必需方法和可选 `is_launcher_mode` 都通过同一个探测入口。不应删除协议完整性检查，也不应仅凭 Android 平台强制认为桥接可用。

进度以 10Hz 读取并仅在状态变化时更新界面。**100% 不代表 ready；99% + `is_ready=true` 可以进入。** 每次点击都会重新读取 ready，防止上一帧的就绪状态失效。就绪不会自动关小游戏。

圆环未收到 ready 时最高显示 99%，即使宿主报告 100% 也不会开放启动；真实 ready 到达后补满圆环并显示“启动”，但桥接内部保留宿主原始百分比。按钮在补间完成前保持禁用，ready 撤销时立即禁用并隐藏。点击后仍执行原有保存握手；保存失败显示“重试”，不删除旧存档。

### Godot 回传事件

```text
ready                 上游场景和 session 已初始化，桥接开始工作
launcher_ui_ready     Godot 已接管启动面板，可隐藏 Android 的重复进度/进入按钮
enter_requested       用户点击进入按钮；宿主应设置 should_leave=true
save_retry_requested  用户在保存失败后重试；宿主重新进入等待确认状态/重置超时
save_failed           同步保存失败，不可当作成功进入主游戏
saved                 等待已有自动保存后，本次存档已写入、flush 并原子替换
```

宿主必须处理 `enter_requested`，不能只提供进度 getter。Android 应在 UI 线程验证当前会话和 ready 后设置退出标记；Godot 收到 `should_leave` 后调用现有 `SlingSession.save()`，成功后暂停场景树并回传 `saved`。宿主收到保存确认才正常完成 Activity 切换。不要直接在 `enter_requested` 时销毁进程。

失败时保留小游戏、显示重试按钮，不清理旧存档；持续的 `should_leave=true` 不会每 100ms 自动重试。用户主动重试先回传 `save_retry_requested`，让宿主在原保存超时之后也能重新等待确认。宿主仍可独立提供明确标注“未保证本次保存”的强制返回入口。

主游戏 ready 与小游戏场景 `ready` 是两个不同方向的状态：前者由宿主提供，后者仅说明 Godot 初始化成功。

## 对接到 SlayTheAmethyst 双包原型

配套宿主改动位于 SlayTheAmethystModded 仓库：

- `PrototypeHost.Bridge` 提供 `is_launcher_mode()`。
- `GodotMinigameActivity` 将 `enter_requested` 接入原有保存退出流程，处理保存重试事件；启动器模式不显示重复的 Android 进度与进入按钮，原生控件仅用于异常恢复。
- `scripts/godot/build_prototype.py` 发现上游 `src/core/launcher.gd` 时直接导出原主场景，不再注入第二个保存/ready 控制器；最小测试场景和旧上游仍保留原型包装。

首次接入需要兼容该单例协议的引擎容器与启动器；0.0.3 圆环改动保持协议不变，仅需更新 PCK，无需改引擎固定 hash。之前已装到手机上的 PCK 不会随本地源码变化。本次不修改旧 Web 实现，也不迁移或删除任何旧存档。

## 回归

```sh
python3 godot/tools/run_checks.py --godot godot --test launcher_test --test ui_test --test button_focus_test --test transition_test
python3 godot/tools/run_checks.py --godot godot --gui --test launcher_test --test interface_input_test

# Android PCK、SHA-256 与版本信息旁文件
python3 godot/tools/build_pack.py --platform android --output agent-tmp/godot/releases/0.0.3/game.pck

# 实际渲染逐帧预览，可用 ffmpeg 转为 GIF
xvfb-run -a godot --path godot --rendering-method gl_compatibility --audio-driver Dummy --script res://tools/preview_launcher.gd
```

`launcher_test` 使用可控的宿主替身验证进度边界、ready 门禁、重复点击、保存失败与重试、真实进度文件、独立入口和主题/弹窗布局。GUI 模式使用真实 Controls 命中测试，并将明色加载、暗色就绪和保存错误截图写入 `agent-tmp/godot/native/launcher-*.png`。替身测试不是 Android Binder 或最新双包真机验收的替代品。

0.0.3 的真实 GL 预览保存在 `agent-tmp/godot/launcher-ring/`，其中 `loading-light.png`、`ready-light.png`、`ready-dark.png` 展示与市场按钮镜像对齐的效果，`symmetric-frames/` 是 30fps 的六秒动效序列。导出资源门禁要求 PCK 含 `launcher.gd/.gdc`、`launcher_dock.gd/.gdc`、共享布局脚本与圆环 shader，避免交付缺少启动控件的内容包。

2026-10-31 本地结果：上述四项 headless 测试和两项 GUI 测试均通过。最新上游面板尚未重新导出、安装到 Android 验收；此前双包原型的真机结论不能替代此次新增上游界面的设备测试。
