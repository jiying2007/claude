# claude — 全局工程仓库

本仓库管理本机 Claude Code 的全局工程能力，是 [jiying2007/codex](https://github.com/jiying2007/codex) 的 Claude Code 等价实现。

## 架构（四层）

1. **运行时层**：sessions、history、cache（不纳入版本管理）
2. **控制层**：`control/`（catalog、角色、流程、脚本、知识）
3. **激活层**：`commands/`（symlinks）、`agents/`、`CLAUDE.md`（Claude Code 直接读取）
4. **供应层**：`vendor/`（第三方能力与版本，纳入 git）

> **关键原则**：`commands/` 中的 vendor-sourced 入口是机器本地的软链接，由 `activate-profile.sh` 生成，不纳入 git。本地原创命令（`using-skills.md`、`parallel-collab.md`）以文件形式纳入 git。

## 新机器安装（首次上手）

```bash
# clone 到本地
git clone <repo-url> ~/claude

# 一键安装（team-collab profile）
~/claude/control/scripts/install.sh

# 或指定 profile
~/claude/control/scripts/install.sh solo-dev
```

`install.sh` 自动完成：
- 链接 CLAUDE.md / settings.json / commands/ / agents/ 到 `~/.claude/`
- 按 profile 激活 command symlinks（`activate-profile.sh`）
- 运行 `doctor.sh` 体检

## 日常使用

```bash
# 切换 profile（重建 command symlinks）
~/claude/control/scripts/activate-profile.sh solo-dev

# 一致性体检
~/claude/control/scripts/doctor.sh

# 重新生成 commands/registry.csv（commands.csv 变更后执行）
~/claude/control/scripts/gen-registry.sh
```

## 脚本一览

| 脚本 | 用途 |
|------|------|
| `install.sh` | 新机器首次安装 |
| `activate-profile.sh` | 切换 profile（重建 command symlinks）|
| `gen-registry.sh` | 从 catalog 生成 commands/registry.csv |
| `doctor.sh` | 一致性体检（vendor、symlinks、catalog）|
| `session-start.sh` | SessionStart hook：注入 using-skills 元技能 |

## Profile 说明

| Profile | 能力集 | 适用场景 |
|---------|--------|----------|
| `minimal` | using-skills + caveman + daily summary | 轻量单人任务 |
| `solo-dev` | minimal + debugging + parallel-collab | 个人深度开发 |
| `team-collab` | solo-dev + superpowers 全套 + 团队角色 | 团队协作 |

## 框架核心：自动技能触发

通过 `settings.json` 的 `SessionStart` hook 在每次会话开始时注入 `using-skills` 元技能。Claude 在回答任何问题之前都会先检查是否有匹配的技能（slash command）。

## Vendor 内容

| 来源 | 路径 | 说明 |
|------|------|------|
| superpowers 1.1.9 | `vendor/plugins/superpowers/` | brainstorming/debugging 等全套 |
| session-wrap 3.1.0 | `vendor/skills/session-wrap/` | 会话收尾 |
| commit-daily-summary 3.1.0 | `vendor/skills/commit-daily-summary/` | 提交日报 |
| project-daily-summary 3.1.0 | `vendor/skills/project-daily-summary/` | 项目日报 |
| research-note-wrap 3.1.0 | `vendor/skills/research-note-wrap/` | 调研纪要 |
| worktree-closeout 3.1.0 | `vendor/skills/worktree-closeout/` | Worktree 收口 |
| caveman 1.0.0 | `vendor/skills/caveman/` | 超低 token 沟通模式 |

## 关键约束

1. 第三方内容只放 `vendor/`
2. `commands/` 中 vendor-sourced symlinks 不纳入 git（见 `.gitignore`）
3. `control/catalog/*.csv` 是 SSOT
4. 任何变更后执行 `doctor.sh` 体检
5. 变更 commands.csv 后执行 `gen-registry.sh`

## 目录导航

- 设计方案：`control/knowledge/claude-design-and-usage.md`
- 流程说明：`control/workflows/README.md`
- Catalog 规范：`control/catalog/README.md`
- 脚本说明：`control/scripts/README.md`
