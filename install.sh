#!/usr/bin/env bash

# PSP: Platform Support Package
# (c) 2022 Lanner Electronics Inc. (https://www.lannerinc.com)
# Lanner PSP is an SDK that facilitates communication between you and your Lanner IPC's IO.
#
# Installs and Updates PSP
#
# This file is copyright under the latest version of the EUPL.
# Please see LICENSE file for your rights under this license.

# link.lannerinc.com/psp
#
# Install with this command (from your Linux machine):
#
# curl -sSL https://link.lannerinc.com/psp/install | bash -s <product-type> [version-name]

# -e option instructs bash to immediately exit if any command [1] has a non-zero exit status
# We do not want users to end up with a partially working install, so we exit the script
# instead of continuing the installation with something broken
set -e

# Append common folders to the PATH to ensure that all basic commands are available.
# When using "su" an incomplete PATH could be passed: https://github.com/???
export PATH+=':/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

######## VARIABLES #########
# For better maintainability, we store as much information that can change in variables
# This allows us to make a change in one place that can propagate to all instances of the variable
# These variables should all be GLOBAL variables, written in CAPS
# Local variables will be in lowercase and will exist only within functions
# It's still a work in progress, so you may see some variance in this guideline until it is complete

# Location for final installation log storage
readonly INSTALL_LOG_LOC="/opt/lanner/psp-manager/install.log"
# This is a file used for the colorized output
readonly coltable="/opt/lanner/psp-manager/COL_TABLE"

# We clone (or update) a git repository during the install. This helps to make sure that we always have the latest versions of the relevant files.
# psp-manager contains various setup scripts and files which are critical to the installation.
# Search for "PM_LOCAL_REPO" in this file to see all such scripts.
readonly BASE_URL="https://link.lannerinc.com"
readonly PM_GIT_URL="https://github.com/lanneriotsw/psp-manager.git"
readonly PM_LOCAL_REPO="/opt/lanner/psp-manager"
readonly PSP_INSTALL_DIR="/opt/lanner/psp"
readonly DOWNLOAD_DIR="/opt/lanner/download"

######## Undocumented Flags. Shhh ########
# These are undocumented flags; some of which we can use when repairing an installation
# The runUnattended flag is one example of this
reconfigure=false
runUnattended=false
# Check arguments for the undocumented flags
for var in "$@"; do
    case "$var" in
        "--reconfigure" ) reconfigure=true;;
        "--unattended" ) runUnattended=true;;
    esac
done

# If the color table file exists,
if [[ -f "${coltable}" ]]; then
    # source it
    source "${coltable}"
# Otherwise,
else
    # Set these values so the installer can still run in color
    COL_NC='\e[0m' # No Color
    COL_LIGHT_GREEN='\e[1;32m'
    COL_LIGHT_RED='\e[1;31m'
    TICK="[${COL_LIGHT_GREEN}✓${COL_NC}]"
    CROSS="[${COL_LIGHT_RED}✗${COL_NC}]"
    INFO="[i]"
    # shellcheck disable=SC2034
    DONE="${COL_LIGHT_GREEN} done!${COL_NC}"
    OVER="\\r\\033[K"
fi

# A simple function that just echoes out our logo in ASCII format
show_ascii_logo() {
    echo -e "${COL_LIGHT_GREEN}"
    echo -e '
     _               _   _ _   _ ______ _____
    | |        /\   | \ | | \ | |  ____|  __ \
    | |       /  \  |  \| |  \| | |__  | |__) |
    | |      / /\ \ | . ` | . ` |  __| |  _  /   .__  __..__
    | |____ / ____ \| |\  | |\  | |____| | \ \   [__)(__ [__)
    |______/_/    \_\_| \_|_| \_|______|_|  \_\  |   .__)|
    '
    echo -e "${COL_NC}"
}

is_command() {
    # Checks to see if the given command (passed as a string argument) exists on the system.
    # The function returns 0 (success) if the command exists, and 1 if it doesn't.
    local check_command="$1"

    command -v "${check_command}" >/dev/null 2>&1
}

