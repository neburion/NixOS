{ pkgs, ... }:

{
  home.packages = with pkgs; [
    blueman              # Bluetooth applet
    networkmanagerapplet # Network applet
    pavucontrol          # Audio control
    razergenie           # Razer device manager
    solaar               # Logitech device manager
  ];
}
