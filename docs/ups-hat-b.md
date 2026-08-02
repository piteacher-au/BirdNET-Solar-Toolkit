# Waveshare UPS HAT (B)

The logger reads the HAT's INA219 monitor from I²C bus 1, address `0x42`, every two seconds. Negative current means the battery is supplying the Raspberry Pi; positive current means it is charging.

The service stores one CSV file per day under `/var/log/birdnet-solar-toolkit/battery_logs/`:

```text
timestamp,voltage_v,current_a,power_w,battery_percent,state
2026-08-01T13:24:38,6.668,-0.051300,0.354,27.8,Discharging
```

`battery_percent` is an estimate based on the HAT's documented two-cell voltage range (6.0–8.4 V). Treat it as an operational indicator rather than a calibrated fuel gauge.

## Verify a deployment

```bash
i2cdetect -y 1
systemctl status birdnet-ups-logger.service
tail -f /var/log/birdnet-solar-toolkit/battery_logs/battery_$(date +%F).csv
```

The I²C scan should show `42`. If it appears on another bus or address, edit the service `ExecStart` to add `--i2c-bus` or `--i2c-address`, then restart the service.
