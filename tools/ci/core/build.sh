#!/bin/bash

##
# Main entry for monorepository build.
# Triggers builds for all modified projects in order respecting their dependencies.
# 
# Usage:
#   build.sh
##

set -e

# Find script directory (no support for symlinks)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Configuration with default values
: "${CI_TOOL:=bitbucket}"
: "${CI_PLUGIN:=$DIR/../plugins/${CI_TOOL}.sh}"

# Resolve commit range for current build 
LAST_SUCCESSFUL_COMMIT=$(${CI_PLUGIN} hash last)
echo "Last commit: ${LAST_SUCCESSFUL_COMMIT}"
if [[ ${LAST_SUCCESSFUL_COMMIT} == "null" ]]; then
    #TODO:  set to first commit instead of current changes ?
    #       there was issue when something failed on first commit and after fix next commit just shown "No projects to build"
    #LAST_SUCCESSFUL_COMMIT=$(git rev-list --max-parents=0 HEAD)
    COMMIT_RANGE="origin/master"
else
    COMMIT_RANGE="$(${CI_PLUGIN} hash current)..${LAST_SUCCESSFUL_COMMIT}"
fi
echo "Commit range: $COMMIT_RANGE"

# Collect all modified projects
PROJECTS_TO_BUILD=$($DIR/list-projects-to-build.sh $COMMIT_RANGE)

# If nothing to build inform and exit
if [[ -z "$PROJECTS_TO_BUILD" ]]; then
    echo "No projects to build"
    exit 0
fi

echo "Following projects need to be built"
echo -e "$PROJECTS_TO_BUILD"

# Build all modified projects
echo -e "$PROJECTS_TO_BUILD" | while read PROJECTS; do
    $DIR/build-projects.sh ${PROJECTS}
done;