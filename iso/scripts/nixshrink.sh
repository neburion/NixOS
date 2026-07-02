#!/usr/bin/env bash
# In-place shrink of an existing NixOS install to make room for a Windows
# dual-boot partition. Preserves all data on the root filesystem AND the
# swap partition's UUID (so hardware-configuration.nix doesn't need changes).
#
# Starting layout: EFI | ext4 root | swap        (swap at end of disk)
# Final layout:    EFI | ext4 root | swap | NTFS-Windows
# (swap is relocated to sit between root and Windows so Linux stays
# contiguous and Windows is at the end of the disk.)
#
# Run this from a NixOS live USB (i.e. the installer ISO). It will NOT run
# from a booted system because the root partition is mounted.

set -euo pipefail

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'; NC='\033[0m'

usage() {
  echo "Usage: nixshrink [<disk>] [<new-root-GiB>] [<swap-GiB>]"
  echo "  <disk>          Target NVMe/SSD (default: /dev/nvme0n1)"
  echo "  <new-root-GiB>  Target size of the ext4 root partition (default: 720)"
  echo "  <swap-GiB>      Size of the relocated swap partition (default: 17)"
  echo ""
  echo "Windows partition takes whatever space remains after root + swap."
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { usage; exit 0; }

DISK="${1:-/dev/nvme0n1}"
NEW_ROOT_GIB="${2:-720}"
SWAP_GIB="${3:-17}"

ROOT_PART="${DISK}p2"
SWAP_PART="${DISK}p3"

echo -e "${YLW}=== NixOS in-place shrink + dual-boot prep ===${NC}"
echo "Disk:       $DISK"
echo "Root:       $ROOT_PART  -> shrink to ${NEW_ROOT_GIB}G"
echo "Swap:       $SWAP_PART  -> relocate (preserve UUID), size ${SWAP_GIB}G"
echo "Windows:    new partition at end, fills remaining space"
echo ""

# Safety check: ensure target partitions are NOT mounted (we're on the live USB).
if mount | grep -q "$ROOT_PART\|$SWAP_PART"; then
  echo -e "${RED}Error: $ROOT_PART or $SWAP_PART is currently mounted.${NC}"
  echo -e "${RED}This script must run from a live USB, not the booted system.${NC}"
  exit 1
fi

parted "$DISK" unit GiB print

read -rp "Proceed? [y/N] " confirm
[[ "$confirm" != "y" && "$confirm" != "Y" ]] && { echo "Aborted."; exit 0; }

# ---- 1. fsck root ----------------------------------------------------------
# e2fsck exit codes: 0=clean, 1=errors corrected, 2=errors corrected + reboot
# recommended (we power off anyway), >=4=uncorrected/fatal. set -e would kill
# us on a benign exit 1 (e.g. dirty journal recovered), so accept 0-2.
echo -e "\n${GRN}1/6  fsck on $ROOT_PART...${NC}"
set +e
e2fsck -f -y "$ROOT_PART"
FSCK_RC=$?
set -e
if [ "$FSCK_RC" -gt 2 ]; then
  echo -e "${RED}fsck failed (exit $FSCK_RC); refusing to proceed.${NC}"
  exit "$FSCK_RC"
fi
[ "$FSCK_RC" -gt 0 ] && echo "  -> fsck corrected errors (exit $FSCK_RC), continuing"

# ---- 2. shrink the ext4 filesystem -----------------------------------------
echo -e "\n${GRN}2/6  Shrinking ext4 filesystem to ${NEW_ROOT_GIB}G...${NC}"
resize2fs "$ROOT_PART" "${NEW_ROOT_GIB}G"

# ---- 3. shrink the root partition (sgdisk: delete + recreate) --------------
# parted's `resizepart` defaults to CANCEL in -s mode (refuses shrink for
# safety). sgdisk just edits the partition table — data blocks untouched.
echo -e "\n${GRN}3/6  Shrinking root partition to ${NEW_ROOT_GIB}G...${NC}"
ROOT_START=$(sgdisk -i 2 "$DISK" | awk '/First sector/{print $3}')
ROOT_TYPE=$(sgdisk -i 2 "$DISK" | awk '/Partition GUID code/{print $4}')
ROOT_NAME=$(sgdisk -i 2 "$DISK" | sed -n "s/^Partition name: '\(.*\)'/\1/p")
sgdisk -d 2 "$DISK" >/dev/null
sgdisk -n "2:${ROOT_START}:+${NEW_ROOT_GIB}G" "$DISK" >/dev/null
[ -n "$ROOT_TYPE" ] && sgdisk -t "2:${ROOT_TYPE}" "$DISK" >/dev/null
[ -n "$ROOT_NAME" ] && sgdisk -c "2:${ROOT_NAME}" "$DISK" >/dev/null
echo "  -> p2: start=${ROOT_START}, size=${NEW_ROOT_GIB}GiB"

# ---- 4. relocate swap: capture UUID, delete old, recreate after root ------
# Without relocation, Windows ends up between root and swap. Relocating swap
# keeps Linux contiguous so Windows can sit at the end (easier to grow/shrink
# either side later).
echo -e "\n${GRN}4/6  Relocating swap (UUID preserved)...${NC}"
SWAP_UUID=$(blkid -s UUID -o value "$SWAP_PART" || true)
if [ -n "$SWAP_UUID" ]; then
  echo "  -> existing swap UUID: $SWAP_UUID"
  sgdisk -d 3 "$DISK" >/dev/null
  # 0 for start = sgdisk picks the next aligned sector in the largest free
  # block (which is the space we just freed by shrinking root).
  sgdisk -n "3:0:+${SWAP_GIB}G" -t "3:8200" -c "3:swap" "$DISK" >/dev/null
  partprobe "$DISK" || true
  sleep 1
  mkswap -U "$SWAP_UUID" "$SWAP_PART" >/dev/null
  echo "  -> p3: new position, UUID preserved (hardware-configuration.nix unchanged)"
else
  echo -e "  ${YLW}-> no existing swap UUID found; skipping swap relocation${NC}"
fi

# ---- 5. Windows partition fills the rest ----------------------------------
echo -e "\n${GRN}5/6  Creating Windows partition (fills remaining space)...${NC}"
# 0:0:0 = next partition number, sgdisk picks start (next aligned sector in
# the largest free block), end = "use all of it".
sgdisk -n "0:0:0" -t "0:0700" -c "0:windows" "$DISK" >/dev/null

# ---- 6. re-read partition table -------------------------------------------
echo -e "\n${GRN}6/6  Re-reading partition table...${NC}"
partprobe "$DISK" || true

echo ""
echo -e "${GRN}Done. Final layout:${NC}"
parted "$DISK" unit GiB print

echo ""
echo -e "${YLW}Next steps:${NC}"
echo "  1. poweroff, unplug this USB."
echo "  2. Boot normally — NixOS comes back up with all data intact."
echo "  3. When ready for Windows: boot the Windows USB, pick \"Custom install\","
echo "     install into the new ~Windows partition (typically ${DISK}p4)."
echo "  4. After Windows is installed, boot back into NixOS and run:"
echo "       sudo nixos-rebuild switch --flake ~/NixOS#pod042"
echo "     so GRUB picks up the Windows entry."
