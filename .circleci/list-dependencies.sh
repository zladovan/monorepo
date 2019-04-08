#!/bin/bash

##
# List all dependencies between projects.
# Poject is identified with relative path to project's root directory from repository root.
# Dependencies are based on Gradle's `composite build` feature (https://docs.gradle.org/current/userguide/composite_builds.html).
# Dependency is defined by using `includeBuild` function in project build script.
# 
# Outputs lines of tuples in format PROJECT1 PROJECT2 (separated by space), 
# where PROJECT1 depends on PROJECT2.
#
# Usage:
#   list-dependencies.sh
##

set -e

# Find script directory (no support for symlinks)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
 
# If project contain `includeBuild` function in any of it's *.gradle file
# then there is dependency on included project
for PROJECT in $(${DIR}/list-projects.sh); do    
    grep --include=\*.gradle -rwh "$DIR/../$PROJECT" -e "includeBuild" | while read INCLUDE; do
        INCLUDE=$(echo "$INCLUDE" | sed -r -n "s/^.*['\"](.*?)['\"].*$/\1/p")
        # todo use already defined projects to find "project id" and without realpath as it's probably not supported on mac
        INCLUDE=$(realpath --relative-to="$DIR/.." "$DIR/../$PROJECT/$INCLUDE")
        echo "$PROJECT $INCLUDE"
    done
done