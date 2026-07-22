#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# prevent-overwrites.sh
# Prevents Maven SNAPSHOT artifacts from different branches overwriting each other
#
# Supports: GitHub Actions, GitLab CI/CD, and standalone execution
# ============================================================================

# --- Configuration via Environment Variables ---

# Branch name (auto-detected from CI environment if not set)
BRANCH_NAME="${BRANCH_NAME:-}"

# Action configuration
ENFORCE_BRANCH_VERSION="${ENFORCE_BRANCH_VERSION:-true}"
PUSH_CHANGES="${PUSH_CHANGES:-true}"
POM_FILE="${POM_FILE:-pom.xml}"
COMMIT_MESSAGE_SUFFIX="${COMMIT_MESSAGE_SUFFIX:-}"
GIT_USER_NAME="${GIT_USER_NAME:-ci-bot}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-ci-bot@example.com}"
CORE_BRANCHES="${CORE_BRANCHES:-main master develop release*}"

# Output file for CI integration (optional, for GitLab dotenv artifacts)
OUTPUT_FILE="${OUTPUT_FILE:-}"

# Optional per-branch version pinning configuration (see README).
# If the file does not exist, behaviour is unchanged.
CONFIG_FILE="${CONFIG_FILE:-.prevent-overwrites.conf}"

# --- Utility Functions ---

log_info() {
    echo "[INFO] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

# Detect CI platform and set BRANCH_NAME if not already set
detect_ci_platform() {
    if [[ -n "$BRANCH_NAME" ]]; then
        log_info "Branch name provided: $BRANCH_NAME"
        return
    fi

    if [[ -n "${GITHUB_REF_NAME:-}" ]]; then
        BRANCH_NAME="$GITHUB_REF_NAME"
        log_info "Detected GitHub Actions, branch: $BRANCH_NAME"
    elif [[ -n "${CI_COMMIT_REF_NAME:-}" ]]; then
        BRANCH_NAME="$CI_COMMIT_REF_NAME"
        log_info "Detected GitLab CI/CD, branch: $BRANCH_NAME"
    elif [[ -n "${BITBUCKET_BRANCH:-}" ]]; then
        BRANCH_NAME="$BITBUCKET_BRANCH"
        log_info "Detected Bitbucket Pipelines, branch: $BRANCH_NAME"
    elif [[ -n "${CIRCLE_BRANCH:-}" ]]; then
        BRANCH_NAME="$CIRCLE_BRANCH"
        log_info "Detected CircleCI, branch: $BRANCH_NAME"
    elif [[ -n "${TRAVIS_BRANCH:-}" ]]; then
        BRANCH_NAME="$TRAVIS_BRANCH"
        log_info "Detected Travis CI, branch: $BRANCH_NAME"
    else
        # Fallback to git command
        BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
        if [[ -n "$BRANCH_NAME" ]]; then
            log_info "Detected local git, branch: $BRANCH_NAME"
        else
            log_error "Could not detect branch name. Set BRANCH_NAME environment variable."
            exit 1
        fi
    fi
}

# Set output variable (works with GitHub Actions and GitLab CI/CD)
set_output() {
    local name="$1"
    local value="$2"

    # GitHub Actions output
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        echo "${name}=${value}" >> "$GITHUB_OUTPUT"
    fi

    # GitLab CI/CD dotenv artifact (if OUTPUT_FILE is set)
    if [[ -n "${OUTPUT_FILE:-}" ]]; then
        echo "${name}=${value}" >> "$OUTPUT_FILE"
    fi

    log_info "Output: ${name}=${value}"
}

# --- Core Logic Functions ---

check_branch_needs_version() {
    log_info "Checking if branch needs version suffix..."
    log_info "Current branch: '$BRANCH_NAME'"

    NEEDS_BRANCH_VERSION="true"
    for pattern in $CORE_BRANCHES; do
        # shellcheck disable=SC2053
        if [[ "$BRANCH_NAME" == $pattern ]]; then
            NEEDS_BRANCH_VERSION="false"
            break
        fi
    done

    log_info "Needs branch version: $NEEDS_BRANCH_VERSION"
}

get_project_version() {
    log_info "Getting project version from POM file..."
    # Extract version from the project's own <version> tag (not parent's).
    # Uses the first <version> that is a direct child of <project>, or falls back
    # to the first <version> found outside a <parent> block.
    PROJECT_VERSION=$(sed -n '/<parent>/,/<\/parent>/!{ s/.*<version>\(.*\)<\/version>.*/\1/p; }' "$POM_FILE" | head -1)
    if [[ -z "$PROJECT_VERSION" ]]; then
        # If no version outside <parent>, the project inherits from parent
        PROJECT_VERSION=$(sed -n 's/.*<version>\(.*\)<\/version>.*/\1/p' "$POM_FILE" | head -1)
    fi
    log_info "Project version: $PROJECT_VERSION"
}

setup_git() {
    log_info "Setting up git configuration..."
    git config --local user.name "$GIT_USER_NAME"
    git config --local user.email "$GIT_USER_EMAIL"
}

# Load per-branch version pins from CONFIG_FILE (if present).
#
# Format (whitespace-separated columns; '#' comments and blank lines ignored):
#   <branch-pattern>  project-version              <pinned-version>
#   <branch-pattern>  dependency:<groupId>:<artifactId>  <pinned-version>
#
# The branch-pattern is glob-matched against BRANCH_NAME (like CORE_BRANCHES).
# Only rows matching the current branch are collected. Pinned values MUST follow
# the branch-version pattern so that the core-branch restore logic can strip them
# back to <base>-SNAPSHOT on merge; a value that does not match is a hard error.
load_config_overrides() {
    PINNED_PROJECT_VERSION=""
    PIN_DEP_KEYS=()
    PIN_DEP_VERSIONS=()

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_info "No config file at '$CONFIG_FILE'. Using default behaviour."
        return
    fi

    log_info "Loading version pins from '$CONFIG_FILE' for branch '$BRANCH_NAME'..."
    local pin_regexp='^[0-9]+\.[0-9]+\.[0-9].*-.+-SNAPSHOT$'

    local pattern target value
    while read -r pattern target value _; do
        # Skip blank lines and comments
        [[ -z "$pattern" || "$pattern" == \#* ]] && continue

        if [[ -z "$target" || -z "$value" ]]; then
            log_error "Malformed line in $CONFIG_FILE (expected 3 columns): $pattern $target $value"
            exit 1
        fi

        # shellcheck disable=SC2053
        [[ "$BRANCH_NAME" == $pattern ]] || continue

        if [[ ! "$value" =~ $pin_regexp ]]; then
            log_error "Invalid pinned version '$value' for target '$target' (branch pattern '$pattern')."
            log_error "Pinned versions must match '<base>-<suffix>-SNAPSHOT' (e.g. 1.2.3-f1-SNAPSHOT) so they can be reverted on core branches."
            exit 1
        fi

        case "$target" in
            project-version)
                if [[ -z "$PINNED_PROJECT_VERSION" ]]; then
                    PINNED_PROJECT_VERSION="$value"
                    log_info "Pin: project-version -> $value"
                fi
                ;;
            dependency:*:*)
                local dep_key="${target#dependency:}"
                PIN_DEP_KEYS+=("$dep_key")
                PIN_DEP_VERSIONS+=("$value")
                log_info "Pin: dependency $dep_key -> $value"
                ;;
            *)
                log_error "Unknown target '$target' in $CONFIG_FILE (expected 'project-version' or 'dependency:<groupId>:<artifactId>')."
                exit 1
                ;;
        esac
    done < "$CONFIG_FILE"
}

