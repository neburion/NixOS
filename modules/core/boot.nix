{ ... }:
{
  boot.loader.efi.canTouchEfiVariables = true;

  # Grub
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
  };
}
