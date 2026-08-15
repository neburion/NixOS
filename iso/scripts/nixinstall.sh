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

printf '%b=== NixOS Installer ===%b\n' "$YLW" "$NC"

if ! curl -fsS --max-time 5 https://cache.nixos.org/ -o /dev/null; then
  printf '%bNo network. Bring up an interface first (nmtui, wpa_passphrase, etc.).%b\n' "$RED" "$NC"
  exit 1
fi

STAGE=$(mktemp -d)
DISKO_TEMP=""
cleanup() { rm -rf "$STAGE"; [[ -n "$DISKO_TEMP" ]] && rm -f "$DISKO_TEMP"; }
trap cleanup EXIT

printf '\n%bFetching config from GitHub...%b\n' "$GRN" "$NC"
git clone --depth 1 "$REPO_URL" "$STAGE/repo"

# -type d: hosts/ and users/ hold one directory per host/user. find over ls
# so a stray file (README, .keep) can't show up as a selectable choice.
mapfile -t HOSTS < <(find "$STAGE/repo/hosts" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
if [[ -d "$STAGE/repo/users" ]]; then
  mapfile -t USERS < <(find "$STAGE/repo/users" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
else
  USERS=()
fi

# ── HOST SELECTION ────────────────────────────────────────────────────────────
printf '\n%bSelect host:%b\n' "$YLW" "$NC"
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
  [[ -z "$HOST" ]] && { printf '%bHostname cannot be empty.%b\n' "$RED" "$NC"; exit 1; }
elif [[ "$HOST_CHOICE" -ge 1 && "$HOST_CHOICE" -lt "$NEW_HOST_OPT" ]]; then
  HOST="${HOSTS[$((HOST_CHOICE - 1))]}"
else
  printf '%bInvalid choice.%b\n' "$RED" "$NC"; exit 1
fi

# ── USER SELECTION (new minimal hosts only) ───────────────────────────────────
USERNAME=""
HASHED_PW=""

if $NEW_HOST; then
  printf '\n%bSelect user:%b\n' "$YLW" "$NC"
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
    [[ -z "$USERNAME" ]] && { printf '%bUsername cannot be empty.%b\n' "$RED" "$NC"; exit 1; }
  elif [[ "$USER_CHOICE" -ge 1 && "$USER_CHOICE" -lt "$NEW_USER_OPT" ]]; then
    USERNAME="${USERS[$((USER_CHOICE - 1))]}"
  else
    printf '%bInvalid choice.%b\n' "$RED" "$NC"; exit 1
  fi

  printf "\n"
  read -rsp "Password for $USERNAME: " PW1; printf "\n"
  read -rsp "Confirm password: "       PW2; printf "\n"
  [[ "$PW1" != "$PW2" ]] && { printf '%bPasswords do not match.%b\n' "$RED" "$NC"; exit 1; }
  HASHED_PW=$(openssl passwd -6 "$PW1")
fi

# ── DISK SELECTION ────────────────────────────────────────────────────────────
printf '\n%bAvailable disks:%b\n' "$YLW" "$NC"
lsblk -d -e 7,11 -o NAME,SIZE,MODEL --noheadings
printf "\n"
read -rp "Target disk (e.g. /dev/nvme0n1): " DISK
[[ ! -b "$DISK" ]] && { printf '%bNot a block device: %s%b\n' "$RED" "$DISK" "$NC"; exit 1; }

# ── SOPS KEY (existing host only — the standalone "new minimal" path has no secrets) ─
SOPS_ENC="$STAGE/repo/secrets/age-key.enc"
SOPS_PASS=""
INSTALL_SOPS=false

if ! $NEW_HOST && [[ -f "$SOPS_ENC" ]]; then
  printf '\n%bSops master passphrase (empty to skip installing key — any sops-decrypted secret will fail on first activation):%b\n' "$YLW" "$NC"
  read -rsp "> " SOPS_PASS; printf "\n"
  if [[ -n "$SOPS_PASS" ]]; then
    # Dry-run decrypt now so we catch a wrong passphrase BEFORE we've wiped the disk.
    if ! printf '%s' "$SOPS_PASS" | openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 \
         -in "$SOPS_ENC" -pass stdin >/dev/null 2>&1; then
      printf '%bWrong passphrase for secrets/age-key.enc — bailing before touching the disk.%b\n' "$RED" "$NC"
      exit 1
    fi
    INSTALL_SOPS=true
  fi
fi

# ── CONFIRM ───────────────────────────────────────────────────────────────────
printf '\n%bSummary:%b\n' "$YLW" "$NC"
if $NEW_HOST; then
  printf "  Host:  %s (new minimal)\n" "$HOST"
  printf "  User:  %s\n" "$USERNAME"
else
  printf "  Host:  %s (from repo)\n" "$HOST"
  printf "  Sops:  %s\n" "$($INSTALL_SOPS && echo 'age key will be installed to /var/lib/sops-nix/key.txt' || echo 'SKIPPED')"
fi
printf "  Disk:  %s\n\n" "$DISK"
printf '%bWARNING: ALL DATA on %s will be erased.%b\n' "$RED" "$DISK" "$NC"
read -rp "Proceed? [y/N] " CONFIRM
[[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && { printf "Aborted.\n"; exit 0; }

# ─────────────────────────────────────────────────────────────────────────────
# EXISTING HOST INSTALL
# ─────────────────────────────────────────────────────────────────────────────
if ! $NEW_HOST; then
  DISKO_NIX="$STAGE/repo/hosts/$HOST/hardware-layout/disk-layout.nix"
  [[ ! -f "$DISKO_NIX" ]] && {
    printf '%bhosts/%s/hardware-layout/disk-layout.nix not found.\n' "$RED" "$HOST"
    printf 'Add a disk layout before installing this host.%b\n' "$NC"
    exit 1
  }

  printf '\n%bPartitioning with disko...%b\n' "$GRN" "$NC"
  nix --extra-experimental-features "nix-command flakes" run \
    github:nix-community/disko/latest -- \
    --mode destroy,format,mount \
    --yes-wipe-all-disks \
    "$DISKO_NIX" \
    --arg disk "\"$DISK\""

  printf '\n%bPlacing config at %s...%b\n' "$GRN" "$TARGET" "$NC"
  # -T so a pre-existing $TARGET dir is treated as the destination
  # itself, not a parent to nest under (which would create
  # $TARGET/repo/ on re-runs and leave the real config stale).
  mkdir -p "$TARGET"
  cp -rT "$STAGE/repo" "$TARGET"

  printf '\n%bGenerating hardware-configuration.nix...%b\n' "$GRN" "$NC"
  # Written to hosts/$HOST/ which is gitignored — the flake imports
  # it via `builtins.pathExists ./hardware-configuration.nix` in the
  # host's configuration.nix, so a github flake fetch (which lacks
  # this file) won't clobber it.
  nixos-generate-config --root /mnt --show-hardware-config \
    > "$TARGET/hosts/$HOST/hardware-configuration.nix"

  if $INSTALL_SOPS; then
    printf '\n%bInstalling sops age key to /mnt/var/lib/sops-nix/key.txt...%b\n' "$GRN" "$NC"
    install -Dm400 /dev/null /mnt/var/lib/sops-nix/key.txt
    printf '%s' "$SOPS_PASS" | openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 \
      -in "$SOPS_ENC" -pass stdin \
      > /mnt/var/lib/sops-nix/key.txt
    chmod 400 /mnt/var/lib/sops-nix/key.txt
  fi

  printf '\n%bInstalling NixOS...%b\n' "$GRN" "$NC"
  # `path:` scheme bypasses git-tracked-only filtering so the freshly
  # generated (gitignored) hardware-configuration.nix is included.
  nixos-install --flake "path:$TARGET#$HOST" --no-root-passwd

  printf '\n%bDone. Reboot when ready.%b\n' "$GRN" "$NC"
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

printf '\n%bPartitioning with disko...%b\n' "$GRN" "$NC"
nix --extra-experimental-features "nix-command flakes" run \
  github:nix-community/disko/latest -- \
  --mode destroy,format,mount \
  --yes-wipe-all-disks \
  "$DISKO_TEMP" \
  --arg disk "\"$DISK\""

rm -f "$DISKO_TEMP"

# Scaffold the standalone host config
printf '\n%bScaffolding minimal config at %s...%b\n' "$GRN" "$TARGET" "$NC"
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

printf '\n%bGenerating hardware-configuration.nix...%b\n' "$GRN" "$NC"
nixos-generate-config --root /mnt --show-hardware-config \
  > "$TARGET/hardware-configuration.nix"

printf '\n%bInstalling NixOS...%b\n' "$GRN" "$NC"
nixos-install --flake "$TARGET#$HOST" --no-root-passwd

printf '\n%bDone! %s is installed on %s.%b\n' "$GRN" "$HOST" "$DISK" "$NC"
printf '\n%bConfig is at /etc/nixos — push it to your NixOS repo when ready.%b\n' "$YLW" "$NC"
