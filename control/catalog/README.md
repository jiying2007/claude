# Catalog 说明

本目录是 `~/claude` 的单一事实源（SSOT），驱动以下自动化：

1. `activate-profile.sh`：按 profile 激活 commands / agents。
2. `doctor.sh`：检查目录结构、catalog 一致性。
3. `install.sh`：首次安装，链接到 `~/.claude/`。

## 文件清单

- `profiles.csv`：场景配置与并行策略。
- `commands.csv`：commands 来源、版本、适用 profile。
- `agents.csv`：agent 定义来源、适用 profile。

## CSV 约定

1. 逗号分隔，第一行为表头。
2. 多值字段使用 `|` 分隔。
3. 布尔字段使用 `1` / `0`。
4. 相对路径均相对 `~/claude` 根目录。

## 变更流程

1. 修改对应 CSV。
2. 执行 `activate-profile.sh`。
3. 执行 `doctor.sh` 确认无错误。
