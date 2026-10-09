# 弓引力 Android / X5 客户端

原生 Android 外壳 + **内置 arm64 X5/TBS 46285（Chromium 89）** + APK 内游戏资源。
首次启动从 APK 安装内核，不需要下载；仅使用真实 X5，不回退系统 WebView。

- 最低 API 28，仅 arm64-v8a。API 36 在已验证设备上使用确定性的扩展 DEX 补丁；
  未修改原生库，不代表官方支持 Android 16 或所有 16 KB 页大小设备。
- 应用 ID：`io.github.apricityx.slingbreak`；debug 使用独立的 `.debug` ID。
- 固定 `https://appassets.androidplatform.net/assets/game/index.html` 地址，资源由 X5 请求拦截器从 APK 提供。
  更新保持同一 localStorage origin。旧 Gecko profile 只读迁移：验证数据库 origin/schema，
  解码 UTF8/UTF16-LE 和 raw Snappy，只在 X5 缺少对应值时插入，在游戏启动前完成。
  无迁移提示弹窗，不覆盖已有 X5 进度，不删除旧 profile；失败保留源数据，下次重试。
- 独立客户端加载 `index.html?client=1`，设置中的“页面更新”改为“检查更新”，
  调用原生 APK 更新检查；query 不改变存档 origin。**不传 `launcher=1`**：
  那是其他启动器的加载遮罩模式。普通网页的重新获取页面资源功能保持不变。
- 不显示原生顶栏或占位；X5 WebView 铺满 Activity。沉浸式隐藏状态栏/导航栏，
  内容延伸到刘海、挖孔和系统栏区域，client 模式不预留网页安全区或装饰边框。
  保持游戏原有比例，异比例屏幕的剩余区域仍由游戏背景填充；不拉伸、不裁切游戏。
  系统边缘滑动可临时唤出系统栏。加载失败或崩溃改用原生对话框提示。
- release 关闭远程调试；拒绝外部页面和子资源，禁止 iframe、窗口弹出和文件路径访问。
- `SlingNativeAudio` 是仅音频的版本 2 接口，不提供文件、网络或安装功能。
   加载期间分批离线合成并上传全部音效和常用开场配乐；首次用户交互前保持静音。
   同一任务内的播放请求批量跨桥，实际播放由原生 AudioTrack 负责。
   总线固定为 `effects`（64 声部）、`ui`（16 声部）和 `music`（48 声部），各自限流、淘汰和暂停，
   不会让 Boss 配乐挤掉 UI 或关键效果；0–100% 音量、声像、回声、软限幅、优先音效和游戏/UI
   独立声道均由原生混音器处理。配乐由网页侧离线合成并按乐器层缓存，原生侧负责层级增益、低通、
   回声、淡入淡出和 128 项/64 MiB 有界 LRU；暂停、后台、静音和音频会话重建会使未完成的旧音符失效。
   后台、失焦、失去音频焦点时清空音效并暂停输出；静音时释放原生资源，同页恢复复用网页缓存重传。
   页面结束/退出清空缓存；进入 Boss 和战斗时分批预热对应乐句，不把全部速度组合常驻内存。
   宿主异常仅记录错误并停止原生音频，不自动切回实时 Web Audio；普通浏览器保持 Web Audio。
   模块职责、协议与取消规则见 [音频总线文档](../docs/audio-bus.md)。
- 文件导入/导出接入 Android 文件选择器，不申请全盘存储权限。
- 保持原网页字体栈；当前入口及游戏样式没有外部字体或 CDN 运行依赖。
- release 构建启用 R8 代码压缩和未使用资源移除；debug 构建保持可调试，不做压缩。

## 构建

需要 JDK 17+、Python 3、Android SDK Platform 37.1、Build Tools 36.0.0（AGP 自动选用）。
工具链固定为 AGP 9.4.1 / Gradle 9.6.0，不能直接套用参考项目旧工具链。
另需在忽略的 `engine/tbs_core_release.tbs.apk` 放入固定摘要的原始内核，见 [engine/README.md](engine/README.md)。
构建校验原始内核并使用 smali 2.5.2 生成已验证补丁；仅放行 API 36 的两个版本检查。
设备端在 SDK 加载前验证并备份原始扩展，然后替换已解压的扩展；未知版本/摘要拒绝启动。

```sh
cd android
./gradlew :app:testReleaseUnitTest :app:assembleRelease
./gradlew :app:distributeRelease
```

原始 APK：`app/build/outputs/apk/release/`。
发布包：`app/build/outputs/distribution/`，包含规范命名的 APK 和 SHA-256 文件。
没有签名配置时，正式构建明确失败，不会偷偷使用 debug 密钥。
R8 的 mapping 文件位于 `app/build/outputs/mapping/release/`，仅用于崩溃堆栈还原，
不要将其作为 APK 附件发布。

