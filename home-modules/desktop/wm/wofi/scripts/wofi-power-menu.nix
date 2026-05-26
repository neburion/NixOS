{ pkgs, wofiArgs, ... }:

pkgs.writeShellScriptBin "wofi-power-menu" ''
  shutdown="  Shutdown"
  reboot="  Reboot"
  suspend="  Suspend"
  lock="  Lock"
  logout="  Logout"

  chosen=$(printf "%s\n%s\n%s\n%s\n%s" \
    "$shutdown" "$reboot" "$suspend" "$lock" "$logout" \
    | wofi --show dmenu ${wofiArgs} --cache-file /dev/null)

  case "$chosen" in
    "$shutdown") hypr-session-save; systemctl poweroff ;;
    "$reboot")   hypr-session-save; systemctl reboot ;;
    "$suspend")  systemctl suspend ;;
    "$lock")     busctl call org.freedesktop.DisplayManager \
                   /org/freedesktop/DisplayManager/Seat0 \
                   org.freedesktop.DisplayManager.Seat \
                   SwitchToGreeter ;;
    "$logout")   hypr-session-save; hyprctl dispatch exit ;;
  esac
''
