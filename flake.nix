{
  description = "NixOS configuration";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
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
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { nixpkgs, home-manager, zen-browser, nvf, disko, ... }@inputs:
  let
    themes = import ./home-modules/themes;

    mkSystem = { host, system ? "x86_64-linux" }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit zen-browser nvf inputs; };
        modules = [
          disko.nixosModules.disko
          ./hosts/${host}/configuration.nix
          home-manager.nixosModules.home-manager
          ({ config, ... }: {
            home-manager = {
              useGlobalPkgs       = true;
              useUserPackages     = true;
              backupFileExtension = "backup";
              extraSpecialArgs = {
                inherit zen-browser;
                hostConfig = config.local.host;
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
