#!/usr/bin/env bash

# --------------------- #
# USER EDIT SECTION START

GITHUB_USERNAME="YOUR_GITHUB_USER_NAME"

# USER EDIT SECTION END
# --------------------- #


# Set things up and move into build folder
clear
echo '## RefindBuilder - Setting Up ##'
echo '--------------------------------'
EDIT_BRANCH="${1:-GOPFix}"
BASE_DIR="${HOME}/Documents/RefindGOPFix"
BUILD_DIR="${BASE_DIR}/edk2"
if [ ! -d "${BUILD_DIR}" ] ; then
    echo "ERROR: Could not locate ${BUILD_DIR}"
    echo ''
    exit 1
fi
XCODE_DIR_REL="${BUILD_DIR}/Build/Refind/RELEASE_XCODE5"
XCODE_DIR_DBG="${BUILD_DIR}/Build/Refind/DEBUG_XCODE5"
XCODE_DIR_TMP="${BUILD_DIR}/Build-DBG/Refind/RELEASE_XCODE5"
BINARY_DIR="${XCODE_DIR_REL}/X64"
OUTPUT_DIR="${BUILD_DIR}/000-BOOTx64-Files"
GLOBAL_FILE="${BUILD_DIR}/RefindPkg/refind/global.h"
GLOBAL_FILE_TMP_REL="${BUILD_DIR}/RefindPkg/refind/global-REL.txt"
GLOBAL_FILE_TMP_DBG="${BUILD_DIR}/RefindPkg/refind/global-DBG.txt"
pushd ${BUILD_DIR} > /dev/null || exit 1
if [ -d "${BUILD_DIR}/RefindPkg-OLD" ] ; then
    rm -fr "${BUILD_DIR}/RefindPkg-OLD"
fi
if [ -d "${BUILD_DIR}/RefindPkg" ] ; then
    mv "${BUILD_DIR}/RefindPkg" "${BUILD_DIR}/RefindPkg-OLD"
fi
git checkout rudk
git clone "https://github.com/${GITHUB_USERNAME}/Refind-GOPFix.git" RefindPkg
pushd "${BUILD_DIR}/RefindPkg" > /dev/null || exit 1
# See: https://stackoverflow.com/a/10312587/891636
git branch -r | grep -v '\->' | while read remote; do git branch --track "${remote#origin/}" "$remote"; done
git fetch --all
git pull --all
git checkout ${EDIT_BRANCH}
popd > /dev/null || exit 1


# Basic clean up
clear
echo '## RefindBuilder - Initial Clean Up ##'
echo '--------------------------------------'
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
echo '## RefindBuilder - Building REL Version ##'
echo '------------------------------------------'
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


# Build debug version
clear
echo '## RefindBuilder - Building DBG Version ##'
echo '------------------------------------------'
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

# Tidy up and return to original location
if [ -f "${GLOBAL_FILE}" ] ; then
    rm -fr "${GLOBAL_FILE}"
fi
cp "${GLOBAL_FILE_TMP_REL}" "${GLOBAL_FILE}"
popd > /dev/null || exit 1
echo ''
echo "Output rEFInd EFI Files (BOOTx64): '${OUTPUT_DIR}'"
echo "Output rEFInd EFI Files (Others - DBG): '${XCODE_DIR_DBG}/X64'"
echo "Output rEFInd EFI Files (Others - REL): '${XCODE_DIR_REL}/X64'"
echo ''
echo ''
