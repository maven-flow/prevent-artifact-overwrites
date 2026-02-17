#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FAILED=0
PASSED=0

for test_script in "$SCRIPT_DIR"/test-*.sh; do
    test_name=$(basename "$test_script" .sh)
    echo ""
    echo "================================================================"
    echo "Running: $test_name"
    echo "================================================================"
    if bash "$test_script"; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "================================================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================================================"

if [[ "$FAILED" -gt 0 ]]; then
    exit 1
fi
