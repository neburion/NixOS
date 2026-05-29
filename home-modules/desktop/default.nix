{ pkgs, config, lib, zen-browser, ... }:

{
  imports = [
    ./wm
    ./art
  ];

  # `programs.steam.enable` installs steam.desktop system-wide, which puts Steam
  # in every desktop user's app menu. Shadow it with a NoDisplay=true entry in
  # the user's nix profile so it's hidden by default; the home-manager gaming
  # module sets `gamingLauncher.enable = true` to opt out of the shadow.
  options.gamingLauncher.enable = lib.mkEnableOption
    "showing system-wide gaming launchers (Steam, ...) in the application menu";

  config = {
    xdg.desktopEntries.steam = lib.mkIf (!config.gamingLauncher.enable) {
      name = "Steam";
      noDisplay = true;
      exec = "steam %U";
      type = "Application";
    };

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
  };
}
