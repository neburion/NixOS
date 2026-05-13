{ pkgs, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [
    git
    disko
    (writeShellScriptBin "install-nixos" ''
      set -euo pipefail

      echo "Cloning NixOS config..."
      git clone https://github.com/neburion/NixOS ~/NixOS
      cd ~/NixOS

      echo "Partitioning and formatting disk..."
      sudo disko --mode destroy,format,mount hosts/pod042/disko.nix

      echo "Installing NixOS..."
      sudo nixos-install --flake .#pod042 --no-root-passwd

      echo "Done! You can reboot now."
    '')
  ];

  # Disable sleep/suspend on the live ISO
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
}
