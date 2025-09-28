#!/usr/bin/env bash
###
# RefindPlusBuilder.sh
# A script to build RefindPlus
#
# Copyright (c) 2020-2025 Dayo Akanji
# MIT-0 License
###

COLOR_BASE=""
COLOR_INFO=""
COLOR_STATUS=""
COLOR_ERROR=""
COLOR_NORMAL=""

if test -t 1; then
    NCOLORS=$(tput colors)
    if test -n "${NCOLORS}" && test "${NCOLORS}" -ge 8; then
        COLOR_BASE="\033[0;36m"
        COLOR_INFO="\033[0;33m"
        COLOR_STATUS="\033[0;32m"
        COLOR_ERROR="\033[0;31m"
        COLOR_NORMAL="\033[0m"
    fi
fi

# Provide Custom Colours
msg_raw() {
    printf "${1}\n"
}
msg_base() {
    printf "${COLOR_BASE}${1}${COLOR_NORMAL}\n"
}
msg_info() {
    printf "${COLOR_INFO}${1}${COLOR_NORMAL}\n"
}
msg_status() {
    printf "${COLOR_STATUS}${1}${COLOR_NORMAL}\n"
}
msg_error() {
    printf "${COLOR_ERROR}${1}${COLOR_NORMAL}\n"
}

## REVERT MISC CHANGES ##
#  - Always triggered on exit
#  - This includes crashes
#
# shellcheck disable=SC2329
TrapOUT() {
    export PATH="${ORIG_PATH}";
    rm -rf "${TMP_BIN}"

    # Restore Misc Amended Files
    [[ -f "${BASETYPE_KEPT}" ]] && mv -f "${BASETYPE_KEPT}" "${BASETYPE_MAIN}"
    [[ -f "${TOOLSDEF_KEPT}" ]] && mv -f "${TOOLSDEF_KEPT}" "${TOOLSDEF_MAIN}"
    [[ -f "${MAINFILE_KEPT}" ]] && mv -f "${MAINFILE_KEPT}" "${MAINFILE_MAIN}"
    [[ -f "${SYNCFILE_KEPT}" ]] && mv -f "${SYNCFILE_KEPT}" "${SYNCFILE_MAIN}"

    # Restore Word Wrap
    if (( WORDWRAP_FIX )) ; then
        if tput smam >/dev/null 2>&1; then
            # Enable WordWrap
            WORDWRAP_FIX=0
            tput smam
        fi
    fi
}

## HELPER FOR RUN FLAGS ##
Set_Flags() {
    RUN_REL="$1"
    RUN_DBG="$2"
    RUN_NPT="$3"
}

## ERROR HANDLERS ##
TrapINT() { # $1: message
    # Declare Local Variables
    local errMessage

    # Show error and exit
    errMessage="${1:-Force Quit ... Exiting}"
    echo ''
    msg_error "${errMessage}"
    printf "\n\n"
    exit 1
}

TrapERR() { # $1: message
    # Declare Local Variables
    local errMessage

    # Show error and exit
    errMessage="${1:-Runtime Error ... Exiting}"
    echo ''
    msg_error "${errMessage}"
    printf "\n\n"
    exit 1
}

