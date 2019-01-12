# Monorepo with gradle and circleci

This is an example of managing monorepo with [gradle](https://gradle.org/) as build tool
and [circleci](https://circleci.com/) as CI tool.

## File structure

    apps/
      └── stand-alone runnable and deployable applications

    libs/
      └── reusable libraries (used in apps dependencies)  

    tools/gradle-plugins/
      └── reusable gradle logic (used in apps and libs builds)

## TODO
