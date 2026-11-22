# Redmi A Pro 75（MiTV-ASTR0）本机升级指南

> 本文是 ASTR0 本机升级、备份、核验与恢复的唯一操作指南。所有步骤均使用 AerialTV 仓库内的脚本和代码；不需要外部 toolkit 或其他仓库外文档。电视地址、签名密钥和户主设置只保存在被 Git 忽略的 `local/` 中，不要写入跟踪文件。

## 设备身份与当前基线

- 机型：Redmi Smart TV A Pro 75" 2025 节能版；型号 `MiTV-ASTR0` / `MiTV_ASTR0`，代号 `blueplanet`。
- 系统：Android 11，API 30。
- Aerial 完整版包名：`com.ts.launcher`；源码 namespace 和 Activity 类仍为 `app.orchard.tv`。
- HOME 组件：`com.ts.launcher/app.orchard.tv.MainActivity`；升级使用 `standard` flavor。
- 本机私有安装所需证书 SHA-256：`47:94:7F:3D:B3:EF:0C:DC:1C:04:55:88:E1:64:B6:80:4B:7C:71:B7:8C:A2:94:0F:33:55:9A:BE:29:DB:C5:D0`。这是证书指纹，不是密钥；私钥不得进入版本库。
- 公开 Aerial Release 使用 `app.orchard.tv`，**不能**覆盖升级本机的 `com.ts.launcher`。
- 截至 2026-11-22，本机已完成本次升级：Aerial 2.15 / versionCode 157（1.97 / code 142 → 2.15；备份 `local/backups/aerial-com.ts.launcher-1.97-code142-before-upgrade-20261122-001055.apk`）。安装前核验通过：包名 `com.ts.launcher`、证书指纹（ASTR0 `47:94:7F:...` 与备份一致）、`.dm`（`assets/aerial-dm/28.dm`）组合安装成功；`dumpsys package dexopt` 为 `status=speed`（install 后脚本 `compile -m speed -f` 的编译态，Android 11 上即为编译，非解释）。
- 2026-11-22 升级后实测：HOME 解析一度回到 `android/com.android.internal.app.ResolverActivity`（`isDefault=false`，覆盖安装重置了默认桌面状态）；安装脚本据此启用 Aerial Home Guard，Home 键能把 Aerial 拉回。
- 2026-11-22 部署（户主明确授权）：执行 `adb shell pm disable-user --user 0 com.mitv.tvhome` 后，HOME 直接解析到 `com.ts.launcher/app.orchard.tv.MainActivity`（`isDefault=true`），Home 键不再经过 PatchWall。已实测：Aerial 内按 Home、从其他 App 按 Home、重启后直接进 Aerial、待机唤醒（ADB 保持）、遥控器、Aerial 屏保、断网恢复均正常。此停用属户主决定，不要擅自恢复。
- 2026-11-14 升级前保存的 1.74 / code 94 APK 不是当前 1.97 的备份。每次升级都要重新备份当时设备上的版本。

## ASTR0 设备配置

仓库的 `app/src/main/assets/devices.json` 为此机型保留了三项修正：

- 隐藏 HDMI 硬件 ID 7、8；本机只有两个实际 HDMI 端口。
- `neverFilterKeys`：此固件上的无障碍按键过滤会吞掉遥控器语音键 `KEYCODE_VOICE`（192）。
- `skipTakeoverWhenDefaultHome`：Aerial 已是默认 HOME 时，不要把未知前台应用误判为 PatchWall 并重新拉起 Aerial 覆盖它。

不要为了升级修改这些规则，也不要停用或卸载 `com.mitv.tvhome` 或其他系统应用；始终保留系统桌面作为可恢复的 HOME。

## 升级前准备

1. 在 AerialTV 仓库根目录执行命令。需要 JDK 17、Android SDK、`adb`、`unzip`，以及本机忽略目录中的 `local/signing.properties` 和它引用的 keystore。
2. Release 构建在缺少本机签名配置时会回退到本机 debug key。**若签名配置/keystore 缺失，或证书指纹不是上面的 ASTR0 指纹，停止升级；不要尝试用 debug key 覆盖安装，也不要按安装脚本提示先卸载。**
3. 从电视当前显示的 ADB/无线调试页面取得本机使用的 endpoint，并只在本机 shell 变量中设置。不要把真实 IP、配对码或端口提交到仓库。Android 11 的无线调试 endpoint/端口可能变化，首次连接也可能需要电视显示的配对码；不要假定 `:5555` 永远可用。

