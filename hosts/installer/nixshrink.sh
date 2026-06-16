#!/usr/bin/env bash
# In-place shrink of an existing NixOS install to make room for a Windows
# dual-boot partition. Preserves all data on the root filesystem.
#
# Assumes a layout of: <EFI> <ext4 root> <swap> on a single disk, with the
# ext4 root having enough free space to shrink. Defaults are sized for the
# pod042 NVMe (954G total, 16.8G swap, ~300G used on a 936G root).
#
# Run this from a NixOS live USB (i.e. the installer ISO). It will NOT run
# from a booted system because the root partition is mounted.

set -euo pipefail

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'; NC='\033[0m'

usage() {
  echo "Usage: nixshrink [<disk>] [<new-root-size-GiB>] [<windows-size-GiB>]"
  echo "  <disk>             Target NVMe/SSD (default: /dev/nvme0n1)"
  echo "  <new-root-size>    Target size of the ext4 root partition (default: 720)"
  echo "  <windows-size>     Size to reserve for the Windows partition (default: 200)"
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { usage; exit 0; }

DISK="${1:-/dev/nvme0n1}"
NEW_ROOT_GIB="${2:-720}"
WIN_GIB="${3:-200}"

ROOT_PART="${DISK}p2"
SWAP_PART="${DISK}p3"

echo -e "${YLW}=== NixOS in-place shrink for Windows dual-boot ===${NC}"
echo "Disk:        $DISK"
echo "Root part:   $ROOT_PART  (will shrink to ${NEW_ROOT_GIB}G)"
echo "Swap part:   $SWAP_PART  (untouched)"
echo "Reserve:     ${WIN_GIB}G for Windows (created as new partition)"
echo ""

# Safety check: ensure target partitions are NOT mounted (we're on the live USB).
if mount | grep -q "$ROOT_PART\|$SWAP_PART"; then
  echo -e "${RED}Error: $ROOT_PART or $SWAP_PART is currently mounted.${NC}"
  echo -e "${RED}This script must run from a live USB, not the booted system.${NC}"
  exit 1
fi

# Read current sizes (parted units = GiB to keep math simple).
parted "$DISK" unit GiB print

read -rp "Proceed with shrink? [y/N] " confirm
[[ "$confirm" != "y" && "$confirm" != "Y" ]] && { echo "Aborted."; exit 0; }

echo -e "\n${GRN}1/5  fsck on $ROOT_PART (required before resize)...${NC}"
e2fsck -f -y "$ROOT_PART"

echo -e "\n${GRN}2/5  Shrinking ext4 filesystem to ${NEW_ROOT_GIB}G...${NC}"
resize2fs "$ROOT_PART" "${NEW_ROOT_GIB}G"

# Compute partition end. Root starts at 1GiB (after EFI), so:
#   new end = 1 + NEW_ROOT_GIB
NEW_ROOT_END_GIB=$((1 + NEW_ROOT_GIB))

echo -e "\n${GRN}3/5  Shrinking partition $ROOT_PART to ${NEW_ROOT_END_GIB}GiB...${NC}"
parted -s "$DISK" resizepart 2 "${NEW_ROOT_END_GIB}GiB"

# Windows partition lives in the freed space between the new p2 end and p3.
WIN_START_GIB="$NEW_ROOT_END_GIB"
WIN_END_GIB=$((WIN_START_GIB + WIN_GIB))

echo -e "\n${GRN}4/5  Creating ${WIN_GIB}G partition for Windows at ${WIN_START_GIB}-${WIN_END_GIB}GiB...${NC}"
parted -s "$DISK" mkpart windows "${WIN_START_GIB}GiB" "${WIN_END_GIB}GiB"
# Set the type to Microsoft basic data so the Windows installer recognises it.
parted -s "$DISK" type 4 ebd0a0a2-b9e5-4433-87c0-68b6b72699c7 2>/dev/null \
  || sgdisk -t 4:0700 "$DISK"

echo -e "\n${GRN}5/5  Re-reading partition table...${NC}"
partprobe "$DISK" || true

echo ""
echo -e "${GRN}Done. New layout:${NC}"
parted "$DISK" unit GiB print

echo ""
echo -e "${YLW}Next steps:${NC}"
echo "  1. poweroff, unplug this USB."
echo "  2. Boot normally — NixOS comes back up exactly as before."
echo "  3. When ready for Windows: boot the Windows USB, pick \"Custom install\","
echo "     and install into the new ~${WIN_GIB}G partition (typically ${DISK}p4)."
echo "  4. After Windows is installed, boot back into NixOS and run:"
echo "       sudo nixos-rebuild switch --flake ~/NixOS#pod042"
echo "     so GRUB picks up the Windows entry."
