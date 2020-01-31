# Monorepo with gradle and circleci or bitbucket pipelines

This is an example of how to manage monorepo with [gradle](https://gradle.org/) as build tool
and [circleci](https://circleci.com/) or [bitbucket pipelines](https://bitbucket.org/product/features/pipelines) as CI tool.

## Motivation

When I push some changes to monorepository **I want to**
  
  - build only modified projects
  - build all other projects depending on modified projects
  - build projects in parallel if it is possible
  - not build projects when their dependencies are failing
  - discover dependencies between projects automatically 

## How it works

There is only one job called **build** started automatically on every push. This job is responsible for triggering another jobs for each affected project in order with respecting project dependencies.

Build job is running until all triggered jobs are finished.

Build job is successful only when there were no failed jobs (even when there were no jobs).

### Where are projects defined

There is file `tools/ci/projects.txt` which contains lines with [glob patterns](https://en.wikipedia.org/wiki/Glob_(programming)) pointing to root directories of all supported projects.

### Where are jobs defined

Jobs are defined in default location depending on which CI tool you are using.

  - CircleCI - `.circleci/config.yml`
  - Bitbucket Pipelines - `bitbucket-pipelines.yml`

### How projects are mapped to jobs

Currently there is a convention used for mapping project to CI job. Job name is resolved from project's directory path as last path component. 

> e.g. project under directory `apps/server` is built by job `server`.

### How dependencies between projects are resolved

Dependencies are based on Gradle's [composite build](https://docs.gradle.org/current/userguide/composite_builds.html) feature. To define dependency between projects use `includeBuild` function in project build script (usually in `settings.gradle`).

### How dependencies affects job triggering

To respect dependencies between projects jobs are triggered in multiple rounds. For each round one or more jobs are triggered and only when all jobs are successfully finished next round is processed. Even if there is only one failed job all next rounds are skipped and whole build is failed. 

## Special commands

Commit message can contain some special words which if found can modify default building behavior.

Supported commands:
 - **[rebuild-all]** - build all projects instead of only changed 

## Implementation

Whole logic is implemented as bunch of [Bash](https://en.wikipedia.org/wiki/Bash_(Unix_shell)) scripts under directory `tools/ci`. Every script can be run directly and it should output some documentation when it requires some parameters.

Implementation is split to core logic and plugins for different CI tools. Core logic can be found under `tools/ci/core` and plugins are under `tools/ci/plugins`.

### Which one is main script

Main script is `tools/ci/core/build.sh` and it is only thing started from build job.

### Are there any non-standard tools used

There is tool called [jq](https://stedolan.github.io/jq/) used for JSON parsing.

>You need to care only when you want run it locally or you are using docker images not from circleci for jobs execution. 

## How to run locally

It is possible to run `tools/ci/core/build.sh` locally but there is need to provide few environment variables depending on CI tool used.

### CircleCI

    CI_TOOL=circleci \
    CIRCLE_API_USER_TOKEN=XXX \
    CIRCLE_PROJECT_USERNAME=zladovan \
    CIRCLE_PROJECT_REPONAME=monorepo \
    CIRCLE_BRANCH=master \
    CIRCLE_SHA1=$(git rev-parse HEAD) \
    tools/ci/core/build.sh

Where:

  - **CIRCLE_API_USER_TOKEN** is your private token
  - **CIRCLE_SHA1** should be set to current commit hash, but it can be any commit hash

>Note that this command could trigger some jobs in circleci

### Bitbucket pipelines

    CI_TOOL=bitbucket \
    BITBUCKET_USER=zladovan \
    BITBUCKET_PASSWORD=xxx \
    BITBUCKET_REPO_FULL_NAME=zladovan/monorepo \
    BITBUCKET_BRANCH=master \
    BITBUCKET_COMMIT=$(git rev-parse HEAD) \
    tools/ci/core/build.sh

Where:

  - **BITBUCKET_COMMIT** should be set to current commit hash, but it can be any commit hash

>Note that this command could trigger some jobs in bitbucket

## Folder structure

Folder structure used in this repository is only an example of how it can look like. It is possible to use any structure, there is only need to use different patterns in `tools/ci/projects.txt` 

    apps/
      └── stand-alone runnable and deployable applications

    libs/
      └── reusable libraries (used in apps dependencies)  

    tools/gradle-plugins/
      └── reusable gradle logic (used in apps and libs builds)

    tools/ci
      └── ci scripts 

## Known issues

  - jobs are not triggered in parallel for all cases due to using [tsort](https://en.wikipedia.org/wiki/Tsort) for processing dependencies which produce only sequential order
  - not tested on Mac OS and probably there will be issue with `realpath` used
  
## Todo

  - write how to setup for different ci tools
  - improve parallel executions support
  - create Gradle plugin with same logic as in bash scripts (as a separate project)
  - add support for other popular CI tools (e.g. [Travis](https://travis-ci.org/), [Jenkins](https://jenkins.io/), ...)
  - create [Circleci orb](https://circleci.com/orbs/)

## Credits

Thanks to [Tufin](https://github.com/Tufin) for inspiration in [Tufin/circleci-monorepo](https://github.com/Tufin/circleci-monorepo).
