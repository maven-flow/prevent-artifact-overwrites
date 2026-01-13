# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a CI/CD tool that prevents Maven SNAPSHOT artifacts from different Git branches overwriting each other in Maven repositories. It automatically manages branch-specific version suffixes in pom.xml files. Supports both GitHub Actions and GitLab CI/CD.

## Architecture

```
/
├── action.yml                    # GitHub Action (calls prevent-overwrites.sh)
├── prevent-overwrites.sh         # Core logic - standalone bash script
├── templates/
│   └── prevent-overwrites.yml    # GitLab CI/CD Component
├── README.md
└── ...
```

**Core logic** is in `prevent-overwrites.sh` - a standalone bash script that can run on any CI platform. Both `action.yml` (GitHub) and `templates/prevent-overwrites.yml` (GitLab) call this script.

**Key operations performed by the script:**
1. **Branch detection** - Determines if running on a feature branch (not main/master/develop/release*)
2. **Version extraction** - Uses `mvn help:evaluate` to get current project version
3. **Enforce branch version** - On feature branches, appends branch name to version (e.g., `1.0.0-SNAPSHOT` → `1.0.0-feature-foo-SNAPSHOT`)
4. **Remove branch version** - On main branches, strips branch suffix back to original version
5. **Remove dependency branch versions** - Resets branch-specific dependency versions when merging to main branches

**Version regex pattern:** `^[0-9]+\.[0-9]+\.[0-9].*-[0-9a-zA-Z]+-SNAPSHOT$`

**Environment variables** configure the script (see README.md for full list):
- `BRANCH_NAME` - Auto-detected from CI platform or git
- `ENFORCE_BRANCH_VERSION` - true/false
- `PUSH_CHANGES` - true/false
- `POM_FILE`, `MAVEN_ARGS`, `GIT_USER_NAME`, `GIT_USER_EMAIL`, etc.

## Testing

There are no automated tests. To test changes:
1. Run `prevent-overwrites.sh` locally with environment variables set
2. Use the action in a workflow on a test Maven project repository

## Release Process

- GitHub: Users reference as `maven-flow/prevent-artifact-overwrites@v1`
- GitLab: Users include component as `gitlab.com/maven-flow/prevent-artifact-overwrites/prevent-overwrites@v1`
