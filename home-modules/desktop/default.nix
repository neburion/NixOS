{ pkgs, config, zen-browser, ... }:

{
  imports = [
    ./wm
    ./art
    ./steam-launcher.nix
  ];

  home.packages = with pkgs; [
    # Desktop Utilities
    blueman              # Bluetooth Manager and Applet
    networkmanagerapplet # Network Applet
    loupe                # Image Viewer
    celluloid            # Video Player
    nautilus             # File Manager
    pavucontrol          # Audio Manager
    keepassxc            # Password Manager
    solaar               # Logitech Manager
    razergenie           # Razer Manager
    grim                 # Screenshot
    slurp                # Screen Select
    wl-clipboard         # Wayland Clipboard
    ente-desktop

    # Apps
    signal-desktop
    vesktop              # Discord client
    obsidian
  ] ++ [
    zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # xdg.userDirs writes ~/.config/user-dirs.dirs, which would otherwise
  # collide with the existing read-only home-manager symlink.
  xdg.configFile."user-dirs.dirs".force = true;

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "image/png"        = "org.gnome.Loupe.desktop";
      "image/jpeg"       = "org.gnome.Loupe.desktop";
      "image/gif"        = "org.gnome.Loupe.desktop";
      "image/webp"       = "org.gnome.Loupe.desktop";
      "image/svg+xml"    = "org.gnome.Loupe.desktop";
      "inode/directory"  = "org.gnome.Nautilus.desktop";
    };
  };

  # XDG Directories — creation is handled declaratively by dirs.nix
  xdg.userDirs = {
    enable = true;
    createDirectories = false;
    documents  = "${config.home.homeDirectory}/Docs";
    download   = "${config.home.homeDirectory}/Downloads";
    pictures   = "${config.home.homeDirectory}/Media/Image";
    videos     = "${config.home.homeDirectory}/Media/Video";
    music      = "${config.home.homeDirectory}/Media/Music";
    desktop    = "${config.home.homeDirectory}/.local/share/desktop";
    templates  = "${config.home.homeDirectory}/.local/share/templates";
    publicShare = "${config.home.homeDirectory}/.local/share/public";
  };
}