游戏资源由 `syncGameAssets` 从 `game/` 白名单同步到生成目录；不保存另一份游戏源码，
不会夹带 `bench/results/`、临时文件、Git 数据或密钥。浏览器运行方式不变。

## 签名：必须备份

首次构建的长期密钥位于 **`android/keystore/slingbreak-release.jks`**，
凭据位于 **`android/signing.properties`**；均被 Git 忽略。
请将两者加密备份到独立安全位置。**丢失密钥将无法给已安装客户端覆盖更新。**
不要提交、上传为 Release 附件、贴到日志或分享给客户端。

其他机器可参考 `signing.properties.example`。CI 可提供环境变量：
`SLINGBREAK_STORE_FILE`、`SLINGBREAK_STORE_PASSWORD`、`SLINGBREAK_KEY_ALIAS`、
`SLINGBREAK_KEY_PASSWORD`。其中路径相对 `android/` 或使用绝对路径。

## Release 更新协议

页面设置中的“检查更新”提供手动检查；同一区域的“客户端选项”保留已下载更新安装、
备用源设置、GitHub Release 页面和开源许可入口。成功自动检查的间隔为 24 小时，
发现新版只显示简短提示，不强制中断游戏、不自动下载或静默安装。
页面设置中的“检查更新”仅发送 `slingbreak://check-update` 请求；原生拦截并取消导航，
“客户端选项”使用 `slingbreak://client-options`。只接受内置游戏页面的用户点击，
拒绝重定向及其他页面来源。音频桥不参与更新操作，
网页不能指定下载地址、访问私有文件或直接安装 APK。单独在浏览器打开 `?client=1`
只显示需要 Android 客户端的提示，不会刷新资源或启动外部协议。

参考 `SlayTheAmethystModded` 的更新服务，采用：

1. `GET https://api.github.com/repos/Apricityx/slingbreak/releases/latest`。
2. 排除 draft/prerelease；去除 `v`/`V` 前缀，按数值比较 `major.minor.patch`。
   同一版本：`-devN < -RCN < 正式版 < -hotfixN`；不认识的标签拒绝自动更新，
   不采用“字符串不同就更新”的宽松兜底。
3. 选择 `slingbreak-…-<ABI>.apk`，按设备 `SUPPORTED_ABIS` 优先；
   支持 `-universal.apk` 兜底，排除 debug、unsigned 和其他项目附件。
4. 仅允许本仓库、该 tag 下的 HTTPS Release APK；先 HEAD，失败再 Range 探测。
5. GitHub 优先。用户明确开启备用源后，元数据允许 ghproxy.vip / gh.llkk.cc，
   下载额外允许 gh-proxy.com。保持 TLS 验证，不复制参考项目的 Watt/DNS 加速基础设施。
6. 展示最新版 Release 说明和下载源，用户确认后下载；失败可完整重试备用源，
   支持取消，不把半包标记为可安装。仅最新版说明，不聚合跨版本历史。
7. 检查元数据大小、实际下载长度、GitHub `digest` 的 SHA-256（若有）、APK
   **实际数字签名验证**、与当前安装版签名一致、包名、ABI、Android 最低版本、
   APK versionName 与 tag 一致、versionCode 和 versionName 都必须增加。
8. 私有目录保存已验证 APK，通过窄范围 FileProvider 交给 Android 安装确认。
   未授予“安装未知应用”权限时引导用户设置；再次安装前重新验证。取消不清除存档。

仓库没有 Release 时显示“尚未发布正式 Release”；限流、网络错误或没有兼容 APK
与“已是最新版”分开处理，不能把检查失败当作无更新。

### 发布新版

同时提高 `gradle.properties` 中 `appVersionName` 和 `appVersionCode`。
或构建时指定：

```sh
./gradlew :app:distributeRelease -PappVersionName=1.1.0 -PappVersionCode=3
```

用**同一密钥**签名，将 distribution 中对应的 APK 上传到
`Apricityx/slingbreak` 的正式 Release，例如 tag `v1.1.0`：

```text
slingbreak-1.1.0-arm64-v8a.apk
```

发布包里的 `.sha256` 方便人工验证；客户端优先读取 GitHub API 的 asset `digest`，
无 digest 时仍强制检查 APK 数字签名。不要把 debug APK 放进正式更新渠道。
源码提交和 Release 上传需要另行授权，本次构建不会自动发布。

## 测试

```sh
./gradlew :app:testReleaseUnitTest :app:lintRelease
cd ..
node --test tests/*.test.cjs bench/*.test.mjs
```

单元测试覆盖版本比较、Release/ABI/URL/校验和策略、404/网络失败、备用源选择、
下载完整性、取消、验证失败和临时文件清理。真机验收结果记录在 `docs/android-client.md`。
不会把桌面 benchmark FPS 当作手机性能结果。

TBS SDK/内核及第三方许可入口见包内 `assets/NOTICE.md`。内核的修改和再分发授权尚未确认，
本地构建/验证不等于允许对外发布；发布前需核实对应条款。
