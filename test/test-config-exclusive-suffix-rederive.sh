#!/usr/bin/env bash
set -euo pipefail

# ==========================================================================
# Test: when a suffix is declared 'exclusive-version-suffix' in the config,
#       a pom that inherited that suffix from another (parent) branch is
#       re-derived for the current branch instead of being left untouched.
#       Starting pom: 1.2.3-feature-old-SNAPSHOT, branch: feature/my-feature,
#       config marks 'feature-old' exclusive -> 1.2.3-feature-my-feature-SNAPSHOT
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
echo "=== Comparing result to expected output ==="
if diff "$WORK_DIR/pom.xml" "$SCRIPT_DIR/expected-config-exclusive-suffix-rederive.xml"; then
    echo "=== TEST PASSED ==="
    exit 0
else
    echo "=== TEST FAILED ==="
    exit 1
fi
