#!/bin/bash
# Example hook script for userPromptSubmitted event

# Read JSON input from stdin
INPUT=$(cat)

# Parse JSON fields using jq
TIMESTAMP=$(echo "$INPUT" | jq -r '.timestamp')
CWD=$(echo "$INPUT" | jq -r '.cwd')
PROMPT=$(echo "$INPUT" | jq -r '.prompt')

echo "=== User Prompt Submitted Hook ==="
echo "Timestamp: $TIMESTAMP"
echo "CWD: $CWD"
echo "Prompt (first 100 chars): ${PROMPT:0:100}"
echo ""

# Log to file
LOG_FILE="${CWD}/.copilot/prompts.log"
mkdir -p "$(dirname "$LOG_FILE")"
# Replace newlines with spaces for single-line log format
PROMPT_CLEAN=$(echo "${PROMPT:0:100}" | tr '\n' ' ')
echo "$(date): User Prompt Submitted - Prompt: $PROMPT_CLEAN" >> "$LOG_FILE"

echo "Prompt logged to file"
