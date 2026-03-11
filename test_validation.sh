#!/bin/bash

# Test script for validation functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}        ${YELLOW}ShipFlow Validation Tests${NC}          ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

test_count=0
pass_count=0

run_test() {
    local test_name=$1
    local expected=$2
    shift 2
    local cmd=("$@")

    ((test_count++))
    echo -n "Test $test_count: $test_name ... "

    if "${cmd[@]}" >/dev/null 2>&1; then
        result="pass"
    else
        result="fail"
    fi

    if [ "$result" = "$expected" ]; then
        echo -e "${GREEN}✓${NC}"
        ((pass_count++))
    else
        echo -e "${RED}✗${NC} (expected $expected, got $result)"
    fi
}

echo -e "${BLUE}Testing validate_project_path()${NC}"
echo ""

# Should pass
run_test "Valid path /root" "pass" validate_project_path "/root"
run_test "Valid path /root/ShipFlow" "pass" validate_project_path "/root/ShipFlow"
run_test "Valid path /opt" "pass" validate_project_path "/opt"

# Should fail
run_test "Empty path" "fail" validate_project_path ""
run_test "Relative path" "fail" validate_project_path "relative/path"
run_test "Path traversal" "fail" validate_project_path "/root/../etc"
run_test "Special chars semicolon" "fail" validate_project_path "/root/test;rm"
run_test "Special chars pipe" "fail" validate_project_path "/root/test|cat"
run_test "Special chars dollar" "fail" validate_project_path "/root/test\$USER"
run_test "Non-existent path" "fail" validate_project_path "/root/nonexistent123456"
run_test "Unsafe directory /etc" "fail" validate_project_path "/etc"

echo ""
echo -e "${BLUE}Testing validate_env_name()${NC}"
echo ""

# Should pass
run_test "Valid env name 'myapp'" "pass" validate_env_name "myapp"
run_test "Valid env name 'my-app'" "pass" validate_env_name "my-app"
run_test "Valid env name 'my_app'" "pass" validate_env_name "my_app"
run_test "Valid env name 'my.app'" "pass" validate_env_name "my.app"
run_test "Valid env name 'app123'" "pass" validate_env_name "app123"

# Should fail
run_test "Empty env name" "fail" validate_env_name ""
run_test "Env name with spaces" "fail" validate_env_name "my app"
run_test "Env name starting with dash" "fail" validate_env_name "-myapp"
run_test "Env name starting with dot" "fail" validate_env_name ".myapp"
run_test "Env name with special chars" "fail" validate_env_name "my@app"

echo ""
echo -e "${BLUE}Testing validate_repo_name()${NC}"
echo ""

# Should pass
run_test "Valid repo 'myrepo'" "pass" validate_repo_name "myrepo"
run_test "Valid repo 'my-repo'" "pass" validate_repo_name "my-repo"
run_test "Valid repo 'my_repo'" "pass" validate_repo_name "my_repo"
run_test "Valid repo 'my.repo'" "pass" validate_repo_name "my.repo"

# Should fail
run_test "Empty repo name" "fail" validate_repo_name ""
run_test "Repo with spaces" "fail" validate_repo_name "my repo"
run_test "Repo with special chars" "fail" validate_repo_name "my@repo"

echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "Results: ${GREEN}$pass_count${NC}/${test_count} tests passed"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo ""

if [ $pass_count -eq $test_count ]; then
    echo -e "${GREEN}✅ All validation tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi
