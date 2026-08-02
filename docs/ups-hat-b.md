# Waveshare UPS HAT (B)

The logger reads the HAT's INA219 monitor from IÂ²C bus 1, address `0x42`, every two seconds. Negative current means the battery is supplying the Raspberry Pi; positive current means it is charging.

The service stores one CSV file per day under `/var/log/birdnet-solar-toolkit/battery_logs/`:

```text
timestamp,voltage_v,current_a,power_w,battery_percent,state
2026-08-01T13:24:38,6.668,-0.051300,0.354,27.8,Discharging
```

`battery_percent` is an estimate based on the HAT's documented two-cell voltage range (6.0â€“8.4 V). Treat it as an operational indicator rather than a calibrated fuel gauge.

## Verify a deployment

```bash
i2cdetect -y 1
systemctl status birdnet-ups-logger.service
tail -f /var/log/birdnet-solar-toolkit/battery_logs/battery_$(date +%F).csv
```

The IÂ²C scan should show `42`. If it appears on another bus or address, edit the service `ExecStart` to add `--i2c-bus` or `--i2c-address`, then restart the service.

## Low-battery shutdown and Pi 5 RTC wake

`birdnet-rtc-power-policy.service` checks the HAT battery level once per minute. At **20%** it sets the Pi 5's internal RTC alarm for the next **06:00** local time and performs a clean shutdown. It leaves a 30-minute grace period after a boot so the station does not immediately shut down again.

On a Raspberry Pi 5, the installer applies the necessary bootloader settings automatically. Reboot once after installation to activate them.

Verify the policy service:

```bash
sudo systemctl status birdnet-rtc-power-policy.service
sudo journalctl -u birdnet-rtc-power-policy.service --no-pager -n 20
```

## Export BirdNET-Pi detections to USB

**Field visit order:** export and safely remove the USB data before installing an update or rebooting the station. This prevents an update or restart interrupting a transfer.

After running the installer, insert a blank USB drive formatted as **FAT32** and run:

```bash
export-birdnet-detections
```

The script finds BirdNET-Pi's `birds.db`, makes a consistent SQLite backup, and exports its `detections` table as CSV. Both files are saved under `Logan_City_Council/<station name>/` on the USB drive.

If the drive is not mounted automatically, mount it for the current user and pass its location explicitly:

```bash
sudo mkdir -p /mnt/birdnet-usb
sudo mount -o uid=$(id -u),gid=$(id -g),umask=022 /dev/sda1 /mnt/birdnet-usb
export-birdnet-detections --usb-dir=/mnt/birdnet-usb
sync
sudo umount /mnt/birdnet-usb
```
