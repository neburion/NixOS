#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'; NC='\033[0m'

REPO_URL="https://github.com/neburion/NixOS"
TARGET="/mnt/etc/nixos"

usage() {
  echo "Usage: nixinstall [<host>] [<disk>]"
  echo "  <host>  Host name under hosts/ in the repo (e.g. pod042)"
  echo "  <disk>  Target block device (e.g. /dev/nvme0n1)"
  echo "Both args are prompted for if omitted."
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { usage; exit 0; }

echo -e "${YLW}=== NixOS Installer ===${NC}"

# Network sanity — disko, nixos-install, and the git clone all need it.
if ! curl -fsS --max-time 5 https://cache.nixos.org/ -o /dev/null; then
  echo -e "${RED}No network. Bring up an interface first (e.g. \`nmtui\` or \`sudo wpa_passphrase ...\`).${NC}"
  exit 1
fi

# Stage repo into a scratch dir first so we can list available hosts
# and read the chosen host's disko.nix before doing anything destructive.
STAGE=$(mktemp -d)
trap "rm -rf $STAGE" EXIT
echo -e "\n${GRN}Fetching config...${NC}"
git clone --depth 1 "$REPO_URL" "$STAGE/repo"

mapfile -t HOSTS < <(ls "$STAGE/repo/hosts" | grep -v '^installer$')

# Host selection
HOST="${1:-}"
if [[ -z "$HOST" ]]; then
  echo ""
  echo "Available hosts:"
  for h in "${HOSTS[@]}"; do echo "  - $h"; done
  echo ""
  read -rp "Host: " HOST
fi
# Membership check
if ! printf '%s\n' "${HOSTS[@]}" | grep -qx "$HOST"; then
  echo -e "${RED}Unknown host: $HOST${NC}"
  exit 1
fi

DISKO_NIX="$STAGE/repo/hosts/$HOST/disko.nix"
[[ ! -f "$DISKO_NIX" ]] && {
  echo -e "${RED}hosts/$HOST/disko.nix not found — host has no declarative disk layout.${NC}"
  echo -e "${RED}Add one before installing this host.${NC}"
  exit 1
}

# Disk selection
echo ""
echo "Available disks:"
lsblk -d -o NAME,SIZE,MODEL --noheadings
echo ""
DISK="${2:-}"
[[ -z "$DISK" ]] && read -rp "Target disk (e.g. /dev/nvme0n1): " DISK
[[ ! -b "$DISK" ]] && { echo -e "${RED}Not a block device: $DISK${NC}"; exit 1; }

# Confirmation
echo -e "${RED}WARNING: ALL DATA on $DISK will be erased.${NC}"
read -rp "Install $HOST to $DISK? [y/N] " confirm
[[ "$confirm" != "y" && "$confirm" != "Y" ]] && { echo "Aborted."; exit 0; }

# Partition + format + mount
echo -e "\n${GRN}Partitioning $DISK with disko...${NC}"
nix --extra-experimental-features "nix-command flakes" run \
  github:nix-community/disko/latest -- \
  --mode destroy,format,mount \
  "$DISKO_NIX" \
  --arg disk "\"$DISK\""

# Move the cloned config onto the freshly-mounted target so nixos-install
# can read it from /mnt/etc/nixos.
echo -e "\n${GRN}Placing config at $TARGET...${NC}"
mkdir -p "$(dirname "$TARGET")"
cp -r "$STAGE/repo" "$TARGET"

# Capture hardware-configuration.nix from the actually-mounted disk. The
# repo's checked-in copy holds UUIDs from the original install — they won't
# match the brand-new partitions disko just created. --show-hardware-config
# prints the freshly-detected one to stdout; redirect it into the host dir.
echo -e "\n${GRN}Generating hardware-configuration.nix from new disk...${NC}"
nixos-generate-config --root /mnt --show-hardware-config \
  > "$TARGET/hosts/$HOST/hardware-configuration.nix"

# Install. --no-root-passwd is safe: root is locked declaratively
# (mutableUsers = false), and user passwords are baked into the config.
echo -e "\n${GRN}Installing NixOS...${NC}"
nixos-install --flake "$TARGET#$HOST" --no-root-passwd

echo -e "\n${GRN}Done. Reboot when ready.${NC}"
