{ ... }:

{
  imports = [
    ./hardware-layout

    ../../modules/system/nixos.nix
    ../../modules/system/locale.nix
    ../../modules/system/boot/systemd-boot.nix
    ../../modules/system/networking/networkmanager.nix
    ../../modules/system/networking/ssh.nix
    ../../modules/system/networking/ssh-password-auth.nix
    ../../modules/system/headless.nix
    ../../modules/system/power-profiles.nix
    ../../modules/system/auto-upgrade.nix
    ../../modules/system/printing

    ../../users/printer
  ] ++ (if builtins.pathExists ./hardware-configuration.nix
        then [ ./hardware-configuration.nix ]
        else [ ]);

  networking.hostName = "print-server";

  # Auto-upgrade disabled: hosts/*/hardware-configuration.nix is now
  # gitignored, so a github flake fetch would be missing it and boot
  # into initrd emergency after activation. Re-enable once a wrapper
  # is in place that git-pulls /etc/nixos and rebuilds against
  # `path:/etc/nixos#print-server` (bypasses git-tracked-only filter).
  system.autoUpgrade.enable = false;
}
