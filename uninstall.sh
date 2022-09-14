#!/usr/bin/env bash

# PSP: Platform Support Package
# (c) 2022 Lanner Electronics Inc. (https://www.lannerinc.com)
# Lanner PSP is an SDK that facilitates communication between you and your Lanner IPC's IO.
#
# Completely uninstalls PSP
#
# This file is copyright under the latest version of the EUPL.
# Please see LICENSE file for your rights under this license.

# link.lannerinc.com/psp
#
# Uninstall with this command (from your Linux machine):
#
# bash uninstall.sh

source "/opt/lanner/psp-manager/COL_TABLE"

# Must be root to uninstall
str="Root user check"
if [[ ${EUID} -eq 0 ]]; then
    echo -e "  ${TICK} ${str}"
else
    # Check if sudo is actually installed
    # If it isn't, exit because the uninstall can not complete
    if [ -x "$(command -v sudo)" ]; then
        # export SUDO="sudo"
        exec sudo bash "$0" "$@"
        exit $?
    else
        echo -e "  ${CROSS} ${str}
            Script called with non-root privileges
            The PSP requires elevated privileges to uninstall"
        exit 1
    fi
fi

echo -e "  ${INFO} ${COL_YELLOW}Removing the PSP will cause the machine's I/O to be inaccessible.
      Please make sure the PSP is not currently being used by other applications.${COL_NC}"

while true; do
    read -rp "  ${QST} Are you sure you would like to remove ${COL_WHITE}PSP${COL_NC}? [y/N] " answer
    case ${answer} in
        [Yy]* ) break;;
        * ) echo -e "${OVER}  ${COL_LIGHT_GREEN}Uninstall has been canceled${COL_NC}"; exit 0;;
    esac
done

readonly PM_SCRIPT_DIR="/opt/lanner/psp-manager"
SKIP_INSTALL="true"
PSP_TEST="true"  # TODO: remove
source "${PM_SCRIPT_DIR}/install.sh"

# detect_package_manager() sourced from install.sh
detect_package_manager

# Install packages used by the PSP
DEPS=("${INSTALLER_DEPS[@]}" "${PSP_DEPS[@]}")

# Compatibility
if [ -x "$(command -v apt-get)" ]; then
    # Debian Family
    PKG_REMOVE=("${PKG_MANAGER}" -y remove --purge)
    package_check() {
        dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -c "ok installed"
    }
elif [ -x "$(command -v rpm)" ]; then
    # Fedora Family
    PKG_REMOVE=("${PKG_MANAGER}" remove -y)
    package_check() {
        rpm -qa | grep "^$1-" > /dev/null
    }
else
    echo -e "  ${CROSS} OS distribution not supported"
    exit 1
fi

removeAndPurge() {
    # Purge dependencies
    echo ""
    for i in "${DEPS[@]}"; do
        if package_check "${i}" > /dev/null; then
            while true; do
                read -rp "  ${QST} Do you wish to remove ${COL_WHITE}${i}${COL_NC} from your system? [Y/N] " answer
                case ${answer} in
                    [Yy]* )
                        echo -ne "  ${INFO} Removing ${i}...";
                        ${SUDO} "${PKG_REMOVE[@]}" "${i}" &> /dev/null;
                        echo -e "${OVER}  ${INFO} Removed ${i}";
                        break;;
                    [Nn]* ) echo -e "  ${INFO} Skipped ${i}"; break;;
                esac
            done
        else
            echo -e "  ${INFO} Package ${i} not installed"
        fi
    done

    # Call removeNoPurge to remove PSP specific files
    removeNoPurge
}

removeNoPurge() {
    # Remove PSP
    stop_service lanner-psp
    disable_service lanner-psp
    rm -f /lib/systemd/system/lanner-psp.service &> /dev/null
    rmmod /opt/lanner/psp/bin/amd64/driver/lmbiodrv.ko &> /dev/null
    # modprobe -r i2c-i801 &> /dev/null
    rm -rf /opt/lanner/psp &> /dev/null
    rm -rf /opt/lanner/psp-manager &> /dev/null

    echo -e "  ${TICK} ${COL_LIGHT_GREEN}Uninstallation complete! ${COL_NC}"
}

######### SCRIPT ###########
echo -e "  ${INFO} Be sure to confirm if any dependencies should not be removed"
while true; do
    echo -e "  ${INFO} ${COL_YELLOW}The following dependencies may have been added by the PSP install:"
    echo -n "    "
    for i in "${DEPS[@]}"; do
        echo -n "${i} "
    done
    echo "${COL_NC}"
    read -rp "  ${QST} Do you wish to go through each dependency for removal? (Choosing No will leave all dependencies installed) [Y/n] " answer
    case ${answer} in
        [Yy]* ) removeAndPurge; break;;
        [Nn]* ) removeNoPurge; break;;
        * ) removeAndPurge; break;;
    esac
done
