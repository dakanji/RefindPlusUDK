#!/usr/bin/env bash
###
# The RefindPlus Build Script
# Copyright 2020-2026 Dayo Akanji
# sf.net/u/dakanji/profile
# MIT-0 License
###

# --- Provide Custom Colours ---
COLOR_NORM=''
COLOR_BUST=''
COLOR_FLAG=''
COLOR_INFO=''
COLOR_WARN=''
COLOR_NOTE=''
if test -t 1 ; then
    NCOLORS=$( tput colors 2>/dev/null || true )
    [[ -n "${NCOLORS}" ]] || NCOLORS=0
    if (( NCOLORS >= 8 )) ; then
        COLOR_NORM='\033[0m'
        COLOR_BUST='\033[0;31m'
        COLOR_FLAG='\033[0;32m'
        COLOR_INFO='\033[0;33m'
        COLOR_WARN='\033[0;35m'
        COLOR_NOTE='\033[0;36m'
    fi
fi
msg_base() { # No Colour
    printf "%s\n" "${1}" >&2
} # msg_base()
msg_bust() { # RED: Error
    printf "%b%s%b\n" "${COLOR_BUST}" "${1}" "${COLOR_NORM}" >&2
} # msg_bust()
msg_flag(){ # GREEN: Status
    printf "%b%s%b\n" "${COLOR_FLAG}" "${1}" "${COLOR_NORM}" >&2
} # msg_flag()
msg_info() { # YELLOW: Information
    printf "%b%s%b\n" "${COLOR_INFO}" "${1}" "${COLOR_NORM}" >&2
} # msg_info()
msg_warn() { # MAGENTA: Warning
    printf "%b%s%b\n" "${COLOR_WARN}" "${1}" "${COLOR_NORM}" >&2
} # msg_warn()
msg_note() { # CYAN: Notice
    printf "%b%s%b\n" "${COLOR_NOTE}" "${1}" "${COLOR_NORM}" >&2
} # msg_note()

## REVERT MISC CHANGES ##
#  - Always triggered on exit
#  - This includes crashes
#
# shellcheck disable=SC2329
trapOUT() {
    # Restore PATH
    export PATH="${ORIG_PATH}" ; hash -r

    # Clear Build/Compiler Variables
    unset CC CXX CLANG38_BIN 2>/dev/null || true

    # Reset Misc ... *DO NOT* Quote 'RP_TMP_DIR' Below
    if \
    [[ -n "${TMP_BIN}" ]] && \
    [[ -d "${TMP_BIN}" ]] && \
    [[ "${TMP_BIN}" == ${RP_TMP_DIR}.* ]] ; then
        rm -rf -- "${TMP_BIN}"
    fi

    # Restore Misc Amended Files
    [[ -f "${BASETYPE_KEPT}" ]] && mv -f "${BASETYPE_KEPT}" "${BASETYPE_MAIN}"
    [[ -f "${TOOLSDEF_KEPT}" ]] && mv -f "${TOOLSDEF_KEPT}" "${TOOLSDEF_MAIN}"
    [[ -f "${MAINFILE_KEPT}" ]] && mv -f "${MAINFILE_KEPT}" "${MAINFILE_MAIN}"
    [[ -f "${SYNCFILE_KEPT}" ]] && mv -f "${SYNCFILE_KEPT}" "${SYNCFILE_MAIN}"

    # Restore Line Wrap
    if (( LINEWRAP_FIX )) ; then
        if tput smam >/dev/null 2>&1 ; then
            # Enable Line Wrap
            LINEWRAP_FIX=0
            tput smam
        fi
    fi
} # trapOUT()

## ERROR HANDLERS ##
#
# shellcheck disable=SC2329
trapINT() { # $1: message
    # Declare Local Variables
    local errMessage

    # Show Error and Exit
    errMessage="${1:-Force Quit ... Exiting}"
    printf '\n\n'
    msg_bust "${errMessage}"
    printf '\n\n'
    exit 1
} # trapINT()

# shellcheck disable=SC2329
trapERR() { # $1: message
    # Declare Local Variables
    local errMessage

    # Show Error and Exit
    errMessage="${1:-Runtime Error ... Exiting}"
    printf '\n\n'
    msg_bust "${errMessage}"
    printf '\n\n'
    exit 1
} # trapERR()

## HELPER FOR RUN FLAGS ##
set_flags() {
    RUN_REL="${1}"
    RUN_DBG="${2}"
    RUN_NPT="${3}"
} # set_flags()

get_abs_path() {
    local target="${1}"
    local base_dir
    local file_name

    if [[ -d "${target}" ]] ; then
        printf "%s\n" "$(cd "${target}" && pwd)"
    elif [[ -f "${target}" ]] ; then
        base_dir=$( cd "$(dirname "${target}")" && pwd )
        file_name=$( basename "${target}" )
        printf "%s/%s\n" "${base_dir}" "${file_name}"
    else
        return 1
    fi
} # get_abs_path()

exec_build() {
    local tag_type="${1}"
    local edk_build="${2}"

    # Add Spacer if at Least One Version Built Before
    if (( PRIOR_BUILD )) ; then
        msg_info "Preparing ${tag_type} Build..."
        printf '\n'
    fi

    printf '\n'
    msg_note "## RefindPlusBuilder - Building ${tag_type} Version ##  :  ${BUILD_BRANCH}"
    msg_note '##------------------------------------------##'
    if ! source edksetup.sh BaseTools ; then
        trapERR "Failed to source 'edksetup.sh' for '${tag_type}' Build ... Exiting"
    fi
    if ! build -n "${JOBS_MAX}" -a X64 -b "${edk_build}" -t "${TOOLCHAIN}" -p "${DSC_FILE}" ; then
        trapERR "Failed to Build '${tag_type}' Version ... Exiting"
    fi
} # exec_build()