以下示例中的 `TV_IP_OR_IP:PORT` 是占位符，执行前必须替换为电视当前显示的 endpoint：

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@17
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
TV="TV_IP_OR_IP:PORT"
case "$TV" in *:*) ADB_TARGET="$TV" ;; *) ADB_TARGET="$TV:5555" ;; esac
adb connect "$ADB_TARGET"
adb -s "$ADB_TARGET" get-state
adb -s "$ADB_TARGET" shell getprop ro.product.model
adb -s "$ADB_TARGET" shell getprop ro.build.version.sdk
```

继续前必须确认设备型号为 `MiTV-ASTR0` / `MiTV_ASTR0`、SDK 为 `30`，且 `get-state` 返回 `device`。如需 Android 11 无线调试配对，按电视当前显示的配对页操作；不要复用过期端口或配对码。

## 每次升级流程

### 1. 核对当前安装并备份 APK

先记录设备当前版本、包名路径：

```bash
adb -s "$ADB_TARGET" shell dumpsys package com.ts.launcher | grep -E 'versionCode=|versionName='
adb -s "$ADB_TARGET" shell pm path com.ts.launcher
```

确认输出属于预期的 `com.ts.launcher`，并将下面 `OLD_VERSION`、`OLD_CODE` 换成刚才读到的值。以下命令假定 `pm path` 返回一个 `package:` 路径；如果出现多个路径，先停下核实，不要只备份 split APK 的一部分。请在同一个终端会话中按顺序执行本指南的命令：

```bash
OLD_VERSION="1.97" # 用设备当前 versionName 替换
OLD_CODE="142"      # 用设备当前 versionCode 替换
REMOTE_PATHS=$(adb -s "$ADB_TARGET" shell pm path com.ts.launcher | tr -d '\r')
REMOTE_COUNT=$(printf '%s\n' "$REMOTE_PATHS" | grep -c '^package:' || true)
BACKUP="local/backups/aerial-com.ts.launcher-${OLD_VERSION}-code${OLD_CODE}-before-upgrade-$(date +%Y%m%d-%H%M%S).apk"
if [ "$REMOTE_COUNT" -eq 1 ]; then
  REMOTE_APK=$(printf '%s\n' "$REMOTE_PATHS" | sed -n 's/^package://p')
  mkdir -p local/backups
  if [ -e "$BACKUP" ]; then
    printf 'Backup path already exists; stop and choose a new timestamp.\n' >&2
  elif adb -s "$ADB_TARGET" pull "$REMOTE_APK" "$BACKUP"; then
    printf 'Saved: %s\n' "$BACKUP"
  else
    printf 'Backup failed; stop without installing.\n' >&2
  fi
else
  printf 'Expected exactly one installed APK path, got %s; stop without installing.\n' "$REMOTE_COUNT" >&2
