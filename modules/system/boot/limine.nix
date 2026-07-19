{ config, pkgs, lib, ... }:

# Limine bootloader with sbctl-signed Secure Boot. Uses sbctl keys stored
# at /var/lib/sbctl (enrolled once at the firmware level).

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
      wallpapers = [];  # pure black; overrides the nixpkgs default NixOS wallpaper

      interface = {
        resolution        = "1920x1080";
        branding          = "pod042";
        brandingColor     = "FFFFFF";
        helpColor         = "777777";
        helpColorBright   = "AAAAAA";
      };

      graphicalTerminal = {
        background     = "00000000";  # fully opaque black (TTRRGGBB, TT=00 → opaque)
        marginGradient = 0;           # no vignette halo
      };
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
