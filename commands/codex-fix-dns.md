---
name: codex-fix-dns
description: >
  Fix Codex CLI DNS resolution failures on Linux caused by musl binary incompatibility
  with systemd-resolved. Triggers when user reports: "codex login失败", "token exchange
  failed", "MCP startup incomplete", "codex_apps failed", "dns error: Try again",
  or codex can't connect to OpenAI/ChatGPT domains. Run ~/claude/scripts/codex-fix-dns.sh to fix.
---

# Codex DNS Fix

## 触发条件

以下任一症状出现时使用本 skill：

```
Token exchange failed: error sending request for url (https://auth.openai.com/oauth/token)
MCP startup incomplete (failed: codex_apps)
dns error: failed to lookup address information: Try again
```

## 根本原因

Codex CLI 使用 `x86_64-unknown-linux-musl` 静态编译二进制。musl 的 DNS resolver 向
systemd-resolved stub (127.0.0.53) 发送原始 UDP 查询，在 GFW DNS 污染 + musl/systemd-resolved
timing 不兼容的环境下会解析失败。glibc 工具（curl、dig）走 NSS 所以正常。

受影响域名：
- `auth.openai.com` — OAuth 登录 / token exchange
- `chatgpt.com` — MCP server (`codex_apps`)，`gpt-5.x` 模型后端

## 修复步骤

**Step 1：运行修复脚本**

```bash
~/claude/scripts/codex-fix-dns.sh
```

脚本做三件事：
1. 通过 Google DoH (`dns.google/resolve`) 获取最新 IP，绕过本地 DNS
2. 用 sudo 更新 `/etc/hosts`（已存在的条目会更新，不会重复）
3. 输出每条域名的操作结果（OK / ADD / UPD）

**Step 2：验证**

```bash
grep -E "openai|chatgpt" /etc/hosts
# 期望输出：
# 104.18.41.241 auth.openai.com
# 104.18.32.47  chatgpt.com
```

**Step 3：重启 Codex**

关闭当前 Codex 会话，重新打开。MCP 连接在启动时建立，必须重启才能生效。

## 异常处理

| 情况 | 处理 |
|------|------|
| 脚本报 `could not resolve via Google DNS` | 检查网络，或手动用 `curl -s "https://dns.google/resolve?name=auth.openai.com&type=A"` 取 IP |
| sudo 失败 | 手动执行：`echo "IP domain" \| sudo tee -a /etc/hosts` |
| 加了 hosts 还是失败 | IP 可能已变，重新跑脚本更新；或检查是否有多条重复条目 |
| 重启后 MCP 仍失败 | 查 `~/.codex/log/codex-tui.log` 最新错误，可能有新域名需要加 |

## CC Switch 关联

CC Switch 会把 codex model 设为 `gpt-5.5`，该 model 走 `chatgpt.com/backend-api/`
而非 `api.openai.com`，引入 chatgpt.com 依赖。

不想让 CC Switch 管 Codex：
```json
// ~/.cc-switch/settings.json
"visibleApps": { "codex": false }
```

## 注意事项

- Cloudflare CDN IP 会变，登录再次失败时重跑脚本即可
- `/etc/hosts` 修改立即生效，无需重启系统
- Codex 必须重启才能重新建立 MCP 连接
