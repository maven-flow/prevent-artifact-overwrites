#!/usr/bin/env bash
set -euo pipefail

# ==========================================================================
# Test: When ENFORCE_BRANCH_VERSION=false, no version changes should be made
#       even on a feature branch.
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
git checkout -b feature/my-feature --quiet

BRANCH_NAME="feature/my-feature" \
ENFORCE_BRANCH_VERSION="false" \
PUSH_CHANGES="false" \
POM_FILE="$WORK_DIR/pom.xml" \
GIT_USER_NAME="test" \
GIT_USER_EMAIL="test@test.com" \
CORE_BRANCHES="main master develop release*" \
bash "$REPO_ROOT/prevent-overwrites.sh"

echo ""
echo "=== Resulting pom.xml ==="
cat "$WORK_DIR/pom.xml"

echo ""
echo "=== Verifying ==="

PASS=true

project_version=$(sed -n '/<parent>/,/<\/parent>/!{ s/.*<version>\(.*\)<\/version>.*/\1/p; }' "$WORK_DIR/pom.xml" | head -1)

if [[ "$project_version" == "1.2.3-SNAPSHOT" ]]; then
    echo "PASS: Project version unchanged: '$project_version'"
else
    echo "FAIL: Project version is '$project_version', expected '1.2.3-SNAPSHOT'"
    PASS=false
fi

commit_count=$(git rev-list --count HEAD)
if [[ "$commit_count" == "1" ]]; then
    echo "PASS: No additional commits made"
else
    echo "FAIL: Expected 1 commit, found $commit_count"
    PASS=false
fi

echo ""
if [[ "$PASS" == "true" ]]; then
    echo "=== ALL TESTS PASSED ==="
    exit 0
else
    echo "=== TESTS FAILED ==="
    exit 1
fi
