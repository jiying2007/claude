# refactor-flow

## 适用场景

结构优化、复杂度治理、模块解耦、技术债清理。

## 执行步骤

1. **commander** 明确目标（行为不变）、验收标准、回滚策略
2. **architect** 设计边界变更方案，标注风险
3. **tester** 先补测试（保护现有行为）
4. **implementer** 按计划重构（一次一个单元）
5. **reviewer** 确认行为不变、结构改善
6. **integrator** 收口

## Skill 路由

- 实现前：`/brainstorming → /writing-plans`
- 执行：`/executing-plans`（顺序重要时）
- 验证：`/verification-before-completion`

## 约束

- 重构期间禁止同时加功能
- 必须先有覆盖现有行为的测试，再开始重构
- 较大重构拆分为多个独立 PR
