#!/usr/bin/python3

"""
BirdNET Solar Toolkit
battery_shutdown.py

Monitors the Waveshare UPS HAT battery and performs:
- Scheduled shutdown at 6:00 PM
- Emergency shutdown below the battery threshold
- RTC wake scheduling for 6:00 AM
- Safe filesystem synchronisation before shutdown

Author: Jarrah Newton
Project: BirdNET Solar Toolkit
Version: 0.1.0
License: MIT
"""

import os
import sys
import subprocess
from datetime import datetime, timedelta

sys.path.append('/home/piteacher/UPS_HAT_B')
from INA219 import INA219

# -------------------------
# Configuration
# -------------------------
LOW_BATTERY = 20      # Emergency shutdown threshold (%)
SHUTDOWN_HOUR = 18    # 6:00 PM
WAKE_HOUR = 6         # 6:00 AM

try:
    ina219 = INA219(addr=0x42)

    bus_voltage = ina219.getBusVoltage_V()
    percent = (bus_voltage - 6.0) / 2.4 * 100

    now = datetime.now()

    # Shutdown after 6 PM OR if battery is critically low
    scheduled_shutdown = now.hour >= SHUTDOWN_HOUR
    low_battery = percent <= LOW_BATTERY

    if scheduled_shutdown or low_battery:

        if scheduled_shutdown:
            reason = "scheduled 6 PM shutdown"
        else:
            reason = f"battery below {LOW_BATTERY}% ({percent:.1f}%)"

        os.system(f"logger 'BirdNET-Pi: {reason}'")

        # -------------------------
        # Calculate next wake time
        # -------------------------
        wake = now.replace(
            hour=WAKE_HOUR,
            minute=0,
            second=0,
            microsecond=0
        )

        if wake <= now:
            wake += timedelta(days=1)

        wake_epoch = int(wake.timestamp())

        # -------------------------
        # Program RTC wake alarm
        # -------------------------
        subprocess.run(
            "echo 0 | tee /sys/class/rtc/rtc0/wakealarm > /dev/null",
            shell=True,
            check=True
        )

        subprocess.run(
            f"echo {wake_epoch} | tee /sys/class/rtc/rtc0/wakealarm > /dev/null",
            shell=True,
            check=True
        )

        # -------------------------
        # Verify RTC alarm
        # -------------------------
        with open("/sys/class/rtc/rtc0/wakealarm", "r") as rtc:
            actual = rtc.read().strip()

        if actual != str(wake_epoch):
            os.system(
                f"logger 'RTC wake verification FAILED. Expected {wake_epoch}, got {actual}. Shutdown aborted.'"
            )
            sys.exit(1)

        os.system(f"logger 'RTC wake scheduled for {wake}'")

        # -------------------------
        # Flush filesystem
        # -------------------------
        subprocess.run("sync", shell=True)

        # -------------------------
        # Shutdown
        # -------------------------
        subprocess.run("/usr/sbin/shutdown -h now", shell=True)

except Exception as e:
    os.system(f"logger 'Battery monitor error: {e}'")
