{ pkgs, ... }:

{
  home.file.".config/waybar/scripts/current-power.sh" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      current=$(${pkgs.power-profiles-daemon}/bin/powerprofilesctl get)
      if [ "$current" = "performance" ]; then
          echo '󰈸 Perf'
      elif [ "$current" = "balanced" ]; then
          echo '󰾞 Balance'
      else
          echo ' Eco'
      fi
    '';
  };
}
