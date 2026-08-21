{
  lib,
  appimageTools,
  fetchurl,
}:

# BB_Launcher — launcher and mod manager built solely for Bloodborne on
# shadPS4. Handles the things the generic Qt launcher has no opinion about:
# a mod manager that merges into dvdroot_ps4, the 60fps sound fix, automatic
# backup saves, per-game patch selection and control remapping.
#
# Upstream ships a Linux AppImage and nothing else — no nixpkgs package, no
# flatpak (unlike Sober next door, which is why that one is installed through
# flathub instead). So this wraps the AppImage rather than building from
# source: it is a Qt app with vendored submodules, and the release binary
# already carries its whole Qt runtime under usr/lib.
#
# The `-Downloader` variant, which is the one that works here. Both builds are
# the same program; the difference is `USE_WEBENGINE`, an upstream CMake option
# described as "Use WebEngine to enable downloading non-premium mods on Linux".
# Without it the built-in mod downloader refuses every Nexus fetch with
# "Non-premium downloads not supported on this build" — Nexus makes free
# accounts click through a browser page, and only the WebEngine build can drive
# it. That costs ~110 MB of bundled Qt WebEngine over the plain build; a mod
# manager that cannot download mods is the worse trade.
#
# Its separate "Manage Builds" feature, which fetches shadPS4 releases, is the
# part to leave alone: those binaries are unpatched and will not run on NixOS.
# Point it at the `shadps4` from this same profile instead
# (Options -> shadPS4 executable).

let
  pname = "bb-launcher";
  version = "16.10";

  src = fetchurl {
    url = "https://github.com/rainmakerv3/BB_Launcher/releases/download/Release${version}/BB_Launcher-qt-Downloader.AppImage";
    hash = "sha256-iWCiDbqSk+0LeJRH7OnvfYtmTCwT6PjX3B2yDyHG/mI=";
  };

  # The AppImage carries its own .desktop and icon; lift them out so the app
  # reaches the launcher menu instead of living as a bare binary.
  contents = appimageTools.extractType2 { inherit pname version src; };
in

appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm444 ${contents}/BBLauncher.desktop \
      $out/share/applications/BBLauncher.desktop
    install -Dm444 ${contents}/usr/share/icons/hicolor/256x256/apps/BBIcon.png \
      $out/share/icons/hicolor/256x256/apps/BBIcon.png
    substituteInPlace $out/share/applications/BBLauncher.desktop \
      --replace-fail 'Exec=BB_Launcher' 'Exec=${pname}'
  '';

  meta = {
    description = "Launcher and mod manager for Bloodborne on shadPS4";
    homepage = "https://github.com/rainmakerv3/BB_Launcher";
    license = lib.licenses.gpl3Only;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
