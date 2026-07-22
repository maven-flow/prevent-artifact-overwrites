#!/usr/bin/env bash
set -euo pipefail

# ==========================================================================
# Test: when a branch is created off another feature branch, its pom carries
#       the parent branch's suffix (e.g. 1.2.3-feature-old-SNAPSHOT). By
#       default the version is now RE-DERIVED for the current branch instead
#       of being left as the inherited value.
# ==========================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR=$(mktemp -d)

trap 'rm -rf "$WORK_DIR"' EXIT

echo "=== Setting up test repo in $WORK_DIR ==="

git init "$WORK_DIR" --quiet
# Starting pom has an inherited branch version (1.2.3-feature-old-SNAPSHOT)
cp "$SCRIPT_DIR/sample-pom-with-branch-version.xml" "$WORK_DIR/pom.xml"
cd "$WORK_DIR"
git add pom.xml
git commit -m "Initial commit" --quiet
git checkout -b feature/my-feature --quiet

BRANCH_NAME="feature/my-feature" \
ENFORCE_BRANCH_VERSION="true" \
PUSH_CHANGES="false" \
POM_FILE="$WORK_DIR/pom.xml" \
GIT_USER_NAME="test" \
GIT_USER_EMAIL="test@test.com" \
CORE_BRANCHES="main master develop release*" \
bash "$REPO_ROOT/prevent-overwrites.sh"

echo ""
echo "=== Comparing result to expected output ==="
if diff "$WORK_DIR/pom.xml" "$SCRIPT_DIR/expected-enforce-rederive-inherited-version.xml"; then
    echo "=== TEST PASSED ==="
    exit 0
else
    echo "=== TEST FAILED ==="
    exit 1
fi
