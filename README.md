# Monorepo builds with Gradle and popular CI tools

This is an example of how to manage building projects inside monorepo with [Gradle](https://gradle.org/) as build tool and one of the following services as CI tool:

| Service | Status |
|---------|--------|
| [CircleCI](https://circleci.com/) | [![CircleCI](https://circleci.com/gh/zladovan/monorepo.svg?style=svg)](https://circleci.com/gh/zladovan/workflows/monorepo)
| [Bitbucket Pipelines](https://bitbucket.org/product/features/pipelines) | [![Bitbucket Pipelines](https://img.shields.io/bitbucket/pipelines/zladovan/monorepo)](https://bitbucket.org/zladovan/monorepo/addon/pipelines/home) |
| [Travis CI](https://travis-ci.org/) | [![Travis CI](https://travis-ci.org/zladovan/monorepo.svg?branch=master)](https://travis-ci.org/zladovan/monorepo)
| [GitHub Actions](https://github.com/features/actions) | [![GitHub Actions](https://github.com/zladovan/monorepo/workflows/main/badge.svg)](https://github.com/zladovan/monorepo/actions)

## Motivation

When I push some changes to monorepository **I want to**
  
  - build only modified projects
  - build all other projects depending on modified projects
  - build projects in parallel if it is possible
  - not build projects when their dependencies are failing
  - discover dependencies between projects automatically 

## How it works

There is only one main job called **build** started automatically on every push. This job is responsible for triggering another jobs for each affected project in order with respecting project dependencies.

Build job is running until all triggered jobs are finished.

Build job is successful only when there were no failed jobs (even when there were no jobs).

### Where are projects defined

There is file `tools/ci/projects.txt` which contains lines with [glob patterns](https://en.wikipedia.org/wiki/Glob_(programming)) pointing to root directories of all supported projects.

### Where are jobs defined

Jobs are defined in default location depending on which CI tool you are using.

  - CircleCI - `.circleci/config.yml`
  - Bitbucket Pipelines - `bitbucket-pipelines.yml`
  - Travis CI - `.travis.yml`
  - GitHub Actions - `.github/workflows/`

### How projects are mapped to jobs

Currently there is a convention used for mapping project to CI job. Job name is resolved from project's directory path as last path component. 

> e.g. project under directory `apps/server` is built by job `server`.

### How dependencies between projects are resolved

Dependencies are based on Gradle's [composite build](https://docs.gradle.org/current/userguide/composite_builds.html) feature. To define dependency between projects use `includeBuild` function in project build script (usually in `settings.gradle`).

If you are not using Gradle or you want to add some additional dependency you can specify it in dependency file. Default location is in each project directory on path `.ci/dependencies.txt`. Location can be changed by setting environment variable `CI_DEPENDENCIES_FILE`. File should contain lines with paths to other projects (relative paths to monorepo root, e.g. libs/common).

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

>You need to care only when you want run it locally because **jq** is usually part of default images used in CI tools.

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

### Travis CI

    CI_TOOL=travis \
    TRAVIS_TOKEN=xxx \
    TRAVIS_REPO_SLUG=zladovan/monorepo \
    TRAVIS_BRANCH=master \
    TRAVIS_COMMIT=$(git rev-parse HEAD) \
    tools/ci/core/build.sh

Where:

  - **TRAVIS_COMMIT** should be set to current commit hash, but it can be any commit hash

>Note that this command could trigger some jobs in travis

### GitHub Actions

    CI_TOOL=github \
    GITHUB_REPOSITORY=zladovan/monorepo \
    GITHUB_TOKEN=xxx \
    GITHUB_REF=refs/head/master \
    GITHUB_SHA=$(git rev-parse HEAD) \
    tools/ci/core/build.sh

Where:

  - **GITHUB_TOKEN** should be your personal access token with **repo** rights
  - **GITHUB_SHA** should be set to current commit hash, but it can be any commit hash

>Note that this command could trigger some jobs in github

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
  - Travis CI has some limitations around how many builds can be started via API
  
## Todo

  - write how to setup for different ci tools
  - improve parallel executions support
  - add special command to trigger build for specific project
  - create Gradle plugin with same logic as in bash scripts (as a separate project)
  - add support for other popular CI tools (e.g. [Jenkins](https://jenkins.io/), ...)
  - create downloadable package which could be installed to repo during build time
  - create [Circleci orb](https://circleci.com/orbs/)
  - create [GitHub Action](https://help.github.com/en/actions/building-actions)
  

## Credits

Thanks to [Tufin](https://github.com/Tufin) for inspiration in [Tufin/circleci-monorepo](https://github.com/Tufin/circleci-monorepo).
