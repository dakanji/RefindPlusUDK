#!/usr/bin/env bash

# --------------------- #
# USER EDIT SECTION START

# IMPORTANT: Only change the line below if you have actually setup a branch with your own edits
#            Otherwise leave as is
EDIT_BRANCH='BRANCH_WITH_YOUR_EDITS'

# USER EDIT SECTION END
# --------------------- #


# Update GOPFix Branch
clear
echo '## RefindRepoUpdater ##'
echo '-----------------------'
EDITS_SPECIFIED='NO'
BASE_DIR="${HOME}/Documents/RefindGOPFix/WorkingFolder"
pushd ${BASE_DIR} > /dev/null || exit 1
$ git checkout GOPFix
$ git pull upstream GOPFix
$ git push


# Update Edits Branch if Specified
if [ ${EDIT_BRANCH} != 'BRANCH_WITH_YOUR_EDITS' ] ; then
    EDITS_SPECIFIED='YES'
    git checkout "${EDIT_BRANCH}"
    git rebase GOPFix
    git push
fi


# Clean Up
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
