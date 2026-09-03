{ pkgs, lib, hostConfig, ... }:

# Lid handling that survives a config reload.
#
# Closing the lid ran `hyprctl keyword monitor eDP-1,disable`, which is runtime
# state and nothing more. Every Hyprland reload re-applies the static
# `monitor=eDP-1, …` line from hyprland.conf, so any rebuild with the lid shut
# switched the internal panel back on — and left it on, because the lid switch
# only fires on a transition and the lid was already closed.
#
# The override lives in a file that hyprland.conf sources, so a reload applies
# it as part of the same pass. `source` sorts after `monitor` in the generated
# config, so the disable lands last and wins.
#
# Deliberately a separate file rather than the monitor lines themselves: if
# lid.conf is missing or empty, every monitor line has already been applied and
# the panel is simply on, which is the old behaviour. Moving the monitor lines
# wholesale into a sourced file has a worse failure mode — Hyprland with no
# monitor lines falls back to each output's preferred mode, which on this
# machine means HDMI-A-1 jumps from 2560x1440@144 to its native 3840x2160@60.

let
  b = hostConfig.displays.monitors.builtin;
  enableLine  = "${b.name},${b.mode},${b.position},${b.scale}";
  disableLine = "${b.name},disable";

  lid-monitor = pkgs.writeShellApplication {
    name = "lid-monitor";
    runtimeInputs = with pkgs; [ hyprland coreutils ];
    text = ''
      conf="''${XDG_CONFIG_HOME:-$HOME/.config}/hypr/lid.conf"
      mkdir -p "$(dirname "$conf")"

      case "''${1:-}" in
        close)
          printf '%s\n' 'monitor=${disableLine}' > "$conf"
          hyprctl keyword monitor "${disableLine}" >/dev/null || true
          ;;
        open)
          : > "$conf"
          hyprctl keyword monitor "${enableLine}" >/dev/null || true
          ;;
        *)
          echo "usage: lid-monitor open|close" >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  home.packages = [ lid-monitor ];

  wayland.windowManager.hyprland.settings = {
    bindl = [
      ", switch:on:Lid Switch,  exec, ${lid-monitor}/bin/lid-monitor close"
      ", switch:off:Lid Switch, exec, ${lid-monitor}/bin/lid-monitor open"
    ];
  };

  # extraConfig, not `settings.source`. Home-manager emits every `source=` near
  # the top of the file — before the `monitor=` lines — so an override placed
  # there is immediately overwritten by the very line it exists to countermand.
  # extraConfig is appended last, which is the only position where a later
  # `monitor=eDP-1,disable` actually wins.
  wayland.windowManager.hyprland.extraConfig = ''
    source = ~/.config/hypr/lid.conf
  '';

  # Rewritten on every activation rather than seeded once, because ACPI is the
  # authority here and cannot drift — unlike the monitor transforms, where the
  # persisted state is the only record of a runtime choice and overwriting it
  # would destroy the answer. Reading the real switch also covers the case the
  # bindl cannot: the lid was already shut before this module existed, so no
  # transition will ever fire to tell us.
  home.activation.lidState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    conf="$HOME/.config/hypr/lid.conf"
    mkdir -p "$(dirname "$conf")"
    if grep -qi closed /proc/acpi/button/lid/*/state 2>/dev/null; then
      printf '%s\n' 'monitor=${disableLine}' > "$conf"
      # Converge now as well as on the next reload: activation ordering against
      # home-manager's own hyprland reload is not guaranteed, so the reload may
      # already have re-enabled the panel by the time this runs.
      if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        ${pkgs.hyprland}/bin/hyprctl keyword monitor "${disableLine}" >/dev/null 2>&1 || true
      fi
    else
      : > "$conf"
    fi
  '';
}
