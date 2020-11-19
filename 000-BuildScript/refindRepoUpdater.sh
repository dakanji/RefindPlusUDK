#!/usr/bin/env bash

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
echo '## RefindRepoUpdater ##'
echo '-----------------------'
echo ''
BASE_DIR="${HOME}/Documents/RefindPlus/edk2"
pushd ${BASE_DIR} > /dev/null || exit 1
git checkout rudk
git reset --hard a94082b4e5e42a1cfdcbab0516f9ecdbb596d201
git push origin HEAD -f
git pull --tags upstream rudk
git push origin
git push --tags origin
popd > /dev/null || exit 1


## UPDATE GOPFIX BRANCH ##
BASE_DIR="${HOME}/Documents/RefindPlus/Working"
pushd ${BASE_DIR} > /dev/null || exit 1
git checkout GOPFix
git reset --hard a2cc87f019c4de3a1237e2dc23f432c27cec5ec6
git push origin HEAD -f
git pull --tags upstream GOPFix
git push origin
git push --tags origin


## CLEAN UP ##
popd > /dev/null || exit 1
echo ''
echo "Synced Branch: 'GOPFix'"
echo '-----------------------'
echo '## RefindRepoUpdater ##'
echo ''
echo ''
