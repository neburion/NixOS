{ pkgs, lib, themes, ... }:

let
  # Copies the current awww wallpaper to the SDDM shared path so the login
  # screen background matches the active desktop wallpaper.
  # Called by theme-set and waypaper's post_command.
  sddm-update-wallpaper = pkgs.writeShellScriptBin "sddm-update-wallpaper" ''
    wallpaper="$1"

    if [ -z "$wallpaper" ]; then
      wallpaper=$(${pkgs.awww}/bin/awww query 2>/dev/null \
        | head -1 \
        | awk -F'image: ' '{print $2}')
    fi

    [ -z "$wallpaper" ] && exit 0
    [ ! -f "$wallpaper" ] && exit 0

    cp "$wallpaper" /var/cache/sddm-wallpaper/current
  '';

  wallpaperDirMap = lib.mapAttrs (n: t: t.wallpaperDir or n) themes;

  caseLines = lib.concatStringsSep "\n      " (lib.mapAttrsToList (n: dir:
    ''${n}) wallpaper_dir="${dir}" ;;''
  ) wallpaperDirMap);
in
{
  home.packages = [ sddm-update-wallpaper ];

  themeHooks.wallpaper = pkgs.writeShellScript "theme-hook-wallpaper" ''
    theme="$1"
    wallpaper_dir="$theme"
    case "$theme" in
      ${caseLines}
      *) ;;
    esac
    wallpaper=$(${pkgs.findutils}/bin/find \
      "$HOME/Media/Wallpapers/$wallpaper_dir" -maxdepth 1 \
      -regex '.*\.\(png\|jpg\|jpeg\|gif\|webp\)$' 2>/dev/null \
      | ${pkgs.coreutils}/bin/shuf \
      | ${pkgs.coreutils}/bin/head -1 || true)
    if [ -n "$wallpaper" ] && [ -f "$wallpaper" ]; then
      ${pkgs.coreutils}/bin/mkdir -p "$HOME/.local/state/quickshell"
      printf '%s\n' "$wallpaper" > "$HOME/.local/state/quickshell/wallpaper"
      ${pkgs.coreutils}/bin/cp "$wallpaper" /var/cache/sddm-wallpaper/current 2>/dev/null || true
      ${pkgs.procps}/bin/pkill mpvpaper 2>/dev/null || true
      ${pkgs.awww}/bin/awww img "$wallpaper" --transition-type fade 2>/dev/null || true
    fi
  '';
}
