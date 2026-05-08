# claude — 全局工程仓库

本仓库管理本机 Claude Code 的全局工程能力，是 [jiying2007/codex](https://github.com/jiying2007/codex) 的 Claude Code 等价实现。

## 架构

仓库采用四层结构：

1. **运行时层**：sessions、history、cache（不纳入版本管理）
2. **控制层**：`control/`（catalog、角色、流程、脚本、知识）
3. **激活层**：`commands/`、`agents/`、`CLAUDE.md`（Claude Code 直接读取）
4. **供应层**：`vendor/`（第三方能力与版本）

## 快速开始

```bash
# 首次安装：链接到 ~/.claude/
~/claude/control/scripts/install.sh

# 切换 profile
~/claude/control/scripts/activate-profile.sh solo-dev

# 一致性体检
~/claude/control/scripts/doctor.sh
```

## Profile 说明

| Profile | 能力集 | 适用场景 |
|---------|--------|----------|
| `minimal` | using-skills + daily summary | 轻量单人任务 |
| `solo-dev` | minimal + debugging + parallel-collab | 个人深度开发 |
| `team-collab` | solo-dev + superpowers 全套 + 团队角色 | 团队协作 |

## 框架核心：自动技能触发

本框架通过 `settings.json` 的 `SessionStart` hook 在每次会话开始时注入 `using-skills` 元技能。这使得 Claude 在回答任何问题之前都会先检查是否有匹配的技能（slash command）。

## 目录导航

- 设计方案：`control/knowledge/claude-design-and-usage.md`
- 流程说明：`control/workflows/README.md`
- catalog 规范：`control/catalog/README.md`
- 脚本说明：`control/scripts/README.md`

## 关键约束

1. 第三方内容只放 `vendor/`
2. `commands/` 与 `agents/` 仅保留激活层入口
3. `control/catalog/*.csv` 是 SSOT
4. 任何变更后执行 `doctor.sh` 体检
