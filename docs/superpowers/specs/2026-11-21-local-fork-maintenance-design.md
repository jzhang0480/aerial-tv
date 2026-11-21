# 本地 fork 维护方案：上下文分流（设计稿）

日期：2026-11-21
分支：`main`（2026-11-22 由 `claude/package-id-com-ts-launcher` 改名，并推送到 origin/main）
状态：已批准、实施、推送（2026-11-22）

用户决定：
- MISSION.md 对安装/升级命令**只放指针**（指向 `docs/devices/xiaomi-mitv-astr0.md`，不重复命令）。
- `tools/merge-upstream.sh` **要做**（默认构建 standard + guard；`LITE=1` 追加 lite 全量编译检查）。
- 追加核查：上游自分叉点（1.97）起**未改过** `AGENTS.md` 和 `CLAUDE.md`，重写 AGENTS.md 不会引入新的合并冲突点；CLAUDE.md 与上游一致（`@AGENTS.md`），不动。

## 1. 背景与目标

这个本地 fork 存在**一个**目的：把 Aerial 完整版的 applicationId 改成 `com.ts.launcher`，
让它在小米 ASTR0（Redmi Smart TV A Pro 75）上进入系统 HOME 白名单，替换原桌面。

当前痛点：
1. **上下文污染**：`AGENTS.md` 要求新 agent 第一份读 `docs/HANDOFF.md`（775 行）和
   `docs/ARCHITECTURE.md`（376 行）+ `docs/devices/*`（39 个品牌文件）。这些是上游维护者
   的**整个开源项目**的状态（337 issue、几十台电视、官网部署、发版流程），与「ASTR0 一台
   替换桌面」的目标 95% 无关，但 agent 必须读。
2. **合并成本**：上游活跃（2.13/2.14/2.15 连续发版）。用户需要继续追新。

约束（用户已确认）：
- **继续跟进上游**（保留 `git merge upstream/main` 通道，不新建独立仓库）。
- **只有 ASTR0 一台**目标电视。

## 2. 现状勘误（本次勘察的真实数据）

- 本地分支相对 `upstream/main`(2.15) 有 **4 个自有提交**，改 **~50 文件**（代码 18 文件
  /84 行 + docs/devices 等文档）：
  - `8b4fcf0` 改包名（applicationId + 7 脚本/文档，约 23 行）
  - `4f67d29` ASTR0 设备行为（`DeviceProfile.kt` 按功能检测 + 新增 `CoocaaHome.kt`）
  - `13d4dfa` ASTR0 升级文档（`docs/devices/xiaomi-mitv-astr0.md` 133 行）
  - `b23a521` 合并 `upstream/main`(2.15)
- **包名改动本身极小**，且上游后续 112 个提交**未触碰** 4 个包名敏感文件
  （`tools/install.sh`、`tools/restore.sh`、`tools/test_install.py`、`tools/test_restore.py`）
  ——这次 merge 的 4 个包名冲突是**一次性的**（本地在 1.97 改、上游在 2.13 改同一区域），
  以后 merge 不会再重复撞这 4 处。
- **真正的成本是上下文**：775 行 HANDOFF + 376 行 ARCHITECTURE + 39 个 devices 文件，
  agent 每次都要读才能开始干活。
- `main` 分支还停在 1.97（`app.orchard.tv`），所有定制在 `claude/package-id-com-ts-launcher`。
- `.gitignore` 第 9 行 `local/`（无前导斜杠）**误伤** `docs/local/`（git 无前导斜杠的模式
  匹配任意层级）。上游后续也未修。

## 3. 方案（上下文分流，用户已选 A）

**保留完整仓库、git 历史、merge 通道；只把"agent 上下文"做薄。**

代码与历史一个字节不动（`site/`、`lite/`、i18n、非 ASTR0 devices 全部保留可合并），
只改 3 处：

### 3.1 新增 `docs/local/MISSION.md`（被 AGENTS.md 顶置）

约 50–60 行，新 agent **第一份**读的文件，内容：
- **目的**：ASTR0 一台，`com.ts.launcher` 进白名单替换系统桌面；代码 namespace 仍是
  `app.orchard.tv`，Lite 仍 `app.orchard.tv.lite`（不动）。
- **构建**：只 `standard` + `guard`；`lite` 不构建（ASTR0 是 Android 11，用不到 4.x Lite）。
- **上游是"只读素材库"**：`docs/HANDOFF.md`（上游全项目状态，非你的）、
  `docs/ARCHITECTURE.md`、`docs/devices/*`（除 `xiaomi-mitv-astr0.md`）**都不必读**，
  需要时按文件名查；ASTR0 相关只读 `docs/devices/xiaomi-mitv-astr0.md`。
