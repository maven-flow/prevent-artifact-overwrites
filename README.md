# Prevent Overwriting Maven Artifact Versions From Feature Branches

Since Apache Maven does not have native support for building SNAPSHOT artifact versions from different branches, you can run into annoying problems when developing projects with Git Flow.

### Example Problem

- You are developing an application called `my-app` which uses a library called `my-lib`. According to Git Flow, you are developing on the `develop` branch, where the version of `my-lib` is currently `1.1.0-SNAPSHOT`. The same version is used in `my-app` as a dependency.

- You are creating a new feature, which requires a breaking change in the `my-lib` API. So you create a branch named `feature/foo` both in `my-lib` and `my-app`.

- You implement the breaking API change in `feature/foo` of both `my-lib` and `my-app` and your CI build runs OK.

- The problem is, that the next build on `develop` branch in `my-app` will fail with a compilation error, because the original version `1.1.0-SNAPSHOT` of `my-lib`, got overwritten in the Maven repository by the same version from `feature/foo` (with the breaking API change).

- This could be fixed by running the build of `my-lib` on `develop` again, but that would break the build of `my-app` on `feature/foo`.

- You are now in a state when your builds are failing randomly, depending on which branch of `my-lib` was built last. If you are using more than 1 feature branch simultaneously, the problem gets even worse.

This GitHub action attempts to solve this problem in the most simple and convenient way possible.

## How It Works

### Change to Branch-Specific Version on Feature Branches


### Change to Non Branch-Specific Version in Regular Branches


### Change Dependency Versions


