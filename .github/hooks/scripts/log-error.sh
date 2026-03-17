#!/bin/bash
# Example hook script for errorOccurred event

# Read JSON input from stdin
INPUT=$(cat)

# Parse JSON fields using jq
ERROR_NAME=$(echo "$INPUT" | jq -r '.error.name')
ERROR_MESSAGE=$(echo "$INPUT" | jq -r '.error.message')
CWD=$(echo "$INPUT" | jq -r '.cwd')

echo "=== Error Occurred Hook ==="
echo "Error Name: $ERROR_NAME"
echo "Error Message: $ERROR_MESSAGE"
echo ""

# Log to file
ERROR_LOG="${CWD}/.copilot/errors.log"
mkdir -p "$(dirname "$ERROR_LOG")"
# Replace newlines with spaces for single-line log format
ERROR_NAME_CLEAN=$(echo "$ERROR_NAME" | tr '\n' ' ')
ERROR_MESSAGE_CLEAN=$(echo "$ERROR_MESSAGE" | tr '\n' ' ')
echo "$(date): [$ERROR_NAME_CLEAN] $ERROR_MESSAGE_CLEAN" >> "$ERROR_LOG"

# Optional: Send notification (example with macOS notification)
if command -v osascript &> /dev/null; then
    osascript -e "display notification \"$ERROR_MESSAGE\" with title \"Copilot Error: $ERROR_NAME\""
fi

echo "Error logged"
