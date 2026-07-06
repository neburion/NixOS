{ pkgs, lib, ... }:

let
  inherit (import ../shared-config.nix { inherit lib; }) wofiArgs;
in
{
  home.packages = [
    (pkgs.writeShellScriptBin "wofi-power-menu" ''
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
        "$lock")     hyprlock ;;
        "$logout")   hypr-session-save; hyprctl dispatch exit ;;
      esac
    '')
  ];
}
