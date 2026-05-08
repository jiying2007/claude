# Claude Code 全局工程化设计方案

- 版本：v1.0.0
- 更新时间：2026-05-08

## 1. 架构设计

### 1.1 四层架构

1. **运行时层**：sessions、history、cache——不纳入版本管理
2. **控制层**：`control/`——catalog（SSOT）、角色、流程、脚本、知识
3. **激活层**：`commands/`、`agents/`、`CLAUDE.md`——Claude Code 直接读取
4. **供应层**：`vendor/`——第三方能力版本（superpowers + 个人 skills）

### 1.2 核心原则

1. 第三方内容只放 `vendor/`，不直接放 `commands/` 根目录
2. `control/catalog/*.csv` 是 SSOT，驱动一切自动化
3. SessionStart hook 自动注入 `using-skills`，无需手动调用
4. profile 驱动能力分级（minimal / solo-dev / team-collab）
5. 升级采用"新增版本目录 + 切换激活"策略，保证可回滚

### 1.3 与 Codex 的对应关系

| Codex | Claude Code |
|-------|-------------|
| `config.toml` | `settings.json` |
| `AGENTS.md` | `CLAUDE.md` |
| `skills/` | `commands/`（slash commands）|
| `spawn_agent` / `wait` | Agent 工具（`run_in_background`）|
| `update_plan` | TaskCreate / TaskUpdate |
| `~/.codex/sessions/` | `~/.claude/projects/` |
| `rtk <command>` | 直接 Bash（Claude Code 无需 rtk 前缀）|

### 1.4 自动触发机制

SessionStart hook (`settings.json`) → `session-start.sh` →
注入 `using-skills.md` 内容 → Claude 在每次回应前检查 skill

## 2. 使用说明

### 2.1 首次安装

```bash
~/claude/control/scripts/install.sh
~/claude/control/scripts/doctor.sh
```

### 2.2 Profile 建议

- `minimal`：日常问答、轻量单文件修改
- `solo-dev`：个人深度开发（调试、日报、并行）
- `team-collab`：团队项目（完整 superpowers + 角色分工）

### 2.3 新增 Command

1. 在 `commands/` 创建 `<name>.md`
2. 在 `control/catalog/commands.csv` 增加记录
3. 执行 `doctor.sh` 确认

### 2.4 新增 Agent

1. 在 `agents/` 创建 `<name>.md`
2. 在 `control/catalog/agents.csv` 增加记录
3. 执行 `doctor.sh` 确认

### 2.5 更新 superpowers

1. 将新版本放入 `vendor/plugins/superpowers/<new-version>/`
2. 更新 `control/catalog/commands.csv` 中各 source_rel 路径
3. 执行 `doctor.sh` 确认
