#!/bin/bash

# Documentation
read -r -d '' USAGE_TEXT << EOM
Usage:
    list-projects-to-builds.sh <revision range>

    List all projects which had some changes in given commit range.
    Project is identified with relative path to project's root directory from repository root.
    Output list is ordered respecting dependencies between projects (lower projects depends on upper).
    There can be multiple projects (separated by space) on single line which means they can be build on parallel.
   
    If one of commit messages in given commit range contains [rebuild-all] flag then all projects will be listed.

    <revision reange>       range of revision hashes where changes will be looked for
                            format is HASH1..HASH2
EOM

set -e

# Capture input parameter and validate it
COMMIT_RANGE=$1
COMMIT_RANGE_FOR_LOG="$(echo $COMMIT_RANGE | sed -e 's/\.\./.../g')"

if [[ -z $COMMIT_RANGE ]]; then
    echo "ERROR: You need to provide revision range in fomrat HASH1..HASH2 as input parameter"
    echo "$USAGE_TEXT"
    exit 1
fi    

# Find script directory (no support for symlinks)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Look for changes in given revision range
CHANGED_PATHS=$(git diff $COMMIT_RANGE --name-status)
#echo -e "Changed paths:\n$CHANGED_PATHS" 

# Look for dependencies between projects
PROJECT_DEPENDENCIES=$(${DIR}/list-dependencies.sh)

# Setup variables for output collecting 
CHANGED_PROJECTS=""
CHANGED_DEPENDENCIES=""

##
# Recusively look for projects which depends on given project.
# Outputs lines of tuples in format PROJECT1 PROJECT2 (separated by space), 
# where PROJECT1 depends on PROJECT2.
# 
# Input:
#   PROJECT - id of project
##
function process_dependants {
    local PROJECT=$1
    local DEPENDENCIES=$(echo "$PROJECT_DEPENDENCIES" | grep ".* $PROJECT")
    echo "$NEW_DEPENDENCEIS" | while read DEPENDENCY; do
        DEPENDENCY=$(echo "$DEPENDENCY" | cut -d " " -f1)
        if [[ ! $(echo "$CHANGED_PROJECTS" | grep "$DEPENDENCY") ]]; then
            NEW_DEPENDENCEIS="$DEPENDENCIES\n$(process_dependants $DEPENDENCY)"
        fi
    done    
    echo -e "$DEPENDENCIES"
}

# If [rebuild-all] command passed it's enought to take all projects and all dependencies as changed
if [[ $(git log "$COMMIT_RANGE_FOR_LOG" | grep "\[rebuild-all\]") ]]; then
    CHANGED_PROJECTS="$(${DIR}/list-projects.sh)"
    CHANGED_DEPENDENCIES="$PROJECT_DEPENDENCIES"
else    
    # For all known projects check if there was a change and look for all dependant projects
    for PROJECT in $(${DIR}/list-projects.sh); do
        PROJECT_NAME=$(basename $PROJECT)
        if [[ $(echo -e "$CHANGED_PATHS" | grep "$PROJECT") ]]; then                
            CHANGED_PROJECTS="$CHANGED_PROJECTS\n$PROJECT"
            CHANGED_DEPENDENCIES="$CHANGED_DEPENDENCIES\n$(process_dependants $PROJECT)"                 
        fi               
    done
fi

# Build output 
PROJECTS_TO_BUILD=$(echo -e "$CHANGED_DEPENDENCIES" | tsort | tac)
for PROJECT in $(echo -e "$CHANGED_PROJECTS"); do
    if [[ ! $(echo -e "$PROJECTS_TO_BUILD" | grep "$PROJECT") ]]; then    
        PROJECTS_TO_BUILD="$PROJECT $PROJECTS_TO_BUILD"
    fi
done

# Print output
echo -e "$PROJECTS_TO_BUILD"
