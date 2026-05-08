---
description: "完成任务、实现重要功能或合并前使用——派发代码审查子代理"
---

# Requesting Code Review

派发 `code-reviewer` 子代理，在问题级联之前捕获它们。审查者获得精心制作的上下文进行评估——永远不是你的会话历史。这使审查者专注于工作产品，而不是你的思考过程，并为你保留继续工作的上下文。

**核心原则：** 早审查，经常审查。

## 何时请求审查

**强制：**
- 在子代理驱动开发中的每个任务后
- 完成重要功能后
- 合并到 main 之前

**可选但有价值：**
- 当卡住时（新鲜视角）
- 重构前（基线检查）
- 修复复杂 bug 后

## 如何请求

**1. 获取 git SHA：**
```bash
BASE_SHA=$(git rev-parse HEAD~1)  # 或 origin/main
HEAD_SHA=$(git rev-parse HEAD)
```

**2. 使用 Agent 工具派发 code-reviewer 子代理：**

使用 `code-reviewer` agent（定义在 `~/.claude/agents/code-reviewer.md`），填充以下占位符：

- `{WHAT_WAS_IMPLEMENTED}` — 你刚构建了什么
- `{PLAN_OR_REQUIREMENTS}` — 它应该做什么
- `{BASE_SHA}` — 起始提交
- `{HEAD_SHA}` — 结束提交
- `{DESCRIPTION}` — 简短摘要

**3. 根据反馈行动：**
- 立即修复 Critical 问题
- 继续前修复 Important 问题
- 记录 Minor 问题留待以后
- 如果审查者错误，用理由推回

## 示例

```
[刚完成任务 2：添加验证函数]

让我在继续之前请求代码审查。

BASE_SHA=$(git log --oneline | grep "Task 1" | head -1 | awk '{print $1}')
HEAD_SHA=$(git rev-parse HEAD)

[派发 code-reviewer 子代理]
  WHAT_WAS_IMPLEMENTED: 对话索引的验证和修复函数
  PLAN_OR_REQUIREMENTS: docs/superpowers/plans/deployment-plan.md 中的任务 2
  BASE_SHA: a7981ec
  HEAD_SHA: 3df7661
  DESCRIPTION: 添加了具有 4 种问题类型的 verifyIndex() 和 repairIndex()

[子代理返回]:
  优点：干净的架构，真实的测试
  问题：
    Important: 缺少进度指示器
    Minor: 进度间隔的魔法数字 (100)
  评估：可以继续

[修复进度指示器]
[继续到任务 3]
```

## 与工作流集成

**子代理驱动开发：**
- 每个任务后审查
- 在问题复杂化之前捕获它们
- 修复后再移动到下一个任务

**执行计划：**
- 每批次后审查（3 个任务）
- 获取反馈，应用，继续

**临时开发：**
- 合并前审查
- 卡住时审查

## 红旗

**永远不要：**
- 因为"简单"就跳过审查
- 忽略 Critical 问题
- 带着未修复的 Important 问题继续
- 与有效的技术反馈争论

**如果审查者错误：**
- 用技术理由推回
- 展示证明有效的代码/测试
- 请求澄清
