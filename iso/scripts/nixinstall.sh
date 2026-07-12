#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'; NC='\033[0m'

REPO_URL="https://github.com/neburion/NixOS"
TARGET="/mnt/etc/nixos"
NIXOS_VERSION="26.05"

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && {
  printf 'Usage: nixinstall\n'
  printf '  Interactive NixOS installer. Clones config from GitHub,\n'
  printf '  partitions the target disk, and installs.\n'
  exit 0
}

printf "${YLW}=== NixOS Installer ===${NC}\n"

if ! curl -fsS --max-time 5 https://cache.nixos.org/ -o /dev/null; then
  printf "${RED}No network. Bring up an interface first (nmtui, wpa_passphrase, etc.).${NC}\n"
  exit 1
fi

STAGE=$(mktemp -d)
DISKO_TEMP=""
cleanup() { rm -rf "$STAGE"; [[ -n "$DISKO_TEMP" ]] && rm -f "$DISKO_TEMP"; }
trap cleanup EXIT

printf "\n${GRN}Fetching config from GitHub...${NC}\n"
git clone --depth 1 "$REPO_URL" "$STAGE/repo"

mapfile -t HOSTS < <(ls "$STAGE/repo/hosts" | sort)
if [[ -d "$STAGE/repo/users" ]]; then
  mapfile -t USERS < <(ls "$STAGE/repo/users" | sort)
else
  USERS=()
fi

# ── HOST SELECTION ────────────────────────────────────────────────────────────
printf "\n${YLW}Select host:${NC}\n"
idx=1
for h in "${HOSTS[@]}"; do
  printf "  %d) %s\n" "$idx" "$h"
  idx=$((idx + 1))
done
printf "  %d) [new minimal host]\n" "$idx"
NEW_HOST_OPT=$idx

printf "\n"
read -rp "Choice [1-$idx]: " HOST_CHOICE

NEW_HOST=false
HOST=""

if [[ "$HOST_CHOICE" -eq "$NEW_HOST_OPT" ]]; then
  NEW_HOST=true
  printf "\n"
  read -rp "Hostname: " HOST
  [[ -z "$HOST" ]] && { printf "${RED}Hostname cannot be empty.${NC}\n"; exit 1; }
elif [[ "$HOST_CHOICE" -ge 1 && "$HOST_CHOICE" -lt "$NEW_HOST_OPT" ]]; then
  HOST="${HOSTS[$((HOST_CHOICE - 1))]}"
else
  printf "${RED}Invalid choice.${NC}\n"; exit 1
fi

# ── USER SELECTION (new minimal hosts only) ───────────────────────────────────
USERNAME=""
HASHED_PW=""

if $NEW_HOST; then
  printf "\n${YLW}Select user:${NC}\n"
  uidx=1
  for u in "${USERS[@]}"; do
    printf "  %d) %s (from repo)\n" "$uidx" "$u"
    uidx=$((uidx + 1))
  done
  printf "  %d) [new minimal user]\n" "$uidx"
  NEW_USER_OPT=$uidx

  printf "\n"
  read -rp "Choice [1-$uidx]: " USER_CHOICE

  if [[ "$USER_CHOICE" -eq "$NEW_USER_OPT" ]]; then
    printf "\n"
    read -rp "Username: " USERNAME
    [[ -z "$USERNAME" ]] && { printf "${RED}Username cannot be empty.${NC}\n"; exit 1; }
  elif [[ "$USER_CHOICE" -ge 1 && "$USER_CHOICE" -lt "$NEW_USER_OPT" ]]; then
    USERNAME="${USERS[$((USER_CHOICE - 1))]}"
  else
    printf "${RED}Invalid choice.${NC}\n"; exit 1
  fi

  printf "\n"
  read -rsp "Password for $USERNAME: " PW1; printf "\n"
  read -rsp "Confirm password: "       PW2; printf "\n"
  [[ "$PW1" != "$PW2" ]] && { printf "${RED}Passwords do not match.${NC}\n"; exit 1; }
  HASHED_PW=$(openssl passwd -6 "$PW1")
