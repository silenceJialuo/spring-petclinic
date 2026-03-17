#!/bin/bash
# Example hook script for preToolUse event
# This script checks tool usage and can approve or deny execution

# Read JSON input from stdin
INPUT=$(cat)

# Parse JSON fields using jq
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName')
TOOL_ARGS=$(echo "$INPUT" | jq -r '.toolArgs')
CWD=$(echo "$INPUT" | jq -r '.cwd')

# Setup log file
LOG_FILE="${CWD}/.copilot/safety-checks.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Log to stderr (won't interfere with JSON output)
echo "=== Pre-Tool Use Hook ===" >&2
echo "Tool: $TOOL_NAME" >&2
echo "Arguments: $TOOL_ARGS" >&2
echo "" >&2

# Block run_in_terminal with dangerous file operations
if [[ "$TOOL_NAME" == "run_in_terminal" ]]; then
    if echo "$TOOL_ARGS" | jq -e '.command' >/dev/null 2>&1; then
        COMMAND=$(echo "$TOOL_ARGS" | jq -r '.command')
        # Check for dangerous file operations
        if echo "$COMMAND" | grep -qE "\brm\b|\bmv\b|\bcp\b|sudo\s+rm|mkfs|format|dd\s+if"; then
            TOOL_NAME_CLEAN=$(echo "$TOOL_NAME" | tr '\n' ' ')
            COMMAND_CLEAN=$(echo "${COMMAND:0:100}" | tr '\n' ' ')
            echo "WARNING: Dangerous command pattern detected!" >&2
            echo "$(date): [DENIED] Tool: $TOOL_NAME_CLEAN - Command: $COMMAND_CLEAN - Reason: File operation detected" >> "$LOG_FILE"
            echo '{"permissionDecision": "deny", "permissionDecisionReason": "Command contains file operations that require manual approval"}'
            exit 0
        fi
        # Check for script interpreters that could be used to bypass restrictions
        if echo "$COMMAND" | grep -qE "^\s*(python[0-9]?|node(js)?|ruby|perl|php|bash\s+-c|sh\s+-c)\b"; then
            TOOL_NAME_CLEAN=$(echo "$TOOL_NAME" | tr '\n' ' ')
            COMMAND_CLEAN=$(echo "${COMMAND:0:100}" | tr '\n' ' ')
            echo "WARNING: Script interpreter detected!" >&2
            echo "$(date): [DENIED] Tool: $TOOL_NAME_CLEAN - Command: $COMMAND_CLEAN - Reason: Script interpreter usage blocked" >> "$LOG_FILE"
            echo '{"permissionDecision": "deny", "permissionDecisionReason": "Script interpreters (python, node, ruby, etc.) require manual approval"}'
            exit 0
        fi
    fi
fi

# Allow by default
echo "Tool usage approved" >&2
TOOL_NAME_CLEAN=$(echo "$TOOL_NAME" | tr '\n' ' ')
# Log command for run_in_terminal
if [[ "$TOOL_NAME" == "run_in_terminal" ]] && echo "$TOOL_ARGS" | jq -e '.command' >/dev/null 2>&1; then
    COMMAND=$(echo "$TOOL_ARGS" | jq -r '.command')
    COMMAND_CLEAN=$(echo "$COMMAND" | tr '\n' ' ')
    echo "$(date): [ALLOWED] Tool: $TOOL_NAME_CLEAN - Command: $COMMAND_CLEAN" >> "$LOG_FILE"
else
    echo "$(date): [ALLOWED] Tool: $TOOL_NAME_CLEAN" >> "$LOG_FILE"
fi
echo '{"permissionDecision": "allow"}'
