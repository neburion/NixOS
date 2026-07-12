{ pkgs, ... }:

{
  boot.loader = {
    efi.canTouchEfiVariables = true;
    grub = {
      enable     = true;
      efiSupport = true;
      device     = "nodev";
      theme      = pkgs.grub2-theme-vimix;
    };
  };
}
