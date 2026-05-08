---
description: "用户要求 worktree 收口、分支收口、并行收口或工作树整理时使用，特别是工作跨多个会话时"
---

# worktree-closeout

## 概述

针对跨多个会话、分支或 worktrees 的 Claude 工作的只读收口 triage。

此 skill **不会**自动合并、自动删除、自动推送或自动清理。它询问日期和范围，运行扫描器，读取生成的 artifact，然后将该 artifact 转化为聊天摘要、建议的收口顺序和可立即使用的交接指令。

## 使用时机

- 用户想知道哪些 worktrees 或分支仍需收口
- 工作跨多个会话分割，当前状态不清楚
- 在决定合并 / 保留 / 清理操作之前需要基于日期的扫描
- 想要控制提示和每个项目的收口后续提示

## 不使用时机

- **单个当前会话收尾：** 使用 `/session-wrap`
- **同日项目报告：** 使用 `/project-daily-summary`
- **单个分支已选择进行最终处理：** 使用 `/finishing-a-development-branch`
- **危险的分支操作：** 不要将此 skill 用作自动合并、删除、清理或推送的权限

`/project-daily-summary` 在用户希望进行**同日所有 repo 摘要配合收口附录**时可以可选地调用此 skill。

## 必需流程

### 1. 首先询问日期

在询问任何其他内容之前，解析日期。

- 接受 `YYYY-MM-DD` 或相对日期如"昨天"
- 重述解析的**确切日期**
- 如果用户已提供清晰日期，确认它而不是编造不同的

### 2. 其次询问范围

询问扫描：

- `当前 repo` / `current repo` → 扫描范围 `repo`
- `所有 repo` / `all repos touched that day` → 扫描范围 `all`

不要假设范围。

### 3. 扫描 git 状态

对于每个相关仓库，收集：

```bash
# 列出 worktrees
git worktree list

# 检查每个分支状态
git log --oneline origin/main..HEAD  # 是否超前于 base
git status --short                   # 是否有未提交变更
git branch -vv                       # 追踪状态
```

### 4. 分类每个 worktree / 分支

使用以下分类：

**`safe_prune`（可安全清理）**
- 分支已合并到基础分支
- Worktree 干净
- 适合**手动**确认清理

**`ready_to_merge`（可合并）**
- 分支未合并
- Worktree 干净
- 分支超前于 base
- 最近会话证据表明它是活跃的真实候选

将这些交给 `/finishing-a-development-branch` 当用户想实际完成一个分支时。

**`blocked`（阻塞）**
- 脏 worktree、落后于 base 状态、有活跃变更的 base 分支 worktree，或其他表明项目未准备好最终收口的信号

这些需要先做最小安全的解阻步骤。

**`orphaned`（孤立）**
- 缺少或弱 git/会话证据
- 无法从当前事实自信地判断合并/清理

这些需要重新 triage，不要激进清理。

### 5. 输出聊天摘要

用中文总结扫描结果：

- 扫描日期和范围
- repo / worktree 总数
- 哪些 repos 或分支需要首先关注
- 任何不确定或孤立项，需要手动重新 triage

如果没有需要收口的内容，明确说明，而不是假装有工作要做。

### 6. 输出建议的并行收口顺序

- `Phase 1: 可并行 -> safe_prune`
- `Phase 2: 条件并行 -> ready_to_merge`
- `Phase 3: 串行收尾 -> blocked, orphaned`

不要将 `blocked` 或 `orphaned` 项提升到宽泛的并行合并波。

### 7. 输出每个项目的建议

对于每个收口候选，提供：

```
## <repo-name> / <branch-name>

**分类：** ready_to_merge / safe_prune / blocked / orphaned

**状态：**
- 超前于 main：X 个提交
- 未提交变更：是/否
- 最近活跃：YYYY-MM-DD

**建议操作：**
[具体的下一步]

**如果选择处理这个：**
在新会话中运行 `/finishing-a-development-branch` 并说明你正在处理分支 <branch-name>。
```

## 输出合约

最终收口响应应按此顺序包含：

1. 简短聊天摘要
2. 建议的并行收口顺序
3. 每个项目的建议提示
4. 扫描覆盖范围声明

不要隐藏不确定性。如果证据和当前聊天上下文不一致，指出来。

## 与其他 Skills 的关系

### `/session-wrap`
- `/session-wrap` 关闭**一个当前会话**
- `/worktree-closeout` 为**选定日期跨会话/worktrees** 扫描

### `/project-daily-summary`
- `/project-daily-summary` 仍然是主要的同日、按项目摘要 skill
- 仅当用户还需要基于日期的分支/worktree 收口附录时才使用 `/worktree-closeout`

### `/finishing-a-development-branch`
- `/worktree-closeout` 识别哪些项目是候选
- `/finishing-a-development-branch` 在选择候选后执行单分支完成流程

## 守护栏

- 无自动合并
- 无自动分支删除
- 无自动 worktree 移除
- 无自动推送或 PR 创建
- 如果扫描返回空或模糊，不要编造状态

使用此 skill 来组织收口工作，而不是悄悄执行有风险的 git 操作。
