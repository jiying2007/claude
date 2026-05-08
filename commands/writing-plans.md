---
description: "有规格或需求时，在触碰代码之前使用——编写综合实现计划"
---

# Writing Plans

## 概述

编写综合实现计划，假设工程师对代码库零上下文且品味存疑。记录他们需要知道的一切：每个任务要修改哪些文件、代码、测试、需要查看的文档、如何测试。把整个计划拆成一口一口的小任务。DRY。YAGNI。TDD。频繁提交。

假设他们是熟练开发者，但对工具集或问题域几乎一无所知。假设他们不太擅长良好的测试设计。

**开始时宣告：** "我正在使用 writing-plans skill 来创建实现计划。"

**上下文：** 应该在专用 worktree 中运行（由 brainstorming skill 创建）。

**计划保存至：** `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`

## 范围检查

如果规格涵盖多个独立子系统，应该在 brainstorming 期间已经拆分为子项目规格。如果没有，建议拆分为独立计划——每个子系统一个。每个计划应该能独立产出可工作、可测试的软件。

## 文件结构

在定义任务之前，列出哪些文件将被创建或修改，以及各自的职责。这是锁定分解决策的地方。

- 设计边界清晰、接口定义良好的单元
- 优先使用专注于单一职责的小文件
- 一起变化的文件应该放在一起。按职责分割，不按技术层次分割
- 在现有代码库中，遵循已建立的模式

## 任务粒度（一口大小）

**每步是一个动作（2-5 分钟）：**
- "编写失败测试" — 一步
- "运行以确认它失败" — 一步
- "实现使测试通过的最小代码" — 一步
- "运行测试并确认通过" — 一步
- "提交" — 一步

## 计划文档头部

**每个计划必须以这个头部开始：**

```markdown
# [Feature Name] 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use `/subagent-driven-development` (recommended) or `/executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** [一句话描述这构建了什么]

**架构：** [2-3 句关于方法]

**技术栈：** [关键技术/库]

---
```

## 任务结构

````markdown
### 任务 N：[组件名]

**文件：**
- 创建：`exact/path/to/file.py`
- 修改：`exact/path/to/existing.py:123-145`
- 测试：`tests/exact/path/to/test.py`

- [ ] **步骤 1：编写失败测试**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **步骤 2：运行测试以确认它失败**

运行：`pytest tests/path/test.py::test_name -v`
预期：FAIL with "function not defined"

- [ ] **步骤 3：编写最小实现**

```python
def function(input):
    return expected
```

- [ ] **步骤 4：运行测试以确认通过**

运行：`pytest tests/path/test.py::test_name -v`
预期：PASS

- [ ] **步骤 5：提交**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## 禁止占位符

每步必须包含工程师需要的实际内容。这些是**计划失败**——永远不要写：
- "TBD"、"TODO"、"稍后实现"、"填写细节"
- "添加适当的错误处理" / "添加验证" / "处理边界情况"
- "为上面写测试"（没有实际测试代码）
- "类似于任务 N"（重复代码——工程师可能乱序读任务）
- 描述做什么而不展示如何做的步骤（代码步骤需要代码块）

## 要点
- 始终使用精确文件路径
- 每步完整代码——如果步骤改变代码，展示代码
- 精确命令及预期输出
- DRY、YAGNI、TDD、频繁提交

## 自检

写完完整计划后，用新视角对照规格检查计划：

**1. 规格覆盖：** 浏览规格中的每个节/需求。能指出实现它的任务吗？列出任何遗漏。

**2. 占位符扫描：** 搜索计划中的红旗——"禁止占位符"部分中的任何模式。修复它们。

**3. 类型一致性：** 后续任务中使用的类型、方法签名和属性名是否与前面任务中定义的一致？

如果发现问题，原地修复。

## 执行移交

保存计划后，提供执行选择：

**"计划完成并已保存至 `docs/superpowers/plans/<filename>.md`。两种执行选项：**

**1. 子代理驱动（推荐）** - 每个任务派发一个新鲜子代理，任务间审查，快速迭代

**2. 内联执行** - 在本会话中使用 `/executing-plans` 执行任务，批量执行配合检查点

**选择哪种方式？"**

**如果选择子代理驱动：**
- **必须使用：** `/subagent-driven-development`

**如果选择内联执行：**
- **必须使用：** `/executing-plans`
