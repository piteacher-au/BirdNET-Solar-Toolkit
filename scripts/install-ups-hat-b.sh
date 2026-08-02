#!/usr/bin/env bash
set -euo pipefail

REPOSITORY="https://github.com/piteacher-au/BirdNET-Solar-Toolkit.git"
DESTINATION="${BIRDNET_SOLAR_TOOLKIT_DIR:-/opt/birdnet-solar-toolkit}"
BRANCH="${BIRDNET_SOLAR_TOOLKIT_REF:-main}"
SERVICE_NAME="birdnet-ups-logger.service"

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root, for example: curl -fsSL <installer URL> | sudo bash" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y git python3 python3-smbus i2c-tools

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
install -d -o birdnet -g birdnet -m 0755 /var/log/birdnet-solar-toolkit/battery_logs
install -m 0644 "${DESTINATION}/systemd/${SERVICE_NAME}" "/etc/systemd/system/${SERVICE_NAME}"
systemctl daemon-reload
systemctl enable --now "${SERVICE_NAME}"
echo "UPS HAT (B) logger installed. Verify it with: systemctl status ${SERVICE_NAME}"
