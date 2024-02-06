#!/bin/bash


# Constants :: BitBucket Cloud
BBC_API_HOST="https://api.bitbucket.org"


# Variables :: BitBucket Cloud
BBC_WORKSPACE="${1:-msc_luxury_division}"   # BitBucket work slug or UUID
BBC_PRJCT_KEY="${2:-MULE}"                  # BitBucket project slug or 
BBC_AUTH_TYPE="${3:-APP}"                   # BitBucket authentication type: 'PAT' or 'APP'
BBC_AUTH_USER="${4:-ej-svc-bitbucket-mule}" # BitBucket authentication user: 'x-auth-token' or user name
BBC_AUTH_PASS="${5:-${APP}}"                # BitBucket authentication pass: token, user password or app password
BBC_REPO_NAME="${6:-test_sync_jp}"          # BitBucket repository name
BBC_REPO_NAME=${BBC_REPO_NAME,,}            # lowercase

# Generate cURL common parameters
if [[ "${BBC_AUTH_TYPE}" == "PAT" ]]; then
    echo "INFO: Authentication method set: Access token"
    PUSH_LINK=${BBC_AUTH_PASS}
    CURL_OPTS=(--silent --header "Authorization: Bearer ${BBC_AUTH_PASS}" --header "Accept: application/json" --header "Content-Type: application/json")
elif [[ "${BBC_AUTH_TYPE}" == "APP" ]]; then
    echo "INFO: Authentication method set: HTTP basic auth"
    PUSH_LINK="${BBC_AUTH_USER}:${BBC_AUTH_PASS}"
    CURL_OPTS=(--silent -u "${BBC_AUTH_USER}:${BBC_AUTH_PASS}" --header "Accept: application/json" --header "Content-Type: application/json")
else
    echo "ERROR: Invalid BitBucket authentication type: ${BBC_AUTH_TYPE} (must be 'PAT' or 'APP')"
    exit 1
fi


function check_workspace() {
    echo "INFO: Check if BitBucket workspace exists: ${BBC_WORKSPACE}"
    response=$(curl "${CURL_OPTS[@]}" -X GET "${BBC_API_HOST}/2.0/repositories/${BBC_WORKSPACE}")
    if [[ -z "${response}" ]] || [[ $(echo "${response}" | grep -o --color '"type": "error"') ]]; then
        echo "ERROR: Cannot access workspace: ${BBC_WORKSPACE}"
        echo "       ${response}"
        return 1
    else
        echo "INFO: Workspace exists: ${BBC_WORKSPACE}"
        return 0
    fi
}


function check_repository() {
    echo "INFO: Check if BitBucket repository exists: ${BBC_WORKSPACE}/${BBC_REPO_NAME}"
    response=$(curl "${CURL_OPTS[@]}" -X GET "${BBC_API_HOST}/2.0/repositories/${BBC_WORKSPACE}/${BBC_REPO_NAME}")
    if [[ -z "${response}" ]] || [[ $(echo "${response}" | grep -o --color '"type": "error"') ]]; then
        echo "INFO: Repository does not exists, will be created: ${BBC_WORKSPACE}/${BBC_REPO_NAME}"
        echo "      ${response}"
        return 1
    else
        echo "INFO: Repository already exists: ${BBC_WORKSPACE}/${BBC_REPO_NAME}"
        return 0
    fi
}


function create_repository() {
    echo "INFO: Create BitBucket repository: ${BBC_WORKSPACE}/${BBC_REPO_NAME}"
    response=$(curl "${CURL_OPTS[@]}" -X POST "${BBC_API_HOST}/2.0/repositories/${BBC_WORKSPACE}/${BBC_REPO_NAME}/" -d '{
        "scm": "git",
        "is_private": true,
        "name": "'${BBC_REPO_NAME}'",
        "project": {
            "key": "'${BBC_PRJCT_KEY}'"
        }
    }')
    if [[ -z "${response}" ]] || [[ $(echo "${response}" | grep -o --color '"type": "error"') ]]; then
        echo "ERROR: Failed to create repository: ${BBC_WORKSPACE}/${BBC_REPO_NAME}"
        echo "       ${response}"
        return 1
    else
        echo "INFO: Repository created: ${BBC_WORKSPACE}/${BBC_REPO_NAME}"
        sync_repository
        return 0
    fi
}


function sync_repository() {
    echo "INFO: Sync BitBucket repository: ${BBC_WORKSPACE}/${BBC_REPO_NAME}"
    #git push https://"${PUSH_LINK}"@bitbucket.org/${BBC_WORKSPACE}/${BBC_REPO_NAME}.git --all

    for branch in $(git branch --format '%(refname:short)'); do
        echo "branch: $branch"
        git push https://"${PUSH_LINK}"@bitbucket.org/${BBC_WORKSPACE}/${BBC_REPO_NAME}.git "$branch"
    done
    
    return 0
}


function main() {
    echo "INFO: \
BBC_WORKSPACE=${BBC_WORKSPACE}, \
BBC_PRJCT_KEY=${BBC_PRJCT_KEY}, \
BBC_AUTH_TYPE=${BBC_AUTH_TYPE}, \
BBC_AUTH_USER=${BBC_AUTH_USER}, \
BBC_AUTH_PASS=<secret>, \
BBC_REPO_NAME=${BBC_REPO_NAME}\
    "
    if check_workspace; then
        if ! check_repository; then
            if ! create_repository; then
                exit 1
            fi
        else
            sync_repository
            exit $?
        fi
    else
        exit 1
    fi
}


main
