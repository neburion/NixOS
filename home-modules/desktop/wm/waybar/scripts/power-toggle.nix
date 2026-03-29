{ pkgs, ... }:

{
  home.file.".config/waybar/scripts/power-toggle.sh" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      current=$(${pkgs.power-profiles-daemon}/bin/powerprofilesctl get)
      if [ "$current" = "performance" ]; then
          ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set power-saver
          echo ' Eco'
      elif [ "$current" = "power-saver" ]; then
          ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced
          echo '󰾞 Balanced'
      else
          ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance
          echo '󰈸 Perf'
      fi
    '';
  };
}
