# Copilot Agent Hooks Configuration

This directory contains hook configuration files for GitHub Copilot agent events.

## Files

### `hooks.json`
Complete example with all supported hook events:
- `userPromptSubmitted` - Triggered when user submits a prompt
- `preToolUse` - Triggered before tool execution (can deny execution)
- `postToolUse` - Triggered after tool execution
- `errorOccurred` - Triggered when errors occur

### `hooks-simple.json`
Simplified configuration with just `userPromptSubmitted` and `errorOccurred` hooks.

### `hooks-deny-tool.json`
Example configuration that demonstrates denying tool execution based on tool name.

## Configuration Format

```json
{
  "version": 1,
  "hooks": {
    "<eventType>": [
      {
        "type": "command",
        "bash": "script for Unix/Linux/macOS",
        "powershell": "script for Windows",
        "cwd": "optional/working/directory",
        "env": {
          "VAR_NAME": "value"
        },
        "timeoutSec": 30
      }
    ]
  }
}
```

## How Hook Scripts Work

**IMPORTANT**: Hook scripts receive input via **stdin** as JSON and output responses via **stdout**.

### Reading Input (Bash)
```bash
#!/bin/bash
# Read JSON from stdin
INPUT=$(cat)

# Parse with jq
TIMESTAMP=$(echo "$INPUT" | jq -r '.timestamp')
PROMPT=$(echo "$INPUT" | jq -r '.prompt')
```

### Reading Input (PowerShell)
```powershell
# Read JSON from stdin
$input = [Console]::In.ReadToEnd() | ConvertFrom-Json

# Access properties
$timestamp = $input.timestamp
$prompt = $input.prompt
```

### Outputting Responses

For hooks that need to return decisions (like `preToolUse`), output JSON to stdout:

```bash
# Allow tool execution
echo '{"permissionDecision": "allow"}'

# Deny tool execution
echo '{"permissionDecision": "deny", "permissionDecisionReason": "Reason here"}'
```

**Important**: Use stderr for logging/debugging to avoid interfering with JSON output:
```bash
echo "Debug info" >&2  # Goes to stderr, won't interfere with JSON
echo '{"permissionDecision": "allow"}'  # Goes to stdout
```

## Event Types and Input JSON

### userPromptSubmitted

**Input JSON:**
```json
{
  "timestamp": 1704614500000,
  "cwd": "/path/to/project",
  "prompt": "Fix the authentication bug"
}
```

### preToolUse

**Input JSON:**
```json
{
  "timestamp": 1704614600000,
  "cwd": "/path/to/project",
  "toolName": "bash",
  "toolArgs": "{\"command\":\"npm test\"}"
}
```

**Output JSON** (to control execution):
```json
{
  "permissionDecision": "allow"  // or "deny"
  "permissionDecisionReason": "Optional reason for denial"
}
```

### postToolUse

**Input JSON:**
```json
{
  "timestamp": 1704614700000,
  "cwd": "/path/to/project",
  "toolName": "bash",
  "toolArgs": "{\"command\":\"npm test\"}",
  "toolResult": {
    "resultType": "success",  // or "error", "cancelled"
    "textResultForLlm": "All tests passed"
  }
}
```

### errorOccurred

**Input JSON:**
```json
{
  "timestamp": 1704614800000,
  "cwd": "/path/to/project",
  "error": {
    "message": "Network timeout",
    "name": "TimeoutError",
    "stack": "TimeoutError: Network timeout\n    at ..."
  }
}
```

## Testing

To test these hooks:

1. Copy desired configuration to `.github/hooks/hooks.json` in your workspace
2. Start a Copilot Edits session
3. Perform actions that trigger the hooks:
   - Submit a prompt → `userPromptSubmitted`
   - Use a tool → `preToolUse` and `postToolUse`
   - Cause an error → `errorOccurred`
4. Check hook execution results in the Copilot UI

## Security Considerations

- Hook scripts execute with workspace permissions
- Be cautious with `preToolUse` deny logic - overly restrictive rules may block legitimate operations
- Validate hook script paths and contents
- Use appropriate timeouts to prevent hanging
- Consider audit logging for sensitive operations
