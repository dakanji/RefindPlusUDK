#!/usr/bin/env bash

###
 # RefindPlusBuilder.sh
 # A script to build RefindPlus
 #
 # Copyright (c) 2020-2022 Dayo Akanji
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

## REVERT WORD_WRAP FIX ##
RevertWordWrap() {
    if [ "${WORD_WRAP}" == '0' ] ; then
        # Enable WordWrap
        tput smam
    fi
}

## REVERT SHASUM FIX ##
RevertShasumFix() {
    if [ "${SHASUM_FIX}" == 'true' ] ; then
        mv -f "${TMP_SHASUM}" "${DUP_SHASUM}"
    fi
}


## ERROR HANDLERS ##
trapINT() { # $1: message
    # Declare Local Variables
    local errMessage

    # In case it was stopped while shasum is unset
    RevertShasumFix ;

    # Revert Word Wrap Fix
    RevertWordWrap ;

    # SHow error and exit
    errMessage="${1:-Force Quit ... Exiting}"
    echo ''
    msg_error "${errMessage}"
    echo ''
    echo ''
    exit 1
}


runErr() { # $1: message
    # Declare Local Variables
    local errMessage

    # In case it failed while shasum is unset
    RevertShasumFix ;

    # Revert Word Wrap Fix
    RevertWordWrap ;

    # SHow error and exit
    errMessage="${1:-Runtime Error ... Exiting}"
    echo ''
    msg_error "${errMessage}"
    echo ''
    echo ''
    exit 1
}
trap runErr ERR
trap trapINT SIGINT


# Set Script Params
DONE_ONE="False"

BUILD_BRANCH="${1:-GOPFix}"
DEBUG_TYPE="${2:-SOME}"
WORD_WRAP="${3:-0}"
if [ "${WORD_WRAP}" == '0' ] ; then
    # Disable WordWrap
    tput rmam
fi

RUN_REL="True"
RUN_DBG="True"
RUN_NPT="False"
if [ "${DEBUG_TYPE^^}" == 'DBG' ] || [ "${DEBUG_TYPE^^}" == 'NPT' ] ; then
    RUN_REL="False"
fi
if [ "${DEBUG_TYPE^^}" == 'REL' ] || [ "${DEBUG_TYPE^^}" == 'NPT' ] ; then
    RUN_DBG="False"
fi
if [ "${DEBUG_TYPE^^}" == 'ALL' ] || [ "${DEBUG_TYPE^^}" == 'NPT' ] || ( [ "${DEBUG_TYPE^^}" != 'REL' ] && [ "${DEBUG_TYPE^^}" != 'DBG' ] && [ "${DEBUG_TYPE^^}" != 'SOME' ] ) ; then
    RUN_NPT="True"
fi


# Set things up for build
clear
msg_info "## RefindPlusBuilder - Setting Up ##  :  ${BUILD_BRANCH}"
msg_info '##--------------------------------##'
BASE_DIR="${HOME}/Documents/RefindPlus"
WORK_DIR="${BASE_DIR}/Working"
EDK2_DIR="${BASE_DIR}/edk2"
if [ ! -d "${EDK2_DIR}" ] ; then
    runErr "ERROR: Could not locate ${EDK2_DIR}"
fi
XCODE_DIR_REL="${EDK2_DIR}/Build/RefindPlus/RELEASE_XCODE5"
XCODE_DIR_DBG="${EDK2_DIR}/Build/RefindPlus/DEBUG_XCODE5"
XCODE_DIR_NPT="${EDK2_DIR}/Build/RefindPlus/NOOPT_XCODE5"
BINARY_DIR_REL="${XCODE_DIR_REL}/X64"
BINARY_DIR_DBG="${XCODE_DIR_DBG}/X64"
BINARY_DIR_NPT="${XCODE_DIR_NPT}/X64"
OUTPUT_DIR="${EDK2_DIR}/000-BOOTx64-Files"
OUR_SHASUM='/usr/bin/shasum'
DUP_SHASUM='/usr/local/bin/shasum'
TMP_SHASUM='/usr/local/bin/_shasum'

