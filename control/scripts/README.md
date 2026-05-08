# Scripts 说明

## 脚本列表

| 脚本 | 用途 |
|------|------|
| `install.sh` | 首次安装，将仓库内容链接到 `~/.claude/` |
| `session-start.sh` | SessionStart hook，注入 using-skills 到每次会话 |
| `doctor.sh` | 一致性体检，检查激活层、hooks、catalog |
| `activate-profile.sh` | 切换 profile（当前版本为标注用） |

## 使用顺序

```bash
# 1. 首次安装
~/claude/control/scripts/install.sh

# 2. 体检
~/claude/control/scripts/doctor.sh

# 3. 切换 profile（可选）
~/claude/control/scripts/activate-profile.sh team-collab
```

## SessionStart Hook

`session-start.sh` 由 `settings.json` 中的 SessionStart hook 调用。

它读取 `commands/using-skills.md` 并输出符合 Claude Code 格式的 JSON，
将 using-skills 内容注入到每次会话的初始上下文中。

这是整个 skills 系统自动触发的关键机制。
