#!/usr/bin/env bash
# Export BirdNET-Pi detections and a safe SQLite backup to a mounted USB drive.
set -euo pipefail

DESTINATION=""
for arg in "$@"; do
  case "$arg" in
    --usb-dir=*) DESTINATION="${arg#*=}" ;;
    *) echo "Usage: $0 [--usb-dir=/path/to/USB]" >&2; exit 2 ;;
  esac
done

find_database() {
  local candidate
  for candidate in \
    "$HOME/BirdNET-Pi/scripts/birds.db" \
    "/home/pi/BirdNET-Pi/scripts/birds.db" \
    "/home/birdnet/BirdNET-Pi/scripts/birds.db"; do
    [[ -f "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
  done
  return 1
}

find_usb() {
  local base candidate
  for base in "/media/$USER" "/run/media/$USER" /media /mnt; do
    [[ -d "$base" ]] || continue
    for candidate in "$base"/*; do
      [[ -d "$candidate" && -w "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
    done
  done
  return 1
}

DATABASE="$(find_database)" || {
  echo "BirdNET-Pi database birds.db was not found." >&2
  echo "Run this from the BirdNET-Pi account, or update the database location in this script." >&2
  exit 1
}

if [[ -z "$DESTINATION" ]]; then
  DESTINATION="$(find_usb)" || {
    echo "No writable USB drive found. Insert the labelled USB drive and try again." >&2
    exit 1
  }
fi

[[ -d "$DESTINATION" && -w "$DESTINATION" ]] || {
  echo "USB destination is not writable: $DESTINATION" >&2
  exit 1
}

SITE_NAME="$(awk -F= '/^[[:space:]]*SITE_NAME[[:space:]]*=/{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' "$HOME/BirdNET-Pi/birdnet.conf" 2>/dev/null || true)"
SITE_NAME="${SITE_NAME:-$(hostname)}"
SAFE_NAME="$(printf '%s' "$SITE_NAME" | tr -cs 'A-Za-z0-9._-' '_')"
STAMP="$(date +%F_%H%M%S)"
OUT_DIR="$DESTINATION/Logan_City_Council/$SAFE_NAME"
mkdir -p "$OUT_DIR"

CSV="$OUT_DIR/${SAFE_NAME}_detections_${STAMP}.csv"
BACKUP="$OUT_DIR/${SAFE_NAME}_birds_${STAMP}.db"

# SQLite's backup command gives a consistent copy while BirdNET-Pi is running.
sqlite3 "$DATABASE" ".backup '$BACKUP'"
sqlite3 -header -csv "$BACKUP" 'SELECT * FROM detections;' > "$CSV"
sync

echo "Export complete"
echo "CSV:    $CSV"
echo "Backup: $BACKUP"
