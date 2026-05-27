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
    # Community Linux port of the official Anthropic Claude Desktop app.
    # Pinned to its own nixpkgs (unstable) because the Electron bundle is
    # finicky and the upstream flake builds against that.
    claude-desktop.url = "github:k3d3/claude-desktop-linux-flake";
  };
  outputs = { nixpkgs, home-manager, zen-browser, nvf, disko, claude-desktop, ... }@inputs:
  let
    sharedHMConfig = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      extraSpecialArgs = { inherit zen-browser claude-desktop; };
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
        };
      };

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
            environment.etc."nixrestore.sh".source         = ./installer/nixrestore.sh;
            nix.settings.experimental-features = [ "nix-command" "flakes" ];
          })
        ];
      };
    };
  };
}
