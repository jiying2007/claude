# feature-flow

## 适用场景

新功能开发、行为扩展、新组件/API/脚本。

## 执行步骤

1. **commander** 明确目标、边界、验收标准
2. **architect** 产出边界设计与风险列表
3. **implementer** 分片实现（必要时用 `/subagent-driven-development`）
4. **reviewer** 输出 findings
5. **tester** 执行回归
6. **integrator** 收口并输出 merge plan

## Skill 路由

- 实现前：`/brainstorming → /writing-plans`
- 执行：`/subagent-driven-development`（推荐）或 `/executing-plans`
- 代码审查：`/requesting-code-review`
- 完成前：`/verification-before-completion`
- 收口：`/finishing-a-development-branch`
