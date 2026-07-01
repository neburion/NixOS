{ pkgs, ... }:

{
  imports = [
    ./dirs.nix
  ];

  home-manager.users.neburion.imports = [
    ../../home-modules/base.nix
    ../../home-modules/shells/fish.nix
    ../../home-modules/cli/neovim
    ../../home-modules/cli/sperfile.nix
    ../../home-modules/cli/compression.nix
    ../../home-modules/cli/fastfetch.nix
    ../../home-modules/cli/btop.nix
    ../../home-modules/cli/packagers/flatpak.nix
    ../../home-modules/cli/packagers/appimage.nix
    ../../home-modules/cli/tree.nix

    ../../home-modules/desktop/wm/hyprland
    ../../home-modules/desktop/terminal/ghostty.nix
    ../../home-modules/desktop/terminal/notifications/mako
    ../../home-modules/desktop/terminal/launcher/wofi
    ../../home-modules/desktop/terminal/wallpaper/awww.nix
    ../../home-modules/desktop/clipboard/wl-clipboard.nix
    ../../home-modules/desktop/theming/gtk
    ../../home-modules/desktop/utils/nautilus.nix
    ../../home-modules/desktop/utils/loup.nix
    ../../home-modules/desktop/utils/celluloid.nix
    ../../home-modules/desktop/utils/pavucontrol.nix
    ../../home-modules/desktop/utils/libre-office.nix
    ../../home-modules/desktop/utils/peripherals/razer-genie.nix
    ../../home-modules/desktop/utils/peripherals/solaar.nix

    ../../home-modules/dev
    ../../home-modules/gaming
    ../../home-modules/art

    ../../home-modules/apps/zen-browser.nix
    ../../home-modules/apps/keepassxc.nix
    ../../home-modules/apps/spotify.nix
    ../../home-modules/apps/obsidian.nix
    ../../home-modules/apps/vesktop.nix
  ];

  users.users.neburion = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.fish;
  };

}
