#!/usr/bin/env bash

###
 # RefindPlusBuilder.sh
 # A script to build RefindPlus
 #
 # Copyright (c) 2020-2021 Dayo Akanji
 # MIT License
###

COLOUR_BASE=""
COLOUR_INFO=""
COLOUR_STATUS=""
COLOUR_ERROR=""
COLOUR_NORMAL=""

if test -t 1; then
    NCOLOURS=$(tput colors)
    if test -n "${NCOLOURS}" && test ${NCOLOURS} -ge 8; then
        COLOUR_BASE="\033[0;36m"
        COLOUR_INFO="\033[0;33m"
        COLOUR_STATUS="\033[0;32m"
        COLOUR_ERROR="\033[0;31m"
        COLOUR_NORMAL="\033[0m"
    fi
fi

# Provide custom colours
msg_base() {
    echo -e "${COLOUR_BASE}${1}${COLOUR_NORMAL}"
}
msg_info() {
    echo -e "${COLOUR_INFO}${1}${COLOUR_NORMAL}"
}
msg_status() {
    echo -e "${COLOUR_STATUS}${1}${COLOUR_NORMAL}"
}
msg_error() {
    echo -e "${COLOUR_ERROR}${1}${COLOUR_NORMAL}"
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


# Set things up for build
clear
msg_info '## RefindPlusBuilder - Setting Up ##'
msg_info '------------------------------------'
sleep 2
EDIT_BRANCH="${1:-GOPFix}"
BASE_DIR="${HOME}/Documents/RefindPlus"
WORK_DIR="${BASE_DIR}/Working"
EDK2_DIR="${BASE_DIR}/edk2"
if [ ! -d "${EDK2_DIR}" ] ; then
    msg_error "ERROR: Could not locate ${EDK2_DIR}"
    echo ''
    exit 1
fi
XCODE_DIR_REL="${EDK2_DIR}/Build/RefindPlus/RELEASE_XCODE5"
XCODE_DIR_DBG="${EDK2_DIR}/Build/RefindPlus/DEBUG_XCODE5"
BINARY_DIR_REL="${XCODE_DIR_REL}/X64"
BINARY_DIR_DBG="${XCODE_DIR_DBG}/X64"
OUTPUT_DIR="${EDK2_DIR}/000-BOOTx64-Files"
GLOBAL_FILE="${EDK2_DIR}/RefindPlusPkg/BootMaster/globalExtra.h"
GLOBAL_FILE_TMP_REL="${EDK2_DIR}/RefindPlusPkg/BootMaster/globalExtra-REL.txt"
GLOBAL_FILE_TMP_DBG="${EDK2_DIR}/RefindPlusPkg/BootMaster/globalExtra-DBG.txt"
BUILD_DSC="${EDK2_DIR}/RefindPlusPkg/RefindPlusPkg.dsc"
BUILD_DSC_REL="${EDK2_DIR}/RefindPlusPkg/RefindPlusPkg-REL.dsc"
BUILD_DSC_DBG="${EDK2_DIR}/RefindPlusPkg/RefindPlusPkg-DBG.dsc"
BASETOOLS='false'
OUR_RAND=$(( RANDOM % 17 ))
if [ ! -d "${EDK2_DIR}/BaseTools/Source/C/bin" ] || [ "${OUR_RAND}" == "0" ] ; then
    OUR_RAND=$(( RANDOM % 2 ))
    if [ ! -d "${EDK2_DIR}/BaseTools/Source/C/bin" ] || [ "${OUR_RAND}" == "0" ] ; then
        BASETOOLS='true'
    fi
fi

pushd "${WORK_DIR}" > /dev/null || exit 1
msg_base "Checkout '${EDIT_BRANCH}' branch..."
git checkout ${EDIT_BRANCH} > /dev/null
msg_status '...OK'; echo ''
sleep 2
msg_base 'Update RefindPlusPkg...'

# Remove later #
rm -fr "${EDK2_DIR}/RefindPkg"
# Remove later #

rm -fr "${EDK2_DIR}/RefindPlusPkg"
cp -fa "${WORK_DIR}" "${EDK2_DIR}/RefindPlusPkg"
rm -fr "${EDK2_DIR}/RefindPlusPkg/.gitignore"
rm -fr "${EDK2_DIR}/RefindPlusPkg/.git"
msg_status '...OK'; echo ''
sleep 2
popd > /dev/null || exit 1

if [ "${BASETOOLS}" == 'true' ] ; then
    pushd "${EDK2_DIR}/BaseTools/Source/C" > /dev/null || exit 1
    msg_base 'Make Clean...'
    sleep 2
    make clean
    msg_status '...OK'; echo ''
    popd > /dev/null || exit 1

    pushd "${EDK2_DIR}" > /dev/null || exit 1
    sleep 2
    msg_base 'Make BaseTools...'
    sleep 2
    make -C BaseTools/Source/C
    msg_status '...OK'; echo ''
    sleep 2
    popd > /dev/null || exit 1
fi


# Basic clean up
clear
msg_info '## RefindPlusBuilder - Initial Clean Up ##'
msg_info '------------------------------------------'
sleep 2

if [ -d "${EDK2_DIR}/Build" ] ; then
    rm -fr "${EDK2_DIR}/Build"
fi
mkdir -p "${EDK2_DIR}/Build"
if [ -d "${OUTPUT_DIR}" ] ; then
    rm -fr "${OUTPUT_DIR}"
fi
mkdir -p "${OUTPUT_DIR}"

# Build release version
clear
msg_info '## RefindPlusBuilder - Building REL Version ##'
msg_info '----------------------------------------------'

sleep 2
pushd "${EDK2_DIR}" > /dev/null || exit 1
if [ -d "${EDK2_DIR}/.Build-TMP" ] ; then
    rm -fr "${EDK2_DIR}/.Build-TMP"
fi
if [ -f "${GLOBAL_FILE}" ] ; then
    rm -fr "${GLOBAL_FILE}"
fi
cp "${GLOBAL_FILE_TMP_REL}" "${GLOBAL_FILE}"

if [ -f "${BUILD_DSC}" ] ; then
    rm -fr "${BUILD_DSC}"
fi
cp "${BUILD_DSC_REL}" "${BUILD_DSC}"

source edksetup.sh BaseTools
build -b RELEASE

if [ -d "${EDK2_DIR}/Build" ] ; then
    cp "${BINARY_DIR_REL}/RefindPlus.efi" "${OUTPUT_DIR}/BOOTx64-REL.efi"
fi
popd > /dev/null || exit 1
echo ''
msg_info "Completed REL Build on '${EDIT_BRANCH}' Branch of RefindPlus"
sleep 2
msg_info 'Preparing DBG Build...'
echo ''
sleep 4


# Build debug version
clear
msg_info '## RefindPlusBuilder - Building DBG Version ##'
msg_info '----------------------------------------------'
sleep 2
pushd "${EDK2_DIR}" > /dev/null || exit 1
if [ -f "${GLOBAL_FILE}" ] ; then
    rm -fr "${GLOBAL_FILE}"
fi
cp "${GLOBAL_FILE_TMP_DBG}" "${GLOBAL_FILE}"

if [ -f "${BUILD_DSC}" ] ; then
    rm -fr "${BUILD_DSC}"
fi
cp "${BUILD_DSC_DBG}" "${BUILD_DSC}"

source edksetup.sh BaseTools
build -b DEBUG

if [ -d "${EDK2_DIR}/Build" ] ; then
    cp "${BINARY_DIR_DBG}/RefindPlus.efi" "${OUTPUT_DIR}/BOOTx64-DBG.efi"
fi
if [ -d "${EDK2_DIR}/.Build-TMP" ] ; then
    rm -fr "${EDK2_DIR}/.Build-TMP"
fi
if [ -d "${EDK2_DIR}/Build" ] ; then
    cp "${BINARY_DIR_REL}/RefindPlus.efi" "${OUTPUT_DIR}/BOOTx64-REL.efi"
fi
popd > /dev/null || exit 1
echo ''
msg_info "Completed DBG Build on '${EDIT_BRANCH}' Branch of RefindPlus"
echo ''


# Tidy up
if [ -f "${GLOBAL_FILE}" ] ; then
    rm -fr "${GLOBAL_FILE}"
fi
cp "${GLOBAL_FILE_TMP_REL}" "${GLOBAL_FILE}"
if [ -f "${BUILD_DSC}" ] ; then
    rm -fr "${BUILD_DSC}"
fi
cp "${BUILD_DSC_REL}" "${BUILD_DSC}"
echo ''
msg_info 'Output EFI Files...'
msg_status "RefindPlus EFI Files (BOOTx64)      : '${OUTPUT_DIR}'"
msg_status "RefindPlus EFI Files (Others - DBG) : '${XCODE_DIR_DBG}/X64'"
msg_status "RefindPlus EFI Files (Others - REL) : '${XCODE_DIR_REL}/X64'"
echo ''
echo ''
