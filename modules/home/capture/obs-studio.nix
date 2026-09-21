{ pkgs, ... }:

# OBS, stock but for one wrapper.
#
# Screen and window capture go through the PipeWire portal that Hyprland
# already answers, so the wlroots capture plugin is not wanted here.
#
# No virtual camera. That needs v4l2loopback in the kernel and a system.nix
# beside this file, and it would be a downgrade for its obvious use: Discord
# encodes a camera for motion and a screen for text, and Chromium's V4L2
# capture collapses to 640x480 on Linux anyway. Screen share beats it.
#
# The wrapper is for NVENC. OBS dlopens libnvidia-encode.so.1 by bare name,
# and nothing puts the driver's directory on the search path, so it fails and
# the encoder list comes up with x264 and nothing else — on a machine with a
# 4060 in it. /run/opengl-driver/lib is where NixOS keeps the running
# driver's libraries; with it on the path obs-nvenc-test reports nvenc 13.0,
# Ada, one device. symlinkJoin rather than overrideAttrs so this stays a
# wrapper and does not rebuild OBS from source.
#
# `programs.obs-studio` from home-manager is not used: it only exists to run
# the same wrapper for plugins, and there are no plugins here.

let
  obs-studio = pkgs.symlinkJoin {
    name  = "obs-studio-${pkgs.obs-studio.version}";
    paths = [ pkgs.obs-studio ];

    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/obs --prefix LD_LIBRARY_PATH : /run/opengl-driver/lib
    '';
  };
in
{
  home.packages = [ obs-studio ];
}
