#!/usr/bin/env bash
# Run this after first login as neburion to restore your latest backup from gDrive.
set -euo pipefail

GDRIVE="gDrive:/Backups"
DEST="/tmp/nixrestore"
mkdir -p "$DEST"

echo "Fetching latest backup from gDrive..."
rclone --config "$HOME/.config/rclone/rclone.conf" \
  copy --include "*.7z" --max-age 7d "$GDRIVE" "$DEST/"

ARCHIVE=$(ls -t "$DEST"/*.7z 2>/dev/null | head -1)
[[ -z "$ARCHIVE" ]] && { echo "No backup found on gDrive."; exit 1; }
echo "Found: $ARCHIVE"

read -rsp "Backup password: " PASSWORD; echo

echo "Extracting..."
7z x "$ARCHIVE" -p"$PASSWORD" -o"$DEST/extracted" -y

SRC="$DEST/extracted/neburion"
echo "Restoring data..."
cp -rf "$SRC/docs/"*              "$HOME/Docs/"              2>/dev/null || true
cp -rf "$SRC/media/"*             "$HOME/Media/"             2>/dev/null || true
cp -rf "$SRC/projects/"*          "$HOME/Projects/"          2>/dev/null || true
cp -rf "$SRC/config/zen/"         "$HOME/.config/zen/"       2>/dev/null || true
cp -rf "$SRC/config/keepassxc/"   "$HOME/.config/keepassxc/" 2>/dev/null || true
cp -rf "$SRC/config/rclone/"      "$HOME/.config/rclone/"    2>/dev/null || true

rm -rf "$DEST"
echo "Restore complete."