check_input_param() {
    # Use named, local variables
    local str="Input parameter check"
    printf "  %b %s..." "${INFO}" "${str}"
    # Check number of arguments
    if [[ ("$#" -ge 1) && ("$#" -le 2) ]]; then
        printf "%b  %b %s\\n" "${OVER}" "${TICK}" "${str}"
    else
        printf "%b  %b %s\\n" "${OVER}" "${CROSS}" "${str}"
        printf "  %b Usage:\\n" "${INFO}"
        printf "        curl -sSL ${BASE_URL}/psp/install | bash -s <product-type> [version-name]\\n"
        printf "      Example for specifying the version:\\n"
        printf "        curl -sSL ${BASE_URL}/psp/install | bash -s LEC-7242 2.1.2\\n"
        printf "      Or install the latest version:\\n"
        printf "        curl -sSL ${BASE_URL}/psp/install | bash -s LEC-7242\\n"
        exit 1
    fi
}

check_if_psp_support() {
    # Use named, local variables
    local str="PSP info check"
    local product_type=$(echo "${1}" | xargs)
    local version_name=$(echo "${2}" | xargs)
    # If version name is not given, use 'latest'
    if [[ -z ${2} ]]; then
        version_name="latest"
    fi
    printf "  %b %s..." "${INFO}" "${str}"
    # Make an HTTP HEAD request to check if the specified PSP information exists
    local rc=$(curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" \
        "${BASE_URL}/api/v1/psp/info?model=${product_type}&version=${version_name}")
    # Check the response code
    case "${rc}" in
        "000") # Not connected to server or request timed out
            printf "%b  %b %s\\n" "${OVER}" "${CROSS}" "${str}"
            printf "  %bConnection refused, please check the network status or server status%b\\n" "${COL_LIGHT_RED}" "${COL_NC}"
            exit 1
            ;;
        "200") # OK
            printf "%b  %b %s\\n" "${OVER}" "${TICK}" "${str}"
            ;;
        "404") # Not Found
            printf "%b  %b %s\\n" "${OVER}" "${CROSS}" "${str}"
            printf "  %bPSP info not found, see ${BASE_URL}/psp for support%b\\n" "${COL_LIGHT_RED}" "${COL_NC}"
            exit 1
            ;;
        *) # Other
            printf "%b  %b %s\\n" "${OVER}" "${CROSS}" "${str}"
            printf "  %bError response code: %d. Contact support.%b\\n" "${COL_LIGHT_RED}" "${rc}" "${COL_NC}"
            exit 1
            ;;
    esac
}

# Check that the installed OS is officially supported - display warning if not
check_os() {
    # Use named, local variables
    local str="OS check"
    local os_id=$(awk -F= '/^ID=/{print $2}' /etc/os-release | sed 's/\"//g')
    local os_version_id=$(awk -F= '/^VERSION_ID=/{print $2}' /etc/os-release | sed 's/\"//g')
    printf "  %b %s..." "${INFO}" "${str}"
    # echo "$(cat /proc/version)"
    # TODO: Check OS support on cloud

    case "${os_id}" in
        "debian")
            printf "%b  %b %s\\n" "${OVER}" "${TICK}" "${str}"
            ;;
        "ubuntu")
            printf "%b  %b %s\\n" "${OVER}" "${TICK}" "${str}"
            ;;
        "centos")
            printf "%b  %b %s\\n" "${OVER}" "${TICK}" "${str}"
            ;;
        "fedora")
            printf "%b  %b %s\\n" "${OVER}" "${CROSS}" "${str}"
            printf "  %b %bOS not implemented%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
            exit
            ;;
        *) # RHEL, FreeBSD, Yocto
            printf "%b  %b %s\\n" "${OVER}" "${CROSS}" "${str}"
            printf "  %b %bOS not support%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
            exit
            ;;
    esac
}