enforce_branch_version() {
    if [[ "$ENFORCE_BRANCH_VERSION" != "true" ]]; then
        log_info "Project version enforcement is turned off."
        ENFORCE_CHANGES_MADE="false"
        return
    fi

    local version_regexp='^[0-9]+\.[0-9]+\.[0-9].*-.+-SNAPSHOT$'

    # Work out the version this branch should have.
    local new_version
    if [[ -n "${PINNED_PROJECT_VERSION:-}" ]]; then
        new_version="$PINNED_PROJECT_VERSION"
    else
        # Derive from the base version, stripping any existing branch suffix.
        # This way a branch created off another feature branch gets its OWN
        # suffix instead of inheriting (and overwriting) the parent branch's
        # version. For an explicit custom version, use a project-version pin.
        local base_version="$PROJECT_VERSION"
        if [[ "$PROJECT_VERSION" =~ $version_regexp ]]; then
            local prefix
            prefix=$(echo "$PROJECT_VERSION" | grep -oE "^[0-9]+\.[0-9]+\.[0-9](\-rc(\.[0-9]+)?)?")
            base_version="$prefix-SNAPSHOT"
        fi
        local branch_postfix
        branch_postfix=$(echo "$BRANCH_NAME" | tr / -)
        new_version="${base_version%-SNAPSHOT}-${branch_postfix}-SNAPSHOT"
    fi

    if [[ "$PROJECT_VERSION" == "$new_version" ]]; then
        log_info "Project version already correct for this branch: $PROJECT_VERSION"
        ENFORCE_CHANGES_MADE="false"
        return
    fi

    log_info "Changing project version to: $new_version"
    local pom_dir
    pom_dir=$(dirname "$POM_FILE")
    while IFS= read -r pom; do
        if grep -q "$PROJECT_VERSION" "$pom"; then
            log_info "Updating version in $pom"
            # Replace only the project version (first <version> outside <parent>),
            # not dependency versions that happen to match.
            awk -v old="$PROJECT_VERSION" -v new="$new_version" '
                /<parent>/ { in_parent=1 }
                /<\/parent>/ { in_parent=0 }
                !in_parent && !done && index($0, "<version>" old "</version>") {
                    sub("<version>" old "</version>", "<version>" new "</version>")
                    done=1
                }
                { print }
            ' "$pom" > "${pom}.tmp" && mv "${pom}.tmp" "$pom"
        fi
    done < <(find "$pom_dir" -name "pom.xml" -not -path "*/target/*")
    git commit -a -m "Switched to branch-specific version.${COMMIT_MESSAGE_SUFFIX}"
    ENFORCE_CHANGES_MADE="true"
}

