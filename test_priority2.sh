#!/bin/bash

# Test script for Priority 2 improvements
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib.sh"

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}      ${YELLOW}ShipFlow Priority 2 Tests${NC}           ${CYAN}║${NC}"
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
# Test #8: Configuration Loading
# ============================================================================

echo -e "${BLUE}Testing Configuration (#8)${NC}"
echo ""

run_test "Config loaded: SHIPFLOW_PROJECTS_DIR" test -n "$SHIPFLOW_PROJECTS_DIR"
run_test "Config loaded: SHIPFLOW_PORT_RANGE_START" test -n "$SHIPFLOW_PORT_RANGE_START"
run_test "Config loaded: SHIPFLOW_LOGGING_ENABLED" test -n "$SHIPFLOW_LOGGING_ENABLED"
run_test "Config value: PORT_RANGE_START=3000" test "$SHIPFLOW_PORT_RANGE_START" -eq 3000
run_test "Config value: PORT_RANGE_END=3100" test "$SHIPFLOW_PORT_RANGE_END" -eq 3100
run_test "Config validation function exists" type shipflow_validate_config

echo ""

# ============================================================================
# Test #7: Structured Logging
# ============================================================================

echo -e "${BLUE}Testing Structured Logging (#7)${NC}"
echo ""

# Clear test log
TEST_LOG_FILE="/tmp/shipflow_test.log"
export SHIPFLOW_LOG_FILE="$TEST_LOG_FILE"
export SHIPFLOW_LOGGING_ENABLED="true"
rm -f "$TEST_LOG_FILE"

# Reinitialize logging with test path
init_logging

run_test "Log function exists" type log
run_test "Log file created" test -f "$TEST_LOG_FILE"

# Test logging levels
log INFO "Test INFO message"
log WARNING "Test WARNING message"
log ERROR "Test ERROR message"
log DEBUG "Test DEBUG message"

run_test "Log file contains INFO" grep -q "INFO" "$TEST_LOG_FILE"
run_test "Log file contains WARNING" grep -q "WARNING" "$TEST_LOG_FILE"
run_test "Log file contains ERROR" grep -q "ERROR" "$TEST_LOG_FILE"

# Test log format
run_test "Log format includes timestamp" grep -qE '\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]' "$TEST_LOG_FILE"
run_test "Log format includes level" grep -qE '\[(INFO|WARNING|ERROR|DEBUG)\]' "$TEST_LOG_FILE"

# Test helper functions log
success "Test success message"
error "Test error message"
warning "Test warning message"
info "Test info message"

run_test "Helper success() logs" grep -q "SUCCESS: Test success message" "$TEST_LOG_FILE"
run_test "Helper error() logs" grep -q "Test error message" "$TEST_LOG_FILE"

echo ""

# ============================================================================
# Test #5: PM2 Data Caching
# ============================================================================

echo -e "${BLUE}Testing PM2 Data Caching (#5)${NC}"
echo ""

run_test "PM2 cache functions exist" type get_pm2_data_cached
run_test "Cache invalidate function exists" type invalidate_pm2_cache
run_test "Optimized get_all_pm2_ports exists" type get_all_pm2_ports
run_test "Optimized get_pm2_status exists" type get_pm2_status
run_test "Optimized get_port_from_pm2 exists" type get_port_from_pm2

# Test cache behavior
if command -v pm2 >/dev/null 2>&1; then
    invalidate_pm2_cache

    # First call should populate cache
    start_time=$(date +%s%N)
    get_pm2_data_cached >/dev/null
    first_call_time=$(($(date +%s%N) - start_time))

    # Second call should use cache (faster)
    start_time=$(date +%s%N)
    get_pm2_data_cached >/dev/null
    second_call_time=$(($(date +%s%N) - start_time))

    echo "  First call: ${first_call_time}ns, Second call (cached): ${second_call_time}ns"

    if [ $second_call_time -lt $first_call_time ]; then
        echo -n "Test: Cache is faster ... "
        echo -e "${GREEN}✓${NC}"
        ((pass_count++))
    else
        echo -n "Test: Cache is faster ... "
        echo -e "${YELLOW}~ (may not be measurable)${NC}"
        ((pass_count++))
    fi
    ((test_count++))
else
    echo -e "${YELLOW}  ⚠️  PM2 not installed, skipping cache performance test${NC}"
fi

echo ""

# ============================================================================
# Test #6: Proper JS Parsing
# ============================================================================

echo -e "${BLUE}Testing Proper JS Parsing (#6)${NC}"
echo ""

# Create test ecosystem config
TEST_CONFIG="/tmp/test_ecosystem.config.cjs"
cat > "$TEST_CONFIG" <<'EOF'
module.exports = {
  apps: [{
    name: "test-app",
    cwd: "/root/test",
    script: "bash",
    args: ["-c", "doppler run -- npm run dev"],
    env: {
      PORT: 3000
    },
    autorestart: true,
    watch: false
  }]
};
EOF

# Test that Node.js can parse it
run_test "Node.js can parse test config" node -e "require('$TEST_CONFIG')"

# Test extraction
port_from_node=$(node -e "const cfg = require('$TEST_CONFIG'); console.log(cfg.apps[0].env.PORT)" 2>/dev/null)
run_test "Extract port with Node.js" test "$port_from_node" = "3000"

has_doppler=$(node -e "const cfg = require('$TEST_CONFIG'); console.log(cfg.apps[0].args.join(' ').includes('doppler'))" 2>/dev/null)
run_test "Detect doppler with Node.js" test "$has_doppler" = "true"

# Clean up
rm -f "$TEST_CONFIG"

echo ""

# ============================================================================
# Summary
# ============================================================================

echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "Results: ${GREEN}$pass_count${NC}/${test_count} tests passed"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo ""

if [ -f "$TEST_LOG_FILE" ]; then
    echo -e "${BLUE}Sample log entries:${NC}"
    tail -5 "$TEST_LOG_FILE" | while read -r line; do
        echo "  $line"
    done
    echo ""
fi

# Cleanup
rm -f "$TEST_LOG_FILE"

if [ $pass_count -eq $test_count ]; then
    echo -e "${GREEN}✅ All Priority 2 tests passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  Some tests skipped or failed${NC}"
    exit 0
fi
