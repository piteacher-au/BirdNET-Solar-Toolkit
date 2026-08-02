#!/usr/bin/env python3
"""Protect a solar-powered Pi by shutting down at low battery and arming RTC wake."""

from __future__ import annotations

import argparse
from datetime import datetime, timedelta
import logging
import os
from pathlib import Path
import subprocess
import time

from ina219 import INA219

LOG = logging.getLogger("birdnet-power-policy")
RTC_WAKEALARM = Path("/sys/class/rtc/rtc0/wakealarm")


def next_wake_epoch(wake_time: str) -> int:
    hour, minute = (int(value) for value in wake_time.split(":"))
    now = datetime.now().astimezone()
    wake = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
    if wake <= now:
        wake += timedelta(days=1)
    return int(wake.timestamp())


def arm_wake_alarm(epoch: int) -> None:
    if not RTC_WAKEALARM.exists():
        raise RuntimeError(f"Pi RTC wakealarm not available at {RTC_WAKEALARM}")
    RTC_WAKEALARM.write_text("0\n", encoding="ascii")
    RTC_WAKEALARM.write_text(f"{epoch}\n", encoding="ascii")


def uptime_seconds() -> float:
    return float(Path("/proc/uptime").read_text(encoding="ascii").split()[0])


def rtc_wake_is_enabled() -> bool:
    """Confirm the Pi 5 EEPROM settings needed to wake after halt."""
    try:
        result = subprocess.run(
            ["/usr/bin/rpi-eeprom-config"],
            check=True,
            capture_output=True,
            text=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        return False
    settings = {
        line.split("=", 1)[0].strip(): line.split("=", 1)[1].strip()
        for line in result.stdout.splitlines()
        if "=" in line and not line.lstrip().startswith("#")
    }
    return settings.get("POWER_OFF_ON_HALT") == "1" and settings.get("WAKE_ON_GPIO") == "0"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--threshold", type=float, default=20.0, help="Battery percentage that triggers shutdown")
    parser.add_argument("--wake-time", default="06:00", help="Daily local wake time, in HH:MM")
    parser.add_argument("--interval", type=int, default=60, help="Seconds between checks")
    parser.add_argument("--startup-grace-minutes", type=int, default=30, help="Keep the Pi awake after a scheduled boot")
    parser.add_argument("--i2c-bus", type=int, default=1)
    parser.add_argument("--i2c-address", type=lambda value: int(value, 0), default=0x42)
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    try:
        hour, minute = (int(value) for value in args.wake_time.split(":"))
        if not (0 <= hour <= 23 and 0 <= minute <= 59):
            raise ValueError
    except ValueError as error:
        raise SystemExit("--wake-time must be HH:MM in 24-hour local time") from error

    monitor = INA219(args.i2c_bus, args.i2c_address)
    grace_seconds = args.startup_grace_minutes * 60
    LOG.info("Low-battery policy: shut down at %.1f%% and wake at %s", args.threshold, args.wake_time)

    while True:
        try:
            percent = monitor.battery_percent()
            if uptime_seconds() < grace_seconds:
                LOG.info("Battery %.1f%%; startup grace period is active", percent)
            elif percent <= args.threshold:
                if not rtc_wake_is_enabled():
                    LOG.error("Pi 5 RTC wake is not configured; refusing low-battery shutdown to avoid stranding the station")
                    time.sleep(args.interval)
                    continue
                wake_epoch = next_wake_epoch(args.wake_time)
                wake_at = datetime.fromtimestamp(wake_epoch).astimezone().isoformat(timespec="minutes")
                LOG.warning("Battery %.1f%% is at or below %.1f%%; waking at %s", percent, args.threshold, wake_at)
                arm_wake_alarm(wake_epoch)
                os.sync()
                subprocess.run(["/bin/systemctl", "poweroff"], check=True)
                return
            else:
                LOG.info("Battery %.1f%% is above the %.1f%% shutdown threshold", percent, args.threshold)
        except Exception as error:
            LOG.warning("Could not evaluate low-battery policy: %s", error)
        time.sleep(args.interval)


if __name__ == "__main__":
    main()
