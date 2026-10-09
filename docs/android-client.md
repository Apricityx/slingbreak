# Android X5 客户端

## 实现边界

- `android/` 是独立原生客户端；游戏页面、样式与脚本仍位于 `game/`，是同一份源码。
- 内置 arm64 TBS 46285 / SDK 44286，原始内核摘要固定；API 36 两个版本检查使用确定性的 DEX 补丁。
- 最低 API 28；真实 X5 检查通过后才加载游戏，失败拒绝系统 WebView 回退，release 禁用远程调试。
- 固定 HTTPS 本地资源地址；Gecko 存档只读解码并在游戏脚本启动前插入 X5 缺少的值。
  不覆盖已有 X5 进度，不删除 Gecko profile，不显示迁移弹窗，失败可重试。
- 移除整条原生顶栏和安全区 padding；X5 WebView 铺满 Activity，沉浸式隐藏系统栏，
  覆盖刘海/挖孔区域；client 模式关闭网页安全区及装饰边框，但保持游戏原有比例。
- 加载失败/崩溃改用对话框，不恢复顶栏。系统边缘滑动可临时唤出导航栏。
- 游戏入口使用 `?client=1`，页面设置中的“检查更新”通过受限 URL 命令调用原生更新器，
  不刷新 APK 内资源。仅接受来自内置页面的用户点击，不注入通用 JS bridge、不开放本地 HTTP 服务。
- 原生更新菜单的备用源、已下载更新安装、Release 页面及许可入口移到页面设置的“客户端选项”。
- 音频接口只负责样本缓存、状态及播放；离线 Web Audio 保留音色合成，实际声音全由原生
  AudioTrack 混音输出。版本 2 将输出分为 `effects`/`ui`/`music` 三条有界总线，容量分别为
  64/16/48 声部；配乐按乐器层离线生成并使用 128 项、64 MiB LRU，支持阶段/情绪混音、低通、
  回声和淡入淡出。后台、失焦、暂停、静音或会话重建时丢弃旧的异步音符，恢复后重新同步层级，
  不创建实时 `AudioContext`。支持全部 38 类音效、部分音量和游戏/UI 独立声道；后台/失焦停止输出。
  正式宿主异常停止音频并记录诊断，普通浏览器与旧版宿主仍保留原有 Web Audio 行为。
- 导入/导出通过系统文档选择器，不申请共享存储读取权限。

## 更新器与参考项目的关系

已审阅 `SlayTheAmethystModded` 的 `LauncherUpdateService.kt`、
`LauncherUpdateModels.kt` 和 Gecko 宿主。保留其 latest Release 请求、标签归一化、
版本阶段顺序、正式版本过滤、元数据/下载源独立回退和 HEAD→Range 探测思想。

针对本游戏独立实现 Java 更新器，不搬入参考项目的 Compose、Watt 网络服务、
外置引擎、多分支 slim/full 选择或加载遮罩。
区别：GitHub 优先，镜像需明确启用；未知标签不自动更新；按设备 ABI 选择 APK；
增加密码学签名验证、防降级和包名检查。展示最新一版说明，不聚合历史版本说明。

## 签名及发布

正式密钥与凭据只保存在忽略的 `android/keystore/` 和 `android/signing.properties`。
需独立加密备份；后续签名一致且 versionCode 增加才能覆盖安装。
构建/Release 附件协议见 [android/README.md](../android/README.md)。

本次工作不会自动创建 GitHub Release，不将 APK、密钥、浏览器/真机测试截图提交 Git。
由于当前仓库没有正式 Release，联网“发现新版本→下载 GitHub 附件→覆盖安装”
需要发布真正的后续版本后才能完成最终线上验收。测试替代场景不能被描述为线上更新成功。

## X5 与原生音频验收（2026-10-09）

- 当前构建为 `1.0.1` / versionCode `2`，仅 arm64-v8a。已在用户指定的
  `10.126.126.2:5555`（2206122SC、Android 16/API 36）覆盖安装 release 与 debug，保留应用数据。
- debug 实际 UA 为 Chromium `89.0.4389.72` / TBS `046285`，真实 X5 加载正常。
- Node 回归 374 项、Android 单元测试 42 项全部通过；debug/release/instrumentation 构建和 lint 通过。
  lint 有 3 个警告（工具链版本、兼容性 API、JavaScript 设置），无错误。
- release instrumentation 的 `NativeAudioTest` 和 `GeckoMigrationReadTest` 均通过；迁移测试只读 fixture，
  音频测试验证会话校验、部分音量、暂停 UI、音乐上传/播放/混音及释放。
