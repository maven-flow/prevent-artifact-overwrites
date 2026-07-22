#!/usr/bin/env bash
set -euo pipefail

# ==========================================================================
# Test: when a suffix is declared exclusive AND we are on the branch that
#       owns it, the version is left untouched (idempotent). Starting pom:
#       1.2.3-feature-old-SNAPSHOT on branch feature/old with 'feature-old'
#       declared exclusive -> no change.
# ==========================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR=$(mktemp -d)

trap 'rm -rf "$WORK_DIR"' EXIT

echo "=== Setting up test repo in $WORK_DIR ==="

git init "$WORK_DIR" --quiet
cp "$SCRIPT_DIR/sample-pom-with-branch-version.xml" "$WORK_DIR/pom.xml"
cat > "$WORK_DIR/.prevent-overwrites.conf" <<'EOF'
# branch-pattern  target                    value
*                 exclusive-version-suffix  feature-old
EOF
cd "$WORK_DIR"
git add pom.xml
git commit -m "Initial commit" --quiet
git checkout -b feature/old --quiet

BRANCH_NAME="feature/old" \
ENFORCE_BRANCH_VERSION="true" \
PUSH_CHANGES="false" \
POM_FILE="$WORK_DIR/pom.xml" \
CONFIG_FILE="$WORK_DIR/.prevent-overwrites.conf" \
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
