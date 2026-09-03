{
  description = "NixOS configuration";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Rolling channel for cherry-picked packages that need to be fresher
    # than the release channel. Exposed via overlay as `pkgs.unstable.<name>`.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nvf = {
      url = "github:notashelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ── apps ────────────────────────────────────────────────────────────────
    # Projects that live in their own repos and are deployed by
    # modules/system/apps/platform.nix, which reads the app.json at each root.
    # `flake = false` because they contain no Nix at all — that is the point.
    #
    # Updating one is `nix flake update <name>`, which moves the pin and puts
    # the new version in the next system generation, rollback included.
    media-tracker = {
      url = "github:neburion/media-tracker";
      flake = false;
    };
    elden-ring-tracker = {
      url = "github:neburion/elden-ring-tracker";
      flake = false;
    };
  };

  outputs = { nixpkgs, home-manager, zen-browser, nvf, disko, spicetify-nix, sops-nix, ... }@inputs:
  let
    themes = import ./modules/home/themes;

    mkSystem = { host, system ? "x86_64-linux", withHomeManager ? true }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit zen-browser nvf inputs; };
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          { networking.hostName = host; }
          { nixpkgs.overlays = [(final: prev: {
              canon-cups-ufr2 = final.callPackage ./modules/system/services/printing/canon-cups-ufr2/package.nix {};
              unstable = import inputs.nixpkgs-unstable {
                inherit system;
                config.allowUnfree = true;
              };
            })]; }
          ./hosts/${host}/configuration.nix
        ] ++ nixpkgs.lib.optionals withHomeManager [
          home-manager.nixosModules.home-manager
          ({ config, ... }: {
            home-manager = {
              useGlobalPkgs       = true;
              useUserPackages     = true;
              backupFileExtension = "backup";
              extraSpecialArgs = {
                inherit zen-browser;
                # Headless hosts don't declare displays/backlight; fall back
                # to {} so they don't need stub option declarations.
                hostConfig = {
                  displays  = { monitors = config.displays.monitors or {}; };
                  backlight = config.backlight or {};
                };
              };
              sharedModules = [
                nvf.homeManagerModules.default
                spicetify-nix.homeManagerModules.default
                { _module.args.themes = themes; }
              ];
            };
          })
        ];
      };
  in
  {
    nixosConfigurations = {
      pod042 = mkSystem { host = "pod042"; };

      # Headless home server (old i5 laptop). Currently: family print/scan
      # web UI. Planned: network-wide DNS ad blocker and other LAN services.
      home-server = mkSystem { host = "home-server"; };

      # Headless personal server (old laptop) — my own self-hosted services,
      # kept separate from the family-facing home-server. Skeleton for now.
      personal-server = mkSystem { host = "personal-server"; };

      # Live USB installer — build with:
      #   nix build .#nixosConfigurations.installer.config.system.build.isoImage
      # Flash to USB with:
      #   nixflash /dev/sdX
      installer = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./hosts/installer/configuration.nix ];
      };
    };
  };
}
