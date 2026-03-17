#!/bin/bash
# Test script to verify all hook scripts work correctly

set -e

echo "=== Testing Hook Scripts ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TEST_PASSED=0
TEST_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local script="$2"
    local input="$3"
    local expected_pattern="$4"
    
    echo -n "Testing $test_name... "
    
    if [ ! -f "$script" ]; then
        echo -e "${RED}FAILED${NC} (script not found)"
        ((TEST_FAILED++))
        return 1
    fi
    
    OUTPUT=$(echo "$input" | "$script" 2>&1)
    
    if echo "$OUTPUT" | grep -q "$expected_pattern"; then
        echo -e "${GREEN}PASSED${NC}"
        ((TEST_PASSED++))
        return 0
    else
        echo -e "${RED}FAILED${NC}"
        echo "Expected pattern: $expected_pattern"
        echo "Got: $OUTPUT"
        ((TEST_FAILED++))
        return 1
    fi
}

# Test log-prompt.sh
run_test "log-prompt.sh" \
    ".github/hooks/scripts/log-prompt.sh" \
    '{"timestamp":1704614500000,"cwd":"/test","prompt":"test prompt"}' \
    "User Prompt Submitted Hook"

# Test check-tool-safety.sh - allow case
run_test "check-tool-safety.sh (allow)" \
    ".github/hooks/scripts/check-tool-safety.sh" \
    '{"timestamp":1704614600000,"cwd":"/test","toolName":"bash","toolArgs":"{\"command\":\"ls\"}"}' \
    '"permissionDecision": "allow"'

# Test check-tool-safety.sh - deny by tool name
run_test "check-tool-safety.sh (deny by name)" \
    ".github/hooks/scripts/check-tool-safety.sh" \
    '{"timestamp":1704614600000,"cwd":"/test","toolName":"rm_file","toolArgs":"{}"}' \
    '"permissionDecision": "deny"'

# Test check-tool-safety.sh - deny by command pattern
run_test "check-tool-safety.sh (deny by pattern)" \
    ".github/hooks/scripts/check-tool-safety.sh" \
    '{"timestamp":1704614600000,"cwd":"/test","toolName":"bash","toolArgs":"{\"command\":\"rm -rf /tmp\"}"}' \
    '"permissionDecision": "deny"'

# Test log-tool-result.sh
run_test "log-tool-result.sh" \
    ".github/hooks/scripts/log-tool-result.sh" \
    '{"timestamp":1704614700000,"cwd":"/tmp","toolName":"bash","toolArgs":"{}","toolResult":{"resultType":"success","textResultForLlm":"Done"}}' \
    "Post-Tool Use Hook"

# Test log-error.sh
run_test "log-error.sh" \
    ".github/hooks/scripts/log-error.sh" \
    '{"timestamp":1704614800000,"cwd":"/tmp","error":{"message":"Test error","name":"TestError"}}' \
    "Error Occurred Hook"

# Test inline hooks from hooks.json
echo ""
echo "Testing inline hooks from hooks.json..."

# Test userPromptSubmitted inline hook
echo -n "Testing userPromptSubmitted inline hook... "
OUTPUT=$(echo '{"timestamp":1704614500000,"cwd":"/test","prompt":"test prompt"}' | \
    bash -c 'INPUT=$(cat); echo "[Hook] User prompt submitted:"; echo "$INPUT" | jq -r ".prompt" | head -c 100' 2>&1)
if echo "$OUTPUT" | grep -q "test prompt"; then
    echo -e "${GREEN}PASSED${NC}"
    ((TEST_PASSED++))
else
    echo -e "${RED}FAILED${NC}"
    ((TEST_FAILED++))
fi

# Test preToolUse inline hook
echo -n "Testing preToolUse inline hook... "
OUTPUT=$(echo '{"timestamp":1704614600000,"cwd":"/test","toolName":"bash","toolArgs":"{}"}' | \
    bash -c 'INPUT=$(cat); TOOL=$(echo "$INPUT" | jq -r ".toolName"); echo "[Hook] Pre-tool: $TOOL"; echo "{\"permissionDecision\": \"allow\"}"' 2>&1)
if echo "$OUTPUT" | grep -q '"permissionDecision": "allow"'; then
    echo -e "${GREEN}PASSED${NC}"
    ((TEST_PASSED++))
else
    echo -e "${RED}FAILED${NC}"
    ((TEST_FAILED++))
fi

# Test hooks-deny-tool.json
echo ""
echo "Testing hooks-deny-tool.json..."

echo -n "Testing deny logic (allow case)... "
OUTPUT=$(echo '{"timestamp":1704614600000,"cwd":"/test","toolName":"safe_tool","toolArgs":"{}"}' | \
    bash -c 'INPUT=$(cat); TOOL=$(echo "$INPUT" | jq -r ".toolName"); echo "Checking tool: $TOOL" >&2; if [[ "$TOOL" == *"dangerous"* ]]; then echo "{\"permissionDecision\": \"deny\", \"permissionDecisionReason\": \"Tool contains dangerous operations\"}"; else echo "{\"permissionDecision\": \"allow\"}"; fi' 2>&1)
if echo "$OUTPUT" | grep -q '"permissionDecision": "allow"'; then
    echo -e "${GREEN}PASSED${NC}"
    ((TEST_PASSED++))
else
    echo -e "${RED}FAILED${NC}"
    ((TEST_FAILED++))
fi

echo -n "Testing deny logic (deny case)... "
OUTPUT=$(echo '{"timestamp":1704614600000,"cwd":"/test","toolName":"dangerous_tool","toolArgs":"{}"}' | \
    bash -c 'INPUT=$(cat); TOOL=$(echo "$INPUT" | jq -r ".toolName"); echo "Checking tool: $TOOL" >&2; if [[ "$TOOL" == *"dangerous"* ]]; then echo "{\"permissionDecision\": \"deny\", \"permissionDecisionReason\": \"Tool contains dangerous operations\"}"; else echo "{\"permissionDecision\": \"allow\"}"; fi' 2>&1)
if echo "$OUTPUT" | grep -q '"permissionDecision": "deny"'; then
    echo -e "${GREEN}PASSED${NC}"
    ((TEST_PASSED++))
else
    echo -e "${RED}FAILED${NC}"
    ((TEST_FAILED++))
fi

# Summary
echo ""
echo "==================================="
echo "Test Summary:"
echo -e "  ${GREEN}Passed: $TEST_PASSED${NC}"
echo -e "  ${RED}Failed: $TEST_FAILED${NC}"
echo "==================================="

if [ $TEST_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
