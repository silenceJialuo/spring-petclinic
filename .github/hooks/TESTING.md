# Hook Testing Guide

本目录包含用于测试 GitHub Copilot Agent Hooks 功能的配置文件和脚本。

## 文件说明

### 配置文件

1. **hooks.json** - 完整示例，包含所有支持的 hook 事件
   - 包含所有 6 种事件类型的示例
   - 同时提供 bash 和 PowerShell 命令
   - 适合了解所有可用的 hook 类型

2. **hooks-simple.json** - 简化配置
   - 只包含 `userPromptSubmitted` 和 `errorOccurred`
   - 适合快速测试和入门

3. **hooks-deny-tool.json** - 工具拒绝示例
   - 演示如何使用 `preToolUse` hook 拒绝工具执行
   - 当工具名包含 "dangerous" 时会被拒绝

4. **hooks-with-scripts.json** - 使用外部脚本
   - 调用 `scripts/` 目录中的脚本文件
   - 展示如何组织和使用独立的脚本文件

### 脚本文件

`scripts/` 目录包含可复用的 bash 脚本：

- **log-prompt.sh** - 记录用户提交的 prompt
- **check-tool-safety.sh** - 检查工具安全性并可拒绝执行
- **log-tool-result.sh** - 记录工具执行结果
- **log-error.sh** - 记录错误信息

## 快速开始

### 1. 选择配置文件

根据测试需求选择一个配置文件：

```bash
# 使用完整示例
cp .github/hooks/hooks.json .github/hooks/hooks-active.json

# 或使用简化版本
cp .github/hooks/hooks-simple.json .github/hooks/hooks-active.json

# 或使用脚本版本
cp .github/hooks/hooks-with-scripts.json .github/hooks/hooks-active.json
```

> **注意**: HookService 会读取 `.github/hooks/` 目录下的所有 `.json` 文件

### 2. 测试各个 Hook

#### 测试 userPromptSubmitted
```bash
# 启动 Copilot Edits 会话并提交一个 prompt
# Hook 会在你提交 prompt 时触发
```

#### 测试 preToolUse 和 postToolUse
```bash
# 在 Copilot Edits 中请求使用工具
# 例如: "请帮我创建一个文件"
# preToolUse hook 会在工具执行前触发
# postToolUse hook 会在工具执行后触发
```

#### 测试 errorOccurred
```bash
# 触发一个错误，例如请求一个不可能的操作
# 或者在 tool calling loop 中超过最大迭代次数
```

#### 测试工具拒绝功能
```bash
# 使用 hooks-deny-tool.json
# 然后创建一个名字包含 "dangerous" 的工具
# 该工具的执行会被 hook 拒绝
```

### 3. 查看 Hook 执行结果

Hook 的执行结果会通过以下方式呈现：

1. **UI 显示**: 在 Copilot Edits UI 中显示 hook 执行状态
   - `planned` - Hook 计划执行
   - `success` - Hook 执行成功
   - `failure` - Hook 执行失败

2. **日志文件**: 某些脚本会创建日志文件
   ```bash
   # 查看工具使用日志
   cat .copilot/tool-usage.log
   
   # 查看错误日志
   cat .copilot/errors.log
   ```

3. **控制台输出**: Hook 的 stdout/stderr 会被捕获并显示

## Hook 环境变量

**重要说明**: Hook 脚本通过 **stdin** 接收 JSON 输入，而不是环境变量！

### 正确的读取方式

**Bash:**
```bash
#!/bin/bash
# 从 stdin 读取 JSON
INPUT=$(cat)

# 使用 jq 解析
PROMPT=$(echo "$INPUT" | jq -r '.prompt')
TIMESTAMP=$(echo "$INPUT" | jq -r '.timestamp')
```

**PowerShell:**
```powershell
# 从 stdin 读取 JSON
$input = [Console]::In.ReadToEnd() | ConvertFrom-Json

# 访问属性
$prompt = $input.prompt
$timestamp = $input.timestamp
```

### 输入 JSON 格式

#### userPromptSubmitted
```json
{
  "timestamp": 1704614500000,
  "cwd": "/path/to/project",
  "prompt": "User's prompt text"
}
```

#### preToolUse
```json
{
  "timestamp": 1704614600000,
  "cwd": "/path/to/project",
  "toolName": "bash",
  "toolArgs": "{\"command\":\"npm test\"}"
}
```

#### postToolUse
```json
{
  "timestamp": 1704614700000,
  "cwd": "/path/to/project",
  "toolName": "bash",
  "toolArgs": "{\"command\":\"npm test\"}",
  "toolResult": {
    "resultType": "success",
    "textResultForLlm": "Test results..."
  }
}
```

