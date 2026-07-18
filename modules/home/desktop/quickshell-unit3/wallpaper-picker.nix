{ pkgs, ... }:

# WallpaperPicker runs as a separate quickshell process spawned on demand
# (wallpaper.sh checks pgrep to avoid stacking instances). Uses awww to
# apply the selected wallpaper. Wallpaper library lives at
# ~/Pictures/wallpapers/ (seeded by assets.nix).

let
  wallpaperScript = pkgs.writeShellScriptBin "unit3-wallpaper" ''
    #!/usr/bin/env bash
    pgrep -f "WallpaperPicker.qml" && exit 0
    exec env QT_MEDIA_BACKEND=ffmpeg qs -p ~/.config/quickshell/Modules/WallpaperPicker.qml
  '';
in
{
  # awww is referenced by hyprland/auto-exec.nix (as the wallpaper daemon) and
  # by WallpaperPicker.qml (to apply the selected wallpaper). It's provided
  # implicitly by wallpaper/quickshell in the other preset — include it here.
  home.packages = [ wallpaperScript pkgs.awww ];

  wayland.windowManager.hyprland.settings."$wallpaperManager" = "unit3-wallpaper";
}
