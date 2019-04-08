# Monorepo with gradle and circleci

This is an example of managing monorepo with [gradle](https://gradle.org/) as build tool
and [circleci](https://circleci.com/) as CI tool.

## Motivation

When I push some changes to monorepository **I want to**
  
  - build only modified projects
  - build all other projects depending on modified projects
  - build projects in parallel if it is possible
  - not build projects when their dependencies are failing
  - dicover dependencies between projects automatically 

## How it works

There is only one job called **build** started automatically on every push. This job is responsible for triggering another jobs for each affected project in order with respecting project dependencies.

Build job is running until all triggered jobs are finished.

Build job is successful only when there were no failed jobs (even when there were no jobs).

### Where are projects defined

There is file `.circleci/projects.txt` which contains lines with [glob patterns](https://en.wikipedia.org/wiki/Glob_(programming)) pointing to root directories of all supported projects.

### Where are jobs defined

Jobs are defined in `.circleci/config.yml` as by default when circleci is used. 

### How projects are mapped to jobs

Currently there is a convention used for mapping project to circleci job. Job name is resolved from project's directory path as last path component. 

> e.g. project under directory `apps/server` represents job `server`.

### How dependencies between projects are resolved

Dependencies are based on Gradle's [composite build](https://docs.gradle.org/current/userguide/composite_builds.html) feature. To define dependency between projects use `includeBuild` function in project build script (usually in `settings.gradle`).

### How dependencies affects job triggering

To respect dependencies between projects jobs are triggered in multiple rounds. For each round one or more jobs are triggered and only when all jobs are succesfuly finished next round is processed. Even if there is only one failed job all next rounds are skipped and whole build is failed. 

## Folder structure

    apps/
      └── stand-alone runnable and deployable applications

    libs/
      └── reusable libraries (used in apps dependencies)  

    tools/gradle-plugins/
      └── reusable gradle logic (used in apps and libs builds)
