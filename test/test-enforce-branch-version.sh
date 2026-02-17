#!/usr/bin/env bash
set -euo pipefail

# ==========================================================================
# Test: enforce_branch_version should only change the project version,
#       not dependency versions that happen to match.
# ==========================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR=$(mktemp -d)

trap 'rm -rf "$WORK_DIR"' EXIT

echo "=== Setting up test repo in $WORK_DIR ==="

# Initialize a git repo with sample pom.xml
git init "$WORK_DIR" --quiet
cp "$SCRIPT_DIR/sample-pom.xml" "$WORK_DIR/pom.xml"
cd "$WORK_DIR"
git add pom.xml
git commit -m "Initial commit" --quiet

# Create and switch to a feature branch
git checkout -b feature/my-feature --quiet

# Run the script with environment variables that simulate a feature branch build
BRANCH_NAME="feature/my-feature" \
ENFORCE_BRANCH_VERSION="true" \
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

EXPECTED_PROJECT_VERSION="1.2.3-feature-my-feature-SNAPSHOT"
EXPECTED_DEP_VERSION="1.2.3-SNAPSHOT"

project_version=$(sed -n '/<parent>/,/<\/parent>/!{ s/.*<version>\(.*\)<\/version>.*/\1/p; }' "$WORK_DIR/pom.xml" | head -1)
dep_version=$(sed -n '/<dependencies>/,/<\/dependencies>/{ s/.*<version>\(.*\)<\/version>.*/\1/p; }' "$WORK_DIR/pom.xml" | head -1)

PASS=true

if [[ "$project_version" == "$EXPECTED_PROJECT_VERSION" ]]; then
    echo "PASS: Project version is '$project_version'"
else
    echo "FAIL: Project version is '$project_version', expected '$EXPECTED_PROJECT_VERSION'"
    PASS=false
fi

if [[ "$dep_version" == "$EXPECTED_DEP_VERSION" ]]; then
    echo "PASS: Dependency version is '$dep_version' (unchanged)"
else
    echo "FAIL: Dependency version is '$dep_version', expected '$EXPECTED_DEP_VERSION'"
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