# Compatibility
detect_package_manager() {
    # First check to see if apt-get is installed.
    if is_command apt-get ; then
        # Set some global variables here
        # We don't set them earlier since the installed package manager might be rpm, so these values would be different
        PKG_MANAGER="apt-get"
        # A variable to store the command used to update the package cache
        UPDATE_PKG_CACHE="${PKG_MANAGER} update"
        # The command we will use to actually install packages
        PKG_INSTALL=("${PKG_MANAGER}" -qq --no-install-recommends install)
        # grep -c will return 1 if there are no matches. This is an acceptable condition, so we OR TRUE to prevent set -e exiting the script.
        PKG_COUNT="${PKG_MANAGER} -s -o Debug::NoLocking=true upgrade | grep -c ^Inst || true"
        # Update package cache
        update_package_cache || exit 1
        # Packages required to run this install script (stored as an array)
        INSTALLER_DEPS=(git ca-certificates jq)
        # Packages required to run PSP (stored as an array)
        PSP_DEPS=(build-essential linux-headers-$(uname -r) curl sudo tar)

        # This function waits for dpkg to unlock, which signals that the previous apt-get command has finished.
        test_dpkg_lock() {
            i=0
            # fuser is a program to show which processes use the named files, sockets, or filesystems
            # So while the lock is held,
            while fuser /var/lib/dpkg/lock >/dev/null 2>&1
            do
                # we wait half a second,
                sleep 0.5
                # increase the iterator,
                ((i=i+1))
            done
            # and then report success once dpkg is unlocked.
            return 0
        }

    # If apt-get is not found, check for rpm.
    elif is_command rpm ; then
        # Then check if dnf or yum is the package manager
        if is_command dnf ; then
            PKG_MANAGER="dnf"
        else
            PKG_MANAGER="yum"
        fi

        # These variable names match the ones for apt-get. See above for an explanation of what they are for.
        PKG_INSTALL=("${PKG_MANAGER}" install -y)
        PKG_COUNT="${PKG_MANAGER} check-update | egrep '(.i686|.x86|.noarch|.arm|.src)' | wc -l"
        OS_CHECK_DEPS=(grep bind-utils)
        INSTALLER_DEPS=(git ca-certificates jq)
        PSP_DEPS=(make automake gcc gcc-c++ kernel-devel kernel-headers curl sudo tar)

    # If neither apt-get or yum/dnf package managers were found
    else
        # we cannot install required packages
        printf "  %b No supported package manager found\\n" "${CROSS}"
        # so exit the installer
        exit
    fi
}

update_package_cache() {
    # Update package cache on apt based OSes. Do this every time since
    # it's quick and packages can be updated at any time.

    # Local, named variables
    local str="Update local cache of available packages"
    printf "  %b %s..." "${INFO}" "${str}"
    # Create a command from the package cache variable
    if eval "${UPDATE_PKG_CACHE}" &> /dev/null; then
        printf "%b  %b %s\\n" "${OVER}" "${TICK}" "${str}"
    else
        # Otherwise, show an error and exit

        # In case we used apt-get and apt is also available, we use this as recommendation as we have seen it
        # gives more user-friendly (interactive) advice
        if [[ ${PKG_MANAGER} == "apt-get" ]] && is_command apt ; then
            UPDATE_PKG_CACHE="apt update"
        fi
        printf "%b  %b %s\\n" "${OVER}" "${CROSS}" "${str}"
        printf "  %bError: Unable to update package cache. Please try \"%s\"%b\\n" "${COL_LIGHT_RED}" "sudo ${UPDATE_PKG_CACHE}" "${COL_NC}"
        return 1
    fi
}

