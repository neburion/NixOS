{ pkgs, lib, config, ... }:

# Screen dark, for the lock screen only.
#
# Floors the internal backlight and covers every monitor with a black image
# drawn by hyprlock itself. Deliberately NOT dpms, NOT ddcutil:
#   - dpms off/on left the MSI G321CU presenting a stale frame while the
#     output reported healthy, recoverable only by a forced mode change.
#   - DDC brightness writes are one-way in practice: the LG on DP-1 stopped
#     answering EDID reads mid-cycle, so the saved level could never be
#     written back and the panel stayed at 0.
# Neither monitor leaves its normal power state here. The externals go black
# because they are being sent black pixels, which is all "dark" ever needed.
#
# The cover is an `image` widget with `reload_time = 0`, meaning hyprlock
# re-reads it only on SIGUSR2. `lock-cover.png` is a symlink this script
# flips between a transparent PNG and an opaque black one; the signal makes
# hyprlock pick up the swap instantly.

let
  brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
  hypridle      = "${pkgs.hypridle}/bin/hypridle";
  pkill         = "${pkgs.procps}/bin/pkill";
  pidof         = "${pkgs.procps}/bin/pidof";

  mkCover = name: color: pkgs.runCommand "lock-cover-${name}.png" { } ''
    ${pkgs.imagemagick}/bin/magick -size 8x8 xc:${color} PNG32:$out
  '';

  coverBlack = mkCover "black" "black";
  coverClear = mkCover "clear" "none";

  coverLink = "${config.home.homeDirectory}/.config/hypr/lock-cover.png";

  screen-dark = pkgs.writeShellScriptBin "screen-dark" ''
    set -u

    black="${coverBlack}"
    clear="${coverClear}"
    link="${coverLink}"

    state="$HOME/.local/state/hypr/screen-dark"
    xdg="$state/xdg"
    pidfile="$state/hypridle.pid"

    # Armed only while the screen is dark, and torn down the moment it fires.
    # hyprlock exposes no "the user touched something" hook, so we borrow the
    # compositor's idle-notify protocol: idle for one second, and then the very
    # next input fires on-resume. Not a timer — nothing runs unless you pressed
    # the button.
    #
    # hypridle 0.1.7 advertises -c/--config but ignores it: it always searches
    # HOME/XDG_CONFIG_HOME/XDG_CONFIG_DIRS/etc/hypr and aborts if it finds
    # nothing. So hand this child its own XDG_CONFIG_HOME instead of dropping a
    # stray hypridle.conf into ~/.config/hypr where a future rebuild might fight
    # over it.
    arm_detector() {
      mkdir -p "$xdg/hypr"
      printf '%s\n' \
        'general {'  \
        '    ignore_dbus_inhibit = true' \
        '}' \
        'listener {' \
        '    timeout    = 1' \
        "    on-timeout = ${pkgs.coreutils}/bin/true" \
        "    on-resume  = $0 off" \
        '}' > "$xdg/hypr/hypridle.conf"

      XDG_CONFIG_HOME="$xdg" ${hypridle} >/dev/null 2>&1 &
      echo $! > "$pidfile"
    }

    # By recorded PID, checked against /proc comm — never by pkill pattern,
    # which is how a careless -f match once killed the calling shell.
    disarm_detector() {
      [ -r "$pidfile" ] || return 0
      pid=$(cat "$pidfile" 2>/dev/null || true)
      if [ -n "''${pid:-}" ] && [ "$(cat /proc/"$pid"/comm 2>/dev/null || true)" = "hypridle" ]; then
        kill "$pid" 2>/dev/null || true
      fi
      rm -f "$pidfile"
    }

    case "''${1:-on}" in
      on)
        # Lock screen only. Without hyprlock there is nothing drawing the
        # cover, and flooring the backlight would just blind you.
        ${pidof} hyprlock >/dev/null 2>&1 || exit 0

        ln -sfn "$black" "$link"
        ${pkill} -USR2 -x hyprlock >/dev/null 2>&1 || true
        ${brightnessctl} -q -s set 0 || true

        disarm_detector
        arm_detector
        ;;

      off)
        disarm_detector
        ln -sfn "$clear" "$link"
        ${pkill} -USR2 -x hyprlock >/dev/null 2>&1 || true
        # Quiet: a bare `off` with no prior `on` has nothing saved to restore,
        # and that is a normal no-op, not something to log about.
        # Quiet: a bare `off` with no prior `on` has nothing saved to restore,
        # and that is a normal no-op. `-r` prints the device table regardless
        # of -q, so both streams go to /dev/null.
        ${brightnessctl} -q -r >/dev/null 2>&1 || true
        ;;

      *)
        echo "usage: screen-dark [on|off]" >&2
        exit 1
        ;;
    esac
  '';
in
{
  home.packages = [ screen-dark ];

  # Super+D while locked. `bindl` is the "works while the session is locked"
  # variant — the same flag lid.nix relies on.
  wayland.windowManager.hyprland.settings.bindl = [
    "$mod, D, exec, screen-dark"
  ];

  # Always start clear. A rebuild while the cover happened to be black would
  # otherwise leave the next lock screen blacked out with nothing armed to
  # undo it.
  home.activation.resetLockCover = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$(dirname "${coverLink}")"
    ln -sfn "${coverClear}" "${coverLink}"
  '';
}
