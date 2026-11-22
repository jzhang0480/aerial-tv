# 本地工作区收窄与部署状态固化（方案 B）

- 日期：2026-11-22
- 范围：AerialTV 本地 fork 的**维护方式**，不改应用代码与构建产物。

## 1. 意图与原因

这个 fork 的唯一目的是：把 Aerial 的 applicationId 改成 `com.ts.launcher`，进入小米电视
的 HOME 白名单，替换原桌面。上游 `pengchujin/aerial-tv` 的其余内容（官网、Lite、其他机型
适配、全项目状态）只是为保证能持续合并而保留，不是本仓库的目标。

现状的三个缺口：

1. 2026-11-22 的部署状态（停用 `com.mitv.tvhome`、HOME 直连 Aerial）没有写进跟踪文档，
   新 agent 可能把它当成违规状态去"恢复"。
2. 本地改动的"补丁面"没有集中说明，合并上游后只能靠脚本检查。
3. 无关目录（`site/`、`docs/HANDOFF.md`、非 ASTR0 设备文档等）仍在本地工作区，agent 容易误读。

## 2. 目标 / 非目标

**目标**

- 新 agent 打开项目，只读 `AGENTS.md` + `docs/local/MISSION.md` 就能说出：目的、当前部署
  状态、构建方式、什么不能碰。
- 无关文件**不在本地工作区**，但仍完整存在于 git 历史与上游。
- 上游合并通道、构建、安装流程不变。
- 部署状态与回滚命令有唯一出处。

**非目标**

- 不删除任何 git 跟踪文件；不改变上游合并方式；不改应用代码；不动 `lite/` 与 i18n。
- 不把该方案扩展到多台电视（本 fork 只有 ASTR0 一台）。

**反目标**

- 让合并每次都要手工解决删除/修改冲突。
- 让新 agent 误恢复 PatchWall，或误把 `com.ts.launcher` 改回 `app.orchard.tv`。

## 3. 方案对比（已选 B）

| 方案 | 做法 | 代价 |
|---|---|---|
| A | 文件全留，只靠文档约束 | 合并零成本，但 agent 仍会误读无关内容 |
| **B（选中）** | **sparse-checkout 让无关目录本地不落地** | 文件仍在 git/上游，合并不受影响；需一条本地命令恢复视图 |
| C | 从 fork 里删除目录 | 工作区最干净，但每次合并产生删除/修改冲突，维护成本最高 |

选 B：合并通道不动，本地视图收窄，错读从"靠自觉"变成"物理上不存在"。

## 4. 实施内容

### 4.1 sparse-checkout（非 cone 模式）

排除（本地不落地）：

- `site/`
- `docs/HANDOFF.md`
- `docs/LITE.md`
- 非 ASTR0 的 `docs/devices/*`（保留 `xiaomi-mitv-astr0.md`）

保留：`app/`、`lite/`（`settings.gradle.kts` 引用）、`docs/local/`、`docs/superpowers/`、
`tools/`、根目录构建文件。

新增 `tools/sparse.sh`：

- `tools/sparse.sh`（默认 `apply`）：幂等应用上述模式；
- `tools/sparse.sh off`：`git sparse-checkout disable`，恢复完整视图；
- `tools/sparse.sh status`：列出当前 sparse 规则与工作区状态。

sparse 配置写在 `.git/info/sparse-checkout`，不进入版本库；新克隆执行一次 `tools/sparse.sh`
即可得到同样的视图。

### 4.2 文档固化

- `AGENTS.md`：顶部补充"当前部署状态"（`com.mitv.tvhome` 已由户主授权停用，不要擅自恢复）
  与 sparse 说明。
- `docs/local/MISSION.md`：补"当前部署状态 / 回滚命令 / sparse 用法"。
- `docs/devices/xiaomi-mitv-astr0.md`：记录 2026-11-22 部署与验证结论、回滚命令。

### 4.3 合并后不变量检查（`tools/merge-upstream.sh`）

在现有 applicationId 检查之外，合并后追加：

- `app/src/standard/AndroidManifest.xml` 仍声明 `android.intent.category.HOME`
- FileProvider authorities 仍使用 `${applicationId}`
- `revival_account.xml` / `revival_sync.xml` 的 `accountType` 仍为 `com.ts.launcher`

构建后追加：

- aapt2 核对产物 `package: name='com.ts.launcher'`
- aapt2 核对产物仍声明 HOME category
- apksigner 确认产物已签名

任一失败即停止，不安装、不推送。

## 5. 验证

1. `tools/sparse.sh` 执行后：`site/`、`docs/HANDOFF.md`、非 ASTR0 设备文档不在工作区；
   `git status` 干净。
2. `./gradlew assembleStandardRelease assembleGuardRelease` 通过。
3. 只读 `AGENTS.md` + `MISSION.md`，能说出目的、当前部署状态、回滚方式。
4. `tools/sparse.sh off` 后完整视图恢复。

## 6. 回滚

- 工作区视图：`tools/sparse.sh off`。
- 文档/脚本改动：常规 git revert。

## 7. 留给实施者

- 新增 `tools/sparse.sh`、更新三份文档与 `tools/merge-upstream.sh`。
- 不修改应用代码、不重新安装电视端。
