{ pkgs, ... }:

pkgs.writeShellScriptBin "wofi-power-menu" ''
  shutdown="Shutdown"
  reboot="Reboot"
  suspend="Suspend"
  lock="Lock"
  logout="Logout"

  chosen=$(printf "%s\n%s\n%s\n%s\n%s" \
    "$shutdown" "$reboot" "$suspend" "$lock" "$logout" \
    | wofi --show dmenu --width 300 --height 250 \
           --prompt "Power:" --cache-file /dev/null)

  case "$chosen" in
    "$shutdown") systemctl poweroff ;;
    "$reboot")   systemctl reboot ;;
    "$suspend")  systemctl suspend ;;
    "$lock")     hyprlock ;;
    "$logout")   hyprctl dispatch exit ;;
  esac
''
