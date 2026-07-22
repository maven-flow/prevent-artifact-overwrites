#!/usr/bin/env bash
set -euo pipefail

# ==========================================================================
# Test: when a config file exists but has no entry for the current branch,
#       the default branch-version behaviour applies unchanged.
# ==========================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR=$(mktemp -d)

trap 'rm -rf "$WORK_DIR"' EXIT

echo "=== Setting up test repo in $WORK_DIR ==="

git init "$WORK_DIR" --quiet
cp "$SCRIPT_DIR/sample-pom.xml" "$WORK_DIR/pom.xml"
cat > "$WORK_DIR/.prevent-overwrites.conf" <<'EOF'
# Config only covers feature/f1 - the run below is on feature/my-feature
feature/f1  project-version  1.2.3-f1-SNAPSHOT
EOF
cd "$WORK_DIR"
git add pom.xml
git commit -m "Initial commit" --quiet
git checkout -b feature/my-feature --quiet

BRANCH_NAME="feature/my-feature" \
ENFORCE_BRANCH_VERSION="true" \
PUSH_CHANGES="false" \
POM_FILE="$WORK_DIR/pom.xml" \
CONFIG_FILE="$WORK_DIR/.prevent-overwrites.conf" \
GIT_USER_NAME="test" \
GIT_USER_EMAIL="test@test.com" \
CORE_BRANCHES="main master develop release*" \
bash "$REPO_ROOT/prevent-overwrites.sh"

echo ""
echo "=== Comparing result to expected output (default enforce behaviour) ==="
if diff "$WORK_DIR/pom.xml" "$SCRIPT_DIR/expected-enforce-branch-version.xml"; then
    echo "=== TEST PASSED ==="
    exit 0
else
    echo "=== TEST FAILED ==="
    exit 1
fi