#### errorOccurred
```json
{
  "timestamp": 1704614800000,
  "cwd": "/path/to/project",
  "error": {
    "message": "Error message",
    "name": "ErrorName",
    "stack": "Stack trace (if enabled)"
  }
}
```

## PreToolUse Hook 响应格式

`preToolUse` hook 是唯一可以控制流程的 hook。它通过 **stdout** 输出 JSON 来决定是否允许工具执行：

### 允许执行
```bash
echo '{"permissionDecision": "allow"}'
```

### 拒绝执行
```bash
echo '{"permissionDecision": "deny", "permissionDecisionReason": "拒绝原因说明"}'
```

**重要提示**: 
- JSON 输出必须写到 **stdout**（不是 stderr）
- 调试信息应该写到 stderr: `echo "Debug info" >&2`
- 确保 JSON 格式正确，使用 `jq` 可以帮助生成有效的 JSON

## 调试技巧

### 1. 检查配置文件语法
```bash
# 验证 JSON 语法
cat .github/hooks/hooks.json | jq .
```

### 2. 测试 Hook 脚本
`cho '{"timestamp":1704614500000,"cwd":"/test","prompt":"test prompt"}' | .github/hooks/scripts/log-prompt.sh

# 测试 preToolUse hook
echo '{"timestamp":1704614600000,"cwd":"/test","toolName":"bash","toolArgs":"{\"command\":\"ls\"}"}' | .github/hooks/scripts/check-tool-safety.sh

# 测试带有危险工具名的情况
echo '{"timestamp":1704614600000,"cwd":"/test","toolName":"dangerous_tool","toolArgs":"{}"}' | .github/hooks/scripts/check-tool-safety
export CWD=$(pwd)
.github/hooks/scripts/log-prompt.sh
```

### 3. 查看 Hook 服务日志
Hook 执行的详细信息会记录在 Copilot 的日志中，通常在：
- VS Code: 输出面板 → Copilot
- 日志级别: 可通过 `github.copilot.advanced.debug.overrideLogLevels` 配置

### 4. 启用 Stack Trace
在 `.vscode/settings.json` 中启用错误堆栈追踪：
```json
{
  "github.copilot.internal.hookErrorOccurredStackTrace": true
}
```

## 常见问题

### Hook 没有被触发？
1. 确认配置文件在 `.github/hooks/` 目录下
2. 确认文件名以 `.json` 结尾
3. 确认 JSON 格式正确
4. 确认脚本有执行权限（`chmod +x`）
5. 确认使用的是 Agent 模式（Copilot Edits）

### Hook 执行超时？
- 调整 `timeoutSec` 参数
- 默认是 30 秒
- 避免在 hook 中执行长时间运行的操作

### PreToolUse Hook 拒绝不生效？
- 确认输出的是正确的 JSON 格式
- 确认 JSON 输出在 stdout 中（不是 stderr）
- 确认没有其他输出混在 JSON 中

### 脚本路径问题？
- 使用相对于 workspace root 的路径
- 或使用 `cwd` 参数指定工作目录
- 确认脚本文件存在且有执行权限

## 示例场景

### 场景 1: 审计所有工具使用
使用 `hooks-with-scripts.json`，所有工具使用会被记录到 `.copilot/tool-usage.log`

### 场景 2: 阻止危险操作
使用 `check-tool-safety.sh`，包含 "rm"、"delete" 等关键词的工具会被拒绝

### 场景 3: 监控错误
使用 `log-error.sh`，所有错误会被记录并可选地发送通知

### 场景 4: 记录用户行为
使用 `log-prompt.sh`，记录所有用户提交的 prompt 用于分析

## 进阶用法

### 1. 多个 Hook 配置
```json
{
  "version": 1,
  "hooks": {
    "preToolUse": [
      {
        "type": "command",
        "bash": "check-security.sh"
      },
      {
        "type": "command",
        "bash": "log-usage.sh"
      }
    ]
  }
}
```

### 2. 环境变量传递
```json
{
  "type": "command",
  "bash": "script.sh",
  "env": {
    "LOG_LEVEL": "debug",
    "NOTIFICATION_URL": "https://example.com/webhook"
  }
}
```

### 3. 指定工作目录
```json
{
  "type": "command",
  "bash": "script.sh",
  "cwd": "scripts"
}
```

## 贡献和反馈

如果你发现 bug 或有改进建议，请提交 issue 或 PR。

## 参考资料

- [Hook Event Types](../../../lib/src/hook/hookType.ts)
- [Hook Service Implementation](../../../lib/src/hook/hookService.ts)
- [Hook Progress Implementation](../../../lib/src/hook/hookProgress.ts)
