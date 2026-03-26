# Fork 改动记录

本文件记录 veniai/Claude-to-IM-skill fork 相对于上游 op7418/Claude-to-IM-skill 的所有改动。
后续更新或新增功能时参考此文件了解已有修改。

## 依赖变更

- 桥接库依赖从 `file:../Claude-to-IM`（本地路径）改为 `github:veniai/Claude-to-IM`
- 原因：统一到 fork，安装时只需 `npx skills add veniai/Claude-to-IM-skill`
- 同时 fork 了桥接库 op7418/Claude-to-IM → veniai/Claude-to-IM

## 桥接库改动 (veniai/Claude-to-IM)

### context.ts — 4 个可选扩展点

| 字段 | 作用 |
|------|------|
| `updateLLMProvider(provider)` | 运行时热替换 LLM provider |
| `onCommand(command, args, chatId)` | 命令拦截，在内置 switch 之前 |
| `onMessage(text, chatId)` | 非命令消息拦截，在路由到 LLM 之前 |
| `extraHelpLines()` | 给 /help 和 /start 追加自定义行 |

全部 optional，向后兼容。

### bridge-manager.ts

1. `handleMessage`：命令检查之后、消息发给 LLM 之前，调用 `ctx.onMessage`
2. `handleCommand`：内置 switch 之前，调用 `cmdCtx.onCommand`
3. `/start` 和 `/help`：调用 `cmdCtx.extraHelpLines()` 追加内容

## Skill 改动 (src/)

### llm-provider.ts — 1 行

```typescript
settingSources: ['user', 'project'],
```
修复 Claude Agent SDK 不发现 skills 的问题。SDK 默认 `settingSources` 为空数组，不加载文件系统设置。

### main.ts — 新增功能

#### 1. /status 增强

显示当前 binding 的 runtime、CWD、mode、model、session/thread ID、
以及电脑端恢复命令（`claude --resume` 或 `codex resume`）。

#### 2. /sessions 扫描所有本地 session

- 扫描 `~/.codex/sessions/` 和 `~/.claude/projects/`
- 按当前工作目录（CWD）过滤
- 按 runtime 过滤（Claude Code / Codex）
- 按文件修改时间排序（最新优先）
- 显示编号列表 + 用户消息预览
- 回复数字绑定/切换到对应 session

#### 3. /runtime 热切换

`/runtime claude|codex|auto` — 不重启 daemon 即可切换 LLM provider。

#### 4. 数字回复绑定 session

发 `/sessions` 后回复 `1`-`10` 自动绑定对应 session。
TTL 5 分钟过期，Map 超 50 条自动清理过期项。

#### 5. Session 预览提取

解析 JSONL session 文件，跳过系统消息（AGENTS.md、environment_context）
和无意义消息（"你是什么模型？"等），取第一条有意义的用户消息作为预览。

#### 6. autoApprove 默认开启

`config.ts` 中 `CTI_AUTO_APPROVE` 默认为 true（pro 模式）。
设 `CTI_AUTO_APPROVE=false` 可禁用。

#### 7. /new 修复 sdkSessionId 未重置

`store.ts` 的 `upsertChannelBinding` 更新时会重置 `sdkSessionId`。
之前 `/new` 创建新 session 后，旧的 sdkSessionId 保留，导致 CLI 继续 resume 旧 session。

## 数据流

```
用户发消息到 IM
  → bridge-manager.handleMessage()
  → /命令? → handleCommand()
  │    → cmdCtx.onCommand() 先执行（/runtime, /status, /sessions）
  │    → 未命中则 fall through 到内置 switch
  → 非命令 → ctx.onMessage() 先执行（数字绑定 session）
  │    → 返回 undefined 则正常发给 LLM
  → 权限 1/2/3 快捷（原有逻辑不变）
  → 发给 LLM 处理
```

## PR 状态

| 仓库 | PR | 状态 |
|------|----|------|
| op7418/Claude-to-IM | #21 | 等 review |
| op7418/Claude-to-IM-skill | #80 | 等 review |

PR 被合则切回上游，否则继续用 fork。

## 安装方式

```bash
npx skills add veniai/Claude-to-IM-skill
```
