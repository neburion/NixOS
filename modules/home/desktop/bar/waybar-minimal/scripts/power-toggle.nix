{ pkgs, ... }:

{
  home.file.".config/waybar/scripts/power-toggle.sh" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      # Performance mode also disables Hyprland VFR (compositor stays at full
      # refresh) — pairs with NVreg_DynamicPowerManagement=0x00 to eliminate
      # the "lag after idle" feel on the external monitor.
      current=$(${pkgs.power-profiles-daemon}/bin/powerprofilesctl get)
      if [ "$current" = "performance" ]; then
          ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set power-saver
          ${pkgs.hyprland}/bin/hyprctl keyword misc:vfr 1 >/dev/null
          echo ' Eco'
      elif [ "$current" = "power-saver" ]; then
          ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced
          ${pkgs.hyprland}/bin/hyprctl keyword misc:vfr 1 >/dev/null
          echo '󰾞 Balanced'
      else
          ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance
          ${pkgs.hyprland}/bin/hyprctl keyword misc:vfr 0 >/dev/null
          echo '󰈸 Perf'
      fi
    '';
  };
}
