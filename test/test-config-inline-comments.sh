#!/usr/bin/env bash
set -euo pipefail

# ==========================================================================
# Test: the config parser strips '#' comments both on their own line and
#       trailing a regular entry, and still applies the parsed pins.
#       Reuses the pin-dependency-versions fixtures/expected output.
# ==========================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR=$(mktemp -d)

trap 'rm -rf "$WORK_DIR"' EXIT

echo "=== Setting up test repo in $WORK_DIR ==="

git init "$WORK_DIR" --quiet
cp "$SCRIPT_DIR/sample-pom-two-deps.xml" "$WORK_DIR/pom.xml"
cat > "$WORK_DIR/.prevent-overwrites.conf" <<'EOF'
# full-line comment: branch-pattern  target  value
feature/f1        dependency:com.example:d1  1.0.0-f1-SNAPSHOT   # pin d1 for f1
feature/f1        dependency:com.example:d2  5.0.0-f1-SNAPSHOT # pin d2 for f1
   # indented full-line comment should be ignored too
EOF
cd "$WORK_DIR"
git add pom.xml
git commit -m "Initial commit" --quiet
git checkout -b feature/f1 --quiet

BRANCH_NAME="feature/f1" \
ENFORCE_BRANCH_VERSION="false" \
PUSH_CHANGES="false" \
POM_FILE="$WORK_DIR/pom.xml" \
CONFIG_FILE="$WORK_DIR/.prevent-overwrites.conf" \
GIT_USER_NAME="test" \
GIT_USER_EMAIL="test@test.com" \
CORE_BRANCHES="main master develop release*" \
bash "$REPO_ROOT/prevent-overwrites.sh"

echo ""
echo "=== Comparing result to expected output ==="
if diff "$WORK_DIR/pom.xml" "$SCRIPT_DIR/expected-config-pin-dependency-versions.xml"; then
    echo "=== TEST PASSED ==="
    exit 0
else
    echo "=== TEST FAILED ==="
    exit 1
fi
