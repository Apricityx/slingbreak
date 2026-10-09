# Slingbreak · 弓引力

无需构建的浏览器游戏，最低支持 Chrome/Chromium 89（含旧版腾讯 X5 WebView）。

## 目录

```text
game/                   浏览器小游戏的完整运行时（可整体独立部署）
  index.html            游戏入口，显式声明脚本和样式加载顺序
  manifest.json         PWA 清单
  src/                  游戏源码，按职责分组
    core/               游戏状态、物理/碰撞、收益与成就
    skills/             技能规则、组合、延迟伤害和持续效果
    bosses/             Boss 插件、里程碑战斗宿主与 Boss 配乐
    render/             Canvas 渲染、输入和主帧循环
    effects/            特效缓存、技能图案、开场及转场演出
    audio/              Web Audio、原生音频适配和诊断
    theme/              调色板与兼容的动态颜色工具
    ui/                 HUD、技能界面、设置、屏幕适配和宿主集成
  styles/               样式与主题令牌，保持原有加载顺序
  vendor/               第三方运行库与图标子集生成器
  icons/                PWA 图标
tests/                  Node 回归测试
bench/                  浏览器基准页、驱动与测试工具自检
  particles.html        普通碎屑/帧时间基准入口
  results/              本地生成的报告、数据及截图（Git 忽略）
android/                内置 X5 的 arm64 Android 客户端与 Release 更新器
docs/                   设计和兼容性说明
agent-tmp/              浏览器、临时快照及验收产物（Git 忽略）
```

本次目录整理不改变模块实现：仍使用普通脚本扩展 `window.Game`，不是 ES module 或 ECS 迁移。新增模块时，在对应的 `game/src/` 子目录创建文件，并在 `game/index.html` 的正确位置添加引用；不能随意调整加载顺序。

## 本地运行

在项目根目录启动静态服务器：

```sh
python3 -m http.server 8080
```

打开 `http://localhost:8080/game/`。部署时完整保留上述相对路径；不需要安装运行时依赖或生成打包文件。

## 验证

```sh
node --test tests/*.test.cjs bench/*.test.mjs
```

浏览器改动还须运行真实 Chromium 89 验收和视觉检查，具体命令见 [兼容性说明](docs/chromium89-compatibility.md)。开发要求统一在 [AGENTS.md](AGENTS.md)。

性能工具见 [普通粒子基准](bench/README.md) 和 [全特效基准](bench/FX-README.md)。普通粒子基准页现在位于 `/bench/particles.html`，不再使用根目录的 `/bench.html`。

添加 Lucide 图标后重新生成子集：

```sh
node game/vendor/build-lucide-subset.cjs
```

基准结果和临时文件只保存在本地，不加入版本控制。

## Android APK

Android 的独立离线客户端使用内置 X5（仅 arm64，A16 使用已验证补丁），支持检查本仓库 GitHub Release、
下载验证和系统确认安装。构建、签名备份及发布命名协议见 [android/README.md](android/README.md)。