process_binaries() {
    local tag_type="${1}"
    local bin_folder="${2}"
    local meta_tag
    local our_tag
    local file

    # Handle Files Produced
    # Only if Files Exist
    shopt -s nullglob
    for file in "${bin_folder}"/*.efi ; do
        our_tag=$( basename "${file%.efi}" )
        if [[ "${our_tag}" == "RefindPlus" ]] ; then
            meta_tag='APP_xx_000'
            cp -pf "${file}" "${OUTPUT_DIR}/BOOTx64-${tag_type}.efi" || true
            mv -f  "${file}" "${bin_folder}/${meta_tag}---x64_${our_tag}_${tag_type}.efi" || true
        elif [[ "${our_tag}" == "gptsync" ]] ; then
            meta_tag="APP_xx_${tag_type}"
            mv -f "${file}" "${bin_folder}/${meta_tag}---x64_${our_tag}.efi" || true
        else
            meta_tag="DRV_xx_${tag_type}"
            mv -f "${file}" "${bin_folder}/${meta_tag}---x64_${our_tag}.efi" || true
        fi
    done
    shopt -u nullglob
} # process_binaries()

copy_blobs() {
    local tag_type="${1}"
    local bin_folder="${2}"
    local meta_tag="BLB_xx_${tag_type}"
    local blob_file
    local blob_bin

    # Add Binary Blobs
    for blob_bin in shell memtest86p gdisk CleanNvram ipxe ; do
      blob_file="x64_${blob_bin}.efi"
      if [[ -f "${BLOB_DIR}/${blob_file}" ]] ; then
          cp -pf "${BLOB_DIR}/${blob_file}" "${bin_folder}/${meta_tag}---${blob_file}" || true
      fi
    done
} # copy_blobs()

copy_licenses() {
    local bin_folder="${1}"
    local meta_tag='000_xx_000'
    local lic_name
    local lic_orig
    local lic_file
    local lic_boot

    # Add License Data
    for lic_name in INFO LICENSE ; do
        lic_orig="${PLUS_DIR}/${lic_name}.txt"
        lic_file="${meta_tag}---${lic_name}.txt"
        lic_boot="${OUTPUT_DIR}/${lic_name}.txt"

        if [[ -f "${lic_orig}" ]] ; then
            cp -pf "${lic_orig}" "${bin_folder}/${lic_file}" || true

            if [[ ! -f "${lic_boot}" ]] ; then
                cp -pf "${lic_orig}" "${lic_boot}" || true
            fi
        fi
    done
} # copy_licenses()

dispatcher() { # $1=SUFFIX (REL/DBG/NPT), $2=EDK BUILD TYPE (RELEASE/DEBUG/NOOPT), $3=BINARY_DIR
    local tag_type="${1}"
    local edk_build="${2}"
    local bin_folder="${3}"

    exec_build "${tag_type}" "${edk_build}" ;
    process_binaries "${tag_type}" "${bin_folder}" ;
    copy_blobs "${tag_type}" "${bin_folder}" ;
    copy_licenses "${bin_folder}" ;

    printf '\n'
    msg_note "Completed '${tag_type}' Build on the RefindPlus '${BUILD_BRANCH}' Branch"
    PRIOR_BUILD=1
} # dispatcher()



##########################
# Procedural Code Starts #
##########################

# Set Event Traps
trap trapERR ERR ;
trap trapOUT EXIT ;
trap trapINT SIGINT ;

# Set Temp Binary Dir ... Ensure No Spaces in 'RP_TMP_DIR'
RP_TMP_DIR='/tmp/refindplus_dir'
TMP_BIN="$( mktemp -d ${RP_TMP_DIR}.XXXXXX )"
[[ -d "${TMP_BIN}" ]] || trapERR "Failed to Create 'TMP_BIN' ... Exiting"

# Set Basic Params
PRIOR_BUILD=0
LINEWRAP_FIX=0
ORIG_PATH="${PATH}"
if [[ -z "${IS_REMOTE}" && -z "${END_NOTICE}" ]] ; then
    IS_LOCAL=1
else
    IS_LOCAL=0
fi


# ============================== #
#       Parameter Handling       #
#   '--flag=value' OR arranged   #
# ============================== #

# --- Defaults ---
BUILD_BRANCH="HEAD"
BUILD_TYPE="TWO"
BUILD_ENV=1
NO_WRAP=1

# --- Parse for 'help' Param ---
show_help=0
for arg in "$@" ; do
    case "${arg}" in
        --help|-h)
            show_help=1
        break
        ;;
    esac
done

# Closing 'fi' for 'if show_help' is after 'cat' block
if (( show_help )) ; then
    (( IS_LOCAL )) && clear

cat <<EOF

The RefindPlus Build Script
Copyright Dayo Akanji
MIT-0 License

Usage:
  * Optional Arranged Parameters (Deprecated):
    RefindPlusBuilder.sh [ build-branch ] [ build-type ] [ build-env ] [ no-wrap ]

  * Optional Specific Parameters:
    RefindPlusBuilder.sh [ --build-branch=ABC ]
                         [ --build-type=XYZ ]
                         [ --build-env=0|1 ]
                         [ --no-wrap=0|1 ]

Parameter Details:
  * [build-branch]
      Name of Local Git Branch to Build.
      Default: "HEAD" (Checked Out Branch)
               - Default works without git.

  * [build-type]
      Build Type(s) to Generate:
        TWO  - REL and DBG Builds (Default)
        REL  - REL Build Only
        DBG  - DBG Build Only
        NPT  - NPT Build Only
        ALL  - All Build Types

  * [build-env]
      Linux Build Environment Checks:
        1  - Verify Debian Linux Build Environment (Default)
        0  - Do Not Verify Linux Build Environment

  * [no-wrap]
      Line Wrapping in Terminal:
        1  - Line Wrapping is Disabled (Default)
        0  - Line Wrapping is Preserved

Rules:
  * Use EITHER Arranged OR Specific Parameters (Not Both)
  * Use The '--flag=value' Syntax For Specific Parameters

EOF

    exit 0
fi


# --- Parse Other Params ---
seen_specific=0
seen_arranged=0
pos_index=0

for arg in "$@" ; do
    pos_index=$(( pos_index + 1 ))
    case "${arg}" in
        --build-branch=*)
            seen_specific=1
            BUILD_BRANCH=${arg#*=}
            [[ -n "${BUILD_BRANCH}" ]] || trapERR "'--build-branch' requires a value ... Exiting"
        ;;
        --build-type=*)
            seen_specific=1
            BUILD_TYPE=${arg#*=}
            [[ -n "${BUILD_TYPE}" ]] || trapERR "'--build-type' requires a value ... Exiting"
        ;;
        --build-env=*)
            seen_specific=1
            BUILD_ENV=${arg#*=}
            [[ -n "${BUILD_ENV}" ]] || trapERR "'--build-env' requires a value ... Exiting"
        ;;
        --no-wrap=*)
            seen_specific=1
            NO_WRAP=${arg#*=}
            [[ -n "${NO_WRAP}" ]] || trapERR "'--no-wrap' requires a value ... Exiting"
        ;;

        # Catch Misc Malformed Parameters
        --build-branch|--build-type|--build-env|--no-wrap)
            trapERR "Parameter '${arg}' is missing the '=' sign (use --flag=value) ... Exiting"
        ;;
        --*)
            trapERR "Unknown Parameter: '${arg}' ... Exiting"
        ;;
        --*=)
            trapERR "Parameter '${arg}' requires a value ... Exiting"
        ;;
        -*)
            trapERR "Invalid Parameter: '${arg}' (use --flag=value) ... Exiting"
        ;;
        *)
            seen_arranged=1
            [ "${pos_index}" -gt 4 ] && trapERR "Too Many Parameters Specified ... Exiting"
            case "${pos_index}" in
                1) BUILD_BRANCH="${arg}" ;;
                2) BUILD_TYPE="${arg}"   ;;
                3) BUILD_ENV="${arg}"    ;;
                4) NO_WRAP="${arg}"      ;;
            esac
        ;;
    esac
done

if [ "${seen_arranged}" -eq 1 ] ; then
    if [ "${seen_specific}" -eq 1 ] ; then
        # --- Reject Mixed Param Types ---
        trapERR "Mixed Specific/Arranged Parameters NOT Allowed ... Exiting"
    fi

    if (( IS_LOCAL )) ; then
        clear
        printf '\n\n'
        msg_warn "WARN: Old 'Arranged' parameters are deprecated"
        msg_info "      New '--flag=value' parameters now preferred"
        msg_info "      Run 'RefindPlusBuilder.sh --help' for details"
        printf '\n'

        read -p "Continue with Arranged Parameters? [y/N]: " \
        -n 1 -r response < /dev/tty || true

        printf '\n'
        [[ "${response}" =~ ^[Yy]$ ]] || {
            printf '\n'
            msg_flag 'Exiting RefindPlus Build'
            printf '\n\n'
            exit 0
        }
        printf '\n\n'
    fi
fi

# --- Validate Input ---
# Preserve Remote Line Wrap
(( IS_LOCAL )) || NO_WRAP=0

# Handles Deprecated 'SOME' Setting For 'BUILD_TYPE'
BLD_TYP_TMP=$( tr '[:lower:]' '[:upper:]' <<< "${BUILD_TYPE}" )
[[ "${BUILD_BRANCH}" =~ ^[A-Za-z0-9._/-]+$ ]]           || trapERR "Invalid Build Branch   : Exiting ... CurrentValue='${BUILD_BRANCH}'"
[[ "${BLD_TYP_TMP}"  =~ ^(TWO|REL|DBG|NPT|ALL|SOME)$ ]] || trapERR "Invalid Build Typ Flag : Exiting ... CurrentValue='${BUILD_TYPE}'"
[[ "${BUILD_ENV}"    =~ ^(0|1)$ ]]                      || trapERR "Invalid Build Env Flag : Exiting ... CurrentValue='${BUILD_ENV}'"
[[ "${NO_WRAP}"      =~ ^(0|1)$ ]]                      || trapERR "Invalid Line Wrap Flag : Exiting ... CurrentValue='${NO_WRAP}'"
[[ "${BLD_TYP_TMP}"  == 'SOME' ]]   && BUILD_TYPE='TWO' || BUILD_TYPE="${BLD_TYP_TMP}"

# Set Things Up For Build
printf '\n\n'
msg_note "## RefindPlusBuilder - Setting Up ##  :  ${BUILD_BRANCH}"
msg_note '##--------------------------------##'
DSC_FILE="RefindPlusPkg/RefindPlusPkg.dsc"

# Set Final Build Type
case "${BUILD_TYPE}" in
  "TWO") set_flags True  True  False ;;
  "REL") set_flags True  False False ;;
  "DBG") set_flags False True  False ;;
  "NPT") set_flags False False True  ;;
  "ALL") set_flags True  True  True  ;;
esac

msg_info 'Check OS Type...'
Kern_OS="$( uname )"
if [[ "${Kern_OS}" == 'Darwin' ]] ; then
    OS_NAME="macOS"
elif [[ "${Kern_OS}" == 'Linux' ]] ; then
    OS_NAME="Linux"
else
    trapERR "Unsupported OS: '${Kern_OS}' ... Exiting"
fi
msg_base "Detected OS:- '${OS_NAME}'"
msg_flag '...OK' ; printf '\n'

msg_info 'Sync CPU Threads...'
CPUS_ALL=$(
  sysctl -n hw.ncpu 2>/dev/null \
  || nproc 2>/dev/null \
  || getconf _NPROCESSORS_ONLN 2>/dev/null \
  || echo 'Core Count Failed'
)
if [[ ! "${CPUS_ALL}" =~ ^[0-9]+$ ]] ; then
    CPUS_ALL=1
    msg_warn "Core Count Retrieval Failure ... Using Default"
fi

# Set 'JOBS_MAX' Value
#  - For Default   : Use 1
#  - For <7 CPUs   : Use All
#  - For 07-12 CPUs: Use Half + 3
#  - For 13-24 CPUs: Use Half + 2
#  - For 25-48 CPUs: Use Half + 1
#  - For 49+ CPUs  : Use Half + 0
if (( CPUS_ALL < 2 )) ; then
    CPUS_MID=${CPUS_ALL}
else
    CPUS_MID=$(( CPUS_ALL / 2 ))
fi
if (( CPUS_ALL < 7 )) ; then
    JOBS_MAX=${CPUS_ALL}
elif (( CPUS_ALL < 13 )) ; then
    JOBS_MAX=$(( CPUS_MID + 3 ))
elif (( CPUS_ALL < 25 )) ; then
    JOBS_MAX=$(( CPUS_MID + 2 ))
elif (( CPUS_ALL < 49 )) ; then
    JOBS_MAX=$(( CPUS_MID + 1 ))
else
    JOBS_MAX=${CPUS_MID}
fi
(( JOBS_MAX < 1 )) && JOBS_MAX=1 || true

msg_base "All CPUs = ${CPUS_ALL}"
msg_base "Max Jobs = ${JOBS_MAX}"
msg_flag '...OK' ; printf '\n'

# Check Build Prerequisites ... Force On for Mac OS
[[ "${OS_NAME}" == 'macOS' ]] && BUILD_ENV=1
if (( BUILD_ENV )) ; then
    msg_info 'Verify Build Environment...'
    MISSING_UTILS=()

    # Cross-Platform Dependency Checks
    for tool in nasm iasl git ; do
        if ! command -v "${tool}" >/dev/null 2>&1 ; then
            case "${tool}" in
                nasm) MISSING_UTILS+=("nasm (Netwide Assembler)") ;;
                iasl) MISSING_UTILS+=("iasl (ACPI Compiler)")     ;;
                git)  MISSING_UTILS+=("git (Version Control)")    ;;
            esac
        fi
    done

    Kit_Missing=0
    if [[ "${OS_NAME}" == 'Linux' ]] ; then
        # Linux Dependency Checks
        Add_Build_Essential=1
        REQUIRED_UTILS=("clang" "gcc" "make" "curl")
        for util in "${REQUIRED_UTILS[@]}" ; do
            if ! command -v "${util}" >/dev/null 2>&1 ; then
                if [[ "${util}" == "make" || "${util}" == "gcc" ]] ; then
                    if (( Add_Build_Essential )) ; then
                        Add_Build_Essential=0
                        MISSING_UTILS+=("build-essential")
                    fi
                else
                    MISSING_UTILS+=("${util}")
                fi
            fi
        done

        if command -v clang >/dev/null 2>&1 ; then
            OUR_CC='clang'
        else
            OUR_CC='gcc'
        fi
        if ! command -v "${OUR_CC}" >/dev/null 2>&1 ; then
            Kit_Missing=1
        else
            for header in uuid/uuid.h openssl/ssl.h zlib.h ffi.h ; do
                pkg=""
                case "${header}" in
                    uuid/uuid.h)   pkg="uuid-dev"   ;;
                    openssl/ssl.h) pkg="libssl-dev" ;;
                    zlib.h)        pkg="zlib1g-dev" ;;
                    ffi.h)         pkg="libffi-dev" ;;
                esac
                if ! "${OUR_CC}" -E - <<< "#include <${header}>" >/dev/null 2>&1 ; then
                    MISSING_UTILS+=("${pkg}")
                fi
            done
        fi
    fi

    if (( ${#MISSING_UTILS[@]} )) ; then
        # Dependency Check Failure Notice
        msg_warn "Invalid Build Environment"

        IFS=$'\n' UNIQUE_MISSING=($(printf "%s\n" "${MISSING_UTILS[@]}" | sort -u))
        unset IFS

        if (( ${#UNIQUE_MISSING[@]} > 1 )) ; then
            plural_type='are'
            plural_item='items'
        else
            plural_item='item'
            plural_type='is'
        fi
        msg_warn "The following ${plural_item} ${plural_type} missing:"

        for item in "${UNIQUE_MISSING[@]}" ; do
            msg_base "  - ${item}"
        done

        BASE_LIST=$( printf "%s " "${UNIQUE_MISSING[@]}" | sed 's/([^)]*)//g' | xargs )
        if [[ "${OS_NAME}" == 'macOS' ]] ; then
            INSTALL_LIST=$( echo " ${BASE_LIST} " | sed 's/ iasl / acpica /g' | xargs )
            msg_info "Suggested fix: brew install ${INSTALL_LIST}"
            msg_info "Alternate fix: sudo port install ${INSTALL_LIST}"
            msg_info "             : Requires 'HomeBrew' or 'MacPorts'"
        elif command -v apt >/dev/null 2>&1 ; then
            INSTALL_LIST=$( echo " ${BASE_LIST} " | sed 's/ iasl / acpica-tools /g' | xargs )
            msg_info "Suggested fix: sudo apt update && sudo apt install -y ${INSTALL_LIST}"
        else
            msg_info "Suggested fix: Rerun RefindPlusBuilder and set '--build-env=0' to skip Debian Linux specific checks."
            msg_info "               Use your package manager to install missing items identified in build failure notices."
        fi

        if (( Kit_Missing )) ; then
            # Some item detection requires clang/gcc
            printf '\n'
            msg_note "More missing items may be revealed on rerun after installing the listed ${plural_item}"
        fi

        trapERR "Build Environment Check Failure ... Exiting"
    fi
    msg_flag '...OK' ; printf '\n'
fi

# Confirm Git Branch Name Validity
# 'HEAD' is an accepted reserved word
CHECKOUT_FLAG=$( tr '[:lower:]' '[:upper:]' <<< "${BUILD_BRANCH}" )
if [[ "${CHECKOUT_FLAG}" != 'HEAD' ]] ; then
    # 'git check-ref-format' Can Run Outside a Git Folder
    if ! git check-ref-format --branch "${BUILD_BRANCH}" >/dev/null 2>&1 ; then
        trapERR "Invalid Script Parameter: '${BUILD_BRANCH}' is not a valid git branch name ... Exiting"
    fi
fi

DOCS_DIR="${HOME}/Documents"
if [[ "${OS_NAME}" == 'Linux' ]] ; then
    if command -v xdg-user-dir >/dev/null 2>&1 ; then
        chk_dir="$( xdg-user-dir DOCUMENTS )"
        if [[ -n "${chk_dir}" ]] ; then
            DOCS_DIR="${chk_dir}"
        fi
    fi
fi
[[ -d "$DOCS_DIR" ]] || trapERR "Could Not Locate '${DOCS_DIR}' ... Exiting"

BASE_DIR="${DOCS_DIR}/RefindPlus"
[[ -d "$BASE_DIR" ]] || trapERR "Could Not Locate '${BASE_DIR}' ... Exiting"

WORK_DIR="${BASE_DIR}/Working"
[[ -d "${WORK_DIR}" ]] || trapERR "Could Not Locate '${WORK_DIR}' ... Exiting"

EDK2_DIR="${BASE_DIR}/edk2"
[[ -d "${EDK2_DIR}" ]] || trapERR "Could Not Locate '${EDK2_DIR}' ... Exiting"

HELP_DIR="${EDK2_DIR}/.BuildHelp"
mkdir -p "${HELP_DIR}"
EXTEND_TWEAKS="${HELP_DIR}/ExtendTweaks.txt"

PLUS_DIR="${EDK2_DIR}/RefindPlusPkg"
if [[ ! -L "${PLUS_DIR}" ]] || [[ ! -e "${PLUS_DIR}" ]] ; then
    [[ -n "${PLUS_DIR}" && -d "${PLUS_DIR}" ]] && rm -rf -- "${PLUS_DIR}"
    ln -sf "${WORK_DIR}" "${PLUS_DIR}"
fi

OUTPUT_DIR="${EDK2_DIR}/000-BOOTx64-Files"

CONF_DIR="${EDK2_DIR}/Conf"
BLOB_DIR="${CONF_DIR}/Blobs"
BASETOOLS_DIR="${EDK2_DIR}/BaseTools"
BASESOURCE_DIR="${BASETOOLS_DIR}/Source/C"

if [[ "${OS_NAME}" == 'macOS' ]] ; then
    TOOLCHAIN="XCODE5"
else
    TOOLCHAIN="CLANG38"

    export CC=clang
    export CXX=clang++
    CLANG_PATH="$(command -v clang || true)"
    if [[ -n "${CLANG_PATH}" ]] ; then
        export CLANG38_BIN="$(dirname "${CLANG_PATH}")"
    fi
fi
BUILD_DIR_REL="${EDK2_DIR}/Build/RefindPlus/RELEASE_${TOOLCHAIN}"
BUILD_DIR_DBG="${EDK2_DIR}/Build/RefindPlus/DEBUG_${TOOLCHAIN}"
BUILD_DIR_NPT="${EDK2_DIR}/Build/RefindPlus/NOOPT_${TOOLCHAIN}"
BINARY_DIR_REL="${BUILD_DIR_REL}/X64"
BINARY_DIR_DBG="${BUILD_DIR_DBG}/X64"
BINARY_DIR_NPT="${BUILD_DIR_NPT}/X64"

# Handle Misc Core Folder Renaming
if [[ -d "${PLUS_DIR}/Main" ]] ; then
    MAIN_DIR="${PLUS_DIR}/Main"
elif [[ -d "${PLUS_DIR}/BootMaster" ]] ; then
    MAIN_DIR="${PLUS_DIR}/BootMaster"
elif [[ -d "${PLUS_DIR}/MainLoader" ]] ; then
    MAIN_DIR="${PLUS_DIR}/MainLoader"
elif [[ -d "${PLUS_DIR}/MainRP" ]] ; then
    MAIN_DIR="${PLUS_DIR}/MainRP"
elif [[ -d "${PLUS_DIR}/refind" ]] ; then
    MAIN_DIR="${PLUS_DIR}/refind"
else
    trapERR "Could Not Locate Core Files ... Exiting"
fi
[[ -d "${MAIN_DIR}" ]] || trapERR "Could Not Locate '${MAIN_DIR}' ... Exiting"

MAINFILE_MAIN="${MAIN_DIR}/main.c"
MAINFILE_KEPT="${MAIN_DIR}/main-kept.c"
if [[ ! -f "${MAINFILE_MAIN}" ]] ; then
    trapERR "Could Not Locate Main File ... Exiting"
fi

TOOLSDEF_MAIN="${CONF_DIR}/tools_def.txt"
TOOLSDEF_KEPT="${CONF_DIR}/tools_def-kept.txt"
SYNCFILE_MAIN="${PLUS_DIR}/gptsync/gptsync.c"
SYNCFILE_KEPT="${PLUS_DIR}/gptsync/gptsync-kept.c"
BASETYPE_MAIN="${BASESOURCE_DIR}/Include/Common/BaseTypes.h"
BASETYPE_KEPT="${BASESOURCE_DIR}/Include/Common/BaseTypes-kept.h"

if [[ "${CHECKOUT_FLAG}" == 'HEAD' ]] ; then
    # Get Actual Branch Name If Available
    ENTERED_WORK_DIR=1
    pushd "${WORK_DIR}" > /dev/null || {
        ENTERED_WORK_DIR=0
    }
    if (( ENTERED_WORK_DIR )) ; then
        if [[ -d ".git" ]] ; then
            # 'git rev-parse' Must Be Within a Git Folder
            current_branch="$( git rev-parse --abbrev-ref HEAD )"
            if [[ -n "${current_branch}" ]] ; then
                BUILD_BRANCH="${current_branch}"
            fi
        fi
        popd > /dev/null || true
    fi
fi


####
## Clear Potential Leftover Legacy Items ... Remove Later - START ##
rm -fr "${EDK2_DIR}/RefindPkg"
rm -fr "${EDK2_DIR}/.Build-TMP"
rm -f  "${EDK2_DIR}/000-BuildScript/RepoUpdateSHA.txt"
## Clear Potential Leftover Legacy Items ... Remove Later - CLOSE ##
####


# Sync BaseTools
ErrMsg="Could Not Find '${BASETOOLS_DIR}' ... Exiting"
pushd "${BASETOOLS_DIR}" > /dev/null || trapERR "${ErrMsg}"

BASETOOLS_SHA_FILE="${HELP_DIR}/BaseToolsSHA.txt"
if [[ ! -f "${BASETOOLS_SHA_FILE}" ]] ; then
    BASETOOLS_SHA_OLD='Default'
else
    # shellcheck disable=SC1090
    source "${BASETOOLS_SHA_FILE}" || BASETOOLS_SHA_OLD='Default'
fi

OUR_SHASUM='NO-OP'
if [[ "${OS_NAME}" == 'macOS' ]] ; then
    command -v shasum >/dev/null && OUR_SHASUM="shasum"
else
    for tool in shasum sha1sum md5sum ; do
        if command -v "${tool}" >/dev/null ; then
            OUR_SHASUM="${tool}"
            break
        fi
    done
fi

if [[ "${OUR_SHASUM}" == 'NO-OP' ]] ; then
    BUILD_TOOLS=1
else
    Get_Sha_Str="$( find "${BASETOOLS_DIR}" "${CONF_DIR}" \
      -type f \( -name '*.c' -or -name '*.cpp' -or -name '*.h' -or -name '*.py' -or \
      -name '*.txt' -or -name '*.template' -or -name '*.makefile' -or -name 'GNUmakefile' \) \
      -print0 | sort -z | xargs -0 ${OUR_SHASUM} | ${OUR_SHASUM} | awk '{print $1}' || true)"

    if [[ "${OS_NAME}" == 'macOS' ]] ; then
        Get_OS_Ver="$( sysctl kern.osrelease | cut -d ':' -f 2 | xargs )" || true
    else
        Get_Distro="$( grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"' )" || true
        Get_Kernel="$( uname -r | cut -d '-' -f 1 )" || true
        Get_OS_Ver="${Get_Distro}_${Get_Kernel}"
    fi
    Get_OS_ARCH="$( uname -m )"

    BUILD_TOOLS=0
    if [[ -z "${Get_Sha_Str}" || -z "${Get_OS_Ver}" || -z "${Get_OS_ARCH}" ]] ; then
        OUR_SHASUM='NO-OP'
        BUILD_TOOLS=1
    else
        BASETOOLS_SHA_NEW="${Get_Sha_Str}:${Get_OS_Ver}:${Get_OS_ARCH}"
        if [[ ! -d "${BASESOURCE_DIR}/bin" ]] || [[ "${BASETOOLS_SHA_NEW}" != "${BASETOOLS_SHA_OLD}" ]] ; then
            BUILD_TOOLS=1
        fi
    fi
fi
popd > /dev/null || true

msg_info 'Export Temp "PATH"...'
[[ "${OS_NAME}" != 'macOS' ]] && ADD_PATH=''
[[ "${OS_NAME}" == 'macOS' ]] && ADD_PATH=':/usr/bin:/opt/local/bin:/opt/local/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin'
export PATH="${TMP_BIN}${ADD_PATH}:${ORIG_PATH}" ; hash -r
msg_flag '...OK' ; printf '\n'

# Python 2 is a Hard Requirement for RefindPlusUDK
# Assume Missing, Verify, then Provide if Required
NO_PYTHON=1

if python2 --version 2>&1 | grep -q "Python 2" ; then
    ALT_PYTHON="$(command -v python2 || true)"
    if [[ -n "${ALT_PYTHON}" ]] ; then
        msg_info 'Check Python 2...'
        msg_base "Use Command:- 'python2'"

        ln -sf "${ALT_PYTHON}" "${TMP_BIN}/python"
        ln -sf "${ALT_PYTHON}" "${TMP_BIN}/python2"

        # Found Python 2 ... Continue
        NO_PYTHON=0
        msg_flag '...OK' ; printf '\n'
    fi
fi
if (( NO_PYTHON )) ; then
    if python --version 2>&1 | grep -q "Python 2" ; then
        ALT_PYTHON="$(command -v python || true)"
        if [[ -n "${ALT_PYTHON}" ]] ; then
            msg_info 'Locate Python 2...'
            msg_base "Use Command:- 'python'"

            ln -sf "${ALT_PYTHON}" "${TMP_BIN}/python"
            ln -sf "${ALT_PYTHON}" "${TMP_BIN}/python2"

            # Found Python 2 ... Continue
            NO_PYTHON=0
            msg_flag '...OK' ; printf '\n'
        fi
    fi
fi
if (( NO_PYTHON )) ; then
    msg_info "Python 2 Instance Not Found"
    if [[ "${OS_NAME}" == 'macOS' ]] ; then
        trapERR "Unable to proceed without Python 2 ... Exiting"
    else
        # Try Bundled AppImage for Linux
        PYTHON2_APPIMAGE="${BLOB_DIR}/Python2_x86_64.AppImage"
        if [[ ! -f "${PYTHON2_APPIMAGE}" ]] ; then
            trapERR "Python 2 is NOT available ... Exiting"
        else
            msg_info 'Attempt Bundled AppImage...'
            rm -f "${TMP_BIN}/python"
            rm -f "${TMP_BIN}/python2"

            ABS_APPIMAGE=$( get_abs_path "${PYTHON2_APPIMAGE}" )
            if [[ -z "${ABS_APPIMAGE}" ]] ; then
                # Should Not Be Possible Given Earlier Check
                trapERR "Invalid AppImage Path ... Exiting"
            fi

            chmod a+x "${PYTHON2_APPIMAGE}"
            if "${PYTHON2_APPIMAGE}" --version >/dev/null 2>&1 ; then
                msg_flag 'Unit appears set up for AppImages ... Proceeding'
                ln -sf "${PYTHON2_APPIMAGE}" "${TMP_BIN}/python"
                ln -sf "${PYTHON2_APPIMAGE}" "${TMP_BIN}/python2"
            else
                if (( IS_LOCAL )) ; then
                    printf '\n'
                    msg_note 'NOTE TO USER: Consider installing Python 2 or libfuse2'
                    msg_info '              Installing Python 2 allows build support:- Native'
                    msg_info '              Installing libfuse2 allows build support:- AppImages'
                    msg_info '              This script will try to work around current limitations'
                    msg_info '              Python will run slower than with Native/AppImage support'
                    msg_info '              Native Python 2 support, when possible, is typically best'
                    printf '\n'

                    read -p "Continue with Workaround? [Y/n]: " \
                    -n 1 -r response < /dev/tty || true

                    printf '\n'
                    [[ "${response}" =~ ^[Nn]$ ]] && {
                        printf '\n'
                        msg_warn 'Aborted RefindPlus Build'
                        printf '\n\n'
                        exit 0
                    } || true
                fi


####
## Create AppImage Wrapper - START ##
msg_note 'Unit not set up for AppImages ... Create Wrapper'
APPIMAGE_WRAPPER="${TMP_BIN}/python2_appimage_wrapper"
cat > "${APPIMAGE_WRAPPER}" <<'EOF'
#!/usr/bin/env bash
set -e
exec "_x_APPIMAGE_x_" --appimage-extract-and-run "$@"
EOF
sed -i "s|_x_APPIMAGE_x_|${ABS_APPIMAGE}|" "${APPIMAGE_WRAPPER}"
## Create AppImage Wrapper - CLOSE ##
####


                chmod a+x "${APPIMAGE_WRAPPER}"
                if ! "${APPIMAGE_WRAPPER}" --version >/dev/null 2>&1 ; then
                    trapERR "Failed to Execute AppImage Wrapper ... Exiting"
                fi

                ln -sf "${APPIMAGE_WRAPPER}" "${TMP_BIN}/python"
                ln -sf "${APPIMAGE_WRAPPER}" "${TMP_BIN}/python2"
            fi

            if ! python2 --version 2>&1 | grep -q "Python 2" ; then
                if ! python --version 2>&1 | grep -q "Python 2" ; then
                    # Unable to Proceed ... Python 2 Still Unavailable
                    trapERR "Invalid AppImage or Other Failure ... Exiting"
                fi
            fi
            msg_flag '...OK' ; printf '\n'
        fi
    fi
fi

if [[ "${CHECKOUT_FLAG}" != 'HEAD' ]] ; then
    # Use 'cd' for Symlink ... 'pushd/popd' Fails
    CUR_PATH="${PWD}"
    ErrMsg="Could Not Find '${PLUS_DIR}' ... Exiting"
    cd "${PLUS_DIR}" || trapERR "${ErrMsg}"

    # 'git checkout' Must be Run Within a Git Folder
    if [[ ! -d ".git" ]] ; then
        trapERR "Invalid Git Folder: '${PLUS_DIR}' ... Exiting"
    else
        msg_info "Checkout '${BUILD_BRANCH}' branch..."
        git checkout "${BUILD_BRANCH}" || {
            trapERR "'${BUILD_BRANCH}' Git Branch Not Found Under '${PLUS_DIR}' ... Exiting"
        }
        msg_flag '...OK' ; printf '\n'
    fi
    cd "${CUR_PATH}" || true
fi

# Enter EDK2 Dir - START #
ErrMsg="Could Not Access '${EDK2_DIR}' ... Exiting"
pushd "${EDK2_DIR}" > /dev/null || trapERR "${ErrMsg}"

# Recreate 'Build' Dir
# UDK is RefindPlus Specific
# Not Meant for Other Builds
msg_info 'Reset Build Dirs...'
rm -fr   "${OUTPUT_DIR}"
rm -fr   "${EDK2_DIR}/Build"
mkdir -p "${EDK2_DIR}/Build"
mkdir -p "${OUTPUT_DIR}"
msg_flag '...OK' ; printf '\n'

if (( NO_WRAP )) ; then
    if tput rmam >/dev/null 2>&1 ; then
        # Disable Line Wrap
        msg_info 'Sync Line Wrapping...'
        tput rmam
        LINEWRAP_FIX=1
        msg_flag '...OK' ; printf '\n'
    fi
fi

if (( BUILD_TOOLS )) ; then
    ErrMsg="Could Not Access '${BASESOURCE_DIR}' ... Exiting"
    pushd "${BASESOURCE_DIR}" > /dev/null || trapERR "${ErrMsg}"

    if [[ -f "${CONF_DIR}/BuildEnv.sh" ]] ; then
        msg_info 'Nuke Prev BaseTools Env...'
        [[ -z "${EDK_TOOLS_PATH}" ]] || unset EDK_TOOLS_PATH
        rm -fr "${CONF_DIR}/.cache"
        rm -f  "${CONF_DIR}/BuildEnv.sh"
        msg_flag '...OK' ; printf '\n'
    fi

    OurArch="$( uname -m )"
    if [[ "${OurArch}" == *"arm"* ]] ; then
        if [[ "${OS_NAME}" == 'macOS' ]] ; then
            msg_info 'Temp BaseTools BaseType for Apple Silicon...'
            if [[ -f "${BASETYPE_KEPT}" ]] ; then
                cp -pf "${BASETYPE_KEPT}" "${BASETYPE_MAIN}"
            elif [[ -f "${BASETYPE_MAIN}" ]] ; then
                cp -pf "${BASETYPE_MAIN}" "${BASETYPE_KEPT}"
            else
                trapERR "Could *NOT* Find Required File:- '${BASETYPE_MAIN}'"
            fi

            # Apply Patch if Required
            if grep -q '#include <ProcessorBind.h>' "${BASETYPE_MAIN}" ; then
                ErrMsg="Could Not Create 'BASETYPE tmpfile' ... Exiting"
                tmpfile="$( mktemp "${TMP_BIN}"/basetype.XXXXXX )" || trapERR "${ErrMsg}"
                sed 's|#include <ProcessorBind.h>|#include "../AArch64/ProcessorBind.h"|' \
                    "${BASETYPE_MAIN}" > "${tmpfile}" && mv -f "${tmpfile}" "${BASETYPE_MAIN}" || rm -f "${tmpfile}"
            fi
            msg_flag '...OK' ; printf '\n'
        fi
    fi

    if [[ "${OS_NAME}" == 'Linux' ]] ; then
        PYTHON_COMMAND="$(command -v python2 || true)"
        if [[ -z "${PYTHON_COMMAND}" ]] || ! ${PYTHON_COMMAND} --version 2>&1 | grep -q "2.7" ; then
            PYTHON_COMMAND="$(command -v python || true)"
            if [[ -z "${PYTHON_COMMAND}" ]] || ! ${PYTHON_COMMAND} --version 2>&1 | grep -q "2.7" ; then
                trapERR "Python command is absent or does not point to Python 2.7 ... Exiting"
            fi
        fi
    fi

    msg_info 'BaseTools Make Clean...'
    make clean
    msg_flag '...OK' ; printf '\n'
    popd > /dev/null || true

    msg_info 'BaseTools Make...'
    make -j"${JOBS_MAX}" -C "BaseTools/Source/C"
    msg_flag '...OK' ; printf '\n'

    msg_info 'Update BaseTools SHA...'
    if [[ "${OUR_SHASUM}" == 'NO-OP' ]] ; then
        rm -f "${BASETOOLS_SHA_FILE}"
    else
        echo '#!/usr/bin/env bash' > "${BASETOOLS_SHA_FILE}"
        echo "BASETOOLS_SHA_OLD='${BASETOOLS_SHA_NEW}'" >> "${BASETOOLS_SHA_FILE}"
    fi
    msg_flag '...OK' ; printf '\n'

    if [[ "${OurArch}" == *"arm"* ]] ; then
        if [[ -f "${BASETYPE_KEPT}" ]] ; then
            msg_info 'Restore BaseType...'
            mv -f "${BASETYPE_KEPT}" "${BASETYPE_MAIN}" || true
            msg_flag '...OK' ; printf '\n'
        fi
    fi
fi
popd > /dev/null || true
# Enter EDK2 Dir - CLOSE #

# Basic clean up
printf '\n'
msg_note "## RefindPlusBuilder - Misc Checks ##  :  ${BUILD_BRANCH}"
msg_note '##---------------------------------##'
if [[ "${OS_NAME}" != 'macOS' ]] ; then
    msg_info 'Skip MTOC Sync...'
    # Not Mac OS ... Continue
    msg_flag '...OK' ; printf '\n'
else
    msg_info 'Sync MTOC Type...'
    # Default to Bundled ocmtoc (v1.0.4+)
    BLOB_OCMTOC=1
    if command -v mtoc >/dev/null 2>&1 ; then
        # mtoc or ocmtoc Found ... Check if ocmtoc 1.0.4/newer
        # - Both variants share the same binary name
        # - ocmtoc >= v1.0.4 accepts '--fullversion'
        if mtoc --fullversion 2>/dev/null | grep -qi 'Acidanthera ocmtoc' ; then
            # ocmtoc >= v1.0.4 Found ... Use System Instance
            BLOB_OCMTOC=0
        fi
    fi
    if (( BLOB_OCMTOC )) ; then
        msg_base "Target MTOC:- 'Bundled'"
    else
        msg_base "Target MTOC:- 'System'"
    fi
    msg_flag '...OK' ; printf '\n'

    msg_info "Prep 'Tools_Def' file..."
    # Locate and Prep 'Tools_Def'
    # Fix any previous leftovers
    # Must be after 'BLOB_OCMTOC' is set
    if [[ -f "${TOOLSDEF_KEPT}" ]] ; then
        if (( BLOB_OCMTOC )) ; then
            cp -pf "${TOOLSDEF_KEPT}" "${TOOLSDEF_MAIN}"
        else
            mv -f  "${TOOLSDEF_KEPT}" "${TOOLSDEF_MAIN}"
        fi
    elif [[ -f "${TOOLSDEF_MAIN}" ]] ; then
        if (( BLOB_OCMTOC )) ; then
            cp -pf "${TOOLSDEF_MAIN}" "${TOOLSDEF_KEPT}"
        fi
    else
        # Unable to Proceed ... 'Tools_Def' Not Found
        trapERR "Could Not Locate 'Tools_Def' file ... Exiting"
    fi
    msg_flag '...OK' ; printf '\n'

    if (( BLOB_OCMTOC )) ; then
        if grep -Eq '^\*_XCODE5_\*_MTOC_PATH[[:space:]]*=[[:space:]]*mtoc' "${TOOLSDEF_MAIN}" ; then
            # Path to Bundled ocmtoc ... File Name is 'mtoc'
            BUNDLED_OCMTOC="${BLOB_DIR}/mtoc"

            if [[ ! -f "${BUNDLED_OCMTOC}" ]] ; then
                trapERR 'Could Not Locate Bundled MTOC ... Exiting'
            else
                msg_info 'Prep Bundled MTOC...'
                # Remove Quarantine Attribute if Present
                if command -v xattr >/dev/null 2>&1 ; then
                    if xattr -p  com.apple.quarantine "${BUNDLED_OCMTOC}" >/dev/null 2>&1 ; then
                        xattr -d com.apple.quarantine "${BUNDLED_OCMTOC}"
                    fi
                fi

                chmod a+x "${BUNDLED_OCMTOC}"
                if ! "${BUNDLED_OCMTOC}" --fullversion 2>/dev/null | grep -qi 'Acidanthera ocmtoc' ; then
                    trapERR "Invalid Bundled MTOC ... Exiting"
                fi
                msg_flag '...OK' ; printf '\n'

                msg_info 'Create Temp Tools_Def...'
                ErrMsg="Could Not Create 'TOOLSDEF tmpfile' ... Exiting"
                tmpfile="$( mktemp "${TMP_BIN}"/toolsdef.XXXXXX )" || trapERR "${ErrMsg}"
                sed -E "s|^\*_XCODE5_\*_MTOC_PATH[[:space:]]*=.*|*_XCODE5_*_MTOC_PATH = ${BUNDLED_OCMTOC}|" \
                    "${TOOLSDEF_MAIN}" > "${tmpfile}" && mv -f "${tmpfile}" "${TOOLSDEF_MAIN}" || rm -f "${tmpfile}"
                msg_flag '...OK' ; printf '\n'
            fi
        fi
    fi
fi

# Misc Developer Specific Items
# Skipped on Third Party Builds
if [[ ! -f "${EXTEND_TWEAKS}" ]] ; then
    msg_info "Misc 'Extend' Tweaks..."
    msg_base "Skipped"
    msg_flag '...OK' ; printf '\n'
else
    if ! source "${EXTEND_TWEAKS}" ; then
        trapERR "Could Not Access '${EXTEND_TWEAKS}' ... Exiting"
    else
        if ! grep -q '__REFIT_SBAT_' "${MAINFILE_MAIN}" ; then
            msg_info "Run 'SBAT' Tweaks..."
            msg_base "Skipped"
            msg_flag '...OK' ; printf '\n'
        else
            msg_info 'Handle SBAT Tweak...'
            if ! declare -f tweak_sbat >/dev/null ; then
                trapERR "'tweak_sbat' Not Declared ... Exiting"
            else
                if [[ -f "${MAINFILE_KEPT}" ]] ; then
                    cp -pf "${MAINFILE_KEPT}" "${MAINFILE_MAIN}"
                elif [[ -f "${MAINFILE_MAIN}" ]] ; then
                    cp -pf "${MAINFILE_MAIN}" "${MAINFILE_KEPT}"
                else
                    trapERR "Could *NOT* Find Required '${MAINFILE_MAIN}' ... Exiting"
                fi

                if [[ -f "${SYNCFILE_KEPT}" ]] ; then
                    cp -pf "${SYNCFILE_KEPT}" "${SYNCFILE_MAIN}"
                elif [[ -f "${SYNCFILE_MAIN}" ]] ; then
                    cp -pf "${SYNCFILE_MAIN}" "${SYNCFILE_KEPT}"
                else
                    trapERR "Could *NOT* Find Required '${SYNCFILE_MAIN}' ... Exiting"
                fi

                tweak_sbat "${MAINFILE_MAIN}" "refindplus" || trapERR "SBAT Tweak on 'Main' Failed ... Exiting"
                tweak_sbat "${SYNCFILE_MAIN}" "gptsync"    || trapERR "SBAT Tweak on 'Sync' Failed ... Exiting"
            fi
            msg_flag '...OK' ; printf '\n'
        fi

        msg_info 'Handle MAIN Tweak...'
        if ! declare -f tweak_main >/dev/null ; then
            trapERR "'tweak_main' Not Declared ... Exiting"
        else
            tweak_main "${MAINFILE_MAIN}"
        fi
        msg_flag '...OK' ; printf '\n'
    fi
fi

# Execute Build
ErrMsg="Could Not Find '${EDK2_DIR}' ... Exiting"
pushd "${EDK2_DIR}" > /dev/null || trapERR "${ErrMsg}"
[[ "${RUN_REL}" == 'True' ]] && dispatcher "REL" "RELEASE" "${BINARY_DIR_REL}"
[[ "${RUN_DBG}" == 'True' ]] && dispatcher "DBG" "DEBUG"   "${BINARY_DIR_DBG}"
[[ "${RUN_NPT}" == 'True' ]] && dispatcher "NPT" "NOOPT"   "${BINARY_DIR_NPT}"
popd > /dev/null || true
printf '\n\n'

if (( IS_LOCAL )) ; then
    # FIle Locations
    msg_info 'Locate the EFI Files:'
    [[ -d "${EDK2_DIR}/Build" ]] && msg_flag "RefindPlus EFI Files (BOOTx64)      : '${OUTPUT_DIR}'"
    [[ "${RUN_NPT}" == 'True' ]] && msg_flag "RefindPlus EFI Files (Others - NPT) : '${BUILD_DIR_NPT}/X64'"
    [[ "${RUN_DBG}" == 'True' ]] && msg_flag "RefindPlus EFI Files (Others - DBG) : '${BUILD_DIR_DBG}/X64'"
    [[ "${RUN_REL}" == 'True' ]] && msg_flag "RefindPlus EFI Files (Others - REL) : '${BUILD_DIR_REL}/X64'"
    printf '\n\n'

    # Filename Metadata
    msg_note "Filename Handling Recommendation"
    msg_info "Output files have the form: '[METADATA]---[FILENAME].efi'."
    msg_info "It is anticipated the metadata will be discarded before use."
    printf '\n\n'

    # Binary Blobs
    msg_note "Binary Blob Clarification"
    msg_info "Output files with 'BLB_xx_???' in their filename metadata ARE NOT part of RefindPlus."
    msg_info "These are binaries bundled with RefindPlusUDK and are provided as convenience items."
    msg_info "These binary blobs ARE NOT built on RefindPlus code and were separately developed."
    msg_info "These binary blobs are separately licensed by their actual respective developers."
    msg_flag "- x64_shell.efi: From OpenCore (OpenShell) ... BSD 3-Clause License."
    msg_flag "- x64_CleanNvram.efi: From OpenCore ... BSD 3-Clause License."
    msg_flag "- x64_memtest86p.efi: From memtest.org ... GNU GPLv2 License."
    msg_flag "- x64_gdisk.efi: From Roderick Smith ... GNU GPLv2 License."
    msg_flag "- x64_ipxe.efi: From ipxe.org ... GNU GPLv2 License."
    printf '\n\n'
fi
