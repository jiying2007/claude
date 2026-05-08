# 全局 Agent 规则（Claude Code）

本文件约束 Claude Code 在本机工作区中的默认工作方式。

## ★ 核心规则：先检查 Skill，再行动

在回应任何用户消息或采取任何行动之前，先检查是否有匹配的 skill（slash command）。

**每次会话开始时**，`using-skills` 的内容会通过 SessionStart hook 自动注入。遵循它。

## 指令优先级

1. 当前会话中用户的明确要求
2. 仓库自身的 CLAUDE.md / 项目文档
3. 本文件
4. Slash command / skill 流程定义

## 任务分流

### 只读任务
分析、解释、架构说明、代码阅读、纯信息问答——可直接处理。真实 bug 排查优先 `/systematic-debugging`。

### 实现任务
新功能、bug 修复、重构——按任务重量选流程：

| 任务规模 | 流程 |
|----------|------|
| 轻量（单文件、明确修复） | 直接实现 + 定向验证 |
| 中等（多文件、行为变更） | `/brainstorming → /writing-plans → 实现` |
| 复杂（跨模块、并行） | 完整 superpowers 流程 + 角色分工 |

**轻量任务可跳过** brainstorming / writing-plans / worktree，但不可跳过验证。

### 必须确认的操作
删除文件、大规模重构、shared schema、根配置/CI/依赖、数据库变更、git 历史与远程操作。

## Skill 路由（总结类）

| 触发词 | Command |
|--------|---------|
| 会话收尾/结束会话/总结本次会话 | `/session-wrap` |
| 总结提交/今天做了什么（commit 角度） | `/commit-daily-summary` |
| 项目日报/按项目总结今天 | `/project-daily-summary` |
| 调研纪要/分析纪要/输出结论 | `/research-note-wrap` |
| 日报 + 收口附录 | `/project-daily-summary` + `/worktree-closeout` |
| 并行施工/多 agent/parallel | `/parallel-collab` |

## Commit 规范

格式：`<type>(scope): <summary>`
- `summary`：中文、动词开头、≤ 50 字、不加句号
- type：`feat` / `fix` / `refactor` / `docs` / `test` / `chore`

## 沟通风格

- 默认简体中文，技术术语可混用英文
- 代码标识符用英文，代码注释优先中文
- 结论优先，再补背景、依据、权衡
- 不堆砌修饰语，不输出流水账

## 工程约束

- 函数 ≤ 50 行，文件 ≤ 300 行，嵌套 ≤ 3，位置参数 ≤ 3，禁止魔法数字
- 不硬编码密钥/凭证/API Key
- 不虚构命令、退出码或验证结果
- 不在没有验证证据的情况下声称"完成""通过""可提交"
- Safety：不运行破坏性命令（`git reset --hard` 等），除非用户明确要求

## 子代理模型选择

| 任务类型 | 推荐模型 |
|----------|---------|
| 复杂推理、架构、审查 | `claude-opus-4-7` |
| 标准实现、代码修改 | `claude-sonnet-4-6`（默认）|
| 快速、简单任务 | `claude-haiku-4-5` |

显式设置模型时，需说明原因。

## 文档根目录

默认：`$HOME/Documents/Claude`（可用 `CLAUDE_DOCS_ROOT` 覆盖）。
按仓库在工作区中的相对层级映射：
`/home/leiwenjun/work/stock/trading_system` → `$HOME/Documents/Claude/stock/trading_system`
