#!/usr/bin/env python3
"""Continuously write Waveshare UPS HAT (B) readings to daily CSV files."""

import argparse
import csv
import logging
import signal
import time
from datetime import datetime
from pathlib import Path

from ina219 import INA219

LOG = logging.getLogger(__name__)
RUNNING = True


def battery_percent(voltage):
    """Estimate the two-cell battery state from its pack voltage."""
    return max(0.0, min(100.0, (voltage - 6.0) / 2.4 * 100.0))


def stop(_signum, _frame):
    global RUNNING
    RUNNING = False


def write_sample(writer, monitor):
    voltage = monitor.bus_voltage_v()
    current = monitor.current_a()
    power = monitor.power_w()
    percent = battery_percent(voltage)
    state = "Charging" if current > 0 else "Discharging"
    writer.writerow([datetime.now().isoformat(timespec="seconds"), f"{voltage:.3f}", f"{current:.6f}", f"{power:.3f}", f"{percent:.1f}", state])


def run(args):
    logs = Path(args.log_dir)
    logs.mkdir(parents=True, exist_ok=True)
    monitor = INA219(args.i2c_bus, args.i2c_address)
    current_date = None
    handle = writer = None
    while RUNNING:
        today = datetime.now().date()
        if today != current_date:
            if handle:
                handle.close()
            path = logs / f"battery_{today.isoformat()}.csv"
            is_new = not path.exists() or path.stat().st_size == 0
            handle = path.open("a", newline="", encoding="utf-8")
            writer = csv.writer(handle)
            if is_new:
                writer.writerow(["timestamp", "voltage_v", "current_a", "power_w", "battery_percent", "state"])
            current_date = today
            LOG.info("Writing battery readings to %s", path)
        try:
            write_sample(writer, monitor)
            handle.flush()
        except OSError as error:
            LOG.warning("Could not read INA219: %s", error)
        time.sleep(args.interval)
    if handle:
        handle.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log-dir", default="/var/log/birdnet-solar-toolkit/battery_logs")
    parser.add_argument("--interval", type=float, default=2.0)
    parser.add_argument("--i2c-bus", type=int, default=1)
    parser.add_argument("--i2c-address", type=lambda value: int(value, 0), default=0x42)
    args = parser.parse_args()
    if args.interval <= 0:
        parser.error("--interval must be greater than zero")
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    run(args)


if __name__ == "__main__":
    main()