install_dependent_packages() {

    # Install packages passed in via argument array
    # No spinner - conflicts with set -e
    declare -a installArray

    # Debian based package install - debconf will download the entire package list
    # so we just create an array of packages not currently installed to cut down on the
    # amount of download traffic.
    # NOTE: We may be able to use this installArray in the future to create a list of package that were
    # installed by us, and remove only the installed packages, and not the entire list.
    if is_command apt-get ; then
        # For each package, check if it's already installed (and if so, don't add it to the installArray)
        for i in "$@"; do
            printf "  %b Checking for %s..." "${INFO}" "${i}"
            if dpkg-query -W -f='${Status}' "${i}" 2>/dev/null | grep "ok installed" &> /dev/null; then
                printf "%b  %b Checking for %s\\n" "${OVER}" "${TICK}" "${i}"
            else
                printf "%b  %b Checking for %s (will be installed)\\n" "${OVER}" "${INFO}" "${i}"
                installArray+=("${i}")
            fi
        done
        # If there's anything to install, install everything in the list.
        if [[ "${#installArray[@]}" -gt 0 ]]; then
            test_dpkg_lock
            # Running apt-get install with minimal output can cause some issues with
            # requiring user input (e.g password for phpmyadmin see #218)
            printf "  %b Processing %s install(s) for: %s, please wait...\\n" "${INFO}" "${PKG_MANAGER}" "${installArray[*]}"
            printf '%*s\n' "$columns" '' | tr " " -;
            "${PKG_INSTALL[@]}" "${installArray[@]}"
            printf '%*s\n' "$columns" '' | tr " " -;
            return
        fi
        printf "\\n"
        return 0
    fi

    # Install Fedora/CentOS packages
    for i in "$@"; do
        # For each package, check if it's already installed (and if so, don't add it to the installArray)
        printf "  %b Checking for %s..." "${INFO}" "${i}"
        if "${PKG_MANAGER}" -q list installed "${i}" &> /dev/null; then
            printf "%b  %b Checking for %s\\n" "${OVER}" "${TICK}" "${i}"
        else
            printf "%b  %b Checking for %s (will be installed)\\n" "${OVER}" "${INFO}" "${i}"
            installArray+=("${i}")
        fi
    done
    # If there's anything to install, install everything in the list.
    if [[ "${#installArray[@]}" -gt 0 ]]; then
        printf "  %b Processing %s install(s) for: %s, please wait...\\n" "${INFO}" "${PKG_MANAGER}" "${installArray[*]}"
        printf '%*s\n' "$columns" '' | tr " " -;
        "${PKG_INSTALL[@]}" "${installArray[@]}"
        printf '%*s\n' "$columns" '' | tr " " -;
        return
    fi
    printf "\\n"
    return 0
}

# A function for checking if a directory is a git repository
is_repo() {
    # Use a named, local variable instead of the vague $1, which is the first argument passed to this function
    # These local variables should always be lowercase
    local directory="${1}"
    # A variable to store the return code
    local rc
    # If the first argument passed to this function is a directory,
    if [[ -d "${directory}" ]]; then
        # move into the directory
        pushd "${directory}" &> /dev/null || return 1
        # Use git to check if the directory is a repo
        # git -C is not used here to support git versions older than 1.8.4
        git status --short &> /dev/null || rc=$?
    # If the command was not successful,
    else
        # Set a non-zero return code if directory does not exist
        rc=1
    fi
    # Move back into the directory the user started in
    popd &> /dev/null || return 1
    # Return the code; if one is not set, return 0
    return "${rc:-0}"
}

# A function to clone a repo
make_repo() {
    # Set named variables for better readability
    local directory="${1}"
    local remoteRepo="${2}"

    # The message to display when this function is running
    str="Clone ${remoteRepo} into ${directory}"
    # Display the message and use the color table to preface the message with an "info" indicator
    printf "  %b %s..." "${INFO}" "${str}"
    # If the directory exists,
    if [[ -d "${directory}" ]]; then
        # Return with a 1 to exit the installer. We don't want to overwrite what could already be here in case it is not ours
        str="Unable to clone ${remoteRepo} into ${directory} : Directory already exists"
        printf "%b  %b%s\\n" "${OVER}" "${CROSS}" "${str}"
        return 1
    fi
    # Clone the repo and return the return code from this command
    git clone -q --depth 20 "${remoteRepo}" "${directory}" &> /dev/null || return $?
    # Move into the directory that was passed as an argument
    pushd "${directory}" &> /dev/null || return 1
    # Check current branch. If it is master, then reset to the latest available tag.
    # In case extra commits have been added after tagging/release (i.e in case of metadata updates/README.MD tweaks)
    curBranch=$(git rev-parse --abbrev-ref HEAD)
    if [[ "${curBranch}" == "master" ]]; then
        # If we're calling make_repo() then it should always be master, we may not need to check.
        git reset --hard "$(git describe --abbrev=0 --tags)" || return $?
    fi
    # Show a colored message showing it's status
    printf "%b  %b %s\\n" "${OVER}" "${TICK}" "${str}"
    # Data in the repositories is public anyway so we can make it readable by everyone (+r to keep executable permission if already set by git)
    chmod -R a+rX "${directory}"
    # Move back into the original directory
    popd &> /dev/null || return 1
    return 0
}

