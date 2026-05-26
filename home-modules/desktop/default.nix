{ pkgs, config, ... }:

{
  imports = [
    ./wm
    ./art
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
    obsidian
  ];

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

  # XDG Directories
  xdg.userDirs = {
    enable = true;
    createDirectories = false;
    download = "${config.home.homeDirectory}/Downloads";
    documents = "${config.home.homeDirectory}/.local/share/documents"; # placeholder fix since some apps like to mess with the documents directory
  };
}
