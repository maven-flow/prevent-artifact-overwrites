#!/usr/bin/env bash
set -euo pipefail

# ==========================================================================
# Test: enforce_branch_version is idempotent - when the project version
#       already carries THIS branch's suffix, nothing changes.
#       (sample version is 1.2.3-feature-old-SNAPSHOT, branch is feature/old)
# ==========================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR=$(mktemp -d)

trap 'rm -rf "$WORK_DIR"' EXIT

echo "=== Setting up test repo in $WORK_DIR ==="

git init "$WORK_DIR" --quiet
cp "$SCRIPT_DIR/sample-pom-with-branch-version.xml" "$WORK_DIR/pom.xml"
cd "$WORK_DIR"
git add pom.xml
git commit -m "Initial commit" --quiet
git checkout -b feature/old --quiet

BRANCH_NAME="feature/old" \
ENFORCE_BRANCH_VERSION="true" \
PUSH_CHANGES="false" \
POM_FILE="$WORK_DIR/pom.xml" \
GIT_USER_NAME="test" \
GIT_USER_EMAIL="test@test.com" \
CORE_BRANCHES="main master develop release*" \
bash "$REPO_ROOT/prevent-overwrites.sh"

echo ""
echo "=== Comparing result to expected output ==="
if diff "$WORK_DIR/pom.xml" "$SCRIPT_DIR/sample-pom-with-branch-version.xml"; then
    echo "=== TEST PASSED ==="
    exit 0
else
    echo "=== TEST FAILED ==="
    exit 1
fi
