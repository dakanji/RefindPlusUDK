#!/usr/bin/env bash

# ------------------------- #
 # USER EDIT SECTION START #

GITHUB_USERNAME="YOUR_GITHUB_USERNAME"

  # USER EDIT SECTION END #
# ------------------------- #


# Provide custom colors
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

# Set things up and move into build folder
clear
msg_info '## RefindBuilder - Setting Up ##'
msg_info '--------------------------------'
sleep 1
EDIT_BRANCH="${1:-GOPFix}"
BASE_DIR="${HOME}/Documents/RefindPlus"
BUILD_DIR="${BASE_DIR}/edk2"
if [ ! -d "${BUILD_DIR}" ] ; then
    msg_error "ERROR: Could not locate ${BUILD_DIR}"
    echo ''
    exit 1
fi
XCODE_DIR_REL="${BUILD_DIR}/Build/Refind/RELEASE_XCODE5"
XCODE_DIR_DBG="${BUILD_DIR}/Build/Refind/DEBUG_XCODE5"
XCODE_DIR_TMP="${BUILD_DIR}/Build-DBG/Refind/RELEASE_XCODE5"
BINARY_DIR="${XCODE_DIR_REL}/X64"
OUTPUT_DIR="${BUILD_DIR}/000-BOOTx64-Files"
GLOBAL_FILE="${BUILD_DIR}/RefindPkg/refind/globalExtra.h"
GLOBAL_FILE_TMP_REL="${BUILD_DIR}/RefindPkg/refind/globalExtra-REL.txt"
GLOBAL_FILE_TMP_DBG="${BUILD_DIR}/RefindPkg/refind/globalExtra-DBG.txt"
pushd ${BUILD_DIR} > /dev/null || exit 1
git checkout rudk
if [ -d "${BUILD_DIR}/RefindPkg-OLD" ] ; then
    rm -fr "${BUILD_DIR}/RefindPkg-OLD"
fi
if [ -d "${BUILD_DIR}/RefindPkg" ] ; then
    mv "${BUILD_DIR}/RefindPkg" "${BUILD_DIR}/RefindPkg-OLD"
fi
git clone "https://github.com/${GITHUB_USERNAME}/RefindPlus.git" RefindPkg
pushd "${BUILD_DIR}/RefindPkg" > /dev/null || exit 1
# See: https://stackoverflow.com/a/10312587/891636
git branch -r | grep -v '\->' | while read remote; do git branch --track "${remote#origin/}" "$remote"; done
git fetch --all
git pull --all
git checkout ${EDIT_BRANCH}
popd > /dev/null || exit 1


# Basic clean up
clear
msg_info '## RefindPlusBuilder - Initial Clean Up ##'
msg_info '------------------------------------------'
sleep 1
if [ -d "${BUILD_DIR}/Build-OLD" ] ; then
    rm -fr "${BUILD_DIR}/Build-OLD"
fi
if [ -d "${BUILD_DIR}/Build" ] ; then
    mv "${BUILD_DIR}/Build" "${BUILD_DIR}/Build-OLD"
fi
if [ -d "${OUTPUT_DIR}" ] ; then
    rm -fr "${OUTPUT_DIR}"
fi
mkdir -p "${OUTPUT_DIR}"


# Build release version
clear
msg_info '## RefindPlusBuilder - Building REL Version ##'
msg_info '----------------------------------------------'
sleep 1
if [ -d "${BUILD_DIR}/Build-TMP" ] ; then
    rm -fr "${BUILD_DIR}/Build-TMP"
fi
if [ -f "${GLOBAL_FILE}" ] ; then
    rm -fr "${GLOBAL_FILE}"
fi
cp "${GLOBAL_FILE_TMP_REL}" "${GLOBAL_FILE}"
source edksetup.sh BaseTools
build
if [ -d "${BUILD_DIR}/Build" ] ; then
    cp "${BINARY_DIR}/refind.efi" "${OUTPUT_DIR}/BOOTx64-REL.efi"
    mv "${BUILD_DIR}/Build" "${BUILD_DIR}/Build-TMP"
fi
echo ''
msg_info 'Completed REL Build ...Preparing DBG Build'
echo ''
sleep 3


# Build debug version
clear
msg_info '## RefindPlusBuilder - Building DBG Version ##'
msg_info '----------------------------------------------'
sleep 1
if [ -d "${BUILD_DIR}/Build-DBG" ] ; then
    rm -fr "${BUILD_DIR}/Build-DBG"
fi
if [ -f "${GLOBAL_FILE}" ] ; then
    rm -fr "${GLOBAL_FILE}"
fi
cp "${GLOBAL_FILE_TMP_DBG}" "${GLOBAL_FILE}"
source edksetup.sh BaseTools
build
if [ -d "${BUILD_DIR}/Build" ] ; then
    cp "${BINARY_DIR}/refind.efi" "${OUTPUT_DIR}/BOOTx64-DBG.efi"
    mv "${BUILD_DIR}/Build" "${BUILD_DIR}/Build-DBG"
    mv "${BUILD_DIR}/Build-TMP" "${BUILD_DIR}/Build"
    mv "${XCODE_DIR_TMP}" "${XCODE_DIR_DBG}"
fi
if [ -d "${BUILD_DIR}/Build-DBG" ] ; then
    rm -fr "${BUILD_DIR}/Build-DBG"
fi
echo ''
msg_info 'Completed DBG Build'
echo ''


# Tidy up and return to original location
if [ -f "${GLOBAL_FILE}" ] ; then
    rm -fr "${GLOBAL_FILE}"
fi
cp "${GLOBAL_FILE_TMP_REL}" "${GLOBAL_FILE}"
popd > /dev/null || exit 1
echo ''
msg_status "RefindPlus EFI Files (BOOTx64): '${OUTPUT_DIR}'"
msg_status "RefindPlus EFI Files (Others - DBG): '${XCODE_DIR_DBG}/X64'"
msg_status "RefindPlus EFI Files (Others - REL): '${XCODE_DIR_REL}/X64'"
echo ''
echo ''