# We need to make sure the repos are up-to-date so we can effectively install Clean out the directory if it exists for git to clone into
update_repo() {
    # Use named, local variables
    # As you can see, these are the same variable names used in the last function,
    # but since they are local, their scope does not go beyond this function
    # This helps prevent the wrong value from being assigned if you were to set the variable as a GLOBAL one
    local directory="${1}"
    local curBranch

    # A variable to store the message we want to display;
    # Again, it's useful to store these in variables in case we need to reuse or change the message;
    # we only need to make one change here
    local str="Update repo in ${1}"
    # Move into the directory that was passed as an argument
    pushd "${directory}" &> /dev/null || return 1
    # Let the user know what's happening
    printf "  %b %s..." "${INFO}" "${str}"
    # Stash any local commits as they conflict with our working code
    git stash --all --quiet &> /dev/null || true # Okay for stash failure
    git clean --quiet --force -d || true # Okay for already clean directory
    # Pull the latest commits
    git pull --no-rebase --quiet &> /dev/null || return $?
    # Check current branch. If it is master, then reset to the latest available tag.
    # In case extra commits have been added after tagging/release (i.e in case of metadata updates/README.MD tweaks)
    curBranch=$(git rev-parse --abbrev-ref HEAD)
    if [[ "${curBranch}" == "master" ]]; then
        git reset --hard "$(git describe --abbrev=0 --tags)" || return $?
    fi
    # Show a completion message
    printf "%b  %b %s\\n" "${OVER}" "${TICK}" "${str}"
    # Data in the repositories is public anyway so we can make it readable by everyone (+r to keep executable permission if already set by git)
    chmod -R a+rX "${directory}"
    # Move back into the original directory
    popd &> /dev/null || return 1
    return 0
}

# A function that combines the previous git functions to update or clone a repo
getGitFiles() {
    # Setup named variables for the git repos
    # We need the directory
    local directory="${1}"
    # as well as the repo URL
    local remoteRepo="${2}"
    # A local variable containing the message to be displayed
    local str="Checking for existing repository in ${1}"
    # Show the message
    printf "  %b %s..." "${INFO}" "${str}"
    # Check if the directory is a repository
    if is_repo "${directory}"; then
        # Show that we're checking it
        printf "%b  %b %s\\n" "${OVER}" "${TICK}" "${str}"
        # Update the repo, returning an error message on failure
        update_repo "${directory}" || { printf "\\n  %b: Could not update local repository. Contact support.%b\\n" "${COL_LIGHT_RED}" "${COL_NC}"; exit 1; }
    # If it's not a .git repo,
    else
        # Show an error
        printf "%b  %b %s\\n" "${OVER}" "${CROSS}" "${str}"
        # Attempt to make the repository, showing an error on failure
        make_repo "${directory}" "${remoteRepo}" || { printf "\\n  %bError: Could not update local repository. Contact support.%b\\n" "${COL_LIGHT_RED}" "${COL_NC}"; exit 1; }
    fi
    echo ""
    # Success via one of the two branches, as the commands would exit if they failed.
    return 0
}

# Reset a repo to get rid of any local changed
resetRepo() {
    # Use named variables for arguments
    local directory="${1}"
    # Move into the directory
    pushd "${directory}" &> /dev/null || return 1
    # Store the message in a variable
    str="Resetting repository within ${1}..."
    # Show the message
    printf "  %b %s..." "${INFO}" "${str}"
    # Use git to remove the local changes
    git reset --hard &> /dev/null || return $?
    # Data in the repositories is public anyway so we can make it readable by everyone (+r to keep executable permission if already set by git)
    chmod -R a+rX "${directory}"
    # And show the status
    printf "%b  %b %s\\n" "${OVER}" "${TICK}" "${str}"
    # Return to where we came from
    popd &> /dev/null || return 1
    # Function succeeded, as "git reset" would have triggered a return earlier if it failed
    return 0
}

