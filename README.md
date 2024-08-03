# Prevent Overwriting Maven Artifact Versions From Feature Branches

When using [Git Flow](https://nvie.com/posts/a-successful-git-branching-model/) to develop library projects with Maven, you often run in to a problem, that SNAPSHOT artifacts from develop and different feature branches overwrite each-other in the Maven repository, which leads to random compilation errors.

You can solve this by changing the project version into a unique value for every feature branch. For example changing the version `1.1.0-SNAPSHOT` into `1.1.0-cool-feature-SNAPSHOT`. That way, the branches do not interfere with each other.

Changing the versions manually is annoying, time-consuming, and most importantly - people always keep forgetting. Over the years, the internet has come up with [many solutions](https://stackoverflow.com/questions/13583953/deriving-maven-artifact-version-from-git-branch), but they always require some complicated setup on every developer's machine (Git hooks or extensions) and/or do not work well with IDEs (Maven plugins changing the version at compile-time).

This Github action automates the process on a CI/CD level, which brings several benefits:
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
