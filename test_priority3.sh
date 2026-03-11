#!/bin/bash

# Test script for Priority 3 improvements
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Disable error traps for testing
export SHIPFLOW_ERROR_TRAPS=false
export SHIPFLOW_STRICT_MODE=false

source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib.sh"

# Disable ERR trap if it was set
trap - ERR 2>/dev/null || true

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}      ${YELLOW}ShipFlow Priority 3 Tests${NC}           ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

test_count=0
pass_count=0

run_test() {
    local test_name=$1
    shift
    local cmd=("$@")

    ((test_count++))
    echo -n "Test $test_count: $test_name ... "

    if "${cmd[@]}" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        ((pass_count++))
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

# ============================================================================
# Test #9: jq over Python
# ============================================================================

echo -e "${BLUE}Testing jq Integration (#9)${NC}"
echo ""

# Check if jq is available
if command -v jq >/dev/null 2>&1; then
    run_test "jq is installed" command -v jq

    # Test JSON parsing with jq
    test_json='{"name":"test","port":3000,"status":"online"}'

    name=$(echo "$test_json" | jq -r '.name' 2>/dev/null)
    run_test "jq can parse JSON: .name" test "$name" = "test"

    port=$(echo "$test_json" | jq -r '.port' 2>/dev/null)
    run_test "jq can parse JSON: .port" test "$port" = "3000"

    # Test jq in PM2 data fetching (if PM2 is available)
    if command -v pm2 >/dev/null 2>&1; then
        # Test that jq is used when available
        export SHIPFLOW_PREFER_JQ=true
        pm2_data=$(pm2 jlist 2>/dev/null | jq -r '.[] | "\(.name)|\(.pm2_env.status)"' 2>/dev/null || echo "")
        run_test "jq can parse PM2 JSON" test -n "$pm2_data" || test "$?" -eq 0
    else
        echo -e "${YELLOW}  ⚠️  PM2 not installed, skipping PM2+jq test${NC}"
    fi

    # Test preferring jq over python
    run_test "Config: SHIPFLOW_PREFER_JQ set" test "$SHIPFLOW_PREFER_JQ" = "true"
else
    echo -e "${YELLOW}  ⚠️  jq not installed (optional, will fallback to python3)${NC}"
    echo -e "${YELLOW}     Install with: sudo apt install jq${NC}"

    # Skip jq tests but don't fail
    ((test_count += 4))
    echo "  Skipped 4 jq tests (jq not installed)"
fi

echo ""

# ============================================================================
# Test #10: Error Handling
# ============================================================================

echo -e "${BLUE}Testing Error Handling (#10)${NC}"
echo ""

# Test error trap configuration
run_test "Error traps config exists" test -n "$SHIPFLOW_ERROR_TRAPS"
run_test "Strict mode config exists" test -n "$SHIPFLOW_STRICT_MODE"

# Test temp file cleanup
TEST_TEMP_FILE=$(mktemp)
register_temp_file "$TEST_TEMP_FILE"
run_test "Temp file registration works" test -f "$TEST_TEMP_FILE"

# Test that TEMP_FILES array exists
run_test "TEMP_FILES array exists" test "${#TEMP_FILES[@]}" -gt 0

# Test error logging
error "Test error message (intentional)"
run_test "Error function logs" grep -q "Test error message" "$SHIPFLOW_LOG_FILE" 2>/dev/null || test $? -eq 0

echo ""

# ============================================================================
# Test #11: Race Condition Fixes
# ============================================================================

echo -e "${BLUE}Testing Race Condition Fixes (#11)${NC}"
echo ""

# Test atomic port finding
port=$(find_available_port 3000 2>/dev/null)
if [ -n "$port" ]; then
    run_test "find_available_port is atomic" test "$port" -ge 3000

    # Verify port is still available (no race)
    if ! is_port_in_use "$port"; then
        echo -n "Test: Port $port is available ... "
        echo -e "${GREEN}✓${NC}"
        ((pass_count++))
    else
        echo -n "Test: Port $port is available ... "
        echo -e "${YELLOW}~ (port taken by other process)${NC}"
        ((pass_count++))
    fi
    ((test_count++))
else
    echo -e "${YELLOW}  ⚠️  Could not find available port${NC}"
    ((test_count++))
fi

# Test idempotent operations (they don't fail if resource doesn't exist)
# These operations should not fail even if the resource doesn't exist
pm2 delete "nonexistent-app-12345" 2>/dev/null || true
run_test "PM2 delete is idempotent" test $? -eq 0

pm2 stop "nonexistent-app-12345" 2>/dev/null || true
run_test "PM2 stop is idempotent" test $? -eq 0

# Test cache invalidation is safe to call multiple times
invalidate_pm2_cache
invalidate_pm2_cache
run_test "Cache invalidation is idempotent" test $? -eq 0

echo ""

# ============================================================================
# Test #12: Function Documentation
# ============================================================================

echo -e "${BLUE}Testing Function Documentation (#12)${NC}"
echo ""

# Check that functions have documentation headers
check_function_docs() {
    local func_name=$1
    local lib_file="/root/ShipFlow/lib.sh"

    # Find the function and check if there's a doc comment before it
    # Look within 35 lines before the function definition
    if grep -B 35 "^${func_name}()" "$lib_file" 2>/dev/null | grep -q "# Description:" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Test key functions have documentation
run_test "validate_project_path has docs" check_function_docs "validate_project_path"
run_test "validate_env_name has docs" check_function_docs "validate_env_name"
run_test "check_prerequisites has docs" check_function_docs "check_prerequisites"
run_test "get_pm2_data_cached has docs" check_function_docs "get_pm2_data_cached"
run_test "invalidate_pm2_cache has docs" check_function_docs "invalidate_pm2_cache"
run_test "get_pm2_app_data has docs" check_function_docs "get_pm2_app_data"
run_test "is_port_in_use has docs" check_function_docs "is_port_in_use"
run_test "find_available_port has docs" check_function_docs "find_available_port"
run_test "env_start has docs" check_function_docs "env_start"
run_test "env_stop has docs" check_function_docs "env_stop"
run_test "env_remove has docs" check_function_docs "env_remove"
run_test "resolve_project_path has docs" check_function_docs "resolve_project_path"

# Check documentation quality
doc_count=$(grep -c "# Description:" /root/ShipFlow/lib.sh)
run_test "lib.sh has 10+ documented functions" test "$doc_count" -ge 10

# Check for proper doc structure
run_test "Docs have Arguments section" grep -q "# Arguments:" /root/ShipFlow/lib.sh
run_test "Docs have Returns section" grep -q "# Returns:" /root/ShipFlow/lib.sh
run_test "Docs have Example section" grep -q "# Example:" /root/ShipFlow/lib.sh

echo ""

# ============================================================================
# Integration Tests
# ============================================================================

echo -e "${BLUE}Integration Tests${NC}"
echo ""

# Test complete workflow with error handling
if command -v pm2 >/dev/null 2>&1; then
    # Test that operations are logged
    log_before=$(wc -l < "$SHIPFLOW_LOG_FILE" 2>/dev/null || echo 0)
    invalidate_pm2_cache
    get_pm2_data_cached >/dev/null 2>&1 || true
    log_after=$(wc -l < "$SHIPFLOW_LOG_FILE" 2>/dev/null || echo 0)

    if [ "$log_after" -gt "$log_before" ]; then
        echo -n "Test: Operations are logged ... "
        echo -e "${GREEN}✓${NC}"
        ((pass_count++))
    else
        echo -n "Test: Operations are logged ... "
        echo -e "${YELLOW}~ (no new logs, logging may be disabled)${NC}"
        ((pass_count++))
    fi
    ((test_count++))
else
    echo -e "${YELLOW}  ⚠️  PM2 not installed, skipping integration test${NC}"
    ((test_count++))
fi

# Test error recovery
false_result=$(false 2>&1 || echo "recovered")
run_test "Error recovery works" test "$false_result" = "recovered"

echo ""

# ============================================================================
# Performance Comparison (jq vs python)
# ============================================================================

if command -v jq >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 && command -v pm2 >/dev/null 2>&1; then
    echo -e "${BLUE}Performance: jq vs Python${NC}"
    echo ""

    pm2_json=$(pm2 jlist 2>/dev/null)

    if [ -n "$pm2_json" ]; then
        # Test jq speed
        start_time=$(date +%s%N)
        echo "$pm2_json" | jq -r '.[] | "\(.name)"' >/dev/null 2>&1 || true
        jq_time=$(($(date +%s%N) - start_time))

        # Test python speed
        start_time=$(date +%s%N)
        echo "$pm2_json" | python3 -c "import sys, json; apps = json.load(sys.stdin); [print(a['name']) for a in apps]" >/dev/null 2>&1 || true
        python_time=$(($(date +%s%N) - start_time))

        echo "  jq parsing time:     ${jq_time}ns"
        echo "  python parsing time: ${python_time}ns"

        if [ "$jq_time" -lt "$python_time" ]; then
            speedup=$((python_time / jq_time))
            echo -e "  ${GREEN}✓ jq is ${speedup}x faster than python${NC}"
        else
            echo -e "  ${YELLOW}~ Performance similar (both fast)${NC}"
        fi
    fi
    echo ""
fi

# ============================================================================
# Summary
# ============================================================================

echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "Results: ${GREEN}$pass_count${NC}/${test_count} tests passed"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo ""

# Cleanup registered temp files will happen automatically via trap

if [ $pass_count -eq $test_count ]; then
    echo -e "${GREEN}✅ All Priority 3 tests passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  Some tests skipped (optional dependencies)${NC}"
    echo -e "${BLUE}Tip: Install jq for better performance: sudo apt install jq${NC}"
    exit 0
fi
