#!/usr/bin/env bash
###
# RefindPlusBuilder.sh
# A script to build RefindPlus
#
# Copyright (c) 2020-2026 Dayo Akanji
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
    printf "%s\n" "${1}"
}
msg_base() {
    printf "%b%s%b\n" "${COLOR_BASE}" "${1}" "${COLOR_NORMAL}"
}
msg_info() {
    printf "%b%s%b\n" "${COLOR_INFO}" "${1}" "${COLOR_NORMAL}"
}
msg_status() {
    printf "%b%s%b\n" "${COLOR_STATUS}" "${1}" "${COLOR_NORMAL}"
}
msg_error() {
    printf "%b%s%b\n" "${COLOR_ERROR}" "${1}" "${COLOR_NORMAL}"
}

## REVERT MISC CHANGES ##
#  - Always triggered on exit
#  - This includes crashes
#
# shellcheck disable=SC2329
TrapOUT() {
    # Restore PATH
    export PATH="${ORIG_PATH}"; hash -r

    # Clear Build/Compiler Variables
    unset CC CXX CLANG38_BIN

    # Reset Misc
    [[ -n "${TMP_BIN}" && "${TMP_BIN}" == "${RP_TMP_DIR}".* ]] && rm -fr "${TMP_BIN}"

    # Restore Misc Amended Files
    [[ -f "${BASETYPE_KEPT}" ]] && mv -f "${BASETYPE_KEPT}" "${BASETYPE_MAIN}"
    [[ -f "${TOOLSDEF_KEPT}" ]] && mv -f "${TOOLSDEF_KEPT}" "${TOOLSDEF_MAIN}"
    [[ -f "${MAINFILE_KEPT}" ]] && mv -f "${MAINFILE_KEPT}" "${MAINFILE_MAIN}"
    [[ -f "${SYNCFILE_KEPT}" ]] && mv -f "${SYNCFILE_KEPT}" "${SYNCFILE_MAIN}"

    # Restore Line Wrap
    if (( LINEWRAP_FIX )); then
        if tput smam >/dev/null 2>&1; then
            # Enable Line Wrap
            LINEWRAP_FIX=0
            tput smam
        fi
    fi
}

## ERROR HANDLERS ##
TrapINT() { # $1: message
    # Declare Local Variables
    local errMessage

    # Show error and exit
    errMessage="${1:-Force Quit ... Exiting}"
    printf '\n'
    msg_error "${errMessage}"
    printf '\n\n'
    exit 1
}
TrapERR() { # $1: message
    # Declare Local Variables
    local errMessage

    # Show error and exit
    errMessage="${1:-Runtime Error ... Exiting}"
    printf '\n'
    msg_error "${errMessage}"
    printf '\n\n'
    exit 1
}

## HELPER FOR RUN FLAGS ##
Set_Flags() {
    RUN_REL="${1}"
    RUN_DBG="${2}"
    RUN_NPT="${3}"
}

Get_Abs_Path() {
    local target="${1}"
    local base_dir
    local file_name

    if [[ -d "${target}" ]]; then
        (cd "${target}" && pwd)
    elif [[ -f "${target}" ]]; then
        base_dir=$(cd "$(dirname "${target}")" && pwd)
        file_name=$(basename "${target}")
        printf "%s/%s\n" "${base_dir}" "${file_name}"
    fi
}

