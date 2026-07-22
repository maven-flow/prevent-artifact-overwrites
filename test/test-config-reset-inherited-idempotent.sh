#!/usr/bin/env bash
set -euo pipefail

# ==========================================================================
# Test: with 'reset-inherited-version true', re-running on a branch whose
#       version already carries THIS branch's suffix makes no change
#       (idempotency is preserved).
# ==========================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR=$(mktemp -d)

trap 'rm -rf "$WORK_DIR"' EXIT

echo "=== Setting up test repo in $WORK_DIR ==="

git init "$WORK_DIR" --quiet
# Starting pom already carries the current branch's own suffix
cp "$SCRIPT_DIR/expected-config-reset-inherited-version.xml" "$WORK_DIR/pom.xml"
cat > "$WORK_DIR/.prevent-overwrites.conf" <<'EOF'
feature/*  reset-inherited-version  true
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
echo "=== Verifying the version was left unchanged ==="
if diff "$WORK_DIR/pom.xml" "$SCRIPT_DIR/expected-config-reset-inherited-version.xml"; then
    echo "=== TEST PASSED ==="
    exit 0
else
    echo "=== TEST FAILED ==="
    exit 1
fi
