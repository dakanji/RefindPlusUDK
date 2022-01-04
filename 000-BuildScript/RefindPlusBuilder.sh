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
    if test -n "${NCOLOURS}" && test "${NCOLOURS}" -ge 8; then
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
BUILD_BRANCH="${1:-GOPFix}"
DEBUG_TYPE="${2:-0}"
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
GLOBAL_FILE="${EDK2_DIR}/RefindPlusPkg/BootMaster/global.h"
SHASUM='/usr/bin/shasum'
DUP_SHASUM='/usr/local/bin/shasum'
TMP_SHASUM='/usr/local/bin/_shasum'

BASETOOLS_SHA_FILE="${EDK2_DIR}/000-BuildScript/BaseToolsSHA.txt"
if [ ! -f "${BASETOOLS_SHA_FILE}" ] ; then
    BASETOOLS_SHA_OLD='Default'
else
    # shellcheck disable=SC1090
    source "${BASETOOLS_SHA_FILE}" || BASETOOLS_SHA_OLD='Default'
fi
if [ -f "${DUP_SHASUM}" ] ; then
    mv "${DUP_SHASUM}" "${TMP_SHASUM}"
    SHASUM_FIX='true'
else
    SHASUM_FIX='false'
fi

pushd "${EDK2_DIR}/BaseTools" > /dev/null || exit 1
BASETOOLS_SHA_NEW="$(find . -type f -name '*.c' -name '*.h' -name '*.py' -print0 | sort -z | xargs -0 ${SHASUM} | ${SHASUM})"
popd > /dev/null || exit 1

if [ "${SHASUM_FIX}" == 'true' ] ; then
    mv "${TMP_SHASUM}" "${DUP_SHASUM}"
fi
if [ ! -d "${EDK2_DIR}/BaseTools/Source/C/bin" ] || [ "${BASETOOLS_SHA_NEW}" != "${BASETOOLS_SHA_OLD}" ] ; then
    BUILD_TOOLS='true'
else
    BUILD_TOOLS='false'
fi

pushd "${WORK_DIR}" > /dev/null || exit 1
msg_base "Checkout '${BUILD_BRANCH}' branch..."
git checkout ${BUILD_BRANCH} > /dev/null
msg_status '...OK'; echo ''
msg_base 'Update RefindPlusPkg...'

# Remove later #
rm -fr "${EDK2_DIR}/RefindPkg"
# Remove later #

if [ ! -L "${EDK2_DIR}/RefindPlusPkg" ]; then
	rm -fr "${EDK2_DIR}/RefindPlusPkg"
    ln -s "${WORK_DIR}" "${EDK2_DIR}/RefindPlusPkg"
fi
msg_status '...OK'; echo ''
popd > /dev/null || exit 1

if [ "${BUILD_TOOLS}" == 'true' ] ; then
    pushd "${EDK2_DIR}/BaseTools/Source/C" > /dev/null || exit 1
    msg_base 'Make Clean...'
    make clean
    msg_status '...OK'; echo ''
    popd > /dev/null || exit 1

    pushd "${EDK2_DIR}" > /dev/null || exit 1
    msg_base 'Make BaseTools...'
    make -C BaseTools/Source/C
    echo '#!/usr/bin/env bash' > "${BASETOOLS_SHA_FILE}"
    echo "BASETOOLS_SHA_OLD='${BASETOOLS_SHA_NEW}'" >> "${BASETOOLS_SHA_FILE}"
    msg_status '...OK'; echo ''
    popd > /dev/null || exit 1
fi


# Basic clean up
clear
msg_info '## RefindPlusBuilder - Initial Clean Up ##'
msg_info '------------------------------------------'
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
pushd "${EDK2_DIR}" > /dev/null || exit 1
if [ -d "${EDK2_DIR}/.Build-TMP" ] ; then
    rm -fr "${EDK2_DIR}/.Build-TMP"
fi
if [ -f "${GLOBAL_FILE}" ] ; then
    DEBUG_LEVEL='0'
    /usr/bin/perl -i -p -e "s~#define REFIT_DEBUG \(\d+\)~#define REFIT_DEBUG (${DEBUG_LEVEL})~" "${GLOBAL_FILE}"
fi

source edksetup.sh BaseTools
build -a X64 -b RELEASE -t XCODE5 -p RefindPlusPkg/RefindPlusPkg.dsc

if [ -d "${EDK2_DIR}/Build" ] ; then
    cp "${BINARY_DIR_REL}/RefindPlus.efi" "${OUTPUT_DIR}/BOOTx64-REL.efi"
fi
popd > /dev/null || exit 1
echo ''
msg_info "Completed REL Build on '${BUILD_BRANCH}' Branch of RefindPlus"
msg_info 'Preparing DBG Build...'
echo ''
sleep 4


# Build debug version
clear
msg_info '## RefindPlusBuilder - Building DBG Version ##'
msg_info '----------------------------------------------'
pushd "${EDK2_DIR}" > /dev/null || exit 1
if [ -f "${GLOBAL_FILE}" ] ; then
    if [ "${DEBUG_TYPE}" == '0' ] ; then
        DEBUG_LEVEL='1'
    else
        DEBUG_LEVEL='2'
    fi
    /usr/bin/perl -i -p -e "s~#define REFIT_DEBUG \(\d+\)~#define REFIT_DEBUG (${DEBUG_LEVEL})~" "${GLOBAL_FILE}"
fi

source edksetup.sh BaseTools
build -a X64 -b DEBUG -t XCODE5 -p RefindPlusPkg/RefindPlusPkg.dsc

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
msg_info "Completed DBG Build on '${BUILD_BRANCH}' Branch of RefindPlus"
echo ''


# Tidy up
if [ -f "${GLOBAL_FILE}" ] ; then
    DEBUG_LEVEL='0'
    /usr/bin/perl -i -p -e "s~#define REFIT_DEBUG \(\d+\)~#define REFIT_DEBUG (${DEBUG_LEVEL})~" "${GLOBAL_FILE}"
fi

echo ''
msg_info 'Output EFI Files...'
msg_status "RefindPlus EFI Files (BOOTx64)      : '${OUTPUT_DIR}'"
msg_status "RefindPlus EFI Files (Others - DBG) : '${XCODE_DIR_DBG}/X64'"
msg_status "RefindPlus EFI Files (Others - REL) : '${XCODE_DIR_REL}/X64'"
echo ''
echo ''
