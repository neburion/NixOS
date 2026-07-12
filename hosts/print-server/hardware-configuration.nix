# Placeholder — nixos-generate-config replaces this at install time
# (nixinstall.sh runs it via --show-hardware-config). Values below
# are only good enough to let `nix flake check` evaluate the host.
{ lib, ... }:

{
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules   = [ ];
  boot.kernelModules          = [ ];
  boot.extraModulePackages    = [ ];

  fileSystems."/"     = { device = "/dev/disk/by-label/nixos"; fsType = "ext4"; };
  fileSystems."/boot" = { device = "/dev/disk/by-label/BOOT";  fsType = "vfat"; };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
}
