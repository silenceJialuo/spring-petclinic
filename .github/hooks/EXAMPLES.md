# Hook 脚本示例

本文档提供了各种 Hook 脚本的完整示例，遵循官方文档的 stdin/stdout 规范。

## 基础示例

### 1. 简单的日志记录 Hook

记录所有用户提交的 prompt：

```bash
#!/bin/bash
# userPromptSubmitted hook

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt')
TIMESTAMP=$(echo "$INPUT" | jq -r '.timestamp')

# 记录到文件
echo "$(date -d @$((TIMESTAMP/1000))): $PROMPT" >> /var/log/copilot/prompts.log
```

### 2. 允许所有工具 Hook

最简单的 preToolUse hook，允许所有工具执行：

```bash
#!/bin/bash
# preToolUse hook - allow all

INPUT=$(cat)
echo '{"permissionDecision": "allow"}'
```

### 3. 基于工具名称的权限控制

根据工具名称决定是否允许执行：

```bash
#!/bin/bash
# preToolUse hook - tool name based

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName')

# 只允许 view 和 read 类工具
if [[ "$TOOL_NAME" =~ ^(view|read|list) ]]; then
    echo '{"permissionDecision": "allow"}'
else
    echo '{"permissionDecision": "deny", "permissionDecisionReason": "Only read operations are allowed"}'
fi
```

## 高级示例

### 4. 基于命令内容的安全检查

检查 bash 命令的内容，阻止危险操作：

```bash
#!/bin/bash
# preToolUse hook - command content check

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName')

# 只检查 bash 工具
if [ "$TOOL_NAME" != "bash" ]; then
    echo '{"permissionDecision": "allow"}'
    exit 0
fi

# 解析命令内容
TOOL_ARGS=$(echo "$INPUT" | jq -r '.toolArgs')
COMMAND=$(echo "$TOOL_ARGS" | jq -r '.command // empty')

# 如果没有命令，允许
if [ -z "$COMMAND" ]; then
    echo '{"permissionDecision": "allow"}'
    exit 0
fi

# 检查危险模式
DANGEROUS_PATTERNS=(
    "rm -rf /"
    "sudo rm"
    "mkfs"
    "dd if="
    "format"
    "> /dev/sd"
    "curl.*|.*sh"
    "wget.*|.*sh"
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qE "$pattern"; then
        echo '{"permissionDecision": "deny", "permissionDecisionReason": "Command contains dangerous pattern: '"$pattern"'"}'
        exit 0
    fi
done

echo '{"permissionDecision": "allow"}'
```

### 5. 白名单目录检查

只允许在特定目录下执行文件操作：

```bash
#!/bin/bash
# preToolUse hook - directory whitelist

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName')
CWD=$(echo "$INPUT" | jq -r '.cwd')

# 文件操作工具列表
FILE_TOOLS=("edit" "create" "delete" "write")

# 检查是否是文件操作工具
IS_FILE_TOOL=false
for tool in "${FILE_TOOLS[@]}"; do
    if [[ "$TOOL_NAME" == "$tool" ]]; then
        IS_FILE_TOOL=true
        break
    fi
done

if [ "$IS_FILE_TOOL" = false ]; then
    echo '{"permissionDecision": "allow"}'
    exit 0
fi

# 白名单目录
ALLOWED_DIRS=(
    "/workspace/src"
    "/workspace/test"
    "/workspace/docs"
)

# 检查 CWD 是否在白名单中
ALLOWED=false
for dir in "${ALLOWED_DIRS[@]}"; do
    if [[ "$CWD" == "$dir"* ]]; then
        ALLOWED=true
        break
    fi
done

if [ "$ALLOWED" = true ]; then
    echo '{"permissionDecision": "allow"}'
else
    echo '{"permissionDecision": "deny", "permissionDecisionReason": "File operations are only allowed in src/, test/, or docs/ directories"}'
fi
```

### 6. 工作时间限制

只允许在工作时间内执行某些操作：

```bash
#!/bin/bash
# preToolUse hook - working hours check

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName')

# 获取当前小时 (0-23)
CURRENT_HOUR=$(date +%H)

# 检查是否是敏感操作（部署、删除等）
SENSITIVE_TOOLS=("deploy" "delete" "drop")

IS_SENSITIVE=false
for tool in "${SENSITIVE_TOOLS[@]}"; do
    if [[ "$TOOL_NAME" == *"$tool"* ]]; then
        IS_SENSITIVE=true
        break
    fi
done

if [ "$IS_SENSITIVE" = false ]; then
    echo '{"permissionDecision": "allow"}'
    exit 0
fi

# 检查是否在工作时间内 (9:00 - 18:00)
if [ "$CURRENT_HOUR" -ge 9 ] && [ "$CURRENT_HOUR" -lt 18 ]; then
    echo '{"permissionDecision": "allow"}'
else
    echo '{"permissionDecision": "deny", "permissionDecisionReason": "Sensitive operations are only allowed during working hours (9:00-18:00)"}'
fi
```

### 7. 审计日志（结构化）

将所有工具使用记录到结构化日志：