ErrMsg="ERROR: Could not find '${EDK2_DIR}/BaseTools'"
pushd "${EDK2_DIR}/BaseTools" > /dev/null || runErr "${ErrMsg}"
SHASUM_FIX='false'
if [ -f "${DUP_SHASUM}" ] ; then
    mv -f "${DUP_SHASUM}" "${TMP_SHASUM}"
    SHASUM_FIX='true'
fi
BASETOOLS_SHA_FILE="${EDK2_DIR}/000-BuildScript/BaseToolsSHA.txt"
# shellcheck disable=SC1090
source "${BASETOOLS_SHA_FILE}" || BASETOOLS_SHA_OLD='Default'
BASETOOLS_SHA_NEW="$(find . -type f \( -name '*.c' -or -name '*.cpp' -or -name '*.h' -or -name '*.py' -or -name '*.makefile' -or -name 'GNUmakefile' \) -print0 | sort -z | xargs -0 ${OUR_SHASUM} | ${OUR_SHASUM} | cut -d ' ' -f 1)"
RevertShasumFix ;
BUILD_TOOLS='false'
if [ ! -d "${EDK2_DIR}/BaseTools/Source/C/bin" ] || [ "${BASETOOLS_SHA_NEW}" != "${BASETOOLS_SHA_OLD}" ] ; then
    BUILD_TOOLS='true'
    echo '#!/usr/bin/env bash' > "${BASETOOLS_SHA_FILE}"
    echo "BASETOOLS_SHA_OLD='${BASETOOLS_SHA_NEW}'" >> "${BASETOOLS_SHA_FILE}"
fi
popd > /dev/null || runErr "${ErrMsg}"

ErrMsg="ERROR: Could not find '${WORK_DIR}'"
pushd "${WORK_DIR}" > /dev/null || runErr "${ErrMsg}"
msg_base "Checkout '${BUILD_BRANCH}' branch..."
git checkout ${BUILD_BRANCH} > /dev/null
msg_status '...OK'; echo ''
msg_base 'Update RefindPlusPkg...'
# Remove Later - START #
rm -fr "${EDK2_DIR}/RefindPkg"
rm -fr "${EDK2_DIR}/.Build-TMP"
# Remove Later - END #
if [ ! -L "${EDK2_DIR}/RefindPlusPkg" ]; then
	rm -fr "${EDK2_DIR}/RefindPlusPkg"
    ln -s "${WORK_DIR}" "${EDK2_DIR}/RefindPlusPkg"
fi
msg_status '...OK'; echo ''
popd > /dev/null || runErr "${ErrMsg}"

if [ "${BUILD_TOOLS}" == 'true' ] ; then
    ErrMsg="ERROR: Could not find '${EDK2_DIR}/BaseTools/Source/C'"
    pushd "${EDK2_DIR}/BaseTools/Source/C" > /dev/null || runErr "${ErrMsg}"
    msg_base 'Make Clean...'
    make clean
    msg_status '...OK'; echo ''
    popd > /dev/null || runErr "${ErrMsg}"

    ErrMsg="ERROR: Could not find '${EDK2_DIR}'"
    pushd "${EDK2_DIR}" > /dev/null || runErr "${ErrMsg}"
    msg_base 'Make BaseTools...'
    make -C BaseTools/Source/C
    msg_status '...OK'; echo ''
    popd > /dev/null || runErr "${ErrMsg}"
fi


# Basic clean up
clear
msg_info "## RefindPlusBuilder - Initial Clean Up ##  :  ${BUILD_BRANCH}"
msg_info '##--------------------------------------##'
rm -fr "${EDK2_DIR}/Build"
mkdir -p "${EDK2_DIR}/Build"
rm -fr "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"