fi

# ── DISK SELECTION ────────────────────────────────────────────────────────────
printf "\n${YLW}Available disks:${NC}\n"
lsblk -d -e 7,11 -o NAME,SIZE,MODEL --noheadings
printf "\n"
read -rp "Target disk (e.g. /dev/nvme0n1): " DISK
[[ ! -b "$DISK" ]] && { printf "${RED}Not a block device: %s${NC}\n" "$DISK"; exit 1; }

# ── CONFIRM ───────────────────────────────────────────────────────────────────
printf "\n${YLW}Summary:${NC}\n"
if $NEW_HOST; then
  printf "  Host:  %s (new minimal)\n" "$HOST"
  printf "  User:  %s\n" "$USERNAME"
else
  printf "  Host:  %s (from repo)\n" "$HOST"
fi
printf "  Disk:  %s\n\n" "$DISK"
printf "${RED}WARNING: ALL DATA on %s will be erased.${NC}\n" "$DISK"
read -rp "Proceed? [y/N] " CONFIRM
[[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && { printf "Aborted.\n"; exit 0; }

# ─────────────────────────────────────────────────────────────────────────────
# EXISTING HOST INSTALL
# ─────────────────────────────────────────────────────────────────────────────
if ! $NEW_HOST; then
  DISKO_NIX="$STAGE/repo/hosts/$HOST/hardware-layout/disk-layout.nix"
  [[ ! -f "$DISKO_NIX" ]] && {
    printf "${RED}hosts/%s/hardware-layout/disk-layout.nix not found.\n" "$HOST"
    printf "Add a disk layout before installing this host.${NC}\n"
    exit 1
  }

  printf "\n${GRN}Partitioning with disko...${NC}\n"
  nix --extra-experimental-features "nix-command flakes" run \
    github:nix-community/disko/latest -- \
    --mode destroy,format,mount \
    --yes-wipe-all-disks \
    "$DISKO_NIX" \
    --arg disk "\"$DISK\""

  printf "\n${GRN}Placing config at %s...${NC}\n" "$TARGET"
  # -T so a pre-existing $TARGET dir is treated as the destination
  # itself, not a parent to nest under (which would create
  # $TARGET/repo/ on re-runs and leave the real config stale).
  mkdir -p "$TARGET"
  cp -rT "$STAGE/repo" "$TARGET"

  printf "\n${GRN}Generating hardware-configuration.nix...${NC}\n"
  # Written to hosts/$HOST/ which is gitignored — the flake imports
  # it via `builtins.pathExists ./hardware-configuration.nix` in the
  # host's configuration.nix, so a github flake fetch (which lacks
  # this file) won't clobber it.
  nixos-generate-config --root /mnt --show-hardware-config \
    > "$TARGET/hosts/$HOST/hardware-configuration.nix"

  printf "\n${GRN}Installing NixOS...${NC}\n"
  # `path:` scheme bypasses git-tracked-only filtering so the freshly
  # generated (gitignored) hardware-configuration.nix is included.
  nixos-install --flake "path:$TARGET#$HOST" --no-root-passwd

  printf "\n${GRN}Done. Reboot when ready.${NC}\n"
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# NEW MINIMAL HOST INSTALL
# ─────────────────────────────────────────────────────────────────────────────

# Generate a temporary disko layout for partitioning
DISKO_TEMP=$(mktemp /tmp/disk-layout.XXXXXX.nix)  # cleanup registered in trap above

cat > "$DISKO_TEMP" <<'NEOF'
{ disk ? "/dev/nvme0n1", ... }:
{
  disko.devices.disk.main = {
    type   = "disk";
    device = disk;
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "1G";
          type = "EF00";
          content = {
            type         = "filesystem";
            format       = "vfat";
            mountpoint   = "/boot";
            mountOptions = [ "fmask=0077" "dmask=0077" ];
          };
        };
        root = {
          size    = "100%";
          content = { type = "filesystem"; format = "ext4"; mountpoint = "/"; };
        };
      };
    };
  };
}
NEOF

