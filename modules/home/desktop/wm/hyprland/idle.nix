{ pkgs, config, ... }:

# Idle staircase: dim → lock → panels off.
#
# Timings are deliberately staggered so each step is recoverable before the
# next one lands: the dim is the warning shot, the lock is the commitment, and
# DPMS off is what actually saves power. `$mod, Escape` (see keybinds.nix) locks
# immediately; hypridle keeps counting from your last input either way, so a
# manual lock still goes dark on its own a minute later.
#
# lock_cmd is guarded with pidof: `loginctl lock-session` fires once per lock
# request, but a second request (lid, dbus, manual) while hyprlock is already up
# would otherwise stack a second instance on the session-lock surface.

let
  hyprctl      = "${config.wayland.windowManager.hyprland.finalPackage}/bin/hyprctl";
  hyprlock     = "${pkgs.hyprlock}/bin/hyprlock";
  brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
  loginctl     = "${pkgs.systemd}/bin/loginctl";
  pidof        = "${pkgs.procps}/bin/pidof";
in
{
  services.hypridle = {
    enable = true;

    settings = {
      general = {
        lock_cmd         = "${pidof} hyprlock || ${hyprlock}";
        before_sleep_cmd = "${loginctl} lock-session";
        after_sleep_cmd  = "${hyprctl} dispatch dpms on";

        # Respect dbus idle inhibitors, so fullscreen video and Steam's
        # "playing" inhibit keep the panel alive without any special-casing.
        ignore_dbus_inhibit = false;
      };

      listener = [
        # 4 min — dim the internal panel. Externals are left alone: ddcutil
        # round-trips take seconds per bus and DPMS off blanks them anyway.
        {
          timeout   = 240;
          on-timeout = "${brightnessctl} -s set 10%";
          on-resume  = "${brightnessctl} -r";
        }

        # 7 min — lock. Goes through logind so the session is genuinely marked
        # locked (hypridle then runs lock_cmd), not just visually covered.
        {
          timeout    = 420;
          on-timeout = "${loginctl} lock-session";
        }

        # 8 min — panels off. Always after the lock, never with it: blanking
        # mid-launch is what leaves hyprlock rendering to a dead output and
        # gives you the "black screen that ignores my password" wake-up.
        {
          timeout    = 480;
          on-timeout = "${hyprctl} dispatch dpms off";
          on-resume  = "${hyprctl} dispatch dpms on";
        }
      ];
    };
  };
}
