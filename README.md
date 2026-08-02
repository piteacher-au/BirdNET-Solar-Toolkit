# BirdNET Solar Toolkit

One-command deployment tools for solar-powered Raspberry Pi BirdNET stations.

## UPS HAT (B) battery logger

The first deployable component supports a Waveshare UPS HAT (B) on a Raspberry Pi. It records battery voltage, current, power, estimated state of charge, and charging state every two seconds in daily CSV files. Negative current means that the battery is powering the Pi; positive current means it is charging.

### Deploy on a new Raspberry Pi

Enable IÂ²C on the Pi, then run this command from an account that can use `sudo`:

```bash
curl -fsSL https://raw.githubusercontent.com/piteacher-au/BirdNET-Solar-Toolkit/main/scripts/install-ups-hat-b.sh | sudo bash
```

The installer installs all required system packages (`git`, `python3`, `python3-smbus`, and `i2c-tools`), obtains this repository under `/opt/birdnet-solar-toolkit`, enables IÂ²C, and starts the `birdnet-ups-logger` service.

### Verify it

```bash
systemctl status birdnet-ups-logger.service
tail -f /var/log/birdnet-solar-toolkit/battery_logs/battery_$(date +%F).csv
```

### Export BirdNET-Pi detections to USB

Insert a blank USB drive formatted as **FAT32**, then run:

```bash
export-birdnet-detections
```

The export creates a dated CSV and a SQLite database backup in `Logan_City_Council/<station name>/` on the USB drive.

If the Pi does not mount the drive automatically, mount it before exporting:

```bash
sudo mkdir -p /mnt/birdnet-usb
sudo mount -o uid=$(id -u),gid=$(id -g),umask=022 /dev/sda1 /mnt/birdnet-usb
export-birdnet-detections --usb-dir=/mnt/birdnet-usb
sync
sudo umount /mnt/birdnet-usb
```

See [UPS HAT (B) deployment and troubleshooting](docs/ups-hat-b.md) for the CSV format and IÂ²C checks.

## Hardware

- Raspberry Pi 5 (or compatible Raspberry Pi with IÂ²C)
- Waveshare UPS HAT (B) with matched batteries
- Solar charging system
- Raspberry Pi OS

## Roadmap

- RTC wake and scheduled shutdown configuration
- BirdNET-Pi service integration
- Battery protection policy and deployment diagnostics

## License

MIT
