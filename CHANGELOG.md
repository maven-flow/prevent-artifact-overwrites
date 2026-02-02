# Prevent Artifact Overwrites Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- GitLab CI/CD Component support (`gitlab/prevent-overwrites.yml`)
- Standalone `prevent-overwrites.sh` script that can run on any CI platform
- Auto-detection of CI platform (GitHub Actions, GitLab CI/CD, Bitbucket, CircleCI, Travis CI)

### Changed
- Refactored `action.yml` to use the shared `prevent-overwrites.sh` script instead of inline bash

## [1.0.0] - 2024-08-04

First released version.
