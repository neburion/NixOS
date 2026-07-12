{
  description = "NixOS configuration";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
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
    lanzaboote = {
      url = "github:nix-community/lanzaboote/001e560fffc8f0235e9db20ebeb4ccde0ade1caf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { nixpkgs, home-manager, zen-browser, nvf, disko, ... }@inputs:
  let
    themes = import ./modules/home/themes;

    mkSystem = { host, system ? "x86_64-linux", withHomeManager ? true }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit zen-browser nvf inputs; };
        modules = [
          disko.nixosModules.disko
          { nixpkgs.overlays = [(final: prev: {
              canon-cups-ufr2 = final.callPackage ./modules/system/canon-cups-ufr2/package.nix {};
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
                hostConfig = {
                  displays = {
                    monitors = config.displays.monitors;
                  };
                };
              };
              sharedModules = [
                nvf.homeManagerModules.default
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

      # Headless family print server (old i5 laptop).
      print-server = mkSystem { host = "print-server"; };

      # Live USB installer — build with:
      #   nix build .#nixosConfigurations.installer.config.system.build.isoImage
      # Flash to USB with:
      #   nixflash /dev/sdX
      installer = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./iso/configuration.nix ];
      };
    };
  };
}
