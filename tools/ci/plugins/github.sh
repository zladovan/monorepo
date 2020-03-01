#!/bin/bash

# Documentation 
read -r -d '' USAGE_TEXT << EOM
Usage: github.sh command [<param>...]
Run given command in github.

Requires github environment variables (additional may be required for specific commands):
    GITHUB_REPOSITORY
    GITHUB_TOKEN
    
Available commands:  
    build <project_name>    start build of given project
                            outputs build request id
                            requires: GITHUB_REF
    status <build_number>   get status of build identified by given build number
                            outputs one of: success | failed | null
    kill <build_number>     kills running build identified by given build number                            
    hash <position>         get revision hash on given positions
                            available positions:
                                last        hash of last succesfull build commit
                                            only commits of 'build' job are considered
                                            accepts: GITHUB_REF, if ommited no branch filtering
                                current     hash of current commit
                                            requires: GITHUB_SHA                         
    help                    display this usage text                             
EOM

set -e

GITHUB_URL="https://api.github.com/repos/${GITHUB_REPOSITORY}"

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
# Make HTTP POST call to github
#
# Input:
#   URL - part of URL after github repo base url
#   DATA - form data to post (optional)
##
function post {
    local URL=$1
    local DATA=$2
    if [[ ! -z $DATA ]]; then
        DATA="-H 'Content-Type: application/json' -d '$DATA'"
    fi
    eval "curl -XPOST -s -g -H 'Accept: application/vnd.github.v3+json' -H 'Authorization: token ${GITHUB_TOKEN}' ${DATA} ${GITHUB_URL}/${URL}"
}

##
# Make HTTP GET call to github
#
# Input:
#   URL - part of URL after github base url
##
function get {
    local URL=$1
    curl -s -g -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GITHUB_TOKEN}" ${GITHUB_URL}/${URL}
}

##
# Get current branch name
#
# Input:
#   REQUIRED - any not empty value to perform validation on existence of environment variable with branch name
##
function get_branch {
    if [[ -n "$1" ]]; then
        require_env_var GITHUB_REF
    fi
    echo ${GITHUB_REF##*/}
}

##
# Trigger build in github
#
# Build in github is triggered by dispatching custom event with job parameter set to project name.
# After event is triggered zero, one or more workflows can be started.
# We need to check all started workflows if they contain job with same name as project name.
# If such a job is found then it's workflow's run id is returned as build id.
#
# There is timeout set to 5 seconds for the workflow run to be started.
# If timeout is reached it is considered that job was not defined and 'null' is returned.
#
# Input:
#   PROJECT_NAME - name of project to start build for
#
# Output:
#   build number
##
function trigger_build {
    local PROJECT_NAME=$1
    require_not_null "Project name not speficied" ${PROJECT_NAME} 
    BRANCH=$(get_branch required)
    NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    BODY="$(cat <<-EOM
    {
        "event_type": "build-${PROJECT_NAME}",
        "client_payload": {
            "job": "${PROJECT_NAME}"
        }
    }
EOM
    )"
    post dispatches "${BODY}"
    for (( WAIT_SECONDS=0; WAIT_SECONDS<=5; WAIT_SECONDS+=1 )); do
        WFS=$(get 'actions/runs?event=repository_dispatch' | jq '[ .workflow_runs[] | select(.created_at > "'${NOW}'" and .head_branch == "'${BRANCH}'") ]')
        ID='null'
        for JOBS_URL in $(echo "$WFS" | jq -r 'map(.jobs_url) | .[]'); do 
            JOBS_URL=${JOBS_URL/$GITHUB_URL/}
            ID=$(get ${JOBS_URL:1} | jq '[ .jobs[] | select(.name == "'${PROJECT_NAME}'") ] | map(.run_id) | .[0]')
            if [[ ${ID} != 'null' ]]; then 
                break
            fi
        done
        if [[ ${ID} == 'null' ]]; then 
            sleep 1
        else
            echo ${ID}
            return
        fi
    done
    echo 'null'
}

##
# Get status of github build
#
# Input:
#   BUILD_ID - id of build (workflow run id)
#
# Output:
#   success | failed | null
##
function get_build_status {
    local BUILD_ID=$1
    require_not_null "Build id not speficied" ${BUILD_ID} 
    STATUS_RESPONSE=$(get actions/runs/${BUILD_ID})
    STATUS=$(echo "$STATUS_RESPONSE" | jq -r .conclusion)
    case $STATUS in
        success)
            echo "success"
            ;;
        failure|cancelled)
            echo "failed"
            ;;
        skipped)
            echo "skipped"
            ;;
        *)
            echo "null"
            ;;
    esac
}


##
# Kill github build
#
# Input:
#   BUILD_ID - id of build (workflow run id)
##
function kill_build {
    local BUILD_ID=$1
    require_not_null "Build id not speficied" ${BUILD_ID} 
    STATUS_RESPONSE=$(post actions/runs/${BUILD_ID}/cancel)
}

##
# Get revision hash of last successful commit which invokes main monorepository build
#
# Output:
#   revision hash or null when there were no commits yet
##
function get_last_successful_commit {
    BRANCH=$(get_branch)
    if [[ -n "$BRANCH" ]]; then
        BRANCH_FILTER='and .head_branch == "'${BRANCH}'"'
    fi
    SELECTOR='.conclusion == "success" '${BRANCH_FILTER}''
    get 'actions/workflows/main.yml/runs' | jq -r "[ .workflow_runs[] | select($SELECTOR) ] | max_by(.run_number | tonumber).head_sha"
}

##
# Get revision hash of current commit
#
# Output:
#   revision hash or null when there were no commits yet
##
function get_current_commit {
    require_env_var GITHUB_SHA
    echo "$GITHUB_SHA"
}

##
# Main
##

# Validatate common requirements
require_env_var GITHUB_REPOSITORY
require_env_var GITHUB_TOKEN

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