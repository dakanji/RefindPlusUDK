#!/usr/bin/env bash

###
 # RepoUpdater.sh
 # A script to sync the RefindPlus and Refind-UDK Repos with upstream
 #
 # Copyright (c) 2020 Dayo Akanji
 # MIT License
###

## ERROR HANDLER ##
runErr() { # $1: message
    # Declare Local Variables
    local errMessage

    errMessage="${1:-Runtime Error ... Exiting}"
    echo ''
    echo "${errMessage}"
    echo ''
    echo ''
    exit 1
}
trap runErr ERR


## UPDATE RUDK BRANCH ##
clear
echo '## RepoUpdater ##'
echo '-----------------'
echo ''
echo "Syncing Refind-UDK"
BASE_DIR="${HOME}/Documents/RefindPlus/edk2"
pushd ${BASE_DIR} > /dev/null || echo "ERROR: Could not find ${BASE_DIR} ...Exiting"; exit 1
git checkout rudk
git reset --hard c656985c0450e1e2eeffc705dd0acbabe5f00094
git push origin HEAD -f
git pull --tags upstream rudk
git push origin
git push --tags origin
popd > /dev/null || exit 1
echo ''
echo "Synced Refind-UDK"
echo ''
echo ''


## UPDATE GOPFIX BRANCH ##
echo "Syncing RefindPlus"
BASE_DIR="${HOME}/Documents/RefindPlus/Working"
pushd ${BASE_DIR} > /dev/null || echo "ERROR: Could not find ${BASE_DIR} ...Exiting"; exit 1
git checkout GOPFix
git reset --hard 664d1b12a30766c63e705cd222bc0d5a0a58df53
git push origin HEAD -f
git pull --tags upstream GOPFix
git push origin
git push --tags origin
popd > /dev/null || exit 1
echo ''
echo "Synced RefindPlus"
echo ''
echo '-----------------'
echo '## RepoUpdater ##'
echo ''
echo ''
