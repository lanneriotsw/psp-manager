# PSP Manager

[Lanner PSP](https://link.lannerinc.com/psp) aims to simplify and enhance the efficiency of customer’s application implementation. 
When developers intend to write an application that involves hardware access, 
they were required to fully understand the specifications to utilize the drivers. 
This is often being considered a time consuming job which requires lots of related knowledge and time. 
In order to achieve better full access hardware functionality, 
[Lanner](https://lannerinc.com/) invests great effort to ease customer’s development journey with the release of a suite of reliable Software APIs.

PSP Manager is a powerful tool that can help you easily install [Lanner PSP](https://link.lannerinc.com/psp).
The following examples will show how to install PSP using PSP Manager and some basic PSP usage.

-----

## Installation

> "product-type" is required, case-insensitive, dashes can be omitted.  
> "version-name" is optional. If leave blank or fill in "latest", the latest version will be automatically selected.

### Method 1: One-Step Automated Install

Those who want to get started quickly and conveniently may install Lanner PSP using the following command:

```shell
curl -sSL https://link.lannerinc.com/psp/install | bash -s <product-type> [version-name]
```

Example for specifying the version:

```shell
curl -sSL https://link.lannerinc.com/psp/install | bash -s LEC-7242 2.1.2
```

Or install the latest version:

```shell
curl -sSL https://link.lannerinc.com/psp/install | bash -s LEC-7242
```

### Method 2: Clone our repository and run

```shell
git clone --depth 1 https://github.com/lanneriotsw/psp-manager.git
cd psp-manager/
sudo bash install.sh <product-type> [version-name]
```

### Method 3: Manually download the installer and run

```shell
wget -O install.sh https://link.lannerinc.com/psp/install
sudo bash install.sh <product-type> [version-name]
```

-----

## Usage

There are several ways to call the SDK. Here are some commonly used methods, the results will be different for each product and version, but each method requires **ROOT** privileges.

### Method 1: Use compiled SDK utils

Show all available SDK utils:

```console
$ ls /opt/lanner/psp/bin/amd64/utils | grep sdk
sdk_bios
sdk_dll
sdk_hwm
sdk_rfm
sdk_sled
sdk_sled_gps
sdk_sled_lte
sdk_sled_lte_stress
sdk_swr
sdk_wdt
```

Show `sdk_hwm` usage:

```console
$ sudo /opt/lanner/psp/bin/amd64/utils/sdk_hwm
Usage: /opt/lanner/psp/bin/amd64/utils/sdk_hwm -temp cpu1/cpu2/sys1/sys2
       /opt/lanner/psp/bin/amd64/utils/sdk_hwm -volt core1/core2/12v/5v/3v3/5vsb/3v3sb/vbat/psu1/psu2
       /opt/lanner/psp/bin/amd64/utils/sdk_hwm -rpm fan1/fan2/fan3/..../fan10
       /opt/lanner/psp/bin/amd64/utils/sdk_hwm -rpm fan1a/fan1b/fan2a/fan2b/....../fan10a/fan10b
       /opt/lanner/psp/bin/amd64/utils/sdk_hwm -callback	 	--> uses callback detect caseopen
       /opt/lanner/psp/bin/amd64/utils/sdk_hwm -sidname #dec	 	--> print sensor name by #dec
       /opt/lanner/psp/bin/amd64/utils/sdk_hwm -sidmsg #dec	 	--> print sensor message by #dec
       /opt/lanner/psp/bin/amd64/utils/sdk_hwm -testop [seconds] 	--> for caseopen testing (default 5 seconds)
       /opt/lanner/psp/bin/amd64/utils/sdk_hwm -testhwm		--> for hardware monitor testing
```

Run `sdk_hwm` test:

```console
$ sudo /opt/lanner/psp/bin/amd64/utils/sdk_hwm -testhwm
CPU-1 temperature =  35 C	(min =  30 C, max =  85 C)
SYS-1 temperature =  36 C	(min =  25 C, max =  65 C)
CPU-1 Vcore =   0.968 V		(min =   0.600 V, max =   2.000 V)
5V =   5.003 V			(min =   4.500 V, max =   5.500 V)
3.3V =   3.323 V		(min =   2.970 V, max =   3.630 V)
Vbat =   3.040 V		(min =   3.000 V, max =   3.300 V)
VDDR =   1.104 V		(min =   1.080 V, max =   1.320 V)
```

Show version information:

```console
$ sudo /opt/lanner/psp/bin/amd64/utils/sdk_dll -v
PSP/SDK version: 2.1.2
IODRV   version: LEB-7242.1.0.2
```

And so on...

### Method 2: Use C language to call functions directly

Get CPU 1 temperature:

```cpp
#include <stdio.h>
#include <stdlib.h>
#include "lmbinc.h"

int main(int argc, char* argv[])
{
    int32_t iRet;
    float fTemp = 0;

    LMB_DLL_Init();

    iRet = LMB_HWM_GetCpuTemp(1, &fTemp);

    if (iRet == ERR_Success)
        printf("CPU 1 temperature is %f\n", fTemp);

    LMB_DLL_DeInit();

    return 0;
}
```

Set the system LED display mode to green:

```cpp
#include <stdio.h>
#include <stdlib.h>
#include "lmbinc.h"

int main(int argc, char* argv[])
{
    int32_t iRet;
    uint8_t sled = 1; //mode1 -> light green LED

    LMB_DLL_Init();

    iRet = LMB_SLED_SetSystemLED(sled);
    if (iRet == ERR_Success) printf(“Green LED is ready\n”);

    LMB_DLL_DeInit();

    return 0;
}
```

And so on...

### Method 3: Call from other programming languages

The following ports are available:

* [NodeJS](https://github.com/lanneriotsw/psp-api-nodejs)
* [Python](https://github.com/lanneriotsw/psp-api-python)

-----

## Uninstall

Use PSP Manager to remove all PSP files:

```shell
sudo bash /opt/lanner/psp-manager/uninstall.sh
```

-----

## Reference

* [PSP_V3S](https://www.lannerinc.com/support/download-center/software/category/30-intelligent-edge-appliances) on Lanner official web

-----

## Todo

* i386 architecture CPU
* Compatible with all product types
* Call from any other languages