# Build RELEASE version
if [ "${RUN_REL}" == 'True' ] ; then
    clear
    msg_info "## RefindPlusBuilder - Building REL Version ##  :  ${BUILD_BRANCH}"
    msg_info '##------------------------------------------##'
    ErrMsg="ERROR: Could not find '${EDK2_DIR}'"
    pushd "${EDK2_DIR}" > /dev/null || runErr "${ErrMsg}"
    source edksetup.sh BaseTools
    build -a X64 -b RELEASE -t XCODE5 -p RefindPlusPkg/RefindPlusPkg.dsc
    if [ -d "${EDK2_DIR}/Build" ] ; then
        cp "${BINARY_DIR_REL}/RefindPlus.efi" "${OUTPUT_DIR}/BOOTx64-REL.efi"
    fi
    popd > /dev/null || runErr "${ErrMsg}"
    echo ''
    msg_info "Completed REL Build on '${BUILD_BRANCH}' Branch of RefindPlus"
    DONE_ONE="True"
fi


# Build DEBUG version
if [ "${RUN_DBG}" == 'True' ] ; then
    if [ "${DONE_ONE}" == 'True' ] ; then
        msg_info 'Preparing DBG Build...'
        echo ''
        sleep 4
    fi

    clear
    msg_info "## RefindPlusBuilder - Building DBG Version ##  :  ${BUILD_BRANCH}"
    msg_info '##------------------------------------------##'
    ErrMsg="ERROR: Could not find '${EDK2_DIR}'"
    pushd "${EDK2_DIR}" > /dev/null || runErr "${ErrMsg}"
    source edksetup.sh BaseTools
    build -a X64 -b DEBUG -t XCODE5 -p RefindPlusPkg/RefindPlusPkg.dsc
    if [ -d "${EDK2_DIR}/Build" ] ; then
        cp -f "${BINARY_DIR_DBG}/RefindPlus.efi" "${OUTPUT_DIR}/BOOTx64-DBG.efi"
    fi
    popd > /dev/null || runErr "${ErrMsg}"
    echo ''
    msg_info "Completed DBG Build on '${BUILD_BRANCH}' Branch of RefindPlus"
    DONE_ONE="True"
fi


# Build NOOPT version
if [ "${RUN_NPT}" == 'True' ] ; then
    if [ "${DONE_ONE}" == 'True' ] ; then
        msg_info 'Preparing NPT Build...'
        echo ''
        sleep 4
    fi

    clear
    msg_info "## RefindPlusBuilder - Building NPT Version ##  :  ${BUILD_BRANCH}"
    msg_info '##------------------------------------------##'
    ErrMsg="ERROR: Could not find '${EDK2_DIR}'"
    pushd "${EDK2_DIR}" > /dev/null || runErr "${ErrMsg}"
    source edksetup.sh BaseTools
    build -a X64 -b NOOPT -t XCODE5 -p RefindPlusPkg/RefindPlusPkg.dsc
    if [ -d "${EDK2_DIR}/Build" ] ; then
        cp -f "${BINARY_DIR_NPT}/RefindPlus.efi" "${OUTPUT_DIR}/BOOTx64-NPT.efi"
    fi
    popd > /dev/null || runErr "${ErrMsg}"
    echo ''
    msg_info "Completed NPT Build on '${BUILD_BRANCH}' Branch of RefindPlus"
fi


# Tidy up
echo ''
echo ''
msg_info 'Output EFI Files...'
msg_status "RefindPlus EFI Files (BOOTx64)      : '${OUTPUT_DIR}'"
if [ "${RUN_NPT}" == 'True' ] ; then
    msg_status "RefindPlus EFI Files (Others - NPT) : '${XCODE_DIR_NPT}/X64'"
fi
if [ "${RUN_DBG}" == 'True' ] ; then
    msg_status "RefindPlus EFI Files (Others - DBG) : '${XCODE_DIR_DBG}/X64'"
fi
if [ "${RUN_REL}" == 'True' ] ; then
    msg_status "RefindPlus EFI Files (Others - REL) : '${XCODE_DIR_REL}/X64'"
fi
echo ''
echo ''

# Revert Word Wrap Fix
RevertWordWrap ;
