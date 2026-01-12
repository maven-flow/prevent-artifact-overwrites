# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a GitHub composite action that prevents Maven SNAPSHOT artifacts from different Git branches overwriting each other in Maven repositories. It automatically manages branch-specific version suffixes in pom.xml files.

## Architecture

The entire action logic is contained in `action.yml` as a composite action with inline bash scripts. There are no external source files.

**Key steps in the action:**
1. **Branch detection** - Determines if running on a feature branch (not main/master/develop/release*)
2. **Version extraction** - Uses `mvn help:evaluate` to get current project version
3. **Enforce branch version** - On feature branches, appends branch name to version (e.g., `1.0.0-SNAPSHOT` → `1.0.0-feature-foo-SNAPSHOT`)
4. **Remove branch version** - On main branches, strips branch suffix back to original version
5. **Remove dependency branch versions** - Resets branch-specific dependency versions when merging to main branches

**Version regex pattern:** `^[0-9]+\.[0-9]+\.[0-9].*-[0-9a-zA-Z]+-SNAPSHOT$`

## Testing

There are no automated tests. To test changes, use the action in a workflow on a test Maven project repository.

## Release Process

The action is published via GitHub releases. Users reference it as `maven-flow/prevent-artifact-overwrites@v1`.