stop_service() {
    # Stop service passed in as argument.
    # Can softfail, as process may not be installed when this is called
    local str="Stopping ${1} service"
    printf "  %b %s..." "${INFO}" "${str}"
    if is_command systemctl ; then
        systemctl stop "${1}" &> /dev/null || true
    else
        service "${1}" stop &> /dev/null || true
    fi
    printf "%b  %b %s...\\n" "${OVER}" "${TICK}" "${str}"
}

# Start/Restart service passed in as argument
restart_service() {
    # Local, named variables
    local str="Restarting ${1} service"
    printf "  %b %s..." "${INFO}" "${str}"
    # If systemctl exists,
    if is_command systemctl ; then
        # use that to restart the service
        systemctl restart "${1}" &> /dev/null
    else
        # Otherwise, fall back to the service command
        service "${1}" restart &> /dev/null
    fi
    printf "%b  %b %s...\\n" "${OVER}" "${TICK}" "${str}"
}

# Enable service so that it will start with next reboot
enable_service() {
    # Local, named variables
    local str="Enabling ${1} service to start on reboot"
    printf "  %b %s..." "${INFO}" "${str}"
    # If systemctl exists,
    if is_command systemctl ; then
        # use that to enable the service
        systemctl enable "${1}" &> /dev/null
    else
        #  Otherwise, use update-rc.d to accomplish this
        update-rc.d "${1}" defaults &> /dev/null
    fi
    printf "%b  %b %s...\\n" "${OVER}" "${TICK}" "${str}"
}

# Disable service so that it will not with next reboot
disable_service() {
    # Local, named variables
    local str="Disabling ${1} service"
    printf "  %b %s..." "${INFO}" "${str}"
    # If systemctl exists,
    if is_command systemctl ; then
        # use that to disable the service
        systemctl disable "${1}" &> /dev/null
    else
        # Otherwise, use update-rc.d to accomplish this
        update-rc.d "${1}" disable &> /dev/null
    fi
    printf "%b  %b %s...\\n" "${OVER}" "${TICK}" "${str}"
}

check_service_active() {
    # If systemctl exists,
    if is_command systemctl ; then
        # use that to check the status of the service
        systemctl is-enabled "${1}" &> /dev/null
    else
        # Otherwise, fall back to service command
        service "${1}" status &> /dev/null
    fi
}

