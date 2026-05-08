---
description: "开始需要与当前工作区隔离的功能开发时，或在执行实现计划之前使用"
---

# Using Git Worktrees

## 概述

Git worktrees 创建共享同一仓库的隔离工作区，允许在不切换的情况下同时在多个分支上工作。

**核心原则：** 系统化目录选择 + 安全验证 = 可靠隔离。

**开始时宣告：** "我正在使用 using-git-worktrees skill 来设置一个隔离的工作区。"

## 目录选择流程

按此优先级顺序：

### 1. 检查现有目录

```bash
# 按优先级顺序检查
ls -d .worktrees 2>/dev/null     # 首选（隐藏）
ls -d worktrees 2>/dev/null      # 替代
```

**如果找到：** 使用该目录。如果两者都存在，`.worktrees` 优先。

### 2. 检查 CLAUDE.md

```bash
grep -i "worktree.*director" CLAUDE.md 2>/dev/null
```

**如果指定了偏好：** 直接使用，不询问。

### 3. 询问用户

如果没有目录存在且 CLAUDE.md 中没有偏好：

```
未找到 worktree 目录。我应该在哪里创建 worktrees？

1. .worktrees/（项目本地，隐藏）
2. ~/.config/worktrees/<project-name>/（全局位置）

你偏好哪种？
```

## 安全验证

### 对于项目本地目录（.worktrees 或 worktrees）

**必须在创建 worktree 之前验证目录已被忽略：**

```bash
git check-ignore -q .worktrees 2>/dev/null || git check-ignore -q worktrees 2>/dev/null
```

**如果没有被忽略：**

立即修复：
1. 向 .gitignore 添加适当的行
2. 提交变更
3. 继续创建 worktree

**为何关键：** 防止意外将 worktree 内容提交到仓库。

### 对于全局目录（~/.config/worktrees）

不需要 .gitignore 验证——完全在项目外。

## 创建步骤

### 1. 检测项目名称

```bash
project=$(basename "$(git rev-parse --show-toplevel)")
```

### 2. 创建 Worktree

```bash
# 确定完整路径
case $LOCATION in
  .worktrees|worktrees)
    path="$LOCATION/$BRANCH_NAME"
    ;;
  ~/.config/worktrees/*)
    path="~/.config/worktrees/$project/$BRANCH_NAME"
    ;;
esac

# 在新分支上创建 worktree
git worktree add "$path" -b "$BRANCH_NAME"
cd "$path"
```

### 3. 运行项目设置

自动检测并运行适当的设置：

```bash
# Node.js
if [ -f package.json ]; then npm install; fi

# Rust
if [ -f Cargo.toml ]; then cargo build; fi

# Python
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
if [ -f pyproject.toml ]; then poetry install; fi

# Go
if [ -f go.mod ]; then go mod download; fi
```

### 4. 验证干净的基线

运行测试以确保 worktree 从干净状态开始：

```bash
# 使用项目适当的命令
npm test / cargo test / pytest / go test ./...
```

**如果测试失败：** 报告失败，询问是否继续或调查。

**如果测试通过：** 报告已准备好。

### 5. 报告位置

```
Worktree 已准备好，位于 <full-path>
测试通过（<N> 个测试，0 次失败）
已准备好实现 <feature-name>
```

## 快速参考

| 情况 | 行动 |
|------|------|
| `.worktrees/` 存在 | 使用它（验证已忽略）|
| `worktrees/` 存在 | 使用它（验证已忽略）|
| 两者都存在 | 使用 `.worktrees/` |
| 都不存在 | 检查 CLAUDE.md → 询问用户 |
| 目录未被忽略 | 添加到 .gitignore + 提交 |
| 基线测试失败 | 报告失败 + 询问 |
| 无 package.json/Cargo.toml | 跳过依赖安装 |

## 常见错误

### 跳过忽略验证
- **问题：** Worktree 内容被追踪，污染 git 状态
- **修复：** 在创建项目本地 worktree 之前始终使用 `git check-ignore`

### 假设目录位置
- **问题：** 创建不一致，违反项目约定
- **修复：** 遵循优先级：已存在 > CLAUDE.md > 询问

### 在失败测试上继续
- **问题：** 无法区分新 bug 和已存在的问题
- **修复：** 报告失败，获得明确许可再继续

## 集成

**由以下调用：**
- **`/brainstorming`** — 设计批准后在实现之前必须使用
- **`/subagent-driven-development`** — 执行任何任务之前必须使用
- **`/executing-plans`** — 执行任何任务之前必须使用

**配合：**
- **`/finishing-a-development-branch`** — 工作完成后的清理