Exec_Build() { # $1=SUFFIX (REL/DBG/NPT), $2=EDK BUILD TYPE (RELEASE/DEBUG/NOOPT), $3=BINARY_DIR
    local tag_type="$1"
    local edk_build="$2"
    local bin_folder="$3"
    local boot_out
    local our_tag
    local file

    # Add spacer if at least one version built before
    if (( PRIOR_BUILD )) ; then
        msg_info "Preparing ${tag_type} Build..."
        echo ''
        sleep 3
    fi

    echo ''
    msg_info "## RefindPlusBuilder - Building ${tag_type} Version ##  :  ${BUILD_BRANCH}"
    msg_info '##------------------------------------------##'
    source edksetup.sh BaseTools
    build -n "${JOBS_MAX}" -a X64 -b "${edk_build}" -t "${TOOLCHAIN}" -p "${DSC_FILE}"

    # Copy BOOTx64
    if [[ -d "${EDK2_DIR}/Build" ]] ; then
        boot_out="${OUTPUT_DIR}/BOOTx64-${tag_type}.efi"
        cp -pf "${bin_folder}/RefindPlus.efi" "${boot_out}"
    fi

    # Rename produced files
    mv -f "${bin_folder}/TOOLS_DEF.X64" "${bin_folder}/zTOOLS_DEF.X64"
    for file in "${bin_folder}"/*.efi; do
        [[ -e "${file}" ]] || continue  # Skip if no matches

        our_tag=$( basename "${file%.efi}" )
        if [[ "${our_tag}" == "RefindPlus" || "${our_tag}" == "gptsync" ]] ; then
            mv -f "${file}" "${bin_folder}/UEFI_APP---x64_${our_tag}_${tag_type}.efi"
        else
            mv -f "${file}" "${bin_folder}/DRIVER_${tag_type}---x64_${our_tag}.efi"
        fi
    done

    echo ''
    msg_info "Completed '${tag_type}' Build of the RefindPlus '${BUILD_BRANCH}' Branch"
    PRIOR_BUILD=1
}

# Set Event Traps
trap TrapERR ERR
trap TrapOUT EXIT
trap TrapINT SIGINT

# Set Basic Params
PRIOR_BUILD=0
WORDWRAP_FIX=0
ORIG_PATH="${PATH}"

TMP_BIN="$( mktemp -d /tmp/refindplus_dir.XXXXXX )" || true
[[ -d "${TMP_BIN}" ]] || TrapERR "Failed to Create 'TMP_BIN' ... Exiting"

BUILD_BRANCH="${1:-GOPFix}"
DEBUG_TYPE="${2:-TWO}"
NO_WRAPPING=${3:-1}

# Set things up for build
clear
msg_info "## RefindPlusBuilder - Setting Up ##  :  ${BUILD_BRANCH}"
msg_info '##--------------------------------##'
DSC_FILE="RefindPlusPkg/RefindPlusPkg.dsc"

BUILD_TYPE=$( tr '[:lower:]' '[:upper:]' <<< "${DEBUG_TYPE}" )
[[ "${BUILD_TYPE}" == 'SOME' ]] && BUILD_TYPE='TWO'
case "${BUILD_TYPE}" in
  "TWO") Set_Flags True  True  False ;;
  "REL") Set_Flags True  False False ;;
  "DBG") Set_Flags False True  False ;;
  "NPT") Set_Flags False False True  ;;
  "ALL") Set_Flags True  True  True  ;;
  *)     TrapERR "Invalid Build Type: '${BUILD_TYPE}' ... Valid Types: 'REL', 'DBG', 'NPT', 'TWO', 'ALL'."
esac

msg_base 'Check OS Type...'
Kern_OS="$( uname )"
if [[ "${Kern_OS}" == 'Darwin' ]] ; then
    OS_NAME="MacOS"
elif [[ "${Kern_OS}" == 'Linux' ]] ; then
    OS_NAME="Linux"
else
    TrapERR "Unsupported OS: '${Kern_OS}' ... Exiting"
fi
msg_raw "Detected OS:- '${OS_NAME}'"
msg_status '...OK'; echo ''

msg_base 'Sync CPU Threads...'
# Determine JOBS_MAX:
# - For failure: use 1
# - For <6 CPUs: use all
# - For 6–11 CPUs: use half + 1
# - For 12+ CPUs: use exactly half
JOBS_ALL=$( getconf _NPROCESSORS_ONLN )
if [[ -z "${JOBS_ALL}" || ! "${JOBS_ALL}" =~ ^[0-9]+$ ]] ; then
    JOBS_ALL=1
    msg_raw "Core Count Retrieval Failure ... Using Default Fallback"
fi
if (( JOBS_ALL < 2 )) ; then
    JOBS_MID=${JOBS_ALL}
else
    JOBS_MID=$(( JOBS_ALL / 2 ))
fi
if (( JOBS_ALL < 4 )) ; then
    JOBS_MAX=${JOBS_ALL}
elif (( JOBS_ALL < 12 )) ; then
    JOBS_MAX=$(( JOBS_MID + 1 ))
else
    JOBS_MAX=${JOBS_MID}
fi
msg_raw "All CPUs = ${JOBS_ALL}"
msg_raw "Max Jobs = ${JOBS_MAX}"
msg_status '...OK'; echo ''

msg_base 'Confirm Build Utilities...'
if [[ "${OS_NAME}" == 'MacOS' ]] ; then
    HINT_NASM="brew install nasm"
    HINT_IASL="brew install acpica"
else
    HINT_NASM="sudo apt install nasm"
    HINT_IASL="sudo apt install acpica-tools"
fi
for tool in nasm iasl; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        case "${tool}" in
            nasm) desc="Netwide Assembler Not Found --- Install to continue (e.g. ${HINT_NASM})" ;;
            iasl) desc="ACPI Compiler Not Found --- Install to continue (e.g. ${HINT_IASL})" ;;
        esac

        msg_raw "${desc}"
        echo ''
        TrapERR
    fi
done

if [[ "${OS_NAME}" == 'Linux' ]] ; then
    REQUIRED_TOOLS=("xdg-user-dir" "uuid-dev" "git")
    MISSING=()

    COUNT_MISSING=0
    for item in "${REQUIRED_TOOLS[@]}"; do
        if [[ "${item}" == 'uuid-dev' ]] ; then
            if ! echo "#include <uuid/uuid.h>" | gcc -E - >/dev/null 2>&1; then
                COUNT_MISSING=$(( COUNT_MISSING + 1 ))
                MISSING+=("uuid-dev")
            fi
        else
            if ! command -v "${item}" >/dev/null 2>&1; then
                COUNT_MISSING=$(( COUNT_MISSING + 1 ))
                if [[ "${item}" == 'xdg-user-dir' ]] ; then
                    MISSING+=("xdg-utils")
                else
                    MISSING+=("${item}")
                fi
            fi
        fi
    done

    if (( ${#MISSING[@]} )) ; then
        if (( COUNT_MISSING > 1 )) ; then
            msg_raw "Missing Required Build Utilities:"
        else
            msg_raw "Missing Required Build Utility:"
        fi
        printf '  - %s\n' "${MISSING[@]}"
        echo ''
        msg_raw "Install to continue (e.g. sudo apt install -y ${MISSING[*]})"
        echo ''
        TrapERR
    fi
fi
msg_status '...OK'; echo ''

if [[ "${OS_NAME}" == 'MacOS' ]] ; then
    DOCS_DIR="${HOME}/Documents"
    TOOLCHAIN="XCODE5"
else
    TOOLCHAIN="GCC5"
    DOCS_DIR="$( xdg-user-dir DOCUMENTS )"
fi

BASE_DIR="${DOCS_DIR}/RefindPlus"
[[ -d "$BASE_DIR" ]] || TrapERR "Could Not Locate '${BASE_DIR}' ... Exiting"

WORK_DIR="${BASE_DIR}/Working"
[[ -d "${WORK_DIR}" ]] || TrapERR "Could Not Locate '${WORK_DIR}' ... Exiting"

EDK2_DIR="${BASE_DIR}/edk2"
[[ -d "${EDK2_DIR}" ]] || TrapERR "Could Not Locate '${EDK2_DIR}' ... Exiting"

PLUS_DIR="${EDK2_DIR}/RefindPlusPkg"

HELP_DIR="${EDK2_DIR}/.BuildHelp"
mkdir -p "${HELP_DIR}"

CONF_DIR="${EDK2_DIR}/Conf"
BLOB_DIR="${CONF_DIR}/Blobs"

BUILD_DIR_REL="${EDK2_DIR}/Build/RefindPlus/RELEASE_${TOOLCHAIN}"
BUILD_DIR_DBG="${EDK2_DIR}/Build/RefindPlus/DEBUG_${TOOLCHAIN}"
BUILD_DIR_NPT="${EDK2_DIR}/Build/RefindPlus/NOOPT_${TOOLCHAIN}"
BINARY_DIR_REL="${BUILD_DIR_REL}/X64"
BINARY_DIR_DBG="${BUILD_DIR_DBG}/X64"
BINARY_DIR_NPT="${BUILD_DIR_NPT}/X64"
OUTPUT_DIR="${EDK2_DIR}/000-BOOTx64-Files"

BASETOOLS_DIR="${EDK2_DIR}/BaseTools"
BASESOURCE_DIR="${BASETOOLS_DIR}/Source/C"

BASETYPE_MAIN="${BASESOURCE_DIR}/Include/Common/BaseTypes.h"
BASETYPE_KEPT="${BASESOURCE_DIR}/Include/Common/BaseTypes-kept.h"
TOOLSDEF_MAIN="${CONF_DIR}/tools_def.txt"
TOOLSDEF_KEPT="${CONF_DIR}/tools_def-kept.txt"

MAINFILE_MAIN="${PLUS_DIR}/BootMaster/main.c"
MAINFILE_KEPT="${PLUS_DIR}/BootMaster/main-kept.c"
SYNCFILE_MAIN="${PLUS_DIR}/gptsync/gptsync.c"
SYNCFILE_KEPT="${PLUS_DIR}/gptsync/gptsync-kept.c"
EXTEND_TWEAKS="${HELP_DIR}/ExtendTweaks.txt"

ErrMsg="Could Not Find '${BASETOOLS_DIR}' ... Exiting"
pushd "${BASETOOLS_DIR}" > /dev/null || TrapERR "${ErrMsg}"

BASETOOLS_SHA_FILE="${HELP_DIR}/BaseToolsSHA.txt"
if [[ ! -f "${BASETOOLS_SHA_FILE}" ]] ; then
    BASETOOLS_SHA_OLD='Default'
else
    # shellcheck disable=SC1090
    source "${BASETOOLS_SHA_FILE}" || BASETOOLS_SHA_OLD='Default'
fi

OUR_SHASUM='NO-OP'
if [[ "${OS_NAME}" == 'MacOS' ]] ; then
    command -v shasum >/dev/null && OUR_SHASUM="shasum"
else
    for tool in shasum sha1sum md5sum; do
        command -v "${tool}" >/dev/null && OUR_SHASUM="${tool}" && break
    done
fi

if [[ "${OUR_SHASUM}" == 'NO-OP' ]] ; then
    BUILD_TOOLS=1
else
    Get_Sha_Str="$( find "${BASETOOLS_DIR}" "${CONF_DIR}" \
      -type f \( -name '*.c' -or -name '*.cpp' -or -name '*.h' -or -name '*.py' -or \
      -name '*.txt' -or -name '*.template' -or -name '*.makefile' -or -name 'GNUmakefile' \) \
      -print0 | sort -z | xargs -0 ${OUR_SHASUM} | ${OUR_SHASUM} | awk '{print $1}' )"

    if [[ "${OS_NAME}" == 'MacOS' ]] ; then
        Get_OS_Ver="$( sysctl kern.osrelease | cut -d ':' -f 2 | xargs )"
    else
        Get_Distro="$( grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"' )"
        Get_Kernel="$( uname -r | cut -d '-' -f 1 )"
        Get_OS_Ver="${Get_Distro}_${Get_Kernel}"
    fi

    BASETOOLS_SHA_NEW="${Get_Sha_Str}:${Get_OS_Ver}"
    if [[ ! -d "${BASESOURCE_DIR}/bin" ]] || \
       [[ "${BASETOOLS_SHA_NEW}" != "${BASETOOLS_SHA_OLD}" ]] ; then
        BUILD_TOOLS=1
    else
        BUILD_TOOLS=0
    fi
fi
popd > /dev/null || true

msg_base 'Export Temp "PATH"...'
export PATH="${TMP_BIN}:/usr/bin:/opt/local/bin:/opt/local/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:${PATH}"
msg_status '...OK'; echo ''

# Python 2 is a hard requirement
NO_PYTHON=1
if python2 --version 2>&1 | grep -q "Python 2"; then
    ALT_PYTHON="$( which python2 )"
    if [[ ! -z "${ALT_PYTHON}" ]] ; then
        msg_base 'Check Python 2...'
        msg_raw "Use Command:- 'python2'"
        ln -s "${ALT_PYTHON}" "${TMP_BIN}/python"
        # Found Python 2 ... Continue
        NO_PYTHON=0
        msg_status '...OK'; echo ''
    fi
fi
if (( NO_PYTHON )) ; then
    if python --version 2>&1 | grep -q "Python 2"; then
        msg_base 'Locate Python 2...'
        msg_raw "Use Command:- 'python'"
        # Found Python 2 ... Continue
        NO_PYTHON=0
        msg_status '...OK'; echo ''
    fi
fi
if (( NO_PYTHON )) ; then
    msg_info "Python 2 Instance Not Found"
    echo ''
    if [[ "${OS_NAME}" == 'MacOS' ]] ; then
        # Unable to proceed without Python 2
        # Default Error Exit
        TrapERR
    else
        # Try bundled AppImage
        msg_base 'Link Bundled Python 2...'
        PYTHON2_APPIMAGE="${BLOB_DIR}/Python2_x86_64.AppImage"
        if [[ ! -f "${PYTHON2_APPIMAGE}" ]] ; then
            TrapERR "Python 2 AppImage Not Found ... Exiting"
        fi

        rm -f "${TMP_BIN}/python"
        chmod +x "${PYTHON2_APPIMAGE}"
        ln -s "${PYTHON2_APPIMAGE}" "${TMP_BIN}/python"

        if ! python --version 2>&1 | grep -q "Python 2"; then
            # Unable to proceed ... Python 2 still unavailable
            TrapERR "Invalid AppImage ... Exiting"
        fi
        msg_status '...OK'; echo ''
    fi
fi

## Clear Potential Leftover Legacy Items ... Remove Later - START ##
rm -fr "${EDK2_DIR}/RefindPkg"
rm -fr "${EDK2_DIR}/.Build-TMP"
rm -f  "${EDK2_DIR}/000-BuildScript/RepoUpdateSHA.txt"
## Clear Potential Leftover Legacy Items ... Remove Later - END ##

if [[ ! -L "${PLUS_DIR}" ]] ; then
    msg_base 'Update RefindPlusPkg...'
    rm -fr "${PLUS_DIR}"
    ln -s "${WORK_DIR}" "${PLUS_DIR}"
    msg_status '...OK'; echo ''
fi

CUR_PATH="${PWD}"
ErrMsg="Could Not Find '${PLUS_DIR}' ... Exiting"
cd "${PLUS_DIR}" || TrapERR "${ErrMsg}"
msg_base "Checkout '${BUILD_BRANCH}' branch..."
git checkout "${BUILD_BRANCH}" || TrapERR "Specified Git Branch Not Available ... Exiting"
msg_status '...OK'; echo ''
cd "${CUR_PATH}" || true

# Enter EDK2 Dir - START #
ErrMsg="Could Not Access '${EDK2_DIR}' ... Exiting"
pushd "${EDK2_DIR}" > /dev/null || TrapERR "${ErrMsg}"

# Recreate 'Build' Dir
# UDK is RefindPlus Specific
# Not Meant for Other Builds
msg_base 'Reset Build Dirs...'
rm -fr "${EDK2_DIR}/Build"
rm -fr "${OUTPUT_DIR}"
mkdir -p "${EDK2_DIR}/Build"
mkdir -p "${OUTPUT_DIR}"
msg_status '...OK'; echo ''

if (( NO_WRAPPING )) ; then
    if tput rmam >/dev/null 2>&1; then
        # Disable WordWrap
        msg_base 'Sync Terminal Wordwrap...'
        tput rmam
        WORDWRAP_FIX=1
        msg_status '...OK'; echo ''
    fi
fi

if (( BUILD_TOOLS )) ; then
    ErrMsg="Could Not Access '${BASESOURCE_DIR}' ... Exiting"
    pushd "${BASESOURCE_DIR}" > /dev/null || TrapERR "${ErrMsg}"

    if [[ -f "${CONF_DIR}/BuildEnv.sh" ]] ; then
        msg_base 'Nuke Prev BaseTools Env...'
        unset EDK_TOOLS_PATH
        rm -fr "${CONF_DIR}/.cache"
        rm -f "${CONF_DIR}/BuildEnv.sh"
        msg_status '...OK'; echo ''
    fi

    OurArch="$( uname -m )"
    if [[ "${OurArch}" == *"arm"* ]] ; then
        if [[ "${OS_NAME}" == 'MacOS' ]] ; then
            msg_base 'Create Temp BaseTools BaseType for Apple Silicon...'
            if [[ -f "${BASETYPE_KEPT}" ]] ; then
                cp -pf "${BASETYPE_KEPT}" "${BASETYPE_MAIN}"
            else
                cp -pf "${BASETYPE_MAIN}" "${BASETYPE_KEPT}"
            fi

            # Apply patch if not already patched
            if grep -q '#include <ProcessorBind.h>' "${BASETYPE_MAIN}"; then
                ErrMsg="Could Not Create 'BASETYPE tmpfile' ... Exiting"
                tmpfile="$( mktemp /tmp/refindplus_basetype.XXXXXX )" || TrapERR "${ErrMsg}"
                sed 's|#include <ProcessorBind.h>|#include "../AArch64/ProcessorBind.h"|' \
                    "${BASETYPE_MAIN}" > "${tmpfile}" && mv -f "${tmpfile}" "${BASETYPE_MAIN}" || rm -f "${tmpfile}"
            fi
            msg_status '...OK'; echo ''
        fi
    fi

    msg_base 'BaseTools Make Clean...'
    make clean
    msg_status '...OK'; echo ''
    popd > /dev/null || true

    msg_base 'BaseTools Make...'
    make -j"${JOBS_MAX}" -C BaseTools/Source/C
    msg_status '...OK'; echo ''

    msg_base 'Update BaseTools SHA...'
    if [[ "${OUR_SHASUM}" != 'NO-OP' ]] ; then
        echo '#!/usr/bin/env bash' > "${BASETOOLS_SHA_FILE}"
        echo "BASETOOLS_SHA_OLD='${BASETOOLS_SHA_NEW}'" >> "${BASETOOLS_SHA_FILE}"
    else
        if [[ -f "${BASETOOLS_SHA_FILE}" ]] ; then
            rm -f "${BASETOOLS_SHA_FILE}"
        fi
    fi
    msg_status '...OK'; echo ''

    if [[ "${OurArch}" == *"arm"* ]] ; then
        if [[ -f "${BASETYPE_KEPT}" ]] ; then
            msg_base 'Restore BaseType...'
            mv -f "${BASETYPE_KEPT}" "${BASETYPE_MAIN}" || true
            msg_status '...OK'; echo ''
        fi
    fi
fi
popd > /dev/null || true
# Enter EDK2 Dir - END #

# Basic clean up
echo ''
msg_info "## RefindPlusBuilder - Misc Checks ##  :  ${BUILD_BRANCH}"
msg_info '##---------------------------------##'
if ! grep -q '__REFIT_SBAT_' "${MAINFILE_MAIN}"; then
    msg_base "Skip 'SBAT' Tweaks..."
    # Not found ... Continue
    msg_status '...OK'; echo ''
else
    if [[ "${OS_NAME}" != 'MacOS' ]] ; then
        msg_base 'Skip MTOC Sync...'
        # Not Mac OS ... Continue
        msg_status '...OK'; echo ''
    else
        msg_base 'Sync MTOC Type...'
        # Default to bundled ocmtoc (v1.0.4+)
        BLOB_OCMTOC=1
        if command -v mtoc >/dev/null 2>&1; then
            # mtoc or ocmtoc found ... Check if ocmtoc 1.0.4/newer
            # - Both variants share the same binary name
            # - ocmtoc >= v1.0.4 accepts '--fullversion'
            if mtoc --fullversion 2>/dev/null | grep -qi 'Acidanthera ocmtoc'; then
                # ocmtoc >= v1.0.4 found ... Use system instance
                BLOB_OCMTOC=0
            fi
        fi
        if (( BLOB_OCMTOC )) ; then
            msg_raw "Target MTOC:- 'Bundled'"
        else
            msg_raw "Target MTOC:- 'System'"
        fi
        msg_status '...OK'; echo ''

        msg_base "Prep 'Tools_Def' file..."
        # Locate and Prep 'Tools_Def'
        # Fix any previous leftovers
        # Must be after 'BLOB_OCMTOC' is set
        if [[ -f "${TOOLSDEF_KEPT}" ]] ; then
            if (( BLOB_OCMTOC )) ; then
                cp -pf "${TOOLSDEF_KEPT}" "${TOOLSDEF_MAIN}"
            else
                mv -f "${TOOLSDEF_KEPT}" "${TOOLSDEF_MAIN}"
            fi
        elif [[ -f "${TOOLSDEF_MAIN}" ]] ; then
            if (( BLOB_OCMTOC )) ; then
                cp -pf "${TOOLSDEF_MAIN}" "${TOOLSDEF_KEPT}"
            fi
        else
            # Unable to proceed ... 'Tools_Def' not found
            TrapERR "Could Not Locate 'Tools_Def' file ... Exiting"
        fi
        msg_status '...OK'; echo ''

        if (( BLOB_OCMTOC )) ; then
            if grep -Eq '^\*_XCODE5_\*_MTOC_PATH[[:space:]]*=[[:space:]]*mtoc' "${TOOLSDEF_MAIN}"; then
                # Path to bundled ocmtoc ... File name is 'mtoc'
                BUNDLED_OCMTOC="${BLOB_DIR}/mtoc"

                if [[ ! -f "${BUNDLED_OCMTOC}" ]] ; then
                    TrapERR 'Could Not Locate Bundled MTOC ... Exiting'
                else
                    msg_base 'Prep Bundled MTOC...'
                    # Remove quarantine attribute if present
                    if command -v xattr >/dev/null 2>&1; then
                        if xattr -p  com.apple.quarantine "${BUNDLED_OCMTOC}" >/dev/null 2>&1; then
                            xattr -d com.apple.quarantine "${BUNDLED_OCMTOC}"
                        fi
                    fi

                    # Ensure bundled mtoc is executable
                    chmod +x "${BUNDLED_OCMTOC}"

                    # Test bundled mtoc
                    if ! "${BUNDLED_OCMTOC}" --fullversion 2>/dev/null | grep -qi 'Acidanthera ocmtoc'; then
                        TrapERR "Invalid Bundled MTOC ... Exiting"
                    fi
                    msg_status '...OK'; echo ''

                    msg_base 'Create Temp Tools_Def...'
                    # Update temp tools_def file
                    ErrMsg="Could Not Create 'TOOLSDEF tmpfile' ... Exiting"
                    tmpfile="$( mktemp /tmp/refindplus_toolsdef.XXXXXX )" || TrapERR "${ErrMsg}"
                    sed -E "s|^\*_XCODE5_\*_MTOC_PATH[[:space:]]*=.*|*_XCODE5_*_MTOC_PATH = ${BUNDLED_OCMTOC}|" \
                        "${TOOLSDEF_MAIN}" > "${tmpfile}" && mv -f "${tmpfile}" "${TOOLSDEF_MAIN}" || rm -f "${tmpfile}"
                    msg_status '...OK'; echo ''
                fi
            fi
        fi
    fi

    if [[ -f "${EXTEND_TWEAKS}" ]] ; then
        if ! source "${EXTEND_TWEAKS}" ; then
            TrapERR "Could Not Source:- '${EXTEND_TWEAKS}'"
        else
            msg_base 'Handle SBAT Tweak...'
            if ! declare -f tweak_sbat >/dev/null; then
                TrapERR "Not Declared:- 'tweak_sbat'"
            else
                if [[ -f "${MAINFILE_KEPT}" ]] ; then
                    cp -pf "${MAINFILE_KEPT}" "${MAINFILE_MAIN}"
                else
                    cp -pf "${MAINFILE_MAIN}" "${MAINFILE_KEPT}"
                fi

                if [[ -f "${SYNCFILE_KEPT}" ]] ; then
                    cp -pf "${SYNCFILE_KEPT}" "${SYNCFILE_MAIN}"
                else
                    cp -pf "${SYNCFILE_MAIN}" "${SYNCFILE_KEPT}"
                fi
                tweak_sbat "${MAINFILE_MAIN}" "refindplus" || TrapERR "SBAT Tweak Failed:- 'Main'"
                tweak_sbat "${SYNCFILE_MAIN}" "gptsync"    || TrapERR "SBAT Tweak Failed:- 'Sync'"
            fi
            msg_status '...OK'; echo ''

            msg_base 'Handle MAIN Tweak...'
            if ! declare -f tweak_main >/dev/null; then
                TrapERR "Not Declared:- 'tweak_main'"
            else
                tweak_main "${MAINFILE_MAIN}"
            fi
            msg_status '...OK'; echo ''
        fi
    fi
fi

# Execute Version Build
ErrMsg="Could Not Find '${EDK2_DIR}' ... Exiting"
pushd "${EDK2_DIR}" > /dev/null || TrapERR "${ErrMsg}"
[[ "${RUN_REL}" == 'True' ]] && Exec_Build "REL" "RELEASE" "${BINARY_DIR_REL}"
[[ "${RUN_DBG}" == 'True' ]] && Exec_Build "DBG" "DEBUG"   "${BINARY_DIR_DBG}"
[[ "${RUN_NPT}" == 'True' ]] && Exec_Build "NPT" "NOOPT"   "${BINARY_DIR_NPT}"
popd > /dev/null || true

# Tidy up
printf "\n\n"
msg_info 'Locate the EFI Files:'
[[ -d "${EDK2_DIR}/Build" ]] && msg_status "RefindPlus EFI Files (BOOTx64)      : '${OUTPUT_DIR}'"
[[ "${RUN_NPT}" == 'True' ]] && msg_status "RefindPlus EFI Files (Others - NPT) : '${BUILD_DIR_NPT}/X64'"
[[ "${RUN_DBG}" == 'True' ]] && msg_status "RefindPlus EFI Files (Others - DBG) : '${BUILD_DIR_DBG}/X64'"
[[ "${RUN_REL}" == 'True' ]] && msg_status "RefindPlus EFI Files (Others - REL) : '${BUILD_DIR_REL}/X64'"
printf "\n\n"
