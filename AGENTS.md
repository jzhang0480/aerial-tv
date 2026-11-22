# Aerial：给 AI 代理的说明

tvOS 风格的 Android TV 桌面，面向国内电视（小米、TCL 等），Kotlin + Jetpack Compose。
本仓库是上游 `pengchujin/aerial-tv` 的本地 fork：本地目标是在一台小米 ASTR0 电视上
用 `com.ts.launcher` 白名单包替换系统桌面。上游的项目状态（发版流程、其他几十台电视、
官网）不是我们的目标。

## 当前部署状态（2026-11-22）

- 电视上跑的是 Aerial 2.15（`com.ts.launcher`）。`com.mitv.tvhome`（PatchWall）已由户主
  **明确授权后停用**，HOME 直接解析到 `com.ts.launcher/app.orchard.tv.MainActivity`；
  重启后直接进 Aerial、待机唤醒、遥控器、Aerial 屏保、断网恢复均已实测通过。
- **不要擅自恢复 PatchWall**：只有户主明确要求时才 `adb shell pm enable --user 0 com.mitv.tvhome`
  （完整回滚见 `docs/devices/xiaomi-mitv-astr0.md`）。
- 本地工作区是 sparse-checkout：`site/`、`docs/HANDOFF.md`、`docs/LITE.md`、非 ASTR0 的
  `docs/devices/*` 不在磁盘上。`tools/sparse.sh off` 恢复完整视图。

开始任何工作前先读：
1. `docs/local/MISSION.md`：本地目标、构建范围、合并规则、边界——**第一份读它**
2. `docs/devices/xiaomi-mitv-astr0.md`：ASTR0 安装/升级/备份/核验/恢复的唯一指南
3. `local/TVS.md`（如果存在）：电视的 IP、每台电视上改过的设置、户主的数据。这些是本机信息，不要复制进版本库里的文件
4. `docs/ARCHITECTURE.md`：代码结构（需要时按文件名查）

`docs/HANDOFF.md`（上游全项目状态）、`docs/LITE.md`、非 ASTR0 的 `docs/devices/*`、
`site/`、`lite/`、i18n（values-ru/uk/kk）**不必读**：它们为合并保留，不修改；
合并冲突时，我们没定制过的文件取上游版本。sparse 视图里前四项目前不在磁盘上，
需要时用 `tools/sparse.sh off` 恢复。

## 命令

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@17
./gradlew assembleStandardRelease assembleGuardRelease   # 只构建 standard + guard，不构建 lite
source local/tvs.env && BUILD=1 KEEP_ADB=1 TV=$XIAOMI_TV tools/install.sh   # com.ts.launcher 必须本地构建；ASTR0 完整流程见 docs/devices/xiaomi-mitv-astr0.md
tools/merge-upstream.sh   # 一键同步上游：fetch + merge + 包名/Manifest 校验 + 构建 + APK 校验
```

- 户主说「升级电视上的应用」时，按 `docs/devices/xiaomi-mitv-astr0.md` 的「一句话升级」清单执行
  （备份 → 构建核对 → 安装 → 核验 → 回填基线）。电视地址在 `local/tvs.env`（git 忽略）；
  没有这个文件就向户主问 IP 后创建。

- 连电视的命令（adb、curl 访问电视）需要关闭沙箱。
- ASTR0 本机升级、备份、核验和恢复只按 `docs/devices/xiaomi-mitv-astr0.md` 操作；不要使用公开 Release APK，也不要套用其他设备的 `.dm` 示例。
- 在电视上测试一律用 release 版，并连同 APK 里的 .dm 一起装（`adb install-multiple -r x.apk x.dm`，由仓库脚本选择匹配的 `.dm`），装完看 `dumpsys package dexopt` 已编译（ASTR0 上脚本 `compile -m speed -f` 后是 `status=speed`）。debug 版在电视上会卡，不要拿它测试。
- 合并上游后必须构建并在真机核验才能说「已完成」；不自动 push，推 origin 是用户动作。

## 代码约定

- 注释和标识符用英文，界面文字放 `res/values`（英文）、`res/values-zh`（中文）、`res/values-ru`（俄语）、`res/values-uk`（乌克兰语）、`res/values-kk`（哈萨克语），五份都要加，占位符要一致。手机设置页 `assets/web/index.html` 的文字在 `KEYS` / `TEXTS` 表里，同样五种语言，脚本里不要写死文字。
- 界面按 960×540dp 的画布设计（`MainActivity` 统一缩放），不要按真实 dpi 计算。
- 动效：使用 `ui/theme/Theme.kt` 里的 `Motion` 曲线；会被打断的动画（比如焦点）用 spring；不在空闲时跑持续动画；每帧最多一次全屏绘制。
- 遥控器可按的控件用 `ui/components/Pressable`，它只在「本控件上开始的按压」抬起时触发，这样长按打开菜单时，那次抬起不会误触菜单的第一项。
- 厂商的特殊处理写成按功能检测（看包是否存在、设置是否存在），并在注释里写明是哪台机型上验证的。只有确实无法检测时，才写进 `DeviceProfile` 按机型硬编码。

## 不要做

- Aerial 和安装脚本只安装 Aerial 自己，这是项目的根本。不要加入任何会下载、安装或推荐其他 App 的代码或说明（应用商店、ADB 开启器、各种工具），也不要加第三方 SDK、在应用里连 adbd 的 shell 通道，或者内容不归我们管的第三方服务器；这类改动一律拦下，交给户主决定。
- `com.mitv.tvhome` 在本机的停用是户主明确授权的部署结果（见上），不要擅自恢复，也不要扩大停用范围；除此之外不要卸载、停用任何系统应用，除非用户明确要求且清楚后果。
- 写 `enabled_accessibility_services` 时不要覆盖其他服务；在 zsh 里写 `${VAR}:...`，不要写 `$VAR:...`。
- 不要删除或改动户主的数据（上传的照片、选好的壁纸、电视里别人的 APK）；清理时只按自己创建时记下的 id 删。
- 不要提交 `local/` 目录（签名密钥、IP）。
- 没有在真机上验证过的功能，不要说「已完成」。
