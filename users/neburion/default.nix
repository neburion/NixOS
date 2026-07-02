{ pkgs, ... }:

{
  imports = [
    ./dirs.nix
  ];

  home-manager.users.neburion.imports = [
    ../../modules/home/base.nix
    ../../modules/home/cli/fonts.nix
    ../../modules/home/cli/shell/fish.nix
    ../../modules/home/cli/neovim
    ../../modules/home/cli/superfile.nix
    ../../modules/home/cli/compression.nix
    ../../modules/home/cli/fastfetch.nix
    ../../modules/home/cli/btop.nix
    ../../modules/home/cli/packager/flatpak.nix
    ../../modules/home/cli/packager/appimage.nix
    ../../modules/home/cli/tree.nix

    ../../modules/home/desktop/wm/hyprland
    ../../modules/home/desktop/bar/waybar
    ../../modules/home/desktop/terminal/ghostty.nix
    ../../modules/home/desktop/notifications/mako
    ../../modules/home/desktop/launcher/wofi
    ../../modules/home/desktop/wallpaper/awww
    ../../modules/home/desktop/clipboard/wl-clipboard.nix
    ../../modules/home/desktop/theming/gtk
    ../../modules/home/desktop/utils/nautilus.nix
    ../../modules/home/desktop/utils/loupe.nix
    ../../modules/home/desktop/utils/celluloid.nix
    ../../modules/home/desktop/utils/pavucontrol.nix
    ../../modules/home/desktop/utils/libre-office.nix
    ../../modules/home/desktop/utils/peripherals/razer-genie.nix
    ../../modules/home/desktop/utils/peripherals/solaar.nix

    ../../modules/home/dev
    ../../modules/home/gaming
    ../../modules/home/art

    ../../modules/home/apps/zen-browser.nix
    ../../modules/home/apps/keepassxc.nix
    ../../modules/home/apps/spotify.nix
    ../../modules/home/apps/obsidian.nix
    ../../modules/home/apps/vesktop.nix
    ../../modules/home/apps/signal.nix
  ];

  users.users.neburion = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.fish;
  };

}
