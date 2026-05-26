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
  };
  outputs = { nixpkgs, home-manager, zen-browser, nvf, disko, ... }@inputs:
  let
    sharedHMConfig = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      extraSpecialArgs = { inherit zen-browser; };
      sharedModules = [
        nvf.homeManagerModules.default
      ];
    };
    mkSystem = { host, system ? "x86_64-linux", users }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit zen-browser nvf inputs; };
        modules = [
          disko.nixosModules.disko
          ./hosts/${host}/configuration.nix
          { nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ]; }
          home-manager.nixosModules.home-manager
          {
            home-manager = sharedHMConfig // {
              users = users;
            };
          }
        ];
      };
  in
  {
    nixosConfigurations = {
      pod042 = mkSystem {
        host = "pod042";
        users = {
          neburion = import ./users/neburion.nix;
          nululy   = import ./users/nululy.nix;
          qellyree = import ./users/qellyree.nix;
          shrine   = import ./users/shrine.nix;
        };
      };
    };
  };
}
