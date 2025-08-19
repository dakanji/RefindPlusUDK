#!/usr/bin/env bash

###
 # RepoUpdater.sh
 # A script to sync the RefindPlus and RefindPlusUDK Repos with upstream
 #
 # Copyright (c) 2020-2025 Dayo Akanji
 # MIT License
###

# Provide custom colours
COLOR_BASE="\033[0;36m"
COLOR_INFO="\033[0;33m"
COLOR_STATUS="\033[0;32m"
COLOR_ERROR="\033[0;31m"
COLOR_NORMAL="\033[0m"

msg_base() {
    printf "${COLOR_BASE}${1}${COLOR_NORMAL}\n"
}
msg_info() {
    printf "${COLOR_INFO}${1}${COLOR_NORMAL}\n"
}
msg_status() {
    printf "${COLOR_STATUS}${1}${COLOR_NORMAL}\n"
}
msg_error() {
    printf "${COLOR_ERROR}${1}${COLOR_NORMAL}\n"
}


## ERROR HANDLERS ##
ErrExit() { # $1: message
    # Declare Local Variables
    local errMessage

    errMessage="${1:-Runtime Error ... Exiting}"
    echo ''
    msg_error "${errMessage}"
    echo ''
    echo ''
    exit 1
}
ErrSync() {
    msg_info 'Failed ...Revise Target'
    if [[ "${OUR_BRANCH}" == 'GOPFix' || "${OUR_BRANCH}" == 'rudk' ]] ; then
        BASE_RUN='false'
        SyncRepo ;
        EXIT_CALL='true'
    else
        ErrExit 'Invalid Input ... Exiting' ;
    fi
}


## REPO UPDATE FUNCTION ##
SyncRepo() {
    # Declare Local Variables
    local resetSHA

    # Trap Errors
    if [[ "${BASE_RUN}" == 'true' ]] ; then
        trap ErrSync ERR
    else
        trap ErrExit ERR
    fi

    # Set SHA Values
    if [[ "${OUR_BRANCH}" == 'GOPFix' ]] ; then
        if [[ "${BASE_RUN}" == 'true' ]] ; then
            resetSHA="${REFINDPLUS_SHA}"
        else
            resetSHA='f8d4b1c0b89b9f3b01d99d16888efaf9217ad76e'
        fi
    elif [[ "${OUR_BRANCH}" == 'rudk' ]] ; then
        if [[ "${BASE_RUN}" == 'true' ]] ; then
            resetSHA="${REFIND_UDK_SHA}"
        else
            resetSHA='191c292441e95d621811ddf6f1c70d24a51555d8'
        fi
    else
        ErrExit 'Invalid Input ... Exiting' ;
    fi

    # Run Sync
    git checkout "${OUR_BRANCH}"

    if [[ "${EXIT_CALL}" == 'true' ]] ; then
        return 0
    fi
    git reset --hard "${resetSHA}"

    if [[ "${EXIT_CALL}" == 'true' ]] ; then
        return 0
    fi
    if [[ "${OUR_BRANCH}" == 'GOPFix' ]] ; then
        (git remote get-url upstream 2>/dev/null | grep -q "https://github.com/RefindPlusRepo/RefindPlus.git") || (git remote remove upstream && git remote add upstream https://github.com/RefindPlusRepo/RefindPlus.git 2>/dev/null)
    else
        (git remote get-url upstream 2>/dev/null | grep -q "https://github.com/RefindPlusRepo/RefindPlusUDK.git") || (git remote remove upstream && git remote add upstream https://github.com/RefindPlusRepo/RefindPlusUDK.git 2>/dev/null)
    fi

    if [[ "${EXIT_CALL}" == 'true' ]] ; then
        return 0
    fi
    git push origin HEAD -f

    if [[ "${EXIT_CALL}" == 'true' ]] ; then
        return 0
    fi
    git pull --tags upstream "${OUR_BRANCH}"

    if [[ "${EXIT_CALL}" == 'true' ]] ; then
        return 0
    fi
    git push origin

    if [[ "${EXIT_CALL}" == 'true' ]] ; then
        return 0
    fi
    git push --tags origin -f
}


## PROCEDURAL CODE ##
clear
msg_info '## RepoUpdater ##'
msg_info '-----------------'
echo ''

REPO_SHA_FILE="${HOME}/Documents/RefindPlus/edk2/.BuildHelp/RepoUpdateSHA.txt"
# shellcheck disable=SC1090
source "${REPO_SHA_FILE}" || msg_info 'WARN: Could not find RepoUpdateSHA.txt'

msg_base 'Syncing RefindPlus'
BASE_DIR="${HOME}/Documents/RefindPlus/Working"
pushd ${BASE_DIR} > /dev/null || ErrExit "ERROR: Could not find ${BASE_DIR} ...Exiting"
OUR_BRANCH='GOPFix'
BASE_RUN='true'
EXIT_CALL='false'
SyncRepo ;
popd > /dev/null || exit 1
echo ''
msg_status 'Synced RefindPlus'
printf "\n\n"

msg_base 'Syncing RefindPlusUDK'
BASE_DIR="${HOME}/Documents/RefindPlus/edk2"
pushd ${BASE_DIR} > /dev/null || ErrExit "ERROR: Could not find ${BASE_DIR} ...Exiting"
OUR_BRANCH='rudk'
BASE_RUN='true'
EXIT_CALL='false'
SyncRepo ;
popd > /dev/null || exit 1
echo ''
msg_status 'Synced RefindPlusUDK'

echo ''
msg_info '-----------------'
msg_info '## RepoUpdater ##'
printf "\n\n"
