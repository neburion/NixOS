#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'; NC='\033[0m'

echo -e "${YLW}=== NixOS Installer for pod042 ===${NC}"
echo ""

echo "Available disks:"
lsblk -d -o NAME,SIZE,MODEL --noheadings
echo ""
read -rp "Target disk device (e.g. /dev/nvme0n1): " DISK
[[ ! -b "$DISK" ]] && { echo -e "${RED}Not a block device: $DISK${NC}"; exit 1; }
echo -e "${RED}WARNING: ALL DATA on $DISK will be erased.${NC}"
read -rp "Continue? [y/N] " confirm
[[ "$confirm" != "y" && "$confirm" != "Y" ]] && { echo "Aborted."; exit 0; }

echo -e "\n${GRN}Partitioning $DISK with disko...${NC}"
nix --extra-experimental-features "nix-command flakes" run \
  github:nix-community/disko/latest -- \
  --mode destroy,format,mount \
  /etc/nixinstall-disko.nix \
  --arg disk "\"$DISK\""

echo -e "\n${GRN}Cloning NixOS config...${NC}"
git clone https://github.com/neburion/NixOS /mnt/etc/nixos

echo -e "\n${GRN}Installing NixOS...${NC}"
nixos-install --flake /mnt/etc/nixos#pod042 --no-root-passwd

echo -e "\n${GRN}Copying restore script to new system...${NC}"
cp /etc/nixrestore.sh /mnt/home/neburion/nixrestore.sh
chmod +x /mnt/home/neburion/nixrestore.sh

echo -e "\n${GRN}Done.${NC}"
echo "After reboot: log in as neburion and run ~/nixrestore.sh to restore your data."
