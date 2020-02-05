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
                                            accepts: TRAVIS_BRANCH, if ommited no branch filtering
                                current     hash of current commit
                                            requires: TRAVIS_COMMIT                         
    help                    display this usage text                             
EOM

set -e

TRAVIS_URL="https://api.travis-ci.org/repo/${TRAVIS_REPO_SLUG/\//%2F}"

# Functions

##
# Print error message and exit program with status code 1
#
# Input:
#   MESSAGE - error message to show
##
function fail {
    MESSAGE=$1
    echo "ERROR: $MESSAGE"
    echo "$USAGE_TEXT"
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
    eval "curl -XPOST -s -g -H 'Travis-API-Version: 3' -H 'Authorization: token ${TRAVIS_TOKEN}' ${DATA} ${TRAVIS_URL}/${URL}"
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
# Input:
#   PROJECT_NAME - name of project to start build for
#
# Output:
#   build number
##
function trigger_build {
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
    TRIGGER_RESPONSE=$(post "requests" "${BODY}")
    echo "$TRIGGER_RESPONSE" | jq -r .request.id 
}

##
# Get status of travis build
#
# Input:
#   REQUEST_ID - id of request triggering build
#
# Output:
#   success | failed | null
##
function get_build_status {
    local REQUEST_ID=$1
    require_not_null "Build number not speficied" ${REQUEST_ID} 
    STATUS_RESPONSE=$(get request/${REQUEST_ID})
    STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.builds[0].state')
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
# Kill travis build or build request if build not created yet
#
# Input:
#   REQUEST_ID - request id which triggered build
##
function kill_build {
    local REQUEST_ID=$1
    require_not_null "Build number not speficied" ${REQUEST_ID} 
    REQUEST_RESPONSE=$(get request/${REQUEST_ID})
    #TODO handle wait for pending request
        #REQUEST_TYPE=$(echo "$REQUEST_RESPONSE" | jq -r '."@type"')
        #if [[ ${REQUEST_TYPE} = 'pending' ]]; then
        #fi
    BUILD_NUM=$(get request/${REQUEST_ID} | jq -r .builds[0].id)
    STATUS_RESPONSE=$(post build/${BUILD_NUM}/cancel)
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
    get "builds?include=job.config" | jq -r "[.builds[] | select($SELECTOR)] | max_by(.number | tonumber).commit.sha"
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