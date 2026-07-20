# Dependencies

This document records all hardware, software, services and configuration
required for a fully functional BirdNET Solar Toolkit deployment.

As additional components are discovered during development, they should
be added to this document before being automated in the installer.

------------------------------------------------------------------------

# Hardware Requirements

## Raspberry Pi

-   Raspberry Pi 5
-   Official Raspberry Pi USB-C power supply (during setup)

## RTC

-   Raspberry Pi 5 RTC battery connected to the RTC header.

Required for:

-   Automatic scheduled boot
-   Accurate time when power is removed

------------------------------------------------------------------------

## UPS

Current supported hardware:

-   Waveshare UPS HAT (D)

Features used:

-   INA219 Battery Monitor
-   Battery voltage monitoring
-   Standby power for RTC wake

------------------------------------------------------------------------

## Solar

Current development platform:

-   Trail camera solar battery pack
-   12 V output
-   Additional external solar panel
-   Waveshare UPS HAT (D)
-   Raspberry Pi 5

------------------------------------------------------------------------

# Operating System

Supported operating system:

-   Raspberry Pi OS (64-bit)

------------------------------------------------------------------------

# Python

Required:

-   Python 3

Verify:

``` bash
python3 --version
```

------------------------------------------------------------------------

# Python Modules

## Standard Library

Used by the toolkit:

-   os
-   sys
-   subprocess
-   datetime

These are included with Python.

## Waveshare UPS Library

Required:

``` python
from INA219 import INA219
```

Current location:

    /home/piteacher/UPS_HAT_B

------------------------------------------------------------------------

# Raspberry Pi Configuration

## I²C

Must be enabled using:

``` bash
sudo raspi-config
```

Enable **Interface Options → I2C**.

## EEPROM

Required settings:

``` text
POWER_OFF_ON_HALT=1
WAKE_ON_GPIO=0
```

------------------------------------------------------------------------

# Linux Packages

Required:

-   python3
-   python3-smbus
-   i2c-tools
-   cron

Install with:

``` bash
sudo apt update
sudo apt install -y python3 python3-smbus i2c-tools
```

------------------------------------------------------------------------

# Scheduled Task

Root crontab:

``` cron
*/10 * * * * /usr/bin/python3 /home/piteacher/battery_shutdown.py
```

------------------------------------------------------------------------

# Battery Management Script

Current script:

    battery_shutdown.py

Functions:

-   Scheduled shutdown at 6 PM
-   Emergency low battery shutdown
-   RTC wake scheduling at 6 AM
-   Safe filesystem synchronisation

------------------------------------------------------------------------

# RTC Verification

``` bash
echo 0 | sudo tee /sys/class/rtc/rtc0/wakealarm
sudo date -d "+2 minutes" +%s | sudo tee /sys/class/rtc/rtc0/wakealarm
sudo poweroff
```

Expected result:

-   Raspberry Pi powers off.
-   Automatically boots approximately two minutes later.

------------------------------------------------------------------------

# Installer Checklist

The installer should eventually verify:

-   Raspberry Pi 5
-   Python installed
-   I²C enabled
-   INA219 library present
-   Waveshare UPS detected
-   RTC battery present
-   EEPROM configured
-   Battery management script installed
-   Cron job installed
-   BirdNET services running

------------------------------------------------------------------------

# Notes

Keep this document updated whenever a new dependency or configuration
step is discovered.