install_psp() {
    # Use named, local variables
    local product_type=$(echo "${1}" | xargs)
    local version_name=$(echo "${2}" | xargs)
    # If version name is not given, use 'latest'
    if [[ -z ${2} ]]; then
        version_name="latest"
    fi
    # Make an HTTP GET request to get the specified PSP information
    local pkg_info=$(curl -s --connect-timeout 10 -X "GET" -H "accept: application/json" \
        "${BASE_URL}/api/v1/psp/info?model=${product_type}&version=${version_name}")
    # Parse the response message
    local pkg_version=$(echo "${pkg_info}" | jq -r '.version')
    local pkg_version_major=$(echo ${pkg_version} | cut -d'.' -f 1)
    local pkg_version_minor=$(echo ${pkg_version} | cut -d'.' -f 2)
    local pkg_version_patch=$(echo ${pkg_version} | cut -d'.' -f 3)
    local pkg_name=$(echo "${pkg_info}" | jq -r '.name')
    local download_url=$(echo "${pkg_info}" | jq -r '.url')
    local extra_packages=( $(echo "${pkg_info}" | jq -c '.ext_packages[]') )

    # Create a download directory
    mkdir -p ${DOWNLOAD_DIR}

    # Download PSP package
    if [ ! -f "${DOWNLOAD_DIR}/${pkg_name}" ]; then
        printf "  %b Download ${pkg_name}\\n" "${INFO}"
        # Check download URL
        if ! curl --output /dev/null --silent --head --fail ${download_url}; then
            printf "  %bCheck download URL failed. Contact support.%b\\n" "${COL_LIGHT_RED}" "${COL_NC}"
            exit 1
        fi
        curl -fL ${download_url} -o ${DOWNLOAD_DIR}/${pkg_name} --progress-bar
    else
        printf "  %b ${pkg_name} already exists in ${DOWNLOAD_DIR}, will not download again\\n" "${INFO}"
    fi

    # Install PSP package
    if [ ! -d ${PSP_INSTALL_DIR} ]; then
        printf "  %b Install ${pkg_name}\\n" "${INFO}"
        mkdir -p ${PSP_INSTALL_DIR}
        tar jxf ${DOWNLOAD_DIR}/${pkg_name} -C ${PSP_INSTALL_DIR}
        # Add replacement Makefile for PSP version 2.1 to fix "liblmbapi.so: undefined symbol" issue
        if [ ${pkg_version_major} = "2" ] && [ ${pkg_version_minor} = "1" ]; then
            cp ${PM_LOCAL_REPO}/Makefile ${PSP_INSTALL_DIR}/sdk/src_sdk/Makefile
        fi
        make -C ${PSP_INSTALL_DIR}
    else
        printf "  %b PSP ${pkg_version} has already been installed in ${PSP_INSTALL_DIR}, will not install again\\n" "${INFO}"
    fi

    # If any extra packages, circular installation
    for ext_pkg in "${extra_packages[@]}"; do
        local ext_pkg_name=$(echo "${ext_pkg}" | jq -r '.name')
        local ext_pkg_url=$(echo "${ext_pkg}" | jq -r '.url')
        case "${ext_pkg_name}" in
            "config-tool-20201229.tar.bz2") # For LEC-7242
                # Download gpio_config_tool
                if [ ! -f "${DOWNLOAD_DIR}/${ext_pkg_name}" ]; then
                    printf "  %b Download ${ext_pkg_name}\\n" "${INFO}"
                    # Check download URL
                    if ! curl --output /dev/null --silent --head --fail ${ext_pkg_url}; then
                        printf "  %bCheck download URL failed. Contact support.%b\\n" "${COL_LIGHT_RED}" "${COL_NC}"
                        exit 1
                    fi
                    curl -L ${ext_pkg_url} -o ${DOWNLOAD_DIR}/${ext_pkg_name} --progress-bar
                else
                    printf "  %b ${ext_pkg_name} already exists in ${DOWNLOAD_DIR}, will not download again\\n" "${INFO}"
                fi
                # Install gpio_config_tool
                if [ ! -d ${PSP_INSTALL_DIR}/tool ]; then
                    printf "  %b Install ${ext_pkg_name}\\n" "${INFO}"
                    tar jxf ${DOWNLOAD_DIR}/${ext_pkg_name} -C ${PSP_INSTALL_DIR}
                    make -C ${PSP_INSTALL_DIR}/tool
                else
                    printf "  %b gpio_config_tool has already been installed in ${PSP_INSTALL_DIR}/tool, will not install again\\n" "${INFO}"
                fi
                ;;
        esac
    done

    # Copy the system service file
    install -T -m 0644 "${PM_LOCAL_REPO}/lanner-psp.service" "/lib/systemd/system/lanner-psp.service"
    # chmod 644 ${PM_LOCAL_REPO}/lanner-psp.service
    # cp ${PM_LOCAL_REPO}/lanner-psp.service /lib/systemd/system/lanner-psp.service
}

clone_or_update_repos() {
    # If the user wants to reconfigure,
    if [[ "${reconfigure}" == true ]]; then
        printf "  %b Performing reconfiguration, skipping download of local repos\\n" "${INFO}"
        # Reset the Core repo
        resetRepo ${PM_LOCAL_REPO} || \
        { printf "  %bUnable to reset %s, exiting installer%b\\n" "${COL_LIGHT_RED}" "${PM_LOCAL_REPO}" "${COL_NC}"; \
        exit 1; \
        }
    # Otherwise, a repair is happening
    else
        # so get git files for Core
        getGitFiles ${PM_LOCAL_REPO} ${PM_GIT_URL} || \
        { printf "  %bUnable to clone %s into %s, unable to continue%b\\n" "${COL_LIGHT_RED}" "${PM_GIT_URL}" "${PM_LOCAL_REPO}" "${COL_NC}"; \
        exit 1; \
        }
    fi
}

