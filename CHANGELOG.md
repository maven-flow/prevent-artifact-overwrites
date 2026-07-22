# Prevent Artifact Overwrites Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Custom per-branch version pinning: pin the project version and/or specific dependency versions to explicit values for chosen branches via an optional config file
- Input attribute `core-branches`
- GitLab CI/CD Component support (`gitlab/prevent-overwrites.yml`)
- Standalone `prevent-overwrites.sh` script that can run on any CI platform
- Auto-detection of CI platform (GitHub Actions, GitLab CI/CD, Bitbucket, CircleCI, Travis CI)

### Changed
- Replaced Maven commands with direct POM file manipulation (sed/grep), significantly improving performance by eliminating slow Maven dependency resolution and downloads
- Refactored `action.yml` to use the shared `prevent-overwrites.sh` script instead of inline bash
- `maven-args` input is deprecated and will be removed in a future version (only kept now for backward compatibility)

### Fixed

- Branch-specific versions containing special characters were not recognized (eg. `1.1.0-FEA-123_comments-SNAPSHOT` was not recognized because of the underscore)

## [1.0.0] - 2024-08-04

First released version.
