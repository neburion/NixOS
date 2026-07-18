{ ... }:

# Limine bootloader with sbctl-signed Secure Boot. Reuses the sbctl keys
# already generated for lanzaboote at /var/lib/sbctl — no re-enrollment
# needed at the firmware level.
#
# Do NOT import this alongside lanzaboote — they both install a bootloader
# to /boot, only one can be active. Swap imports in the host manifest.

{
  boot.loader.efi.canTouchEfiVariables = true;

  boot.loader.limine = {
    enable            = true;
    secureBoot.enable = true;
    maxGenerations    = 10;

    style = {
      wallpapers     = [ ./limine-wallpaper.png ];
      wallpaperStyle = "stretched";

      interface = {
        resolution   = "1920x1080";
        branding     = "pod042";
        brandingColor     = "CBA6F7";  # Catppuccin Mocha mauve
        helpColor         = "89B4FA";  # Catppuccin Mocha blue
        helpColorBright   = "B4BEFE";  # Catppuccin Mocha lavender
      };
    };

    # Chainload Windows Boot Manager. Limine doesn't auto-detect other OSes.
    extraEntries = ''
      /Windows
          protocol: efi_chainload
          path: boot():/EFI/Microsoft/Boot/bootmgfw.efi
    '';
  };
}
