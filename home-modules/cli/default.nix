{ pkgs, config, ... }:

{
  imports = [
    ./fish.nix
    ./superfile.nix
    ./git.nix
    ./neovim
    ./dirs.nix
    ./claude
  ];

  home.packages = with pkgs; [
    p7zip
    unrar
    unzip
    btop
    fastfetch
    tree
    appimage-run
  ];

  home.activation.flatpakSetup =
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
    '';
}
