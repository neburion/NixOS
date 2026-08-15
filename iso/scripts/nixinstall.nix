{ pkgs, ... }:

# `nixinstall` — interactive installer: clones the config from GitHub,
# partitions with disko, installs the sops age key, runs nixos-install.
#
# runtimeInputs carries every binary the script calls, so the tool is
# self-contained rather than depending on a separate ISO-wide package list.
# Adding the script to the ISO is what makes its dependencies available.
#   curl   — reachability probe against cache.nixos.org
#   git    — clone the config repo
#   openssl— `openssl passwd -6` + decrypting secrets/age-key.enc
#   util-linux — lsblk for the disk picker
#   nix    — `nix run` disko for partitioning
#   nixos-install-tools — nixos-generate-config, nixos-install
#   coreutils — mktemp/install/chmod/cp/sort and friends

{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "nixinstall";
      runtimeInputs = with pkgs; [
        coreutils
        curl
        findutils
        git
        nix
        nixos-install-tools
        openssl
        util-linux
      ];
      text = builtins.readFile ./nixinstall.sh;
    })
  ];
}
