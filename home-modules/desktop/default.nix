{ pkgs, ... }:
{
  imports = [ 
    ./hyprland.nix
    ./waybar
    ./wofi
    ./mako
    ./wallpaper.nix
    ./gtk.nix
  ];

  home.packages = with pkgs; [
    # Desktop Managers
    blueman # Bluetooth Manager and Applet
    networkmanagerapplet # Network Applet
    loupe # Image Viewer
    celluloid # Video Viewver
    xfce.thunar # File Manager
    pavucontrol # Audio Manager
    keepassxc # Password Manager
    localsend # File Sharing Manager
    solaar # Logitech Manager
    razergenie # Razer Manager
    grim # Screenshot
    slurp # Screen Select
    wl-clipboard # Wayland Clipboard

    # Desktop Apps
    spotify
    signal-desktop
    discord
    obsidian
    aseprite
  ];

  # XDG Directories
  xdg.userDirs = {
    enable = true;
    createDirectories = false;
    download = "/home/neburion/Downloads";
    documents = "/home/neburion/.local/share/documents";
  };
}
