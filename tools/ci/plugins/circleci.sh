#!/bin/bash

# Documentation 
read -r -d '' USAGE_TEXT << EOM
Usage: circleci.sh command [<param>...]
Run given command in circleci.

Requires circleci environment variables (additional may be required for specific commands):
    CIRCLE_API_USER_TOKEN
    CIRCLE_PROJECT_USERNAME
    CIRCLE_PROJECT_REPONAME

Available commands:  
    build <project_name>    start build of given project
                            outputs build number
                            requires: CIRCLE_BRANCH  
    status <build_number>   get status of build identified by given build number
                            outputs one of: success | failed | null
    kill <build_number>     kills running build identified by given build number                            
    hash <position>         get revision hash on given positions
                            available positions:
                                last        hash of last succesfull build commit
                                            only commits of 'build' job are considered
                                            requires: CIRCLE_BRANCH
                                current     hash of current commit
                                            requires: CIRCLE_SHA1
                                            requires: CIRCLE_BRANCH                            
    help                    display this usage text                             
EOM

set -e

# Constants
# TODO: There is different link for bitbucket projects (../project/bitbucket/..)
CIRCLECI_URL="https://circleci.com/api/v1.1/project/github/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}"

# Functions

##
# Print message on stderr to do not affect stdout which can be used as input to another commands.
#
# Input:
#    MESSAGE - message to print
#
function log {
    MESSAGE=$1
    >&2 echo "$MESSAGE"
}

##
# Print error message and exit program with status code 1
#
# Input:
#   MESSAGE - error message to show
##
function fail {
    MESSAGE=$1
    log "ERROR: $MESSAGE"
    log "$USAGE_TEXT"
    exit 1
}

##
# Fast fail when given environment variable is not set.
#
# Input:
#   ENV_VAR - name of environment variable to check
##
function require_env_var {
    local ENV_VAR=$1
    if [[ -z "${!ENV_VAR}" ]]; then
        fail "$ENV_VAR is not set"
    fi  
}

##
# Fast fail when given parameter is empty
#
# Input:
#   MESSAGE - message to show when requirement is not met
#   PARAM - parameter which should be not null
##
function require_not_null {
    local MESSAGE=$1
    if [[ -z "$2" ]]; then
        fail "$MESSAGE"
    fi
}

##
# Make HTTP POST call to circleci
#
# Input:
#   URL - part of URL after circleci base url
#   DATA - form data to post (optional)
##
function post {
    local URL=$1
    local DATA=$2
    if [[ ! -z $DATA ]]; then
        DATA="-d $DATA"
    fi
    curl -XPOST -s -u ${CIRCLE_API_USER_TOKEN}: ${DATA} ${CIRCLECI_URL}/${URL}
}

##
# Make HTTP GET call to circleci
#
# Input:
#   URL - part of URL after circleci base url
##
function get {
    local URL=$1
    curl -s -u ${CIRCLE_API_USER_TOKEN}: ${CIRCLECI_URL}/${URL}
}

##
# Trigger build in circleci
#
# Input:
#   PROJECT_NAME - name of project to start build for
#
# Output:
#   build number
##
function trigger_build {
    local PROJECT_NAME=$1
    require_env_var CIRCLE_BRANCH
    require_not_null "Project name not speficied" ${PROJECT_NAME} 
    TRIGGER_RESPONSE=$(post "tree/$CIRCLE_BRANCH" "build_parameters[CIRCLE_JOB]=${PROJECT_NAME}")
    echo "$TRIGGER_RESPONSE" | jq -r '.["build_num"]'
}

##
# Get status of circleci build
#
# Input:
#   BUILD_NUM - build identification number
#
# Output:
#   success | failed | null
##
function get_build_status {
    local BUILD_NUM=$1
    require_not_null "Build number not speficied" ${BUILD_NUM} 
    STATUS_RESPONSE=$(get ${BUILD_NUM})
    echo "$STATUS_RESPONSE" | jq -r '.["outcome"]'
}


##
# Kill circleci build
#
# Input:
#   BUILD_NUM - build identification number
##
function kill_build {
    local BUILD_NUM=$1
    require_not_null "Build number not speficied" ${BUILD_NUM} 
    STATUS_RESPONSE=$(post ${BUILD_NUM}/cancel)
}

##
# Get revision hash of last successful commit which invokes main monorepository build
#
# Output:
#   revision hash or null when there were no commits yet
##
function get_last_successful_commit {
    require_env_var CIRCLE_BRANCH
    get "tree/$CIRCLE_BRANCH?filter=successful&limit=100" \
        | jq --raw-output '[.[]|select(.workflows.job_name=="build")] | max_by(.build_num).vcs_revision'    
}

##
# Get revision hash of current commit
#
# Output:
#   revision hash or null when there were no commits yet
##
function get_current_commit {
    require_env_var CIRCLE_SHA1
    echo "$CIRCLE_SHA1"
}

##
# Main
##

# Validatate common requirements
require_env_var CIRCLE_API_USER_TOKEN
require_env_var CIRCLE_PROJECT_USERNAME
require_env_var CIRCLE_PROJECT_REPONAME

# Parse command
case $1 in
    build)        
        trigger_build $2
        ;;
    status)
        get_build_status $2
        ;;
    kill)
        kill_build $2
        ;;    
    hash)
        case $2 in
            last)
                get_last_successful_commit
                ;;
            current)
                get_current_commit
                ;;
            *)
                fail "Unknown hash position $2"             
                ;;
        esac
        ;;        
    *)
        fail "Unknown command $1"
        ;;        
esac