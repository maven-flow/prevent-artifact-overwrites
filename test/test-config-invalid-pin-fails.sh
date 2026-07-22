#!/usr/bin/env bash
set -euo pipefail

# ==========================================================================
# Test: a pinned value that does not follow the '<base>-<suffix>-SNAPSHOT'
#       pattern (required so it can be reverted on core branches) causes the
#       script to fail with a non-zero exit code.
# ==========================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR=$(mktemp -d)

trap 'rm -rf "$WORK_DIR"' EXIT

echo "=== Setting up test repo in $WORK_DIR ==="

git init "$WORK_DIR" --quiet
cp "$SCRIPT_DIR/sample-pom.xml" "$WORK_DIR/pom.xml"
cat > "$WORK_DIR/.prevent-overwrites.conf" <<'EOF'
# 'vf1' is not a valid branch version - must be rejected
feature/f1  project-version  vf1
EOF
cd "$WORK_DIR"
git add pom.xml
git commit -m "Initial commit" --quiet
git checkout -b feature/f1 --quiet

echo "=== Running script (expecting non-zero exit) ==="
set +e
BRANCH_NAME="feature/f1" \
ENFORCE_BRANCH_VERSION="true" \
PUSH_CHANGES="false" \
POM_FILE="$WORK_DIR/pom.xml" \
CONFIG_FILE="$WORK_DIR/.prevent-overwrites.conf" \
GIT_USER_NAME="test" \
GIT_USER_EMAIL="test@test.com" \
CORE_BRANCHES="main master develop release*" \
bash "$REPO_ROOT/prevent-overwrites.sh"
EXIT_CODE=$?
set -e

echo ""
if [[ "$EXIT_CODE" -ne 0 ]]; then
    echo "=== TEST PASSED (script exited with code $EXIT_CODE) ==="
    exit 0
else
    echo "=== TEST FAILED (script exited 0, expected failure) ==="
    exit 1
fi
