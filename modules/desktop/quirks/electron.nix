{ ... }:

{
  # Obsidian (home-modules/desktop/apps/productivity.nix) pulls in electron 38 on 25.11.
  nixpkgs.config.permittedInsecurePackages = [
    "electron-38.8.4"
  ];
}
