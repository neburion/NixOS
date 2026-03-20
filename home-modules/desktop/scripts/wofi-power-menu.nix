{ pkgs, ... }:

pkgs.writeShellScriptBin "wofi-power-menu" ''
  shutdown="  Shutdown"
  reboot="  Reboot"
  suspend="  Suspend"
  lock="  Lock"
  logout="  Logout"

  chosen=$(printf "%s\n%s\n%s\n%s\n%s" \
    "$shutdown" "$reboot" "$suspend" "$lock" "$logout" \
    | wofi --show dmenu \
           --prompt ">" \
           --width "35%" \
           --height "30%" \
           --location center \
           --orientation vertical \
           --columns 1 \
           --normal_window \
           --layer overlay \
           --hide_scroll \
           --no_actions \
           --gtk_dark \
           --insensitive=false \
           --hide_search=false \
           --cache-file /dev/null)

  case "$chosen" in
    "$shutdown") systemctl poweroff ;;
    "$reboot")   systemctl reboot ;;
    "$suspend")  systemctl suspend ;;
    "$lock")     hyprlock ;;
    "$logout")   hyprctl dispatch exit ;;
  esac
''
