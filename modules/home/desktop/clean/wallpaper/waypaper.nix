{ pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    waypaper
  ];

  # waypaper config is runtime-owned: waypaper writes back to it when the user
  # picks a wallpaper, and wofi-theme-switcher updates the folder line.
  # Created here on first activation only — never overwritten by HM.
  home.activation.initWaypaperConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    CONFIG="$HOME/.config/waypaper/config.ini"
    if [ ! -f "$CONFIG" ]; then
      mkdir -p "$(dirname "$CONFIG")"
      cat > "$CONFIG" << 'EOF'
[Settings]
language = en
folder = ~/Media/Wallpapers/Gruvbox
monitors = All
wallpaper = ~/Media/Wallpapers/Gruvbox/Gruvbox-Face.png
show_path_in_tooltip = True
backend = awww
fill = fill
sort = name
color = #ffffff
subfolders = False
all_subfolders = False
show_hidden = False
show_gifs_only = False
zen_mode = True
post_command = sddm-update-wallpaper
number_of_columns = 3
swww_transition_type = any
swww_transition_step = 63
swww_transition_angle = 0
swww_transition_duration = 2
swww_transition_fps = 60
mpvpaper_sound = False
mpvpaper_options =
use_xdg_state = False
EOF
    fi
  '';
}