# Apply pinned dependency versions from the config (feature branches).
# Runs regardless of ENFORCE_BRANCH_VERSION, since application projects also
# pin dependency versions. Idempotent: a dependency already at its pinned
# version produces no change and therefore no commit.
apply_dependency_pins() {
    DEP_PIN_CHANGES_MADE="false"

    if [[ "${#PIN_DEP_KEYS[@]}" -eq 0 ]]; then
        return
    fi

    local changes_made="false"
    local pom_dir
    pom_dir=$(dirname "$POM_FILE")

    local i dep_key dep_version group_id artifact_id
    for i in "${!PIN_DEP_KEYS[@]}"; do
        dep_key="${PIN_DEP_KEYS[$i]}"
        dep_version="${PIN_DEP_VERSIONS[$i]}"
        group_id="${dep_key%%:*}"
        artifact_id="${dep_key#*:}"

        while IFS= read -r pom; do
            # Rewrite the <version> of the matching <dependency> block only.
            awk -v g="$group_id" -v a="$artifact_id" -v nv="$dep_version" '
                function flush() {
                    if (dep_g == g && dep_a == a) {
                        for (i = 0; i < n; i++) {
                            line = buf[i]
                            if (line ~ /<version>.*<\/version>/) {
                                sub(/<version>.*<\/version>/, "<version>" nv "</version>", line)
                            }
                            print line
                        }
                    } else {
                        for (i = 0; i < n; i++) print buf[i]
                    }
                    in_dep = 0; n = 0; dep_g = ""; dep_a = ""
                }
                /<dependency>/ { in_dep = 1; n = 0; dep_g = ""; dep_a = ""; buf[n++] = $0; next }
                in_dep {
                    buf[n++] = $0
                    if ($0 ~ /<groupId>[^<]*<\/groupId>/) {
                        tmp = $0; sub(/.*<groupId>/, "", tmp); sub(/<\/groupId>.*/, "", tmp); dep_g = tmp
                    }
                    if ($0 ~ /<artifactId>[^<]*<\/artifactId>/) {
                        tmp = $0; sub(/.*<artifactId>/, "", tmp); sub(/<\/artifactId>.*/, "", tmp); dep_a = tmp
                    }
                    if ($0 ~ /<\/dependency>/) { flush() }
                    next
                }
                { print }
                END { if (in_dep) flush() }
            ' "$pom" > "${pom}.tmp"

            if ! cmp -s "$pom" "${pom}.tmp"; then
                log_info "Pinning dependency $dep_key to $dep_version in $pom"
                mv "${pom}.tmp" "$pom"
                changes_made="true"
            else
                rm -f "${pom}.tmp"
            fi
        done < <(find "$pom_dir" -name "pom.xml" -not -path "*/target/*")
    done

    if [[ "$changes_made" == "true" ]]; then
        git commit -a -m "Pinned branch-specific dependency versions.${COMMIT_MESSAGE_SUFFIX}"
        DEP_PIN_CHANGES_MADE="true"
    fi
}

