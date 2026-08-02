#!/usr/bin/env bash
set -euo pipefail

REPOSITORY="https://github.com/piteacher-au/BirdNET-Solar-Toolkit.git"
DESTINATION="${BIRDNET_SOLAR_TOOLKIT_DIR:-/opt/birdnet-solar-toolkit}"
BRANCH="${BIRDNET_SOLAR_TOOLKIT_REF:-main}"
SERVICE_NAME="birdnet-ups-logger.service"
POWER_POLICY_SERVICE="birdnet-rtc-power-policy.service"

configure_pi5_rtc_wake() {
  if ! grep -aq "Raspberry Pi 5" /proc/device-tree/model 2>/dev/null; then
    echo "Pi 5 RTC wake setup skipped: this is not a Raspberry Pi 5."
    return 0
  fi

  if ! command -v rpi-eeprom-config >/dev/null 2>&1; then
    echo "WARNING: rpi-eeprom-config is unavailable; Pi 5 RTC wake was not configured." >&2
    return 1
  fi

  local editor
  editor="$(mktemp)"
  cat >"${editor}" <<'EOF'
#!/bin/sh
config="$1"
sed -i '/^[[:space:]]*POWER_OFF_ON_HALT[[:space:]]*=/d; /^[[:space:]]*WAKE_ON_GPIO[[:space:]]*=/d' "$config"
printf '\nPOWER_OFF_ON_HALT=1\nWAKE_ON_GPIO=0\n' >> "$config"
EOF
  chmod 700 "${editor}"
  EDITOR="${editor}" rpi-eeprom-config --edit
  rm -f "${editor}"
  echo "Pi 5 RTC wake firmware settings applied. Reboot once to activate them."
}

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root, for example: curl -fsSL <installer URL> | sudo bash" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y git python3 python3-smbus i2c-tools sqlite3 rpi-eeprom

if ! getent group i2c >/dev/null; then groupadd --system i2c; fi
if ! id -u birdnet >/dev/null 2>&1; then useradd --system --create-home --home-dir /var/lib/birdnet --groups i2c birdnet; fi

if [[ -d "${DESTINATION}/.git" ]]; then
  git -C "${DESTINATION}" fetch --depth 1 origin "${BRANCH}"
  git -C "${DESTINATION}" checkout --force "origin/${BRANCH}"
else
  rm -rf "${DESTINATION}"
  git clone --depth 1 --branch "${BRANCH}" "${REPOSITORY}" "${DESTINATION}"
fi

raspi-config nonint do_i2c 0 || true
configure_pi5_rtc_wake
install -d -o birdnet -g birdnet -m 0755 /var/log/birdnet-solar-toolkit/battery_logs
install -m 0644 "${DESTINATION}/systemd/${SERVICE_NAME}" "/etc/systemd/system/${SERVICE_NAME}"
install -m 0644 "${DESTINATION}/systemd/${POWER_POLICY_SERVICE}" "/etc/systemd/system/${POWER_POLICY_SERVICE}"
install -m 0755 "${DESTINATION}/scripts/export-birdnet-detections.sh" /usr/local/bin/export-birdnet-detections
systemctl daemon-reload
systemctl enable --now "${SERVICE_NAME}"
systemctl enable --now "${POWER_POLICY_SERVICE}"
echo "UPS HAT (B) logger installed. Export detections with: export-birdnet-detections"
echo "Low-battery policy installed: shut down at 20% and wake at 06:00."
