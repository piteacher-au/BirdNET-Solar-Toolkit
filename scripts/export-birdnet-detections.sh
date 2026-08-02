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
    "/home/piteacher/BirdNET-Pi/scripts/birds.db" \
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
    echo "No writable USB drive found." >&2
    echo "Insert a blank USB drive formatted as FAT32, then try again." >&2
    echo "If the drive is not mounted automatically, mount it at /mnt/birdnet-usb and run:" >&2
    echo "  export-birdnet-detections --usb-dir=/mnt/birdnet-usb" >&2
    exit 1
  }
fi

[[ -d "$DESTINATION" && -w "$DESTINATION" ]] || {
    echo "USB destination is not writable: $DESTINATION" >&2
    echo "Use a blank FAT32-formatted USB drive mounted for the current user." >&2
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
# Use Python's standard-library SQLite support if the sqlite3 command-line tool
# was not installed because the normal toolkit deployment did not finish.
if command -v sqlite3 >/dev/null 2>&1; then
  sqlite3 "$DATABASE" ".backup '$BACKUP'"
  sqlite3 -header -csv "$BACKUP" 'SELECT * FROM detections;' > "$CSV"
else
  python3 - "$DATABASE" "$BACKUP" "$CSV" <<'PY'
import csv
import sqlite3
import sys

source_path, backup_path, csv_path = sys.argv[1:]
with sqlite3.connect(source_path) as source_connection, sqlite3.connect(backup_path) as backup_connection:
    source_connection.backup(backup_connection)

with sqlite3.connect(backup_path) as connection, open(csv_path, "w", newline="", encoding="utf-8") as csv_file:
    cursor = connection.execute("SELECT * FROM detections;")
    writer = csv.writer(csv_file)
    writer.writerow([column[0] for column in cursor.description])
    writer.writerows(cursor)
PY
fi
sync

echo "Export complete"
echo "CSV:    $CSV"
echo "Backup: $BACKUP"
