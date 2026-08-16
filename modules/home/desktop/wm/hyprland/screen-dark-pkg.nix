{ pkgs, homeDirectory }:

# The screen-dark script and its two cover images, defined once so that
# screen-dark.nix (keybind, activation) and both hyprlock.nix files (onclick)
# all point at the *same* store path. Referring to it by bare name instead
# would make it depend on whatever PATH hyprlock happened to inherit.

let
  brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
  hypridle      = "${pkgs.hypridle}/bin/hypridle";
  pkill         = "${pkgs.procps}/bin/pkill";
  pidof         = "${pkgs.procps}/bin/pidof";

  # Full-resolution rather than an 8x8 scaled up: whether hyprlock upscales a
  # tiny source to `size` is an assumption, and a cover that silently renders
  # as an 8px dot in the middle of the screen looks exactly like "nothing
  # happened". Solid colour, so both files are a couple of KB regardless.
  #
  # Black is PNG24 — no alpha channel to misinterpret. Clear needs one, and
  # matches dimensions so swapping between them cannot shift the layout.
  coverBlack = pkgs.runCommand "lock-cover-black.png" { } ''
    ${pkgs.imagemagick}/bin/magick -size 3840x2160 xc:black PNG24:$out
  '';

  coverClear = pkgs.runCommand "lock-cover-clear.png" { } ''
    ${pkgs.imagemagick}/bin/magick -size 3840x2160 xc:none PNG32:$out
  '';

  coverLink = "${homeDirectory}/.config/hypr/lock-cover.png";

  script = pkgs.writeShellScriptBin "screen-dark" ''
    set -u

    black="${coverBlack}"
    clear="${coverClear}"
    link="${coverLink}"

    state="$HOME/.local/state/hypr/screen-dark"
    xdg="$state/xdg"
    pidfile="$state/hypridle.pid"
    log="$state/screen-dark.log"

    mkdir -p "$state"

    # Invoked from a lock screen and from a keybind, i.e. two places where
    # nobody will ever see stdout. Without this, "nothing happened" is
    # unfalsifiable.
    say() { printf '%s %s\n' "$(${pkgs.coreutils}/bin/date -Is)" "$*" >> "$log"; }

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

      XDG_CONFIG_HOME="$xdg" ${hypridle} >>"$state/hypridle.log" 2>&1 &
      echo $! > "$pidfile"
      say "detector armed pid=$(cat "$pidfile")"
    }

    # By recorded PID, checked against /proc comm — never by pkill pattern,
    # which is how a careless -f match once killed the calling shell.
    disarm_detector() {
      [ -r "$pidfile" ] || return 0
      pid=$(cat "$pidfile" 2>/dev/null || true)
      if [ -n "''${pid:-}" ] && [ "$(cat /proc/"$pid"/comm 2>/dev/null || true)" = "hypridle" ]; then
        kill "$pid" 2>/dev/null || true
        say "detector disarmed pid=$pid"
      fi
      rm -f "$pidfile"
    }

    case "''${1:-on}" in
      on)
        say "on: requested"

        # Lock screen only. Without hyprlock there is nothing drawing the
        # cover, and flooring the backlight would just blind you.
        if ! ${pidof} hyprlock >/dev/null 2>&1; then
          say "on: no hyprlock running, nothing to do"
          exit 0
        fi

        ln -sfn "$black" "$link"
        ${pkill} -USR2 -x hyprlock >/dev/null 2>&1 || say "on: SIGUSR2 failed"
        ${brightnessctl} -q -s set 0 >/dev/null 2>&1 || say "on: backlight floor failed"

        disarm_detector
        arm_detector
        say "on: done"
        ;;

      off)
        say "off: requested"
        disarm_detector
        ln -sfn "$clear" "$link"
        ${pkill} -USR2 -x hyprlock >/dev/null 2>&1 || true
        # `-r` prints the device table regardless of -q, and a bare `off` with
        # no prior `on` has nothing saved — both are normal, both are noise.
        ${brightnessctl} -q -r >/dev/null 2>&1 || true
        say "off: done"
        ;;

      *)
        echo "usage: screen-dark [on|off]" >&2
        exit 1
        ;;
    esac
  '';
in
{
  inherit script coverBlack coverClear coverLink;
}
