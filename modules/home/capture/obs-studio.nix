{ ... }:

# OBS, stock.
#
# Screen and window capture go through the PipeWire portal that Hyprland
# already answers, so the wlroots capture plugin is not wanted here. NVENC
# comes from the driver in hosts/pod042/, not from anything on this side.
#
# No virtual camera. That needs v4l2loopback in the kernel and a system.nix
# beside this file, and it would be a downgrade for its obvious use: Discord
# encodes a camera for motion and a screen for text, and Chromium's V4L2
# capture collapses to 640x480 on Linux anyway. Screen share beats it.

{
  programs.obs-studio.enable = true;
}
