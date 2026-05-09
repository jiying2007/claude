---
description: Use when starting any session — establishes that slash commands (skills) must be checked before ANY response, including clarifying questions
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, skip this skill.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
If there is even a 1% chance a skill might apply, you ABSOLUTELY MUST invoke it with the Skill tool.

IF A SKILL APPLIES, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is non-negotiable.
</EXTREMELY-IMPORTANT>

## 指令优先级

1. **用户的明确指令**（CLAUDE.md、项目 CLAUDE.md、直接要求）— 最高优先级
2. **Slash command / skill** — 覆盖默认行为
3. **默认系统行为** — 最低优先级

## 如何使用 Skills

**在 Claude Code 中：** 使用 `Skill` 工具。调用后，skill 内容会被加载并呈现给你——直接遵循它。

## 规则

**在任何回应或行动之前，先调用相关 skill。** 哪怕只有 1% 的可能性，也要用 Skill 工具检查。如果调用后发现该 skill 不适用，可以不使用它。

```
收到用户消息
    ↓
有可能命中任何 skill？
    → 是（哪怕 1%）→ 调用 Skill 工具 → 宣告「正在使用 [skill] 来 [目的]」→ 遵循 skill
    → 确定没有 → 直接回应
```

## 技能优先级

当多个 skill 可能适用时：

1. **过程类优先**（brainstorming、systematic-debugging）— 决定如何处理任务
2. **实现类其次**（subagent-driven-development、executing-plans）— 指导执行

## 红旗 — 停止，你在合理化

| 想法 | 现实 |
|------|------|
| "这只是个简单问题" | 问题就是任务。检查 skill。 |
| "我先需要更多上下文" | Skill 检查在澄清问题之前。 |
| "我先探索一下代码库" | Skills 告诉你如何探索。先检查。 |
| "不需要正式 skill" | 如果 skill 存在，就用它。 |
| "我记得这个 skill" | Skills 会更新。读当前版本。 |
| "这个 skill 太重了" | 简单的事会变复杂。用它。 |
| "先做这一件事" | 做任何事之前先检查。 |

## 可用 Skills（Commands）

### 实现流程
| Command | 触发场景 |
|---------|---------|
| `/brainstorming` | 开始构建任何功能、组件或行为变更之前 |
| `/writing-plans` | 有规格或需求，在触碰代码之前 |
| `/executing-plans` | 有书面实现计划要执行 |
| `/subagent-driven-development` | 执行有独立任务的实现计划（推荐） |
| `/dispatching-parallel-agents` | 面临 2+ 个独立问题域 |

### 调试与质量
| Command | 触发场景 |
|---------|---------|
| `/systematic-debugging` | 遇到任何 bug、测试失败、意外行为 |
| `/test-driven-development` | 实现任何功能或 bugfix 之前 |
| `/requesting-code-review` | 完成任务或重要功能后，合并前 |
| `/receiving-code-review` | 收到代码审查反馈时 |
| `/verification-before-completion` | 即将声明工作完成或提交前 |

### Git 工作流
| Command | 触发场景 |
|---------|---------|
| `/using-git-worktrees` | 开始需要隔离的功能开发 |
| `/finishing-a-development-branch` | 实现完成，需要决定如何整合 |

### 总结与记录
| Command | 触发场景 |
|---------|---------|
| `/session-wrap` | 结束会话、收尾、总结本次会话 |
| `/commit-daily-summary` | 总结今天的 git 提交 |
| `/project-daily-summary` | 按项目汇总今日工作 |
| `/research-note-wrap` | 总结调研分析，输出笔记 |
| `/worktree-closeout` | Worktree / 分支收口 triage |

### 并行协作
| Command | 触发场景 |
|---------|---------|
| `/parallel-collab` | 并行施工、多 agent 协作、CSV TODO 驱动 |

### 基础设施
| Command | 触发场景 |
|---------|---------|
| `/codex-fix-dns` | Codex 登录失败、token exchange failed、MCP startup incomplete、DNS 解析错误 |
