# Prevent Overwriting Maven Artifacts from Feature Branches

When using [Git Flow](https://nvie.com/posts/a-successful-git-branching-model/) to develop library projects with Maven, you often run in to a problem, that SNAPSHOT artifacts from develop and different feature branches overwrite each-other in the Maven repository, which leads to random compilation errors.

You can solve this by changing the project version into a unique value for every feature branch. For example changing the version `1.1.0-SNAPSHOT` into `1.1.0-cool-feature-SNAPSHOT`. That way, the branches do not interfere with each other.

Changing the versions manually is annoying, time-consuming, and most importantly - people always keep forgetting. Over the years, the internet has come up with [many solutions](https://stackoverflow.com/questions/13583953/deriving-maven-artifact-version-from-git-branch), but they always require some complicated setup on every developer's machine (Git hooks or extensions) and/or do not work well with IDEs (Maven plugins changing the version at compile-time).

This CI/CD automation (available for both GitHub Actions and GitLab CI/CD) brings several benefits:
- No special setup required on the developer's machine
- Works seamlessly with any IDE and with Maven CLI (since the version is changed directly in pom.xml)

## How It Works

Add a step using this action into your workflow **before** the Maven build step. Do this for your library project (the project whose version needs to change), and also for your application project (the project which uses the library).

The action performs different tasks based on the type of project it is running on:

### When Running on a Library

Set the value of parameter `enforce-branch-version` to `true`.

If the action detects it is running on a feature branch, it will append the branch name to the project version with slashes replaced by hyphens. For example, when running on a branch named `feature/FEA-123-comments`, the version will be changed from `1.1.0-SNAPSHOT` into `1.1.0-feature-FEA-123-comments-SNAPSHOT`. You can also change the version manually into a different value, for example `1.1.0-FEA-123-SNAPSHOT`.

When running on a non-feature branch, the action will change the branch-specific version back into the original value. This means that you don't have to worry about removing the version postfix when you want to merge your feature branch into `develop`. You can just merge the modified version, and the postfix will be removed automatically.

The action changes the project version in the `pom.xml` file, and commits and pushes the changes into GIT.

### When Running on an Application

Set the value of parameter `enforce-branch-version` to `false`.

When running on a non-feature branch, the action will check versions of all dependencies and if it finds a branch-specific version of a dependency, it will change it back to it's original value. As in the case of running on a library, this means that you don't have to worry about changing the dependency versions when merging into `develop`.

## Custom Per-Branch Version Pinning

By default the branch-specific version is derived automatically from the branch name (`1.2.3-SNAPSHOT` → `1.2.3-feature-foo-SNAPSHOT`). If you need to pin the project version and/or specific dependency versions to explicit values for specific branches, add an optional configuration file to your repository (default path: `.prevent-overwrites.conf`, configurable via the `config-file` input).

If the file does not exist, or if it has no entry matching the current branch, behaviour is unchanged.

### Format

The file is a simple whitespace-separated table. Blank lines and lines starting with `#` are ignored.

```
# branch-pattern   target                             value
feature/f1         project-version                    1.2.3-f1-SNAPSHOT
feature/f1         dependency:com.example:d1          2.0.0-f1-SNAPSHOT
feature/f1         dependency:com.example:d2          3.0.0-f1-SNAPSHOT
feature/f2         project-version                    1.2.3-f2-SNAPSHOT
```

- **`branch-pattern`** — glob-matched against the current branch name (same matching as `core-branches`, so `feature/*` works).
- **`target`** — one of `project-version`, `dependency:<groupId>:<artifactId>`, or `exclusive-version-suffix`.
- **`value`** — for the pin targets, the version to pin to; for `exclusive-version-suffix`, the suffix to protect.

### Rules

- **Pinned values must follow the `<base>-<suffix>-SNAPSHOT` pattern** (e.g. `1.2.3-f1-SNAPSHOT`, not `vf1`). This is what allows the version to be **automatically reverted to `<base>-SNAPSHOT`** when the branch is merged into a core branch — exactly like an auto-derived branch version. A value that does not match the pattern is a hard error and fails the job.
- **`project-version`** pins only take effect when `enforce-branch-version` is `true` (they replace the auto-derived project version, even if the pom already carries an inherited branch suffix).
- **`dependency:*`** pins apply on non-core branches regardless of `enforce-branch-version`, so application projects can pin the dependency versions they build against.
- If the project already has a branch-specific version, it is left alone (same as the default behaviour) — unless its suffix has been declared exclusive (see below).

### Exclusive version suffixes

By default, when a pom already carries a branch-specific version, it is left untouched. This is a problem for **long-lived feature branches**: if you branch off `feature/abc` (whose pom is `1.2.3-feature-abc-SNAPSHOT`), your new branch inherits that version and would publish under — and overwrite — `feature/abc`'s artifacts.

The `exclusive-version-suffix` target marks a suffix as belonging to a single branch. When the pom carries that suffix but the current branch is **not** the one it derives from, the version is re-derived for the current branch instead of being left alone. On the owning branch it is left untouched, and re-runs make no change.

```
# branch-pattern  target                    value
*                 exclusive-version-suffix  feature-abc
```

- The **value is a version suffix**, not a branch name: it is the part between `<base>-` and `-SNAPSHOT`, with slashes already replaced by hyphens (`feature/abc` → `feature-abc`).
- Use `*` for the branch-pattern to enforce the suffix everywhere. Note that in glob matching `*` already spans slashes, so `**/*` would only match branches that contain a `/` — use `*` to match every branch.
- Declare one line per suffix you want to protect.
- With no `exclusive-version-suffix` entry, the default (leave inherited versions alone) is unchanged.

## GitHub Actions Usage

Preconditions:

- The `GITHUB_TOKEN` needs to have write permission for scope `contents`, otherwise the version changes cannot be pushed.
  See [GitHub documentation](https://docs.github.com/en/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token) and example workflow below.

- The checkout action needs `GITHUB_TOKEN` to checkout the source in a way that changes can be pushed later. See example workflow below.

- Only Linux-based runners are currently supported.

Minimum action configuration:

```yaml
    - name: Prevent Maven Artifact Overwrites
      uses: maven-flow/prevent-artifact-overwrites@v1
      with:
        enforce-branch-version: true
        push-changes: true
```

Full action configuration:

```yaml
    - name: Prevent Maven Artifact Overwrites
      uses: maven-flow/prevent-artifact-overwrites@v1
      with:
        commit-message-suffix: '[skip ci]'
        enforce-branch-version: true
        git-user-name: 'John Doe'
        git-user-email: 'john.doe@example.com'
        pom-file: 'subdir/pom.xml'
        push-changes: true
        core-branches: 'main master develop release*'
```

Example workflow:

```yaml
name: Java CI with Maven

on: push

jobs:

  build:
    runs-on: ubuntu-latest
    permissions:
      contents: write  # write permission needed to enable GIT push

    steps:

    - uses: actions/checkout@v4
      with:
        token: ${{ github.token }}  # token needed to enable GIT push

    - name: Set up JDK 17
      uses: actions/setup-java@v4
      with:
        java-version: '17'
        distribution: 'temurin'

    - name: Prevent Maven Artifact Overwrites
      uses: maven-flow/prevent-artifact-overwrites@v1
      with:
        enforce-branch-version: true
        push-changes: true

    - name: Build with Maven
      run: mvn -B deploy
      env:
        GITHUB_TOKEN: ${{ github.token }}
```

## Inputs

### `commit-message-suffix`

**Optional.** A suffix that can be added to the commit message when committing changes. For example, you could add `[skip ci]`if you want to prevent another workflow run after performing changes.

**Default value:** `""`

### `enforce-branch-version`

**Required.** Whether the project version should be changed to a branch-specific value on feature branches. Set to `true` on library projects and to `false` on non-library (application) projects.

### `git-user-name`

**Optional.** The user name which will be used to perform GIT commits.

**Default value:** `github-actions[bot]`

### `git-user-email`

**Optional.** The email which will be used to perform GIT commits.

**Default value:** `github-actions[bot]@users.noreply.github.com`

### `maven-args`

**Deprecated.** No longer used. Kept for backwards compatibility.

### `pom-file`

**Optional.** Specify the path to Maven POM file. Useful for example if your POM file is not in the repository root.

**Default value:** `pom.xml`

### `core-branches`

**Optional.** Space-separated list of branch patterns that should NOT receive a branch-specific version suffix. Supports glob patterns like `release*`.

**Default value:** `main master develop release*`

### `config-file`

**Optional.** Path to a per-branch version pinning config file (see [Custom Per-Branch Version Pinning](#custom-per-branch-version-pinning)). If the file does not exist, behaviour is unchanged.

**Default value:** `.prevent-overwrites.conf`

## GitLab CI/CD Usage

This tool is also available as a GitLab CI/CD Component.

### Prerequisites

- GitLab 17.0 or later (for CI/CD Components support)
- Maven installed on the runner (or use a Maven Docker image)
- Git push access configured (the `CI_JOB_TOKEN` is used by default)

### Basic Configuration

Add the following to your `.gitlab-ci.yml`:

```yaml
include:
  - component: gitlab.com/maven-flow/prevent-artifact-overwrites/prevent-overwrites@v1
    inputs:
      enforce-branch-version: true
      push-changes: true
```

### Full Configuration

```yaml
include:
  - component: gitlab.com/maven-flow/prevent-artifact-overwrites/prevent-overwrites@v1
    inputs:
      enforce-branch-version: true
      push-changes: true
      commit-message-suffix: " [skip ci]"
      git-user-name: "John Doe"
      git-user-email: "john.doe@example.com"
      pom-file: "subdir/pom.xml"
      core-branches: "main master develop release*"
      stage: "prepare"
      image: "maven:3.9-eclipse-temurin-17"
      rerun-on-change: true
```

### Example Pipeline

```yaml
stages:
  - prepare
  - build

include:
  - component: gitlab.com/maven-flow/prevent-artifact-overwrites/prevent-overwrites@v1
    inputs:
      enforce-branch-version: true
      push-changes: true

build:
  stage: build
  image: maven:3.9-eclipse-temurin-17
  needs:
    - job: prevent-overwrites
      optional: true
  script:
    - mvn -B deploy
```

### GitLab CI/CD Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `enforce-branch-version` | Yes | - | Whether to enforce branch-specific versions |
| `push-changes` | Yes | - | Whether to push changes to remote |
| `commit-message-suffix` | No | `""` | Text appended to commit messages |
| `git-user-name` | No | `gitlab-ci[bot]` | Git user name for commits |
| `git-user-email` | No | `gitlab-ci[bot]@users.noreply.gitlab.com` | Git user email for commits |
| `maven-args` | No | `""` | **Deprecated.** No longer used. |
| `pom-file` | No | `pom.xml` | Path to Maven POM file |
| `core-branches` | No | `main master develop release*` | Branch patterns that should NOT receive a branch-specific version suffix (supports globs) |
| `config-file` | No | `.prevent-overwrites.conf` | Path to a per-branch version pinning config file (see [Custom Per-Branch Version Pinning](#custom-per-branch-version-pinning)) |
| `stage` | No | `prepare` | Pipeline stage for the job |
| `image` | No | `maven:3.9-eclipse-temurin-17` | Docker image for the job |
| `script-repo-path` | No | `maven-flow/prevent-artifact-overwrites` | GitLab repo path for the script |
| `script-version` | No | `v1` | Git ref to fetch the script from |
| `rerun-on-change` | No | `false` | When true, cancels the current pipeline and triggers a fresh one if `prevent-overwrites` pushed a new commit (see below) |

### Rerun Pipeline on Change

When `prevent-overwrites` pushes a new commit (e.g. to enforce a branch-specific version), the current pipeline is running against a stale commit. Setting `rerun-on-change: true` makes `prevent-overwrites` handle this automatically at the end of its script: if it made any changes, it triggers a new pipeline on the latest commit and cancels the current one.

This requires a `GITLAB_API_TOKEN` CI/CD variable with sufficient API access (at minimum: `api` scope or `read_api` + `write_pipelines`).

```yaml
include:
  - component: gitlab.com/maven-flow/prevent-artifact-overwrites/prevent-overwrites@v1
    inputs:
      enforce-branch-version: true
      push-changes: true
      rerun-on-change: true
```

### Protected Branches

If pushing to protected branches, you may need to:
1. Allow the `CI_JOB_TOKEN` to push to protected branches in your project settings, or
2. Use a project access token with write permissions

### Self-Hosted GitLab

The script is fetched from `${CI_SERVER_URL}/${script-repo-path}`, so it automatically uses your GitLab instance. Just mirror this repository to your GitLab at the default path (`maven-flow/prevent-artifact-overwrites`), or override `script-repo-path` if you use a different location:

```yaml
include:
  - component: gitlab.example.com/my-org/prevent-artifact-overwrites/prevent-overwrites@v1
    inputs:
      enforce-branch-version: true
      push-changes: true
      script-repo-path: "my-org/prevent-artifact-overwrites"
```
