#!/usr/bin/env bash
set -euo pipefail

# ==========================================================================
# Test: On a core branch, remove_branch_version should strip the branch
#       suffix from the project version.
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

# Stay on the default branch (simulating main)
BRANCH_NAME="main" \
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
    echo "PASS: Project version stripped to '$project_version'"
else
    echo "FAIL: Project version is '$project_version', expected '1.2.3-SNAPSHOT'"
    PASS=false
fi

commit_count=$(git rev-list --count HEAD)
if [[ "$commit_count" == "2" ]]; then
    echo "PASS: One commit was made for the version change"
else
    echo "FAIL: Expected 2 commits (initial + version change), found $commit_count"
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
