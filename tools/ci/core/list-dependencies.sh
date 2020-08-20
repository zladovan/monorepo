#!/bin/bash

##
# List all dependencies between projects.
# Poject is identified with relative path to project's root directory from repository root.
#
# Dependencies can be specified in text file where each line is path (from monorepo root) to other project.
# Default location of dependency file is in root dir of each project on path `.ci/dependencies.txt`.
# Location of dependency file can be changed by setting environment variable `CI_DEPENDENCIES_FILE`.
#
# There is a support for automatic discovery of dependencies for Gradle projects.
# Discovery is based on Gradle's `composite build` feature (https://docs.gradle.org/current/userguide/composite_builds.html).
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
 
# Configuration with default values
: "${CI_DEPENDENCIES_FILE:=.ci/dependencies.txt}"

# Look for dependecies of each project
for PROJECT in $(${DIR}/list-projects.sh); do   

    # If project contain `includeBuild` function in any of it's *.gradle file
    # then there is dependency on included project
    grep --include=\*.gradle -rwh "$DIR/../../../$PROJECT" -e "includeBuild" | while read INCLUDE; do
        INCLUDE=$(echo "$INCLUDE" | sed -r -n "s/^.*['\"](.*?)['\"].*$/\1/p")
        INCLUDE=$(realpath --relative-to="$DIR/../../.." "$DIR/../../../$PROJECT/$INCLUDE")
        echo "$PROJECT $INCLUDE"
    done

    # Additionaly look into dependency file where each row is path to other project
    DEPENDENCIES_FILE="$DIR/../../../$PROJECT/$CI_DEPENDENCIES_FILE"
    if [[ -f $DEPENDENCIES_FILE ]]; then
        for INCLUDE in $(cat $DEPENDENCIES_FILE); do 
            echo "$PROJECT $INCLUDE"
        done
    fi
done
