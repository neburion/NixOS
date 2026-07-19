{ ... }:

# TODO: commit hosts/print-server/hardware-configuration.nix next time
# work is done on the print-server itself. Until then, the conditional
# import below tolerates its absence from this checkout — but any
# rebuild MUST run on the print-server against a checkout that has the
# real file, otherwise the build boots into initrd emergency.

{
  imports = [
    ./hardware-layout

    ../../modules/system/nixos.nix
    ../../modules/system/locale.nix
    ../../modules/system/boot/systemd-boot.nix
    ../../modules/system/networking/networkmanager.nix
    ../../modules/system/networking/ssh.nix
    ../../modules/system/always-on.nix
    ../../modules/system/power-profiles.nix
    ../../modules/system/printing

    ../../users/printer
  ] ++ (if builtins.pathExists ./hardware-configuration.nix
        then [ ./hardware-configuration.nix ]
        else [ ]);
}
