#!/usr/bin/env bash

# ------------------------- #
 # USER EDIT SECTION START #

# IMPORTANT: Only change the line below if you have actually setup a branch with your own edits
#            Otherwise leave as is
EDIT_BRANCH='BRANCH_WITH_YOUR_EDITS'

  # USER EDIT SECTION END #
# ------------------------- #


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
BASE_DIR="${HOME}/Documents/RefindGOPFix/edk2"
pushd ${BASE_DIR} > /dev/null || exit 1
git checkout rudk
git pull upstream rudk
git push
popd > /dev/null || exit 1


## UPDATE GOPFIX BRANCH ##
BASE_DIR="${HOME}/Documents/RefindGOPFix/WorkingFolder"
pushd ${BASE_DIR} > /dev/null || exit 1
git checkout GOPFix
git pull upstream GOPFix
git push


## UPDATE EDITS BRANCH (IF SPECIFIED) ##
EDITS_SPECIFIED='NO'
if [ ${EDIT_BRANCH} != 'BRANCH_WITH_YOUR_EDITS' ] ; then
    EDITS_SPECIFIED='YES'
    git checkout "${EDIT_BRANCH}"
    git rebase GOPFix
    git push
fi


## CLEAN UP ##
popd > /dev/null || exit 1
echo ''
echo "Synced Branch: 'GOPFix'"
if [ ${EDITS_SPECIFIED} == 'YES' ] ; then
    echo "Synced Branch: '${EDIT_BRANCH}'"
fi
echo '-----------------------'
echo '## RefindRepoUpdater ##'
echo ''
echo ''