- 真实 Chromium `89.0.4389.0` 兼容性 gate 通过，无页面异常；已复核界面与 Boss 截图。
- 全部 38 类音效在此前真机音频验收中通过。此次验证眼、蛇、钟三套现有配乐的阶段 1/3、
  眩晕及专属情绪，音乐全部进入原生总线；实时 `AudioContext` 创建数为 0。
  35%/70% 增益、暂停时 UI 提示、恢复、音量归零及新会话均验证通过；该轮无声部拒绝、页面异常或 underrun。
- 单独后台验收中声部清空、连续两次渲染帧数相同，前台恢复到 19 个音乐声部；死亡配乐最终增益为 0。
  焦点交接期间有预期播放拒绝，AudioTrack underrun 始终为 0。
- 当前 APK 位于 `android/app/build/outputs/distribution/slingbreak-1.0.1-arm64-v8a.apk`，
  配套 SHA-256 和 APK v2 数字签名校验通过。构建、设备日志和截图保存在忽略的 `agent-tmp/x5-lab/audio-bus-*`。
  此次结果不证明扬声器的主观音质、端到端延迟或所有 Android 设备兼容性。
- 原生整体低通/软限幅与浏览器音乐滤波/压缩器存在差异；维护约定见 [音频总线文档](audio-bus.md)。

## Gecko 客户端历史构建与验收记录

- 正式版本：`1.0.0`，versionCode `1`；发布包位于
  `android/app/build/outputs/distribution/`，包含 arm64-v8a、armeabi-v7a、x86_64
  三个 APK 及对应 SHA-256 文件。
- 构建验证：`:app:assembleRelease`、`:app:testReleaseUnitTest`、`:app:lintRelease`
  和 `:app:assembleReleaseAndroidTest` 成功；Android 单元测试 26 项通过，lint 为
  0 个错误、2 个警告。网页回归 `node --test tests/*.test.cjs bench/*.test.mjs`
  为 363 项通过。
- client/全屏回归：真实 Chromium 89.0.4389.0 的全部 19 个检查通过，涵盖普通网页、
  launcher、本地文件和 client 设置；亮色/深色截图位于被忽略的
  `agent-tmp/chrome89-compat/client-settings-*.png`。这些截图来自桌面浏览器，
  只能验证 UI 和浏览器中的无宿主提示，不能证明 Android 原生导航拦截及刘海屏效果。
- release 已启用 R8/资源压缩；instrumentation APK 的 Error Prone 注解警告使用
  单独的 `proguard-test-rules.pro` 处理，不放宽正式 APK 的规则。
- 交付 APK 三个架构均通过 `apksigner` 的 APK v2 签名验证，三个 `.sha256` 文件均校验
  成功。正式签名证书保持为长期发布密钥；密钥和凭据没有进入 Git 或 APK 交付目录。
- 为验证防降级、同版本拒绝、标签不匹配、篡改拒绝和同签名升级，已用同一正式密钥构建
  仅测试用的 `1.1.0` / versionCode `2` fixture，已归档到被忽略的
  `agent-tmp/android-update-fixture/`。它不是 GitHub Release，也不是交付版。

### 历史设备连接状态（已被上方 X5 验收记录更新）

用户指定的 ADB 目标为 `10.126.126.1:5555`。该地址可以响应网络探测，但截至本次验收
  `nc` 和 `adb connect` 均返回 `Connection refused`。当前另有其他已连接设备，
  但未擅自改用它们。因此尚未
  在该设备安装或启动 APK，也尚未执行渲染、交互、音频、后台恢复、存档导入导出或
  instrumentation 验证；没有把这些项目描述为通过。
  新增的原生命令触发、无顶栏全屏、刘海/挖孔及系统边缘滑动行为也仍待指定设备验收。

设备开放 ADB 后，可按以下顺序继续，不要卸载当前应用或清除数据：

```sh
adb connect 10.126.126.1:5555
adb -s 10.126.126.1:5555 install -r android/app/build/outputs/distribution/slingbreak-1.0.0-arm64-v8a.apk
adb -s 10.126.126.1:5555 push agent-tmp/android-update-fixture/slingbreak-1.1.0-arm64-v8a.apk /sdcard/Android/data/io.github.apricityx.slingbreak/files/update-fixture.apk
adb -s 10.126.126.1:5555 install -r android/app/build/outputs/apk/androidTest/release/app-release-androidTest.apk
```

instrumentation runner 需要传入 `-e fixtureVersion 1.1.0`；fixture 应在正式 APK
已安装的前提下使用，测试完成后不要把 fixture 当作线上发布版本。当前 GitHub
`/releases/latest` 返回 HTTP 404，线上发现新版、下载附件和覆盖安装仍待真正发布
后续 Release 才能验收。
