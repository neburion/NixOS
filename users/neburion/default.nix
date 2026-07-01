{ pkgs, ... }:

{
  imports = [
    ./dirs.nix
  ];

  home-manager.users.neburion.imports = [
    ../../modules/base.nix
    ../../modules/shells/fish.nix
    ../../modules/cli/neovim
    ../../modules/cli/sperfile.nix
    ../../modules/cli/compression.nix
    ../../modules/cli/fastfetch.nix
    ../../modules/cli/btop.nix
    ../../modules/cli/packagers/flatpak.nix
    ../../modules/cli/packagers/appimage.nix
    ../../modules/cli/tree.nix

    ../../modules/desktop/wm/hyprland
    ../../modules/desktop/terminal/ghostty.nix
    ../../modules/desktop/terminal/notifications/mako
    ../../modules/desktop/terminal/launcher/wofi
    ../../modules/desktop/terminal/wallpaper/awww.nix
    ../../modules/desktop/clipboard/wl-clipboard.nix
    ../../modules/desktop/theming/gtk
    ../../modules/desktop/utils/nautilus.nix
    ../../modules/desktop/utils/loup.nix
    ../../modules/desktop/utils/celluloid.nix
    ../../modules/desktop/utils/pavucontrol.nix
    ../../modules/desktop/utils/libre-office.nix
    ../../modules/desktop/utils/peripherals/razer-genie.nix
    ../../modules/desktop/utils/peripherals/solaar.nix

    ../../modules/dev
    ../../modules/gaming
    ../../modules/art

    ../../modules/apps/zen-browser.nix
    ../../modules/apps/keepassxc.nix
    ../../modules/apps/spotify.nix
    ../../modules/apps/obsidian.nix
    ../../modules/apps/vesktop.nix
  ];

  users.users.neburion = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.fish;
  };

}
