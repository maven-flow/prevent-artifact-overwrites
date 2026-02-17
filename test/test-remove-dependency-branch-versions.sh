#!/usr/bin/env bash
set -euo pipefail

# ==========================================================================
# Test: On a core branch, remove_dependency_branch_versions should strip
#       branch suffixes from dependency versions, including rc versions.
#       Dependencies without a branch suffix should remain unchanged.
# ==========================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR=$(mktemp -d)

trap 'rm -rf "$WORK_DIR"' EXIT

echo "=== Setting up test repo in $WORK_DIR ==="

git init "$WORK_DIR" --quiet
cp "$SCRIPT_DIR/sample-pom-with-branch-deps.xml" "$WORK_DIR/pom.xml"
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
echo "=== Resulting pom.xml ==="
cat "$WORK_DIR/pom.xml"

echo ""
echo "=== Verifying ==="

PASS=true

# Extract all dependency versions in order
mapfile -t dep_versions < <(sed -n '/<dependencies>/,/<\/dependencies>/{ s/.*<version>\(.*\)<\/version>.*/\1/p; }' "$WORK_DIR/pom.xml")

# lib-a: 2.0.0-feature-xyz-SNAPSHOT -> 2.0.0-SNAPSHOT
if [[ "${dep_versions[0]}" == "2.0.0-SNAPSHOT" ]]; then
    echo "PASS: lib-a version stripped to '${dep_versions[0]}'"
else
    echo "FAIL: lib-a version is '${dep_versions[0]}', expected '2.0.0-SNAPSHOT'"
    PASS=false
fi

# lib-b: 3.1.0-rc.1-bugfix-abc-SNAPSHOT -> 3.1.0-rc.1-SNAPSHOT
if [[ "${dep_versions[1]}" == "3.1.0-rc.1-SNAPSHOT" ]]; then
    echo "PASS: lib-b version stripped to '${dep_versions[1]}' (rc preserved)"
else
    echo "FAIL: lib-b version is '${dep_versions[1]}', expected '3.1.0-rc.1-SNAPSHOT'"
    PASS=false
fi

# lib-c: 4.0.0-SNAPSHOT -> unchanged (no branch suffix)
if [[ "${dep_versions[2]}" == "4.0.0-SNAPSHOT" ]]; then
    echo "PASS: lib-c version unchanged: '${dep_versions[2]}'"
else
    echo "FAIL: lib-c version is '${dep_versions[2]}', expected '4.0.0-SNAPSHOT'"
    PASS=false
fi

# Project version should be unchanged (it has no branch suffix)
project_version=$(sed -n '/<parent>/,/<\/parent>/!{ s/.*<version>\(.*\)<\/version>.*/\1/p; }' "$WORK_DIR/pom.xml" | head -1)
if [[ "$project_version" == "1.2.3-SNAPSHOT" ]]; then
    echo "PASS: Project version unchanged: '$project_version'"
else
    echo "FAIL: Project version is '$project_version', expected '1.2.3-SNAPSHOT'"
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
