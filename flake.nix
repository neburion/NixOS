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
    mkSystem = { host, system ? "x86_64-linux" }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit zen-browser nvf inputs; };
        modules = [
          disko.nixosModules.disko
          ./hosts/${host}/configuration.nix
          { nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ]; }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = { inherit zen-browser; };
            home-manager.sharedModules = [ nvf.homeManagerModules.default ];
          }
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
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          ({ pkgs, ... }: {
            environment.systemPackages = with pkgs; [
              git rclone p7zip jq
              (pkgs.writeShellScriptBin "nixinstall"
                (builtins.readFile ./installer/nixinstall.sh))
            ];
            environment.etc."nixinstall-disko.nix".source = ./installer/disko.nix;
            nix.settings.experimental-features = [ "nix-command" "flakes" ];
          })
        ];
      };
    };
  };
}
