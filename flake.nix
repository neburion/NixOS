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
  };

  outputs = { nixpkgs, home-manager, zen-browser, nvf, ... }:
  let
    # Reusable HM config applied to every user on every host
    sharedHMConfig = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = { inherit zen-browser nvf; };
      sharedModules = [
        nvf.homeManagerModules.default
        ({ pkgs, ... }: {
          home.packages = [ zen-browser.packages.${pkgs.system}.default ];
          programs.nvf.enable = true;
        })
      ];
    };

    # Helper to build a NixOS system
    mkSystem = { host, system ? "x86_64-linux", users }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit zen-browser nvf; };
        modules = [
          ./hosts/${host}/configuration.nix
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
          # add more pod042 users here
        };
      };

      pod153 = mkSystem {
        host = "pod153";
        users = {
          "9s" = import ./users/9s.nix;
          # add more pod153 users here
        };
      };
    };
  };
}
