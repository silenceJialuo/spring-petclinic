#!/bin/bash
# Example hook script for postToolUse event
# Logs tool execution results

# Read JSON input from stdin
INPUT=$(cat)

# Parse JSON fields using jq
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName')
TOOL_ARGS=$(echo "$INPUT" | jq -r '.toolArgs')
RESULT_TYPE=$(echo "$INPUT" | jq -r '.toolResult.resultType')
RESULT_TEXT=$(echo "$INPUT" | jq -r '.toolResult.textResultForLlm')
CWD=$(echo "$INPUT" | jq -r '.cwd')

echo "=== Post-Tool Use Hook ==="
echo "Tool: $TOOL_NAME"
echo "Result Type: $RESULT_TYPE"
echo "Result (first 200 chars): ${RESULT_TEXT:0:200}"
echo ""

# Log to file
LOG_FILE="${CWD}/.copilot/tool-usage.log"
mkdir -p "$(dirname "$LOG_FILE")"
# Replace newlines with spaces for single-line log format
TOOL_NAME_CLEAN=$(echo "$TOOL_NAME" | tr '\n' ' ')
RESULT_TYPE_CLEAN=$(echo "$RESULT_TYPE" | tr '\n' ' ' | xargs)
RESULT_TEXT_CLEAN=$(echo "${RESULT_TEXT:0:200}" | tr '\n' ' ')
echo "$(date): $TOOL_NAME_CLEAN - [$RESULT_TYPE_CLEAN]: $RESULT_TEXT_CLEAN" >> "$LOG_FILE"

echo "Tool usage logged"
