#!/usr/bin/env bash

###
# RepoUpdater.sh
# A script to sync the RefindPlus and RefindPlusUDK repos with original repos
#
# Copyright (c) 2020-2026 Dayo Akanji
# MIT-0 License
###

COLOR_BASE=""
COLOR_INFO=""
COLOR_STATUS=""
COLOR_ERROR=""
COLOR_NORMAL=""

if test -t 1; then
    NCOLORS=$(tput colors)
    if test -n "${NCOLORS}" && test "${NCOLORS}" -ge 8; then
        COLOR_BASE="\033[0;36m"
        COLOR_INFO="\033[0;33m"
        COLOR_STATUS="\033[0;32m"
        COLOR_ERROR="\033[0;31m"
        COLOR_NORMAL="\033[0m"
    fi
fi

# Provide Custom Colours
msg_raw() {
    printf "%s\n" "${1}"
}
msg_base() {
    printf "%b%s%b\n" "${COLOR_BASE}" "${1}" "${COLOR_NORMAL}"
}
msg_info() {
    printf "%b%s%b\n" "${COLOR_INFO}" "${1}" "${COLOR_NORMAL}"
}
msg_status() {
    printf "%b%s%b\n" "${COLOR_STATUS}" "${1}" "${COLOR_NORMAL}"
}
msg_error() {
    printf "%b%s%b\n" "${COLOR_ERROR}" "${1}" "${COLOR_NORMAL}"
}


## ERROR HANDLERS ##
TrapINT() { # $1: message
    # Declare Local Variables
    local errMessage

    # Show error and exit
    errMessage="${1:-Force Quit ... Exiting}"
    printf '\n'
    msg_error "${errMessage}"
    printf '\n\n'
    exit 1
}
TrapERR() { # $1: message
    # Declare Local Variables
    local errMessage

    # Show error and exit
    errMessage="${1:-Runtime Error ... Exiting}"
    printf '\n'
    msg_error "${errMessage}"
    printf '\n\n'
    exit 1
}

ErrSync() {
    msg_info 'Failed ...Revise Target'
    if [[ "${OUR_BRANCH}" == 'GOPFix' || "${OUR_BRANCH}" == 'rudk' ]]; then
        BASE_RUN='false'
        SyncRepo ;
        EXIT_CALL='true'
    else
        TrapERR 'Invalid Input ... Exiting' ;
    fi
}


## REPO UPDATE FUNCTION ##
SyncRepo() {
    # Declare Local Variables
    local resetSHA

    # Trap Errors
    if [[ "${BASE_RUN}" == 'true' ]]; then
        trap ErrSync ERR
    else
        trap TrapERR ERR
    fi

    # Set SHA Values
    if [[ "${OUR_BRANCH}" == 'GOPFix' ]]; then
        if [[ -n "${REFINDPLUS_SHA}" && "${BASE_RUN}" == 'true' ]]; then
            resetSHA="${REFINDPLUS_SHA}"
        else
            resetSHA='f8d4b1c0b89b9f3b01d99d16888efaf9217ad76e'
        fi
    elif [[ "${OUR_BRANCH}" == 'rudk' ]]; then
        if [[ -n "${REFIND_UDK_SHA}" && "${BASE_RUN}" == 'true' ]]; then
            resetSHA="${REFIND_UDK_SHA}"
        else
            resetSHA='191c292441e95d621811ddf6f1c70d24a51555d8'
        fi
    else
        TrapERR 'Invalid Input ... Exiting' ;
    fi

    # Run Sync
    git checkout "${OUR_BRANCH}"
    git reset --hard "${resetSHA}"
    if [[ "${EXIT_CALL}" == 'true' ]]; then
        return 0
    fi

    if [[ "${OUR_BRANCH}" == 'GOPFix' ]]; then
        REPO_URL="https://github.com/RefindPlusRepo/RefindPlus.git"
    else
        REPO_URL="https://github.com/RefindPlusRepo/RefindPlusUDK.git"
    fi
    CURRENT_UPSTREAM=$(git remote get-url upstream 2>/dev/null)
    if [[ "${CURRENT_UPSTREAM}" != "${REPO_URL}" ]]; then
        git remote add upstream "${REPO_URL}" 2>/dev/null || \
        git remote set-url upstream "${REPO_URL}"
    fi

    git push origin HEAD -f
    git pull --tags upstream "${OUR_BRANCH}"
    git push origin
    git push --tags origin -f
}


##########################
# Procedural Code Starts #
##########################

# Set Event Traps
trap TrapERR ERR
trap TrapINT SIGINT

clear
msg_info '## RepoUpdater ##'
msg_info '-----------------'
printf '\n'

EDK2_DIR="${HOME}/Documents/RefindPlus/edk2"
REPO_SHA_FILE="${EDK2_DIR}/.BuildHelp/RepoUpdateSHA.txt"
# shellcheck disable=SC1090
source "${REPO_SHA_FILE}" || msg_info 'WARN: Could not find RepoUpdateSHA.txt'

msg_base 'Syncing RefindPlus'
BASE_DIR="${HOME}/Documents/RefindPlus/Working"
pushd "${BASE_DIR}" > /dev/null || TrapERR "ERROR: Could not find ${BASE_DIR} ...Exiting"
OUR_BRANCH='GOPFix'
BASE_RUN='true'
EXIT_CALL='false'
SyncRepo ;
popd > /dev/null || exit 1
printf '\n'
msg_status 'Synced RefindPlus'
printf '\n\n'

msg_base 'Syncing RefindPlusUDK'
BASE_DIR="${EDK2_DIR}"
pushd "${BASE_DIR}" > /dev/null || TrapERR "ERROR: Could not find ${BASE_DIR} ...Exiting"

PREV_SHA_FILE="${BASE_DIR}/000-BuildScript/RepoUpdateSHA.txt"
[[ -f "${PREV_SHA_FILE}" ]] && rm -f "${PREV_SHA_FILE}"

OUR_BRANCH='rudk'
BASE_RUN='true'
EXIT_CALL='false'
SyncRepo ;
popd > /dev/null || exit 1
printf '\n'
msg_status 'Synced RefindPlusUDK'

printf '\n'
msg_info '-----------------'
msg_info '## RepoUpdater ##'
printf '\n\n'
