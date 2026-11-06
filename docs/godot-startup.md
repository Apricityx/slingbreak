# 小游戏品牌启动画面

生产入口为 `godot/scenes/boot.tscn`，不是直接加载 `main.tscn`。引擎原生启动图和轻量入口共用 `assets/boot/splash.png`：鼠尾草绿底、弓箭与砖块、小游戏中英文标题，不显示 Godot 标识、准备特效文案或伪进度。

- 图片包含文字，不依赖启动时字体初始化。`python3 godot/tools/build_boot_art.py` 使用项目字体和 Pillow 重建三倍分辨率 PNG；生成图需要随源码保存，引擎只能直接读取 PNG。
- 原生启动图与入口均居中等比适配，空余区域使用相同底色。等待时是一张完整的静态品牌插画，不放会在主线程资源初始化期间卡住的转圈动画。
- 先提交品牌画面，再加载主场景；原有 GL 特效预热保留，但在遮罩后完成，不再额外显示“准备特效…”。真实会话、首屏和启动器桥接初始化完成后才发 `startup_ready`，再等待一帧实际绘制后揭开遮罩。
- 无最短展示时长、倒计时或第二段强制开场。正常模式用 0.64 秒短交接，让棋盘、HUD 和首轮选卡依次接入；减少动画模式直接交接。遮罩存在时阻止鼠标和键盘操作，首轮选卡动画不会在遮罩下提前播完。
- 不省略存档、主游戏 ready、保存返回或启动器通信门禁。真实错误仍显示错误提示，不把失败伪装成无限加载。

回归：`python3 godot/tools/run_checks.py --godot godot --test boot_test --test transition_test --test launcher_test`；加 `--gui` 检查真实渲染。

真实启动录帧：使用隔离的 `XDG_DATA_HOME` 运行 `xvfb-run -a godot --path godot --fixed-fps 30 --audio-driver Dummy --script res://tools/preview_boot.gd`；可在 `--` 后加 `--dark` 或 `--reduced`。输出在忽略目录 `agent-tmp/godot/boot/`。这验证桌面 GL 启动链路，不能代替 Android 固定引擎 + 新 PCK 的首帧真机验收；也不覆盖启动器在 Godot 初始化之前的原生组件校验时间。