remove_branch_version() {
    local version_regexp='^[0-9]+\.[0-9]+\.[0-9].*-.+-SNAPSHOT$'

    if [[ "$PROJECT_VERSION" =~ $version_regexp ]]; then
        log_info "Project has a branch version. Removing it, since we are on a core branch."

        local prefix
        prefix=$(echo "$PROJECT_VERSION" | grep -oE "^[0-9]+\.[0-9]+\.[0-9](\-rc(\.[0-9]+)?)?")
        local new_version="$prefix-SNAPSHOT"

        log_info "New version: $new_version"
        local pom_dir
        pom_dir=$(dirname "$POM_FILE")
        while IFS= read -r pom; do
            if grep -q "$PROJECT_VERSION" "$pom"; then
                log_info "Updating version in $pom"
                sed -i "s|${PROJECT_VERSION}|${new_version}|g" "$pom"
            fi
        done < <(find "$pom_dir" -name "pom.xml" -not -path "*/target/*")
        git commit -a -m "Switched to non branch-specific version.${COMMIT_MESSAGE_SUFFIX}"
        REMOVE_VERSION_CHANGES_MADE="true"
    else
        REMOVE_VERSION_CHANGES_MADE="false"
    fi
}

remove_dependency_branch_versions() {
    local changes_made="false"
    local version_regexp='[0-9]+\.[0-9]+\.[0-9].*-.+-SNAPSHOT'
    local pom_dir
    pom_dir=$(dirname "$POM_FILE")

    # Scan all pom.xml files for branch-specific SNAPSHOT versions and replace them directly.
    # This avoids Maven invocations (which download dependencies and are slow).
    while IFS= read -r pom; do
        while IFS= read -r version; do
            local prefix
            prefix=$(echo "$version" | grep -oE "^[0-9]+\.[0-9]+\.[0-9](\-rc(\.[0-9]+)?)?")
            local new_version="$prefix-SNAPSHOT"

            if [[ "$version" != "$new_version" ]]; then
                log_info "Replacing version $version with $new_version in $pom"
                sed -i "s|${version}|${new_version}|g" "$pom"
                changes_made="true"
            fi
        done < <(grep -oE "$version_regexp" "$pom" | sort -u)
    done < <(find "$pom_dir" -name "pom.xml" -not -path "*/target/*")

    if [[ "$changes_made" == "true" ]]; then
        git commit -a -m "Switched to non branch dependency versions.${COMMIT_MESSAGE_SUFFIX}"
        REMOVE_DEPS_CHANGES_MADE="true"
    else
        REMOVE_DEPS_CHANGES_MADE="false"
    fi
}

push_changes() {
    if [[ "$PUSH_CHANGES" == "true" ]]; then
        log_info "Pushing changes to branch '$BRANCH_NAME'..."
        # Use HEAD:<branch> syntax to support detached HEAD state (common in CI)
        git push origin "HEAD:$BRANCH_NAME"
    else
        log_info "Push changes disabled. Skipping push."
    fi
}

# --- Main Execution ---

main() {
    log_info "============================================"
    log_info "Prevent Maven Artifact Overwrites"
    log_info "============================================"

    # Initialize change tracking
    ENFORCE_CHANGES_MADE="false"
    DEP_PIN_CHANGES_MADE="false"
    REMOVE_VERSION_CHANGES_MADE="false"
    REMOVE_DEPS_CHANGES_MADE="false"
    CHANGES_MADE="false"

    # Detect platform and branch
    detect_ci_platform

    # Check if branch needs version
    check_branch_needs_version

    # Get current project version
    get_project_version

    # Load optional per-branch version pins
    load_config_overrides

    # Setup git for commits
    setup_git

    # Execute based on branch type
    if [[ "$NEEDS_BRANCH_VERSION" == "true" ]]; then
        enforce_branch_version
        apply_dependency_pins
    else
        remove_branch_version
        remove_dependency_branch_versions || true  # continue on error like original
    fi

    # Summarize changes
    if [[ "$ENFORCE_CHANGES_MADE" == "true" ||
          "$DEP_PIN_CHANGES_MADE" == "true" ||
          "$REMOVE_VERSION_CHANGES_MADE" == "true" ||
          "$REMOVE_DEPS_CHANGES_MADE" == "true" ]]; then
        log_info "Changes have been made."
        CHANGES_MADE="true"
    else
        log_info "No changes have been made."
        CHANGES_MADE="false"
    fi

    set_output "changes-made" "$CHANGES_MADE"

    # Push if changes were made
    if [[ "$CHANGES_MADE" == "true" ]]; then
        push_changes
    fi

    log_info "============================================"
    log_info "Completed successfully"
    log_info "============================================"
}

# Run main function
main "$@"