make_temporary_log() {
    # Create a random temporary file for the log
    TEMPLOG=$(mktemp /tmp/psp_temp.XXXXXX)
    # Open handle 3 for templog
    # https://stackoverflow.com/questions/18460186/writing-outputs-to-log-file-and-console
    exec 3>"$TEMPLOG"
    # Delete templog, but allow for addressing via file handle
    # This lets us write to the log without having a temporary file on the drive, which
    # is meant to be a security measure so there is not a lingering file on the drive during the install process
    rm "$TEMPLOG"
}

copy_to_install_log() {
    # Copy the contents of file descriptor 3 into the install log
    # Since we use color codes such as '\e[1;33m', they should be removed
    sed 's/\[[0-9;]\{1,5\}m//g' < /proc/$$/fd/3 > "${INSTALL_LOG_LOC}"
    chmod 644 "${INSTALL_LOG_LOC}"
}

main() {
    ######## FIRST CHECK ########
    # Must be root to install
    local str="Root user check"
    printf "\\n"

    # If the user's id is zero,
    if [[ "${EUID}" -eq 0 ]]; then
        # they are root and all is good
        printf "  %b %s\\n" "${TICK}" "${str}"
        # Show the logo
        show_ascii_logo
        make_temporary_log
    else
        # Otherwise, they do not have enough privileges, so let the user know
        printf "  %b %s\\n" "${INFO}" "${str}"
        printf "  %b %bScript called with non-root privileges%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "      The Lanner-PSP requires elevated privileges to install and run\\n"
        printf "      Please check the installer for any concerns regarding this requirement\\n"
        printf "      Make sure to download this script from a trusted source\\n\\n"
        printf "  %b Sudo utility check" "${INFO}"

        # If the sudo command exists, try rerunning as admin
        if is_command sudo; then
            printf "%b  %b Sudo utility check\\n" "${OVER}"  "${TICK}"

            # when run via curl piping
            if [[ "$0" == "bash" ]]; then
                # Download the install script and run it with admin rights
                exec curl -sSL ${BASE_URL}/psp/install | sudo bash -s "$@"
            else
                # when run via calling local bash script
                exec sudo bash "$0" "$@"
            fi

            exit $?
        else
            # Otherwise, tell the user they need to run the script as root, and bail
            printf "%b  %b Sudo utility check\\n" "${OVER}" "${CROSS}"
            printf "  %b Sudo is needed for the IO Interface to run PSP commands\\n\\n" "${INFO}"
            printf "  %b %bPlease re-run this installer as root${COL_NC}\\n" "${INFO}" "${COL_LIGHT_RED}"
            exit 1
        fi
    fi

    check_input_param "$@"

    check_if_psp_support "$@"

    # Check for supported package managers so that we may install dependencies
    detect_package_manager

    # Check that the installed OS is officially supported - display warning if not
    check_os
    printf "\\n"

    # Install packages used by this installation script
    printf "  %b Checking for / installing Required dependencies for this install script...\\n" "${INFO}"
    install_dependent_packages "${INSTALLER_DEPS[@]}"

    # Download or update the scripts by updating the appropriate git repos
    clone_or_update_repos

    # Install the Core dependencies
    local dep_install_list=("${PSP_DEPS[@]}")

    # Install packages used by the actual software
    printf "  %b Checking for / installing Required dependencies for PSP software...\\n" "${INFO}"
    install_dependent_packages "${dep_install_list[@]}"
    unset dep_install_list

    # Install and log everything to a file
    install_psp "$@" | tee -a /proc/$$/fd/3
    # Check PIPE exit code
    exit_code="${PIPESTATUS[0]}"
    if [[ "${exit_code}" -ne "0" ]]; then
        exit "${exit_code}"
    fi

    # Copy the temp log file into final log location for storage
    copy_to_install_log

    printf "\\n"
    printf "  %b Restarting services...\\n" "${INFO}"
    # Start services
    if is_command systemctl ; then
        systemctl daemon-reload
    fi
    enable_service lanner-psp
    restart_service lanner-psp

    INSTALL_TYPE="Installation"

    # Display where the log file is
    printf "\\n  %b The install log is located at: %s\\n" "${INFO}" "${INSTALL_LOG_LOC}"
    printf "  %b %b%s complete! %b\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${INSTALL_TYPE}" "${COL_NC}"
}

if [[ "${SKIP_INSTALL}" != true ]] ; then
    main "$@"
fi