- **合并**：`git merge upstream/main`；包名冲突规则=保留 `com.ts.launcher`（一次性，
  以后不会再撞）；或跑 `tools/merge-upstream.sh` 一键。
- **边界**：不碰 `site/`、非 ASTR0 的 `docs/devices/*`、i18n、`lite/` 的**代码与文件**
  （保留以便合并）；`local/` 永不提交。
- **验证**：ASTR0 真机 release 安装 + `dumpsys package dexopt` = `speed-profile`；
  没在真机验证过不说「已完成」。
- **指针**：安装/升级/备份/核验/恢复的唯一指南是 `docs/devices/xiaomi-mitv-astr0.md`。

### 3.2 重写 `AGENTS.md`（约 41 行 → 约 30 行）

- 保留项目规则（**不安装其他 App / 第三方 SDK / 第三方服务器**、不提交 `local/`、
  5 语言 strings 占位符一致、960×540dp 画布、`Motion` 曲线、`Pressable` 长按语义、
  按功能检测不硬编码机型、遥控器命令关沙箱）。
- 第一行改为：读 `docs/local/MISSION.md`（不再把 775 行 HANDOFF 列为必读）。
- `docs/devices/` 只点名 `xiaomi-mitv-astr0.md`；`docs/LITE.md` 标注「Lite 不构建，仅合并时参考」。
- **不改上游的 `site/agent.md` / `site/en/agent.md`**（上游维护者自己的文档，留着供合并）。

### 3.3 新增 `tools/merge-upstream.sh`（一键同步，约 30–50 行）

1. `git fetch upstream`
2. `git merge upstream/main`
3. 若有未解决冲突：对 4 个包名敏感文件跑 `grep com.ts.launcher` 校验，并 `git diff` 提示冲突块
4. 构建三个 APK 验证（`assembleStandardRelease assembleGuardRelease :lite:assembleRelease`）
5. 成功后打印「记得 `git push origin`」（**不自动 push**——分支名与远程不匹配，且 push 要用户确认）

### 3.4 顺手修 `.gitignore`（1 行）

`local/` → `/local/`，让 `docs/local/` 能被跟踪（上游未修，本地修）。

## 4. 影响面

| 文件 | 动作 |
|---|---|
| `docs/local/MISSION.md` | 新增 |
| `AGENTS.md` | 重写 |
| `tools/merge-upstream.sh` | 新增 |
| `.gitignore` | 改 1 行 |

`site/`、`lite/`、i18n、非 ASTR0 `docs/devices/*`、`docs/HANDOFF.md`、`docs/ARCHITECTURE.md`
**全部不动**（保留可合并；只是 agent 不再必读）。

## 5. 验证

1. 四个文件 diff 审读。
2. `tools/merge-upstream.sh` 跑一次（上游已合并过，应无冲突，验证构建通过）。
3. 模拟新 agent：只读 `AGENTS.md` + `docs/local/MISSION.md`，确认能独立说出
   「目的 / 构建什么 / 怎么合并 / 什么不碰」。
4. ASTR0 真机：标准 release 安装 + dexopt 核验（沿用 `xiaomi-mitv-astr0.md` 流程）。

结果（2026-11-21/22）：

1. ✅ 四个文件已提交（`4a13dc3`）。
2. ✅ 脚本端到端跑通：merge（已最新）→ 包名校验通过 → BUILD SUCCESSFUL（standard + guard）。
3. ✅ 新 AGENTS.md 被 harness 加载，第一份指向 MISSION.md。
4. ⏳ ASTR0 真机核验：2026-11-22 户主升级 2.15 中（1.97/code 142 → 2.15 跨 18 个版本），
   结果待回填。

## 6. 不做的事

- 不新建独立仓库 / subtree（与"继续追新"冲突）。
- 不从工作区 `git rm --cached` 移除 `site/`/`lite/`/i18n/非 ASTR0 devices（会制造每次 merge
  后的"移回"负担）。
- 不改上游 `site/agent.md`、`site/en/agent.md`。
- 不动 `lite/` 代码（保留以便合并）。
- 不自动 push `origin`。
- 不删 `main` 分支（是否删由用户决定）。

## 7. 留待用户决定（2026-11-22 已定）

- `main` 分支（1.97，旧包名）：**已解决**——定制分支推送到 origin/main
  （fast-forward `1002090..4a13dc3`，无需 force），过时的本地 `main` 已删，
  `claude/package-id-com-ts-launcher` 改名为 `main` 并跟踪 origin/main。
  仓库现在本地和远端都只有一条 `main`。
- 方案 B（从工作区移走 `site/`/`lite/` 等）：**不做**，只做 A。