Exec_Build() { # $1=SUFFIX (REL/DBG/NPT), $2=EDK BUILD TYPE (RELEASE/DEBUG/NOOPT), $3=BINARY_DIR
    local tag_type="${1}"
    local edk_build="${2}"
    local bin_folder="${3}"
    local boot_out
    local our_tag
    local file

    # Add spacer if at least one version built before
    if (( PRIOR_BUILD )); then
        msg_info "Preparing ${tag_type} Build..."
        printf '\n'
    fi

    printf '\n'
    msg_info "## RefindPlusBuilder - Building ${tag_type} Version ##  :  ${BUILD_BRANCH}"
    msg_info '##------------------------------------------##'
    source edksetup.sh BaseTools
    build -n "${JOBS_MAX}" -a X64 -b "${edk_build}" -t "${TOOLCHAIN}" -p "${DSC_FILE}"

    # Copy BOOTx64
    if [[ -d "${EDK2_DIR}/Build" ]]; then
        boot_out="${OUTPUT_DIR}/APP_xx_000---BOOTx64-${tag_type}.efi"
        cp -pf "${bin_folder}/RefindPlus.efi" "${boot_out}"
    fi

    # Rename produced files
    for file in "${bin_folder}"/*.efi ; do
        [[ -e "${file}" ]] || continue  # Skip if no matches

        our_tag=$( basename "${file%.efi}" )
        if [[ "${our_tag}" == "RefindPlus" ]]; then
            mv -f "${file}" "${bin_folder}/APP_xx_000---x64_${our_tag}_${tag_type}.efi"
        elif [[ "${our_tag}" == "gptsync" ]]; then
            mv -f "${file}" "${bin_folder}/APP_xx_${tag_type}---x64_${our_tag}.efi"
        else
            mv -f "${file}" "${bin_folder}/DRV_xx_${tag_type}---x64_${our_tag}.efi"
        fi
    done

    # Add binary blobs
    for blob_bin in shell memtest86 gdisk CleanNvram ipxe; do
      blob_file="${BLOB_DIR}/x64_${blob_bin}.efi"

      if [[ -f "${blob_file}" ]]; then
        cp -f "${blob_file}" "${bin_folder}/BLB_xx_${tag_type}---x64_${blob_bin}.efi" || true
      fi
    done


    # Add licenses
    for lic_name in INFO LICENSE; do
      lic_file="000_xx_000---${lic_name}.txt"
      cp -pf "${PLUS_DIR}/${lic_name}.txt" "${bin_folder}/${lic_file}" || true
      cp -pf "${PLUS_DIR}/${lic_name}.txt" "${OUTPUT_DIR}/${lic_file}" || true
    done


    printf '\n'
    msg_info "Completed '${tag_type}' Build of the RefindPlus '${BUILD_BRANCH}' Branch"
    PRIOR_BUILD=1
}


##########################
# Procedural Code Starts #
##########################

# Set Event Traps
trap TrapERR ERR
trap TrapOUT EXIT
trap TrapINT SIGINT

# Set Temp Binary Dir
RP_TMP_DIR="/tmp/refindplus_dir"
TMP_BIN="$( mktemp -d "${RP_TMP_DIR}".XXXXXX )"
[[ -d "${TMP_BIN}" ]] || TrapERR "Failed to Create 'TMP_BIN' ... Exiting"

# Set Basic Params
PRIOR_BUILD=0
LINEWRAP_FIX=0
ORIG_PATH="${PATH}"

# ============================== #
#       Parameter Handling       #
#   '--flag=value' OR arranged   #
# ============================== #

# --- Defaults ---
BUILD_BRANCH="HEAD"
BUILD_TYPE="TWO"
BUILD_ENV=1
NO_WRAP=1

# --- Track State ---
seen_specific=0
seen_arranged=0
pos_index=1

# --- Parse Params ---
show_help=0
for arg in "$@"; do
    case "${arg}" in
        --help|-h)
            show_help=1
        break
        ;;
    esac
done
if (( show_help )); then
    clear
    cat <<EOF

The RefindPlus Build Script
Copyright (c) Dayo Akanji
MIT-0 License

Usage:
  * Optional Arranged Parameters (Deprecated):
    RefindPlusBuilder.sh [ build-branch ] [ build-type ] [ build-env ] [ no-wrap ]

  * Optional Specific Parameters (Preferred):
    RefindPlusBuilder.sh [ --build-branch=ABC ]
                         [ --build-type=XYZ ]
                         [ --build-env=0|1 ]
                         [ --no-wrap=0|1 ]


Parameter Details:
  * [build-branch]
      Name of local git branch to build.
      Default: "HEAD" (checked out branch)
               - Default works without git.

  * [build-type]
      Controls build type(s) to generate:
        TWO - RELEASE and DEBUG builds (default)
        REL - RELEASE build only
        DBG - DEBUG build only
        NPT - NOOPT build only
        ALL - All build types

  * [build-env]
      Controls Linux build environment checks:
        1 - Verify Debian Linux build environment (default)
        0 - Do not verify Linux build environment (any)

  * [no-wrap]
      Controls terminal line wrapping:
        1 - Terminal line wrapping is disabled (default)
        0 - Terminal line wrapping is preserved


Rules:
  * Use EITHER Arranged OR Specific Parameters (Not Both)
  * Use '--flag=value' syntax for the specific parameters

EOF

    exit 0
fi

for arg in "$@"; do
    case "${arg}" in
        --build-branch=*)
            seen_specific=1
            BUILD_BRANCH=${arg#*=}
            [[ -n "${BUILD_BRANCH}" ]] || TrapERR "--build-branch requires a value ... Exiting"
        ;;
        --build-type=*)
            seen_specific=1
            BUILD_TYPE=${arg#*=}
            [[ -n "${BUILD_TYPE}" ]] || TrapERR "--build-type requires a value ... Exiting"
        ;;
        --build-env=*)
            seen_specific=1
            BUILD_ENV=${arg#*=}
            [[ -n "${BUILD_ENV}" ]] || TrapERR "--build-env requires a value ... Exiting"
        ;;
        --no-wrap=*)
            seen_specific=1
            NO_WRAP=${arg#*=}
            [[ -n "${NO_WRAP}" ]] || TrapERR "--no-wrap requires a value ... Exiting"
        ;;

        # Catch misc malformed parameters
        --build-branch|--build-type|--build-env|--no-wrap)
            TrapERR "Parameter '${arg}' is missing the '=' sign (use --flag=value) ... Exiting"
        ;;
        --*=)
            TrapERR "Parameter '${arg}' requires a value ... Exiting"
        ;;
        --*)
            TrapERR "Unknown Parameter: '${arg}' ... Exiting"
        ;;
        -*)
            TrapERR "Invalid Parameter: '${arg}' (use --flag=value) ... Exiting"
        ;;
        *)
            seen_arranged=1
            [ "${pos_index}" -gt 4 ] && TrapERR "Too many parameters detected ... Exiting"
            case "${pos_index}" in
                1) BUILD_BRANCH="${arg}" ;;
                2) BUILD_TYPE="${arg}"   ;;
                3) BUILD_ENV="${arg}"    ;;
                4) NO_WRAP="${arg}"      ;;
            esac
            pos_index=$((pos_index + 1))
        ;;
    esac
done

if [[ -z "${END_NOTICE}" ]]; then
    # --- Reject Mixing ---
    if [ "${seen_arranged}" -eq 1 ]; then
        if [ "${seen_specific}" -eq 1 ]; then
            TrapERR "Mixing specific with arranged parameters is not allowed ... Exiting"
        fi

        clear
        printf '\n\n'
        msg_info "WARN: Old 'Arranged' parameters are deprecated"
        msg_base "      New '--flag=value' parameters now preferred"
        msg_base "      Run 'RefindPlusBuilder.sh --help' for details"
        msg_info "      This script will continue after 9 Seconds"
        sleep 9
        printf '\n\n'
    fi
fi

# --- Validate Input ---
# Allow deprecated 'SOME' setting for 'BUILD_TYPE' ... Handle later
BLD_TYP_TMP=$( tr '[:lower:]' '[:upper:]' <<< "${BUILD_TYPE}" )
[[ "${BUILD_BRANCH}" =~ ^[a-zA-Z0-9/_-]+$ ]]            || TrapERR "Invalid Git Build Branch  : Exiting ... CurrentValue='${BUILD_BRANCH}'"
[[ "${BLD_TYP_TMP}"  =~ ^(TWO|REL|DBG|NPT|ALL|SOME)$ ]] || TrapERR "Invalid Build Type Flag   : Exiting ... CurrentValue='${BUILD_TYPE}'"
[[ "${BUILD_ENV}"    =~ ^(0|1)$ ]]                      || TrapERR "Invalid Build Check Flag  : Exiting ... CurrentValue='${BUILD_ENV}'"
[[ "${NO_WRAP}"      =~ ^(0|1)$ ]]                      || TrapERR "Invalid Terminal Wrap Flag: Exiting ... CurrentValue='${NO_WRAP}'"
BUILD_TYPE="${BLD_TYP_TMP}"


# Set things up for build
msg_info "## RefindPlusBuilder - Setting Up ##  :  ${BUILD_BRANCH}"
msg_info '##--------------------------------##'
DSC_FILE="RefindPlusPkg/RefindPlusPkg.dsc"

# Handle deprecated 'SOME' setting
[[ "${BUILD_TYPE}" == 'SOME' ]] && BUILD_TYPE='TWO'
case "${BUILD_TYPE}" in
  "TWO") Set_Flags True  True  False ;;
  "REL") Set_Flags True  False False ;;
  "DBG") Set_Flags False True  False ;;
  "NPT") Set_Flags False False True  ;;
  "ALL") Set_Flags True  True  True  ;;
esac

msg_base 'Check OS Type...'
Kern_OS="$( uname )"
if [[ "${Kern_OS}" == 'Darwin' ]]; then
    OS_NAME="macOS"
elif [[ "${Kern_OS}" == 'Linux' ]]; then
    OS_NAME="Linux"
else
    TrapERR "Unsupported OS: '${Kern_OS}' ... Exiting"
fi
msg_raw "Detected OS:- '${OS_NAME}'"
msg_status '...OK'; printf '\n'

msg_base 'Sync CPU Threads...'
# Set 'JOBS_MAX' value
#  - For Default   : Use 1
#  - For <7 CPUs   : Use All
#  - For 07-12 CPUs: Use Half + 3
#  - For 13-24 CPUs: Use Half + 2
#  - For 25-48 CPUs: Use Half + 1
#  - For 49+ CPUs  : Use Half + 0
JOBS_ALL=$(getconf _NPROCESSORS_ONLN 2>/dev/null)
if [[ ! "${JOBS_ALL}" =~ ^[0-9]+$ ]]; then
    JOBS_ALL=1
    msg_raw "Core Count Retrieval Failure ... Using Default"
fi
if (( JOBS_ALL < 2 )); then
    JOBS_MID=${JOBS_ALL}
else
    JOBS_MID=$(( JOBS_ALL / 2 ))
fi
if (( JOBS_ALL < 7 )); then
    JOBS_MAX=${JOBS_ALL}
elif (( JOBS_ALL < 13 )); then
    JOBS_MAX=$(( JOBS_MID + 3 ))
elif (( JOBS_ALL < 25 )); then
    JOBS_MAX=$(( JOBS_MID + 2 ))
elif (( JOBS_ALL < 49 )); then
    JOBS_MAX=$(( JOBS_MID + 1 ))
else
    JOBS_MAX=${JOBS_MID}
fi
(( JOBS_MAX < 1 )) && JOBS_MAX=1
msg_raw "All CPUs = ${JOBS_ALL}"
msg_raw "Max Jobs = ${JOBS_MAX}"
msg_status '...OK'; printf '\n'

# Check Build Prerequisites ... Force On for Mac OS
[[ "${OS_NAME}" == 'macOS' ]] && BUILD_ENV=1
if (( BUILD_ENV )); then
    msg_base 'Verify Build Environment...'
    MISSING_UTILS=()

    # Cross-Platform Dependency Checks
    for tool in nasm iasl git ; do
        if ! command -v "${tool}" >/dev/null 2>&1; then
            case "${tool}" in
                nasm) MISSING_UTILS+=("nasm (Netwide Assembler)") ;;
                iasl) MISSING_UTILS+=("iasl (ACPI Compiler)")     ;;
                git)  MISSING_UTILS+=("git (Version Control)")    ;;
            esac
        fi
    done

    if [[ "${OS_NAME}" == 'Linux' ]]; then
        # Linux Dependency Checks
        Add_Build_Essential=1
        REQUIRED_UTILS=("clang" "gcc" "make" "curl")
        for util in "${REQUIRED_UTILS[@]}" ; do
            if ! command -v "${util}" >/dev/null 2>&1; then
                if [[ "${util}" == "make" || "${util}" == "gcc" ]]; then
                    if (( Add_Build_Essential )); then
                        Add_Build_Essential=0
                        MISSING_UTILS+=("build-essential")
                    fi
                else
                    MISSING_UTILS+=("${util}")
                fi
            fi
        done

        if command -v gcc >/dev/null 2>&1; then
            for header in uuid/uuid.h openssl/ssl.h zlib.h ffi.h; do
                pkg=""
                case "${header}" in
                    uuid/uuid.h)   pkg="uuid-dev"   ;;
                    openssl/ssl.h) pkg="libssl-dev" ;;
                    zlib.h)        pkg="zlib1g-dev" ;;
                    ffi.h)         pkg="libffi-dev" ;;
                esac
                if ! echo "#include <${header}>" | gcc -E - >/dev/null 2>&1; then
                    MISSING_UTILS+=("${pkg}")
                fi
            done
        fi
    fi

    if (( ${#MISSING_UTILS[@]} )); then
        # Dependency Check Failure Notice
        msg_error "Invalid Build Environment"

        IFS=$'\n' UNIQUE_MISSING=($(printf "%s\n" "${MISSING_UTILS[@]}" | sort -u))
        unset IFS

        if (( ${#UNIQUE_MISSING[@]} > 1 )); then
            msg_raw "The following items are missing:"
        else
            msg_raw "The following item is missing:"
        fi

        for item in "${UNIQUE_MISSING[@]}"; do
            msg_raw "  - ${item}"
        done

        BASE_LIST=$(printf "%s " "${UNIQUE_MISSING[@]}" | sed 's/([^)]*)//g' | xargs)
        if [[ "${OS_NAME}" == 'macOS' ]]; then
            INSTALL_LIST=$(echo " ${BASE_LIST} " | sed 's/ iasl / acpica /g' | xargs)
            msg_info "Suggested fix: brew install ${INSTALL_LIST}"
            msg_info "Alternate fix: sudo port install ${INSTALL_LIST}"
            msg_info "             : Requires 'HomeBrew' or 'MacPorts'"
            msg_info "             : Do NOT use 'sudo' with HomeBrew"
        else
            if ! command -v apt &> /dev/null; then
                msg_info "Suggested fix: Rerun RefindPlusBuilder and set '--build-env=0' to skip Debian Linux specific checks"
                msg_info "               Use your package manager to install missing items if identified in a build failure"
            else
                INSTALL_LIST=$(echo " ${BASE_LIST} " | sed 's/ iasl / acpica-tools /g' | xargs)
                msg_info "Suggested fix: sudo apt update && sudo apt install -y ${INSTALL_LIST}"
            fi
        fi

        TrapERR "Build Environment Check Failure ... Exiting"
    fi
    msg_status '...OK'; printf '\n'
fi

# Confirm git branch name validity
# 'HEAD' is an accepted reserved word
CHECKOUT_FLAG=$( tr '[:lower:]' '[:upper:]' <<< "${BUILD_BRANCH}" )
if [[ "${CHECKOUT_FLAG}" != 'HEAD' ]]; then
    # 'git check-ref-format' can be run outside a git repo folder
    if ! git check-ref-format --branch "${BUILD_BRANCH}" >/dev/null 2>&1; then
        TrapERR "Invalid Script Parameter: '${BUILD_BRANCH}' is not a valid git branch name ... Exiting"
    fi
fi

DOCS_DIR="${HOME}/Documents"
if [[ "${OS_NAME}" == 'macOS' ]]; then
    TOOLCHAIN="XCODE5"
else
    TOOLCHAIN="CLANG38"
    if command -v xdg-user-dir >/dev/null 2>&1; then
        DOCS_DIR="$( xdg-user-dir DOCUMENTS )"
    fi

    export CC=clang
    export CXX=clang++
    export CLANG38_BIN=/usr/bin
fi

BASE_DIR="${DOCS_DIR}/RefindPlus"
[[ -d "$BASE_DIR" ]] || TrapERR "Could Not Locate '${BASE_DIR}' ... Exiting"

WORK_DIR="${BASE_DIR}/Working"
[[ -d "${WORK_DIR}" ]] || TrapERR "Could Not Locate '${WORK_DIR}' ... Exiting"
if [[ "${CHECKOUT_FLAG}" == 'HEAD' ]]; then
    # Get actual branch name if available
    ENTERED_WORK_DIR=1
    pushd "${WORK_DIR}" > /dev/null || {
        ENTERED_WORK_DIR=0
    }
    if (( ENTERED_WORK_DIR )); then
        if [[ -d ".git" ]]; then
            # 'git rev-parse' must be run within a git repo folder
            current_branch="$( git rev-parse --abbrev-ref HEAD )"
            if [[ -n "${current_branch}" ]]; then
                BUILD_BRANCH="${current_branch}"
            fi
        fi
        popd > /dev/null || true
    fi
fi

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

if [[ -d "${PLUS_DIR}/Main" ]]; then
    MAIN_DIR="${PLUS_DIR}/Main"
else
    MAIN_DIR="${PLUS_DIR}/BootMaster"
fi
MAINFILE_MAIN="${MAIN_DIR}/main.c"
MAINFILE_KEPT="${MAIN_DIR}/main-kept.c"

SYNCFILE_MAIN="${PLUS_DIR}/gptsync/gptsync.c"
SYNCFILE_KEPT="${PLUS_DIR}/gptsync/gptsync-kept.c"
EXTEND_TWEAKS="${HELP_DIR}/ExtendTweaks.txt"


####
## Clear Potential Leftover Legacy Items ... Remove Later - START ##
rm -fr "${EDK2_DIR}/RefindPkg"
rm -fr "${EDK2_DIR}/.Build-TMP"
rm -f  "${EDK2_DIR}/000-BuildScript/RepoUpdateSHA.txt"
## Clear Potential Leftover Legacy Items ... Remove Later - END ##
####


ErrMsg="Could Not Find '${BASETOOLS_DIR}' ... Exiting"
pushd "${BASETOOLS_DIR}" > /dev/null || TrapERR "${ErrMsg}"

BASETOOLS_SHA_FILE="${HELP_DIR}/BaseToolsSHA.txt"
if [[ ! -f "${BASETOOLS_SHA_FILE}" ]]; then
    BASETOOLS_SHA_OLD='Default'
else
    # shellcheck disable=SC1090
    source "${BASETOOLS_SHA_FILE}" || BASETOOLS_SHA_OLD='Default'
fi

OUR_SHASUM='NO-OP'
if [[ "${OS_NAME}" == 'macOS' ]]; then
    command -v shasum >/dev/null && OUR_SHASUM="shasum"
else
    for tool in shasum sha1sum md5sum ; do
        if command -v "${tool}" >/dev/null; then
            OUR_SHASUM="${tool}"
            break
        fi
    done
fi

if [[ "${OUR_SHASUM}" == 'NO-OP' ]]; then
    BUILD_TOOLS=1
else
    Get_Sha_Str="$( find "${BASETOOLS_DIR}" "${CONF_DIR}" \
      -type f \( -name '*.c' -or -name '*.cpp' -or -name '*.h' -or -name '*.py' -or \
      -name '*.txt' -or -name '*.template' -or -name '*.makefile' -or -name 'GNUmakefile' \) \
      -print0 | sort -z | xargs -0 ${OUR_SHASUM} | ${OUR_SHASUM} | awk '{print $1}' )"

    if [[ "${OS_NAME}" == 'macOS' ]]; then
        Get_OS_Ver="$( sysctl kern.osrelease | cut -d ':' -f 2 | xargs )"
    else
        Get_Distro="$( grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"' )"
        Get_Kernel="$( uname -r | cut -d '-' -f 1 )"
        Get_OS_Ver="${Get_Distro}_${Get_Kernel}"
    fi
    Get_OS_ARCH="$( uname -m )"

    BUILD_TOOLS=0
    if [[ -z "${Get_Sha_Str}" || -z "${Get_OS_Ver}" || -z "${Get_OS_ARCH}" ]]; then
        OUR_SHASUM='NO-OP'
        BUILD_TOOLS=1
    else
        BASETOOLS_SHA_NEW="${Get_Sha_Str}:${Get_OS_Ver}:${Get_OS_ARCH}"
        if [[ ! -d "${BASESOURCE_DIR}/bin" ]] || [[ "${BASETOOLS_SHA_NEW}" != "${BASETOOLS_SHA_OLD}" ]]; then
            BUILD_TOOLS=1
        fi
    fi
fi
popd > /dev/null || true

msg_base 'Export Temp "PATH"...'
if [[ "${OS_NAME}" == 'macOS' ]]; then
    export PATH="/usr/bin:/opt/local/bin:/opt/local/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:${PATH}"
fi
export PATH="${TMP_BIN}:${PATH}"
msg_status '...OK'; printf '\n'

# Python 2 is a hard requirement for RefindPlusUDK
# Assume it is missing, verify, and provide if so
NO_PYTHON=1

if python2 --version 2>&1 | grep -q "Python 2"; then
    ALT_PYTHON="$(command -v python2)"
    if [[ -n "${ALT_PYTHON}" ]]; then
        msg_base 'Check Python 2...'
        msg_raw "Use Command:- 'python2'"

        ln -sf "${ALT_PYTHON}" "${TMP_BIN}/python"
        ln -sf "${ALT_PYTHON}" "${TMP_BIN}/python2"

        # Found Python 2 ... Continue
        NO_PYTHON=0
        msg_status '...OK'; printf '\n'
    fi
fi
if (( NO_PYTHON )); then
    if python --version 2>&1 | grep -q "Python 2"; then
        ALT_PYTHON="$(command -v python)"
        if [[ -n "${ALT_PYTHON}" ]]; then
            msg_base 'Locate Python 2...'
            msg_raw "Use Command:- 'python'"

            ln -sf "${ALT_PYTHON}" "${TMP_BIN}/python"
            ln -sf "${ALT_PYTHON}" "${TMP_BIN}/python2"

            # Found Python 2 ... Continue
            NO_PYTHON=0
            msg_status '...OK'; printf '\n'
        fi
    fi
fi
if (( NO_PYTHON )); then
    msg_info "Python 2 Instance Not Found"
    if [[ "${OS_NAME}" == 'macOS' ]]; then
        TrapERR "Unable to proceed without Python 2 ... Exiting"
    else
        # Try bundled AppImage
        PYTHON2_APPIMAGE="${BLOB_DIR}/Python2_x86_64.AppImage"
        if [[ ! -f "${PYTHON2_APPIMAGE}" ]]; then
            TrapERR "Python 2 is NOT available ... Exiting"
        else
            msg_base 'Attempt Bundled AppImage...'
            rm -f "${TMP_BIN}/python"
            rm -f "${TMP_BIN}/python2"

            chmod +x "${PYTHON2_APPIMAGE}"

            ABS_APPIMAGE=$(Get_Abs_Path "${PYTHON2_APPIMAGE}")
            if [[ -z "${ABS_APPIMAGE}" ]]; then
                # Should not be possible given earlier check
                TrapERR "Invalid AppImage Path ... Exiting"
            fi

            ln -sf "${ABS_APPIMAGE}" "${TMP_BIN}/python"
            ln -sf "${ABS_APPIMAGE}" "${TMP_BIN}/python2"

            export PATH="${TMP_BIN}:${ORIG_PATH}"

            if ! python2 --version 2>&1 | grep -q "Python 2"; then
                if ! python --version 2>&1 | grep -q "Python 2"; then
                    # Unable to proceed ... Python 2 still unavailable
                    TrapERR "Invalid AppImage ... Exiting"
                fi
            fi
            msg_status '...OK'; printf '\n'
        fi
    fi
fi

if [[ ! -L "${PLUS_DIR}" ]]; then
    msg_base 'Update RefindPlusPkg...'
    rm -fr "${PLUS_DIR}"
    ln -sf "${WORK_DIR}" "${PLUS_DIR}"
    msg_status '...OK'; printf '\n'
fi

if [[ "${CHECKOUT_FLAG}" != 'HEAD' ]]; then
    # Use 'cd' for symlink ... 'pushd/popd' fails
    CUR_PATH="${PWD}"
    ErrMsg="Could Not Find '${PLUS_DIR}' ... Exiting"
    cd "${PLUS_DIR}" || TrapERR "${ErrMsg}"
    if [[ ! -d ".git" ]]; then
        TrapERR "Not Valid Git Folder: '${PLUS_DIR}' ... Exiting"
    else
        # 'git checkout' must be run within a git repo folder
        msg_base "Checkout '${BUILD_BRANCH}' branch..."
        git checkout "${BUILD_BRANCH}" || {
            TrapERR "'${BUILD_BRANCH}' Git Branch Not Available Under '${PLUS_DIR}' ... Exiting"
        }
        msg_status '...OK'; echo ''
    fi
    cd "${CUR_PATH}" || true
fi

# Enter EDK2 Dir - START #
ErrMsg="Could Not Access '${EDK2_DIR}' ... Exiting"
pushd "${EDK2_DIR}" > /dev/null || TrapERR "${ErrMsg}"

# Recreate 'Build' Dir
# UDK is RefindPlus Specific
# Not Meant for Other Builds
msg_base 'Reset Build Dirs...'
rm -fr   "${OUTPUT_DIR}"
rm -fr   "${EDK2_DIR}/Build"
mkdir -p "${EDK2_DIR}/Build"
mkdir -p "${OUTPUT_DIR}"
msg_status '...OK'; printf '\n'

if (( NO_WRAP )); then
    if tput rmam >/dev/null 2>&1; then
        # Disable Line Wrap
        msg_base 'Sync Terminal Line Wrapping...'
        tput rmam
        LINEWRAP_FIX=1
        msg_status '...OK'; printf '\n'
    fi
fi


# Reset PATH Hashes
hash -r


if (( BUILD_TOOLS )); then
    ErrMsg="Could Not Access '${BASESOURCE_DIR}' ... Exiting"
    pushd "${BASESOURCE_DIR}" > /dev/null || TrapERR "${ErrMsg}"

    if [[ -f "${CONF_DIR}/BuildEnv.sh" ]]; then
        msg_base 'Nuke Prev BaseTools Env...'
        unset EDK_TOOLS_PATH
        rm -fr "${CONF_DIR}/.cache"
        rm -f  "${CONF_DIR}/BuildEnv.sh"
        msg_status '...OK'; printf '\n'
    fi

    OurArch="$( uname -m )"
    if [[ "${OurArch}" == *"arm"* ]]; then
        if [[ "${OS_NAME}" == 'macOS' ]]; then
            msg_base 'Create Temp BaseTools BaseType for Apple Silicon...'
            if [[ -f "${BASETYPE_KEPT}" ]]; then
                cp -pf "${BASETYPE_KEPT}" "${BASETYPE_MAIN}"
            else
                cp -pf "${BASETYPE_MAIN}" "${BASETYPE_KEPT}"
            fi

            # Apply patch if required
            if grep -q '#include <ProcessorBind.h>' "${BASETYPE_MAIN}"; then
                ErrMsg="Could Not Create 'BASETYPE tmpfile' ... Exiting"
                tmpfile="$( mktemp "${TMP_BIN}"/basetype.XXXXXX )" || TrapERR "${ErrMsg}"
                sed 's|#include <ProcessorBind.h>|#include "../AArch64/ProcessorBind.h"|' \
                    "${BASETYPE_MAIN}" > "${tmpfile}" && mv -f "${tmpfile}" "${BASETYPE_MAIN}" || rm -f "${tmpfile}"
            fi
            msg_status '...OK'; printf '\n'
        fi
    fi

    if [[ "${OS_NAME}" == 'Linux' ]]; then
        PYTHON_COMMAND="$(command -v python2)"
        if [[ -z "${PYTHON_COMMAND}" ]] || ! ${PYTHON_COMMAND} --version 2>&1 | grep -q "2.7"; then
            PYTHON_COMMAND="$(command -v python)"
            if [[ -z "${PYTHON_COMMAND}" ]] || ! ${PYTHON_COMMAND} --version 2>&1 | grep -q "2.7"; then
                TrapERR "Python command is absent or does not point to Python 2.7"
            fi
        fi
    fi

    msg_base 'BaseTools Make Clean...'
    make clean
    msg_status '...OK'; printf '\n'
    popd > /dev/null || true

    msg_base 'BaseTools Make...'
    make -j"${JOBS_MAX}" -C BaseTools/Source/C
    msg_status '...OK'; printf '\n'

    msg_base 'Update BaseTools SHA...'
    if [[ "${OUR_SHASUM}" == 'NO-OP' ]]; then
        rm -f "${BASETOOLS_SHA_FILE}"
    else
        echo '#!/usr/bin/env bash' > "${BASETOOLS_SHA_FILE}"
        echo "BASETOOLS_SHA_OLD='${BASETOOLS_SHA_NEW}'" >> "${BASETOOLS_SHA_FILE}"
    fi
    msg_status '...OK'; printf '\n'

    if [[ "${OurArch}" == *"arm"* ]]; then
        if [[ -f "${BASETYPE_KEPT}" ]]; then
            msg_base 'Restore BaseType...'
            mv -f "${BASETYPE_KEPT}" "${BASETYPE_MAIN}" || true
            msg_status '...OK'; printf '\n'
        fi
    fi
fi
popd > /dev/null || true
# Enter EDK2 Dir - END #

# Basic clean up
printf '\n'
msg_info "## RefindPlusBuilder - Misc Checks ##  :  ${BUILD_BRANCH}"
msg_info '##---------------------------------##'
if [[ -f "${MAINFILE_MAIN}" ]]; then
    if ! grep -q '__REFIT_SBAT_' "${MAINFILE_MAIN}"; then
        msg_base "Skip 'SBAT' Tweaks..."
        # Not found ... Continue
        msg_status '...OK'; printf '\n'
    else
        if [[ "${OS_NAME}" != 'macOS' ]]; then
            msg_base 'Skip MTOC Sync...'
            # Not Mac OS ... Continue
            msg_status '...OK'; printf '\n'
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
            if (( BLOB_OCMTOC )); then
                msg_raw "Target MTOC:- 'Bundled'"
            else
                msg_raw "Target MTOC:- 'System'"
            fi
            msg_status '...OK'; printf '\n'

            msg_base "Prep 'Tools_Def' file..."
            # Locate and Prep 'Tools_Def'
            # Fix any previous leftovers
            # Must be after 'BLOB_OCMTOC' is set
            if [[ -f "${TOOLSDEF_KEPT}" ]]; then
                if (( BLOB_OCMTOC )); then
                    cp -pf "${TOOLSDEF_KEPT}" "${TOOLSDEF_MAIN}"
                else
                    mv -f "${TOOLSDEF_KEPT}" "${TOOLSDEF_MAIN}"
                fi
            elif [[ -f "${TOOLSDEF_MAIN}" ]]; then
                if (( BLOB_OCMTOC )); then
                    cp -pf "${TOOLSDEF_MAIN}" "${TOOLSDEF_KEPT}"
                fi
            else
                # Unable to proceed ... 'Tools_Def' not found
                TrapERR "Could Not Locate 'Tools_Def' file ... Exiting"
            fi
            msg_status '...OK'; printf '\n'

            msg_status '...............01'; printf '\n'
            if (( BLOB_OCMTOC )); then
                msg_status '...............01A'; printf '\n'
                if grep -Eq '^\*_XCODE5_\*_MTOC_PATH[[:space:]]*=[[:space:]]*mtoc' "${TOOLSDEF_MAIN}"; then
                    # Path to bundled ocmtoc ... File name is 'mtoc'
                    BUNDLED_OCMTOC="${BLOB_DIR}/mtoc"

                    if [[ ! -f "${BUNDLED_OCMTOC}" ]]; then
                        TrapERR 'Could Not Locate Bundled MTOC ... Exiting'
                    else
                        msg_base 'Prep Bundled MTOC...'
                        # Remove quarantine attribute if present
                        if command -v xattr >/dev/null 2>&1; then
                            if xattr -p  com.apple.quarantine "${BUNDLED_OCMTOC}" >/dev/null 2>&1; then
                                xattr -d com.apple.quarantine "${BUNDLED_OCMTOC}"
                            fi
                        fi

                        chmod +x "${BUNDLED_OCMTOC}"
                        if ! "${BUNDLED_OCMTOC}" --fullversion 2>/dev/null | grep -qi 'Acidanthera ocmtoc'; then
                            TrapERR "Invalid Bundled MTOC ... Exiting"
                        fi
                        msg_status '...OK'; printf '\n'

                        msg_base 'Create Temp Tools_Def...'
                        ErrMsg="Could Not Create 'TOOLSDEF tmpfile' ... Exiting"
                        tmpfile="$( mktemp "${TMP_BIN}"/toolsdef.XXXXXX )" || TrapERR "${ErrMsg}"
                        sed -E "s|^\*_XCODE5_\*_MTOC_PATH[[:space:]]*=.*|*_XCODE5_*_MTOC_PATH = ${BUNDLED_OCMTOC}|" \
                            "${TOOLSDEF_MAIN}" > "${tmpfile}" && mv -f "${tmpfile}" "${TOOLSDEF_MAIN}" || rm -f "${tmpfile}"
                        msg_status '...OK'; printf '\n'
                    fi
                fi
            fi
        fi

        msg_status '...............02'; printf '\n'
        if [[ -f "${EXTEND_TWEAKS}" ]]; then
            msg_status '...............02A'; printf '\n'
            if ! source "${EXTEND_TWEAKS}"; then
                TrapERR "Could Not Source:- '${EXTEND_TWEAKS}'"
            else
                msg_base 'Handle SBAT Tweak...'
                if ! declare -f tweak_sbat >/dev/null; then
                    TrapERR "Not Declared:- 'tweak_sbat'"
                else
                    if [[ -f "${MAINFILE_KEPT}" ]]; then
                        cp -pf "${MAINFILE_KEPT}" "${MAINFILE_MAIN}"
                    else
                        cp -pf "${MAINFILE_MAIN}" "${MAINFILE_KEPT}"
                    fi

                    if [[ -f "${SYNCFILE_KEPT}" ]]; then
                        cp -pf "${SYNCFILE_KEPT}" "${SYNCFILE_MAIN}"
                    else
                        cp -pf "${SYNCFILE_MAIN}" "${SYNCFILE_KEPT}"
                    fi
                    tweak_sbat "${MAINFILE_MAIN}" "refindplus" || TrapERR "SBAT Tweak Failed:- 'Main'"
                    tweak_sbat "${SYNCFILE_MAIN}" "gptsync"    || TrapERR "SBAT Tweak Failed:- 'Sync'"
                fi
                msg_status '...OK'; printf '\n'

                msg_base 'Handle MAIN Tweak...'
                if ! declare -f tweak_main >/dev/null; then
                    TrapERR "Not Declared:- 'tweak_main'"
                else
                    tweak_main "${MAINFILE_MAIN}"
                fi
                msg_status '...OK'; printf '\n'
            fi
        fi
    fi
fi

msg_status '...............03'; printf '\n'
# Execute Version Build
ErrMsg="Could Not Find '${EDK2_DIR}' ... Exiting"
pushd "${EDK2_DIR}" > /dev/null || TrapERR "${ErrMsg}"
[[ "${RUN_REL}" == 'True' ]] && Exec_Build "REL" "RELEASE" "${BINARY_DIR_REL}" || true
[[ "${RUN_DBG}" == 'True' ]] && Exec_Build "DBG" "DEBUG"   "${BINARY_DIR_DBG}" || true
[[ "${RUN_NPT}" == 'True' ]] && Exec_Build "NPT" "NOOPT"   "${BINARY_DIR_NPT}" || true
popd > /dev/null || true
printf '\n\n'

if [[ -z "${END_NOTICE}" ]]; then
    # Tidy up
    msg_info 'Locate the EFI Files:'
    [[ -d "${EDK2_DIR}/Build" ]] && msg_status "RefindPlus EFI Files (BOOTx64)      : '${OUTPUT_DIR}'"
    [[ "${RUN_NPT}" == 'True' ]] && msg_status "RefindPlus EFI Files (Others - NPT) : '${BUILD_DIR_NPT}/X64'"
    [[ "${RUN_DBG}" == 'True' ]] && msg_status "RefindPlus EFI Files (Others - DBG) : '${BUILD_DIR_DBG}/X64'"
    [[ "${RUN_REL}" == 'True' ]] && msg_status "RefindPlus EFI Files (Others - REL) : '${BUILD_DIR_REL}/X64'"
    printf '\n\n'

    # Wrap Up Notice
    msg_base "Recommended Action on File Names"
    msg_raw "Output files have the form: '[METADATA]---[FILENAME].efi'."
    msg_raw "It is anticipated the metadata will be removed before use."
fi

msg_status '...............04'; printf '\n'
printf '\n\n'
