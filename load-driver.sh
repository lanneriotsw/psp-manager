#!/bin/bash

# PSP: Platform Support Package
# (c) 2022 Lanner Electronics Inc. (https://www.lannerinc.com)
# Lanner PSP is an SDK that facilitates communication between you and your Lanner IPC's IO.
#
# Loading drivers with systemd at OS startup
#
# Modified by UFO Chen
# Original file path: /opt/lanner/psp/bin/amd64/loaddriver.sh

I801=`lsmod | grep i801`

if [ "$EUID" -ne 0 ]; then
	echo -e "\033[1;31mYou must be root to do that!\033[0m"	
	exit 1
fi

if [ -e /sys/class/misc/lmbiodrv ]; then
    echo "<Already> lmbiodrv driver"
else
    echo "<Install> lmbiodrv driver"
    insmod /opt/lanner/psp/bin/amd64/driver/lmbiodrv.ko
    if [ ! -e /dev/lmbiodrv ]; then
        STT=`cat /sys/class/misc/lmbiodrv/dev`
        MINOR=$(grep -Eo [:]+[0-9]+ <<< $STT| sed s/[^0-9]*//g )
        echo "create /dev/lmbiodrv 10:$MINOR"
        mknod /dev/lmbiodrv c 10 $MINOR
    fi
fi

if [ -e "/etc/lsb-release" ]; then
    #Ubuntu
    if [ "$I801" == "" ]; then
        echo "<Install> i2c-i801 driver"
        modprobe i2c-i801
    else
        echo "<Already> i2c-i801 driver"
    fi
else
    #centOS
    if [ -e /dev/i2c-0 ] ; then
        echo "<Already> i2c-dev driver"
    else
        echo "<Install> i2c-dev driver"
        modprobe i2c-dev
    fi
fi
exit 0
