#!/bin/bash

# Documentation 
read -r -d '' USAGE_TEXT << EOM
Usage: travis.sh command [<param>...]
Run given command in travis.

Requires bitbucket environment variables (additional may be required for specific commands):
    TRAVIS_TOKEN
    TRAVIS_REPO_SLUG
    
Available commands:  
    build <project_name>    start build of given project
                            outputs build request id
                            requires: TRAVIS_BRANCH
    status <build_number>   get status of build identified by given build number
                            outputs one of: success | failed | null
    kill <build_number>     kills running build identified by given build number                            
    hash <position>         get revision hash on given positions
                            available positions:
                                last        hash of last succesfull build commit
                                            only commits of 'build' job are considered
                                            requires: TRAVIS_BRANCH
                                current     hash of current commit
                                            requires: TRAVIS_COMMIT                         
    help                    display this usage text                             
EOM

set -e

TRAVIS_URL="https://api.travis-ci.org"

# for some requests root url contains repo resource
TRAVIS_REPO_RES="repo/${TRAVIS_REPO_SLUG/\//%2F}"

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
# Make HTTP POST call to travis
#
# Input:
#   URL - part of URL after travis repo base url
#   DATA - form data to post (optional)
##
function post {
    local URL=$1
    local DATA=$2
    if [[ ! -z $DATA ]]; then
        DATA="-H 'Content-Type: application/json' -d '$DATA'"
    fi
    RESPONSE=$(eval "curl -XPOST -s -g -H 'Travis-API-Version: 3' -H 'Authorization: token ${TRAVIS_TOKEN}' ${DATA} ${TRAVIS_URL}/${URL}")
    TYPE=$(echo "$RESPONSE" | jq -r '."@type"')
    if [[ ${TYPE} = 'error' ]]; then 
        log "ERROR: Error response from travis POST request"
        log "$RESPONSE"
        return 1
    fi
    echo "$RESPONSE"
}

##
# Make HTTP GET call to travis
#
# Input:
#   URL - part of URL after travis base url
##
function get {
    local URL=$1
    curl -s -g -H "Travis-API-Version: 3" -H "Authorization: token ${TRAVIS_TOKEN}" ${TRAVIS_URL}/${URL}
}

##
# Trigger build in travis
#
# Build in travis is triggered by creating a 'request'.
# After crating a request there is need to wait for request to be 'approved'.
# When request is 
#  - approved we can get build id.
#  - rejected we consider it as there is no job defined with given name and return 'null'.
#  - not approved nor rejected within 10 seconds error is raised.
#
# Input:
#   PROJECT_NAME - name of project to start build for
#
# Output:
#   build number
##
function trigger_build {
    # TODO there is a ban for 1 hour if you make 10 POST requests within 30 seconds
    local PROJECT_NAME=$1
    require_env_var TRAVIS_BRANCH
    require_not_null "Project name not speficied" ${PROJECT_NAME} 
    BODY="$(cat <<-EOM
    {
        "request": {
            "branch":"${TRAVIS_BRANCH}",
            "config": {
                "env": {
                    "global": [
                        "CI_JOB=${PROJECT_NAME}"
                    ]
                }
            }
        }   
    }
EOM
    )"
    TRIGGER_RESPONSE=$(post "$TRAVIS_REPO_RES/requests" "${BODY}")
    REQUEST_ID=$(echo "$TRIGGER_RESPONSE" | jq -r .request.id)
    for (( WAIT_SECONDS=0; WAIT_SECONDS<=10; WAIT_SECONDS+=1 )); do
        REQUEST_RESPONSE=$(get $TRAVIS_REPO_RES/request/${REQUEST_ID})
        REQUEST_RESULT=$(echo "$REQUEST_RESPONSE" | jq -r '.result')
        case $REQUEST_RESULT in
            rejected)
                echo "null"
                return
                ;;
            approved)
                echo "$REQUEST_RESPONSE" | jq -r .builds[0].id
                return
                ;;
            *)
                sleep 1
                ;;   
        esac
    done
    log "ERROR: Timeout when waiting for request '$REQUEST_ID' to be approved"
    log "$REQUEST_RESPONSE"
    return 1
}

##
# Get status of travis build
#
# Input:
#   BUILD_ID - id of build (resource id, not build number)
#
# Output:
#   success | failed | null
##
function get_build_status {
    local BUILD_ID=$1
    require_not_null "Build id not speficied" ${BUILD_ID} 
    STATUS_RESPONSE=$(get build/${BUILD_ID})
    STATUS=$(echo "$STATUS_RESPONSE" | jq -r .state)
    case $STATUS in
        passed)
            echo "success"
            ;;
        failed|errored|canceled)
            echo "failed"
            ;;
        *)
            echo "null"
            ;;
    esac
}


##
# Kill travis build
#
# Input:
#   BUILD_ID - id of build (resource id, not build number)
##
function kill_build {
    local BUILD_ID=$1
    require_not_null "Build id not speficied" ${BUILD_ID} 
    STATUS_RESPONSE=$(post build/${BUILD_ID}/cancel)
}

##
# Get revision hash of last successful commit which invokes main monorepository build
#
# Output:
#   revision hash or null when there were no commits yet
##
function get_last_successful_commit {
    #TODO handle case when last successful commit is not on page
    SELECTOR='(.jobs[] | select(.config.name=="build")) and (.state=="passed") and (.branch.name=="'${TRAVIS_BRANCH}'")'
    get "$TRAVIS_REPO_RES/builds?include=job.config" | jq -r "[.builds[] | select($SELECTOR)] | max_by(.number | tonumber).commit.sha"
}

##
# Get revision hash of current commit
#
# Output:
#   revision hash or null when there were no commits yet
##
function get_current_commit {
    require_env_var TRAVIS_COMMIT
    echo "$TRAVIS_COMMIT"
}

##
# Main
##

# Validatate common requirements
require_env_var TRAVIS_TOKEN
require_env_var TRAVIS_REPO_SLUG

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