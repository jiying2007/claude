# bugfix-flow

## 适用场景

生产故障、测试失败、意外行为、性能问题。

## 执行步骤

1. **commander** 确认现象、触发条件、影响范围
2. **systematic-debugging** 根因调查（4 阶段，不得跳过）
3. **implementer** 最小修复（先写失败测试，再实现）
4. **tester** 验证修复 + 回归
5. **reviewer** 确认无副作用
6. **integrator** 收口

## Skill 路由

- 根因调查：`/systematic-debugging`（强制）
- 测试先行：`/test-driven-development`
- 完成前：`/verification-before-completion`
- 收口：`/finishing-a-development-branch`

## 铁律

先根因，再修复。3 次修复失败 = 质疑架构，不是继续修复。