```bash
#!/bin/bash
# postToolUse hook - structured audit log

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName')
RESULT_TYPE=$(echo "$INPUT" | jq -r '.toolResult.resultType')
TIMESTAMP=$(echo "$INPUT" | jq -r '.timestamp')

# 创建结构化日志条目
LOG_ENTRY=$(jq -n \
    --arg ts "$TIMESTAMP" \
    --arg tool "$TOOL_NAME" \
    --arg result "$RESULT_TYPE" \
    --arg user "${USER:-unknown}" \
    '{
        timestamp: $ts,
        tool: $tool,
        result: $result,
        user: $user
    }')

# 追加到 JSON Lines 日志文件
echo "$LOG_ENTRY" >> /var/log/copilot/audit.jsonl
```

### 8. Slack 通知集成

在工具执行失败时发送 Slack 通知：

```bash
#!/bin/bash
# postToolUse hook - Slack notification

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName')
RESULT_TYPE=$(echo "$INPUT" | jq -r '.toolResult.resultType')
RESULT_TEXT=$(echo "$INPUT" | jq -r '.toolResult.textResultForLlm')

# 只在失败时发送通知
if [ "$RESULT_TYPE" != "success" ]; then
    WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
    
    MESSAGE=$(jq -n \
        --arg tool "$TOOL_NAME" \
        --arg result "$RESULT_TEXT" \
        '{
            text: ("Agent Tool Failed: " + $tool),
            blocks: [
                {
                    type: "section",
                    text: {
                        type: "mrkdwn",
                        text: ("*Tool Failed:* " + $tool + "\n*Error:* " + $result)
                    }
                }
            ]
        }')
    
    curl -X POST "$WEBHOOK_URL" \
        -H 'Content-Type: application/json' \
        -d "$MESSAGE" \
        > /dev/null 2>&1
fi
```

### 9. 代码质量检查

在编辑文件前运行 linter：

```bash
#!/bin/bash
# preToolUse hook - code quality check

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName')

# 只检查编辑操作
if [ "$TOOL_NAME" != "edit" ] && [ "$TOOL_NAME" != "create" ]; then
    echo '{"permissionDecision": "allow"}'
    exit 0
fi

# 运行 linter
npm run lint-staged > /tmp/lint-output.txt 2>&1

if [ $? -eq 0 ]; then
    echo '{"permissionDecision": "allow"}'
else
    LINT_ERRORS=$(cat /tmp/lint-output.txt | head -n 10)
    echo '{"permissionDecision": "deny", "permissionDecisionReason": "Code quality check failed. Please fix linting errors first."}'
fi
```

### 10. 多条件组合检查

综合多个条件进行决策：

```bash
#!/bin/bash
# preToolUse hook - multi-condition check

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName')
CWD=$(echo "$INPUT" | jq -r '.cwd')
TIMESTAMP=$(echo "$INPUT" | jq -r '.timestamp')

# 条件 1: 时间检查
CURRENT_HOUR=$(date +%H)
if [ "$CURRENT_HOUR" -lt 6 ] || [ "$CURRENT_HOUR" -gt 22 ]; then
    echo '{"permissionDecision": "deny", "permissionDecisionReason": "Operations not allowed during off-hours (22:00-06:00)"}'
    exit 0
fi

# 条件 2: 工具检查
if [[ "$TOOL_NAME" == *"delete"* ]] || [[ "$TOOL_NAME" == *"drop"* ]]; then
    echo '{"permissionDecision": "deny", "permissionDecisionReason": "Destructive operations require manual approval"}'
    exit 0
fi

# 条件 3: 目录检查
if [[ "$CWD" == *"/production/"* ]]; then
    echo '{"permissionDecision": "deny", "permissionDecisionReason": "Direct operations on production directories are not allowed"}'
    exit 0
fi

# 所有检查通过
echo '{"permissionDecision": "allow"}'
```

## 调试技巧

### 使用 stderr 输出调试信息

```bash
#!/bin/bash
INPUT=$(cat)

# 调试输出（不会影响 JSON 响应）
echo "DEBUG: Received input" >&2
echo "$INPUT" | jq . >&2

TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName')
echo "DEBUG: Processing tool: $TOOL_NAME" >&2

# 实际的 JSON 响应
echo '{"permissionDecision": "allow"}'
```

### 测试脚本

```bash
# 测试 userPromptSubmitted
echo '{"timestamp":1704614500000,"cwd":"/test","prompt":"test"}' | ./your-script.sh

# 测试 preToolUse
echo '{"timestamp":1704614600000,"cwd":"/test","toolName":"bash","toolArgs":"{}"}' | ./your-script.sh

# 测试 postToolUse
echo '{"timestamp":1704614700000,"cwd":"/test","toolName":"bash","toolArgs":"{}","toolResult":{"resultType":"success","textResultForLlm":"Done"}}' | ./your-script.sh
```

### 验证 JSON 输出

```bash
# 确保输出是有效的 JSON
./your-script.sh < test-input.json | jq .

# 如果 jq 能解析，说明 JSON 格式正确
```

## 最佳实践

1. **总是从 stdin 读取输入**: 使用 `INPUT=$(cat)` 或类似方法
2. **使用 jq 解析 JSON**: 可靠且安全
3. **调试信息输出到 stderr**: 使用 `>&2` 重定向
4. **验证 JSON 输出**: 使用 `jq` 验证输出格式
5. **错误处理**: 使用 `set -e` 确保脚本在错误时退出
6. **超时设置**: 为耗时操作设置合理的 `timeoutSec`
7. **日志记录**: 记录重要决策和操作以便审计
8. **安全第一**: 对于 preToolUse hook，默认采取保守策略
