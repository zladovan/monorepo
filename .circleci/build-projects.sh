#!/bin/bash

# Documentation
read -r -d '' USAGE_TEXT << EOM
Usage:
  build-projects.sh <project>...

  Trigger circleci build for all given projects and wait till all builds are successful.
  Project is identified with relative path to project's root directory from repository root.
  When one of build fail then exit with error message.

  Configurable with additional environment variables:
      BUILD_MAX_SECONDS - maximum time in seconds to wait for all builds (15 minutes by default)
      BUILD_CHECK_AFTER_SECONDS - delay between checking status of builds again (15 seconds by default)  
  
  <project>       id of project to build
                  minimally one, can be multiple
EOM

set -e

# Find script directory (no support for symlinks)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Configuration with default values
: "${BUILD_MAX_SECONDS:=$(( 15 * 60 ))}"
: "${BUILD_CHECK_AFTER_SECONDS:=15}"
: "${CI_TOOL:=$DIR/circleci.sh}"

# Validate requirements
if [[ "$#" -eq 0 ]]; then
    echo "ERROR: No projects to build. You must provide at least one project as input parameter."
    echo "$USAGE_TEXT"
    exit 1
fi

# Trigger build for all given projects
PROJECTS=()
for PROJECT in $@; do
    echo "Triggering build for project '$PROJECT'"
    PROJECT_NAME=$(basename $PROJECT)
    BUILD_NUM=$(${CI_TOOL} build $PROJECT_NAME)    
    echo "Build triggered for project '$PROJECT' with number '$BUILD_NUM'"    
    PROJECTS=(${PROJECTS[@]} "$PROJECT,$BUILD_NUM,null")
done;

# Check build status loop
for (( BUILD_SECONDS=0; BUILD_SECONDS<=${BUILD_MAX_SECONDS}; BUILD_SECONDS+=$BUILD_CHECK_AFTER_SECONDS )); do

    # First request status for all not yet finished builds
    for PROJECT_INDEX in "${!PROJECTS[@]}"; do 
        PROJECT_INFO=${PROJECTS[$PROJECT_INDEX]}
        PROJECT=$(echo "$PROJECT_INFO" | cut -d "," -f1)     
        BUILD_NUM=$(echo "$PROJECT_INFO" | cut -d "," -f2)    
        BUILD_OUTCOME=$(echo "$PROJECT_INFO" | cut -d "," -f3)
        if [[ "$BUILD_OUTCOME" == "null" ]]; then            
            BUILD_OUTCOME=$(${CI_TOOL} status ${BUILD_NUM})
            PROJECTS[$PROJECT_INDEX]="$PROJECT,$BUILD_NUM,$BUILD_OUTCOME"
        fi    
    done

    # Then collect build status summary
    SUCCESSFUL_COUNT=0
    BUILDS_RUNNING=""
    for PROJECT_INFO in "${PROJECTS[@]}"; do     
        PROJECT=$(echo "$PROJECT_INFO" | cut -d "," -f1)     
        BUILD_NUM=$(echo "$PROJECT_INFO" | cut -d "," -f2)    
        BUILD_OUTCOME=$(echo "$PROJECT_INFO" | cut -d "," -f3)
        case "$BUILD_OUTCOME" in
            failed)
                echo "Build failed for project '$PROJECT($BUILD_NUM)'"
                exit 1
                ;;
            success)
                SUCCESSFUL_COUNT=$((SUCCESSFUL_COUNT+1))            
                ;;
            *)
                BUILDS_RUNNING="$BUILDS_RUNNING $PROJECT($BUILD_NUM)"
                ;;
        esac    
    done

    # At the end check if all all builds are done
    if [[ ${SUCCESSFUL_COUNT} < ${#PROJECTS[@]} ]]; then
        for RUNNING in $(echo "$BUILDS_RUNNING"); do 
            echo "Waiting for build $RUNNING..."
        done
        sleep ${BUILD_CHECK_AFTER_SECONDS}        
    else
        echo "Build succesul for all projects: $@"
        exit 0
    fi

done    
