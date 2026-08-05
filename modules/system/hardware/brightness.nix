{ pkgs, ... }:

# Unified brightness control for internal panel + DDC/CI-capable external monitors.
#
# - Internal panel: brightnessctl over sysfs (needs `video` group).
# - External monitors: ddcutil over i2c-dev (needs `i2c` group + hardware.i2c).
# - Kernel's ddcci-driver-linux is intentionally NOT used: since Linux 6.8 its
#   auto-probing path is broken (see dmesg WARNING from that module), so we drive
#   DDC/CI directly from userspace via ddcutil.
#
# brightness-all <arg>  applies a brightnessctl-style arg ("10%+", "10%-", "50%")
# to every display in parallel. Bus IDs are cached in $XDG_RUNTIME_DIR so the
# slow `ddcutil detect` only runs on the first invocation per session.

let
  brightness-all = pkgs.writeShellApplication {
    name = "brightness-all";
    runtimeInputs = with pkgs; [ brightnessctl ddcutil coreutils gawk gnused ];
    text = ''
      arg="''${1:?usage: brightness-all <brightnessctl arg, e.g. 10%+ / 10%- / 50%>}"

      brightnessctl -q s "$arg" || true

      val=$(printf '%s' "$arg" | sed -E 's/^([0-9]+)%[+-]?$/\1/')
      sign=$(printf '%s' "$arg" | sed -nE 's/^[0-9]+%([+-])$/\1/p')

      cache="''${XDG_RUNTIME_DIR:-/tmp}/brightness-all-buses"
      if [ ! -s "$cache" ]; then
        mkdir -p "$(dirname "$cache")"
        ddcutil detect --terse 2>/dev/null | awk '
          /^Display / { ok=1; next }
          /^Invalid/  { ok=0; next }
          ok && /I2C bus:/ { sub(".*i2c-",""); print }
        ' > "$cache" || true
      fi

      while read -r bus; do
        [ -n "$bus" ] || continue
        (
          case "$sign" in
            +|-)
              cur=$(ddcutil --bus "$bus" getvcp 10 --terse 2>/dev/null | awk '/^VCP 10/ { print $4 }')
              [ -n "$cur" ] || exit 0
              if [ "$sign" = "+" ]; then new=$((cur + val)); else new=$((cur - val)); fi
              [ "$new" -lt 0   ] && new=0
              [ "$new" -gt 100 ] && new=100
              ddcutil --bus "$bus" setvcp 10 "$new" >/dev/null 2>&1 || true
              ;;
            *)
              ddcutil --bus "$bus" setvcp 10 "$val" >/dev/null 2>&1 || true
              ;;
          esac
        ) &
      done < "$cache"
      wait
    '';
  };
in

{
  hardware.i2c.enable = true;

  environment.systemPackages = with pkgs; [
    brightnessctl
    ddcutil
    brightness-all
  ];
}
