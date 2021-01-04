#!/usr/bin/env bash

###
 # RepoUpdater.sh
 # A script to sync the RefindPlus and Refind-UDK Repos with upstream
 #
 # Copyright (c) 2020-2021 Dayo Akanji
 # MIT License
###

# Provide custom colours
msg_base() {
    echo -e "\033[0;36m$1\033[0m"
}
msg_info() {
    echo -e "\033[0;33m$1\033[0m"
}
msg_status() {
    echo -e "\033[0;32m$1\033[0m"
}
msg_error() {
    echo -e "\033[0;31m$1\033[0m"
}

## ERROR HANDLER ##
runErr() { # $1: message
    # Declare Local Variables
    local errMessage

    errMessage="${1:-Runtime Error ... Exiting}"
    echo ''
    msg_error "${errMessage}"
    echo ''
    echo ''
    exit 1
}
trap runErr ERR


## UPDATE RUDK BRANCH ##
clear
msg_info '## RepoUpdater ##'
msg_info '-----------------'
echo ''
msg_base "Syncing Refind-UDK"
BASE_DIR="${HOME}/Documents/RefindPlus/edk2"
pushd ${BASE_DIR} > /dev/null || runErr "ERROR: Could not find ${BASE_DIR} ...Exiting"
git checkout rudk
git reset --hard c656985c0450e1e2eeffc705dd0acbabe5f00094
git push origin HEAD -f
git pull --tags upstream rudk
git push origin
git push --tags origin
popd > /dev/null || runErr "ERROR: Could not return to starting directory ...Exiting"
echo ''
msg_status "Synced Refind-UDK"
echo ''
echo ''


## UPDATE GOPFIX BRANCH ##
msg_base "Syncing RefindPlus"
BASE_DIR="${HOME}/Documents/RefindPlus/Working"
pushd ${BASE_DIR} > /dev/null || runErr "ERROR: Could not find ${BASE_DIR} ...Exiting"
git checkout GOPFix
git reset --hard 664d1b12a30766c63e705cd222bc0d5a0a58df53
git push origin HEAD -f
git pull --tags upstream GOPFix
git push origin
git push --tags origin
popd > /dev/null || exit 1
echo ''
msg_status "Synced RefindPlus"
echo ''
msg_info '-----------------'
msg_info '## RepoUpdater ##'
echo ''
echo ''
