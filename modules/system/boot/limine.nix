{ config, pkgs, lib, ... }:

# Limine bootloader with sbctl-signed Secure Boot. Reuses the sbctl keys
# already generated for lanzaboote at /var/lib/sbctl — no re-enrollment
# needed at the firmware level.
#
# Do NOT import this alongside lanzaboote — they both install a bootloader
# to /boot, only one can be active. Swap imports in the host manifest.

let
  cfg = config.boot.loader.limine;
  efi = config.boot.loader.efi;

  # Mirror the nixpkgs limineInstallConfig so we can swap in our custom script.
  limineInstallConfig = pkgs.writeText "limine-install.json" (
    builtins.toJSON {
      inherit (config.system.nixos) distroName;
      nixPath           = config.nix.package;
      efiBootMgrPath    = pkgs.efibootmgr;
      liminePath        = cfg.package;
      efiMountPoint     = efi.efiSysMountPoint;
      fileSystems       = config.fileSystems;
      luksDevices       = builtins.attrNames config.boot.initrd.luks.devices;
      canTouchEfiVariables = efi.canTouchEfiVariables;
      efiSupport        = cfg.efiSupport;
      efiRemovable      = cfg.efiInstallAsRemovable;
      secureBoot        = cfg.secureBoot;
      biosSupport       = cfg.biosSupport;
      biosDevice        = cfg.biosDevice;
      partitionIndex    = cfg.partitionIndex;
      force             = cfg.force;
      enrollConfig      = cfg.enrollConfig;
      style             = cfg.style;
      resolution        = cfg.resolution;
      maxGenerations    = if cfg.maxGenerations == null then 0 else cfg.maxGenerations;
      hostArchitecture  = pkgs.stdenv.hostPlatform.parsed.cpu;
      timeout           = if config.boot.loader.timeout == null then "no" else config.boot.loader.timeout;
      enableEditor      = cfg.enableEditor;
      extraConfig       = cfg.extraConfig;
      extraEntries      = cfg.extraEntries;
      additionalFiles   = cfg.additionalFiles;
      validateChecksums = cfg.validateChecksums;
      panicOnChecksumMismatch = cfg.panicOnChecksumMismatch;
    }
  );
in
{
  boot.loader.efi.canTouchEfiVariables = true;

  boot.loader.limine = {
    enable            = true;
    secureBoot.enable = true;
    maxGenerations    = 10;

    style = {
      # No custom wallpaper → nixpkgs default dark-gray NixOS background applies.
      wallpaperStyle = "stretched";

      interface = {
        resolution        = "1920x1080";
        branding          = "pod042";
        brandingColor     = "FFFFFF";  # white
        helpColor         = "777777";  # mid gray
        helpColorBright   = "AAAAAA";  # light gray
      };

      graphicalTerminal.font.scale = "2x2";
    };

    # Chainload Windows Boot Manager. Limine doesn't auto-detect other OSes.
    extraEntries = ''
      /Windows 11
          protocol: efi_chainload
          path: boot():/EFI/Microsoft/Boot/bootmgfw.efi
    '';
  };

  # Use our custom install script: standalone latest entry + Generations dropdown + Windows 11.
  system.build.installBootLoader = lib.mkForce (pkgs.replaceVarsWith {
    src         = ./limine-install-custom.py;
    isExecutable = true;
    replacements = {
      python3    = pkgs.python3.withPackages (p: [ p.psutil ]);
      configPath = limineInstallConfig;
    };
  });
}
