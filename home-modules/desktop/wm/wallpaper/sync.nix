{ pkgs, ... }:

let
  # Copies the current swww wallpaper to the SDDM shared path so the login
  # screen background matches the active desktop wallpaper.
  # Called by wofi-theme-switcher and waypaper's post_command.
  sddm-update-wallpaper = pkgs.writeShellScriptBin "sddm-update-wallpaper" ''
    wallpaper="$1"

    if [ -z "$wallpaper" ]; then
      wallpaper=$(${pkgs.swww}/bin/swww query 2>/dev/null \
        | head -1 \
        | awk -F'image: ' '{print $2}')
    fi

    [ -z "$wallpaper" ] && exit 0
    [ ! -f "$wallpaper" ] && exit 0

    cp "$wallpaper" /var/cache/sddm-wallpaper/current
  '';
in
{
  home.packages = [ sddm-update-wallpaper ];
}
