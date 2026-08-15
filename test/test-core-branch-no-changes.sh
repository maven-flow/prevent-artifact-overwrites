#!/usr/bin/env bash
set -euo pipefail

# ==========================================================================
# Test: On a core branch when the project version has no branch suffix and
#       dependencies have no branch suffixes, no changes should be made.
# ==========================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR=$(mktemp -d)

trap 'rm -rf "$WORK_DIR"' EXIT

echo "=== Setting up test repo in $WORK_DIR ==="

git init "$WORK_DIR" --quiet
cp "$SCRIPT_DIR/sample-pom.xml" "$WORK_DIR/pom.xml"
cd "$WORK_DIR"
git add pom.xml
git commit -m "Initial commit" --quiet

BRANCH_NAME="main" \
PUSH_CHANGES="false" \
POM_FILE="$WORK_DIR/pom.xml" \
GIT_USER_NAME="test" \
GIT_USER_EMAIL="test@test.com" \
CORE_BRANCHES="main master develop release*" \
bash "$REPO_ROOT/prevent-overwrites.sh"

echo ""
echo "=== Comparing result to expected output ==="
if diff "$WORK_DIR/pom.xml" "$SCRIPT_DIR/sample-pom.xml"; then
    echo "=== TEST PASSED ==="
    exit 0
else
    echo "=== TEST FAILED ==="
    exit 1
fi