printf "\n${GRN}Partitioning with disko...${NC}\n"
nix --extra-experimental-features "nix-command flakes" run \
  github:nix-community/disko/latest -- \
  --mode destroy,format,mount \
  --yes-wipe-all-disks \
  "$DISKO_TEMP" \
  --arg disk "\"$DISK\""

rm -f "$DISKO_TEMP"

# Scaffold the standalone host config
printf "\n${GRN}Scaffolding minimal config at %s...${NC}\n" "$TARGET"
mkdir -p "$TARGET/hardware-layout"

# flake.nix — standalone, no home-manager or modules needed
cat > "$TARGET/flake.nix" <<NEOF
{
  description = "$HOST NixOS configuration";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-$NIXOS_VERSION";

  outputs = { nixpkgs, ... }: {
    nixosConfigurations.$HOST = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./configuration.nix ];
    };
  };
}
NEOF

# configuration.nix — use printf to safely embed the hashed password
# (heredoc with unquoted EOF would try to expand $6$... in the hash)
{
  printf '{ pkgs, ... }:\n\n'
  printf '{\n'
  printf '  imports = [ ./hardware-configuration.nix ];\n\n'
  printf '  networking.hostName = "%s";\n\n' "$HOST"
  printf '  boot.loader = {\n'
  printf '    systemd-boot.enable      = true;\n'
  printf '    efi.canTouchEfiVariables = true;\n'
  printf '  };\n\n'
  printf '  nix.settings.experimental-features = [ "nix-command" "flakes" ];\n\n'
  printf '  users.mutableUsers = false;\n'
  printf '  users.users.%s = {\n' "$USERNAME"
  printf '    isNormalUser   = true;\n'
  printf '    extraGroups    = [ "wheel" "networkmanager" ];\n'
  printf '    hashedPassword = "%s";\n' "$HASHED_PW"
  printf '  };\n\n'
  printf '  security.sudo.wheelNeedsPassword = true;\n\n'
  printf '  services.openssh.enable = true;\n\n'
  printf '  environment.systemPackages = with pkgs; [ git vim ];\n\n'
  printf '  system.stateVersion = "%s";\n' "$NIXOS_VERSION"
  printf '}\n'
} > "$TARGET/configuration.nix"

# disk-layout.nix with the chosen disk as default
{
  printf '{ disk ? "%s", ... }:\n\n' "$DISK"
  printf '{\n'
  printf '  disko.devices.disk.main = {\n'
  printf '    type   = "disk";\n'
  printf '    device = disk;\n'
  printf '    content = {\n'
  printf '      type = "gpt";\n'
  printf '      partitions = {\n'
  printf '        boot = {\n'
  printf '          size = "1G";\n'
  printf '          type = "EF00";\n'
  printf '          content = {\n'
  printf '            type         = "filesystem";\n'
  printf '            format       = "vfat";\n'
  printf '            mountpoint   = "/boot";\n'
  printf '            mountOptions = [ "fmask=0077" "dmask=0077" ];\n'
  printf '          };\n'
  printf '        };\n'
  printf '        root = {\n'
  printf '          size    = "100%%";\n'
  printf '          content = { type = "filesystem"; format = "ext4"; mountpoint = "/"; };\n'
  printf '        };\n'
  printf '      };\n'
  printf '    };\n'
  printf '  };\n'
  printf '}\n'
} > "$TARGET/hardware-layout/disk-layout.nix"

printf "\n${GRN}Generating hardware-configuration.nix...${NC}\n"
nixos-generate-config --root /mnt --show-hardware-config \
  > "$TARGET/hardware-configuration.nix"

printf "\n${GRN}Installing NixOS...${NC}\n"
nixos-install --flake "$TARGET#$HOST" --no-root-passwd

printf "\n${GRN}Done! %s is installed on %s.${NC}\n" "$HOST" "$DISK"
printf "\n${YLW}Config is at /etc/nixos — push it to your NixOS repo when ready.${NC}\n"
