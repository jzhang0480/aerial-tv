# 本地使命：ASTR0 白名单桌面替换

> 本仓库任何新 agent 的第一入口。先读本文件，再读 `docs/devices/xiaomi-mitv-astr0.md`。
> 本仓库是上游开源项目 `pengchujin/aerial-tv` 的本地 fork。上游的项目状态
> （`docs/HANDOFF.md`、`site/`、`docs/devices/` 里的大多数文件）**不是我们的目标**，
> 保留只是为了能持续合并上游。

## 目标

- 只有一台目标电视：小米 ASTR0（Redmi Smart TV A Pro 75，Android 11）。
- 把 Aerial 的 applicationId 改成 `com.ts.launcher`，进入小米系统 HOME 白名单，
  替换原桌面。这是本 fork 存在的唯一理由。
- 代码 namespace 和类名保持 `app.orchard.tv`；Lite 保持 `app.orchard.tv.lite`。
- 公开 Release（包名 `app.orchard.tv`）**不能**用于本机升级；`com.ts.launcher`
  必须始终从本仓库本地构建。

## 当前部署状态（2026-11-22）

- 电视：Aerial 2.15（`com.ts.launcher`）。`com.mitv.tvhome` 已由户主明确授权停用
  （`pm disable-user --user 0 com.mitv.tvhome`），HOME 直接解析到
  `com.ts.launcher/app.orchard.tv.MainActivity`（`isDefault=true`）。
- 已实测：Aerial 内按 Home、从其他 App 按 Home、重启后直接进 Aerial、待机唤醒
  （ADB 保持）、遥控器、Aerial 屏保、断网恢复。
- **不要擅自恢复 PatchWall**；只有户主明确要求时才 `pm enable --user 0 com.mitv.tvhome`，
  完整回滚见 `docs/devices/xiaomi-mitv-astr0.md`。
- 工作区是 sparse-checkout（`tools/sparse.sh`）：`site/`、`docs/HANDOFF.md`、
  `docs/LITE.md`、非 ASTR0 的 `docs/devices/*` 不在本地，仍在 git 中。
- 仓库 `main` 已合并上游 2.16（versionCode 159）；电视上仍是 2.15（157）。升级电视是
  单独的机主决定，按 `docs/devices/xiaomi-mitv-astr0.md` 执行，未安装前不得把 2.16 记为已核验。

## 构建与安装

- `export JAVA_HOME=/opt/homebrew/opt/openjdk@17`
- 只构建 `standard` + `guard`：`./gradlew assembleStandardRelease assembleGuardRelease`
- 不构建、不安装 `lite`（ASTR0 是 Android 11，用不到 4.x Lite）。
- 安装/升级/备份/核验/恢复的唯一指南：`docs/devices/xiaomi-mitv-astr0.md`，
  命令不在此重复，以那份文档为准。
- 电视上测试一律用 release 版，连同 APK 里的 .dm 一起装；装完看
  `dumpsys package dexopt` 已编译（ASTR0 上脚本 `compile -m speed -f` 后是 `status=speed`）。

## 跟上游同步

- 一键：`tools/merge-upstream.sh`（fetch + merge + 包名校验 + 构建）；
  或手动 `git fetch upstream && git merge upstream/main`。
- 合并冲突规则：我们没定制过的文件取上游版本；我们定制过的文件
  （applicationId、`tools/install.sh`、`tools/restore.sh`、`tools/test_install.py`、
  `tools/test_restore.py`、ASTR0 相关代码与文档）保留本地的 `com.ts.launcher`。
- 合并后必须构建并在 ASTR0 真机核验，才能说「已完成」。
- 不自动 push；推 `origin` 是用户动作。

## 边界（不碰的东西）

- `site/`、`lite/`（代码）、i18n `values-ru/uk/kk`、非 ASTR0 的 `docs/devices/*`：
  为合并保留，不修改、不必读。
- `docs/HANDOFF.md`（上游全项目状态，775 行）和 `docs/ARCHITECTURE.md` 不必读，
  需要时按文件名查。
- `local/`（签名密钥、电视 IP、户主数据）永不提交。
- 没有在真机上验证过的功能，不要说「已完成」。