fi
```

确认备份文件存在且大小合理。后续构建检查时会一并核对备份 APK 的包名、版本和证书。

此步骤只备份 APK，不备份应用数据，也不保证有对应 `.dm` 文件。保留备份，不要清理其他户主文件。

### 2. 构建并核对待安装包

本机 `local/signing.properties` 及其引用的 keystore 必须存在。构建 `standard` Release，并在安装前核对 APK 的包名、版本与签名：

```bash
./gradlew assembleStandardRelease
APK=app/build/outputs/apk/standard/release/app-standard-release.apk
AAPT2=$(ls "$ANDROID_HOME"/build-tools/*/aapt2 | sort -V | tail -n 1)
APKSIGNER=$(ls "$ANDROID_HOME"/build-tools/*/apksigner | sort -V | tail -n 1)
"$AAPT2" dump badging "$BACKUP" | grep '^package:'
"$APKSIGNER" verify --print-certs "$BACKUP"
"$AAPT2" dump badging "$APK" | grep '^package:'
"$APKSIGNER" verify --print-certs "$APK"
```

备份和待安装包的 `package:` 都应为 `com.ts.launcher`，备份版本应与设备上的旧版本一致；新 APK 的版本应符合本次预期且 versionCode 高于已安装版本。两份 APK 的 `SHA-256` 证书指纹都必须与本指南开头的 ASTR0 指纹一致。格式大小写或冒号不同可以规范化后比较；任何一项不符都停止，不要安装。

### 3. 通过仓库安装脚本覆盖升级

把刚核对过的 APK 交给仓库自带的安装脚本；不要下载公开 Release，也不要用手工 `adb install -r` 替代：

```bash
APK_FILE="$APK" KEEP_ADB=1 TV="$TV" tools/install.sh
```

脚本会按 `standard` flavor 安装本地 APK、恢复 Aerial 所需授权并启动应用。ASTR0 为 API 30，脚本会从 APK 选择匹配的 `assets/aerial-dm/28.dm` 并尝试 APK + `.dm` 组合安装；不需要手工指定其他 API 的 `.dm`。若脚本报告签名不匹配，**不要按提示卸载**，先停止并检查签名配置。

也可以让脚本自行构建并安装：`BUILD=1 KEEP_ADB=1 TV="$TV" tools/install.sh`。此方式没有安装前检查独立构建产物的停顿；推荐优先使用上面的“先构建、检查，再通过 `APK_FILE` 安装”流程。

### 4. 安装后核验

```bash
adb -s "$ADB_TARGET" shell dumpsys package com.ts.launcher | grep -E 'versionCode=|versionName='
adb -s "$ADB_TARGET" shell cmd package resolve-activity --brief \
  -a android.intent.action.MAIN -c android.intent.category.HOME -c android.intent.category.DEFAULT
adb -s "$ADB_TARGET" shell dumpsys package dexopt | grep -A2 'com.ts.launcher]'
```

确认安装版本正确，HOME 解析为 `com.ts.launcher/app.orchard.tv.MainActivity`，dexopt 达到 `speed-profile`（正常情况下原因为 `install-dm`）。在电视上再实际检查遥控器菜单键、语音键、应用切换/返回、Aerial 屏保与待机唤醒。未由机主完成这些交互检查前，不要把它们记录为已验证。

## KEEP_ADB 与恢复

- `KEEP_ADB=1` 通过 Aerial 配置开启保持 ADB 的偏好；Home Guard 运行时会在固件关闭 `adb_enabled` 后尝试恢复它。它不是独立 ADB 服务，也**不保证** Android 11 的无线调试端口、配对或网络 endpoint 永久有效。若电视关闭无线调试或端口变化，需要在电视上查看并重新启用/配对。
- `TV="$TV" tools/restore.sh` 用于停止 Aerial 接管 HOME、把 HOME 交回系统桌面，并让 Aerial 保持安装。执行后按脚本提示重启电视。它不是 APK 降级工具。
- 本机当前为「改包名 + 停用 `com.mitv.tvhome`」模式。恢复原厂桌面：先 `adb shell pm enable --user 0 com.mitv.tvhome`；若同时要把 HOME 交还系统桌面，再执行 `TV="$TV" tools/restore.sh`（它会移除 HOME 角色并设回 `com.mitv.tvhome/.MainActivityUserMode`）。不要把「恢复 PatchWall」当作常规操作，只有户主明确要求时才做。
- APK 降级可能被 Android 以 `INSTALL_FAILED_VERSION_DOWNGRADE` 拒绝；签名不匹配也不能覆盖安装。不要把卸载后重装当作常规回滚：`tools/restore.sh --uninstall` 会卸载 `com.ts.launcher`，可能丢失 Aerial 设置、壁纸及应用数据。只有机主明确接受数据后果并另行决定回滚方案时才考虑卸载。

## 维护此指南

每次完成新的升级后，更新“当前基线与验证边界”中的版本、实测项目和 dexopt 结果。电视 IP、配对码、keystore、密码、家庭设置及备份文件始终只留在被忽略的 `local/`；本指南和其他跟踪文件不得包含这些内容。
