{
  lib,
  appimageTools,
  fetchurl,
  runtimeShell,
  inotify-tools,
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

    # Crash guard. Mod archives packed on Windows carry read-only directory
    # attributes, and the extractor preserves them; the launcher then calls
    # std::filesystem::remove_all on its Temp directory, which cannot unlink
    # entries inside a directory with no write bit, throws, and aborts
    # uncaught (ModDownloader.cpp -> remove_all -> __cxa_throw -> SIGABRT).
    # Once one such archive is extracted the launcher dies on every later
    # download, and the offending mod can never finish installing.
    #
    # So watch Temp and clear the read-only bit as files appear. inotifywait
    # re-arms each iteration, which is what picks up directories created after
    # the watch started. Runs outside the AppImage's FHS sandbox, on the host.
    mv $out/bin/${pname} $out/bin/.${pname}-fhs
    cat > $out/bin/${pname} <<'BBEOF'
#!@shell@
tmp="''${XDG_DATA_HOME:-$HOME/.local/share}/BBLauncher/Temp"
mkdir -p "$tmp"
(
  while true; do
    # attrib matters most: the extractor writes files first and applies the
    # read-only bit afterwards, so create/close_write alone sleeps through it.
    # -t 2 adds a poll so a missed event cannot wedge this permanently.
    @inotifywait@ -q -r -t 2 -e create,moved_to,close_write,attrib "$tmp" >/dev/null 2>&1
    # Only touch directories actually missing u+w. Chmod raises attrib events
    # of its own, so chmod -R unconditionally would feed this loop forever.
    find "$tmp" -type d ! -writable -exec chmod u+w {} + 2>/dev/null || true
  done
) &
watcher=$!
# Not exec: the trap must outlive the app so the watcher is never orphaned.
trap 'kill $watcher 2>/dev/null' EXIT
@fhs@ "$@"
BBEOF
    substituteInPlace $out/bin/${pname} \
      --replace-fail '@shell@'       '${runtimeShell}' \
      --replace-fail '@inotifywait@' '${lib.getExe' inotify-tools "inotifywait"}' \
      --replace-fail '@fhs@'         "$out/bin/.${pname}-fhs"
    chmod +x $out/bin/${pname}
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
