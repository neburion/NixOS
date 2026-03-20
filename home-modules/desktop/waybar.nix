{ pkgs, ... }:
{
  # Scripts
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
          echo ' Eco'
      fi
    '';
  };

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

  programs.waybar = {
    enable = true;

    settings = {
      mainBar = {
        "modules-right" = [ "tray" "group/hardware" ];
        "modules-center" = [ "hyprland/workspaces" ];
        "modules-left" = [ "clock" "custom/power-toggle" ];

        "group/hardware" = {
          orientation = "horizontal";
          modules = [ "pulseaudio" "custom/gpu" "memory" "cpu" "battery" ];
        };

        # Right
        battery = {
          format = "󰂀 {capacity}%";
          format-100 = "󰁹 {capacity}%";
          format-90 = "󰂂 {capacity}%";
          format-80 = "󰂁 {capacity}%";
          format-70 = "󰂀 {capacity}%";
          format-60 = "󰁿 {capacity}%";
          format-50 = "󰁾 {capacity}%";
          format-40 = "󰁽 {capacity}%";
          format-30 = "󰁼 {capacity}%";
          format-20 = "󰁻 {capacity}%";
          format-10 = "󰁺 {capacity}%";
          interval = 5;
          states = {
            "100" = 100;
            "90" = 90;
            "80" = 80;
            "70" = 70;
            "60" = 60;
            "50" = 50;
            "40" = 40;
            "30" = 30;
            "20" = 20;
            "10" = 10;
          };
          tooltip = false;
        };

        cpu = {
          format = "  {usage}%";
          interval = 2;
          states.critical = 90;
          tooltip = false;
        };

        "custom/gpu" = {
          exec = "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits";
          format = "󰢮 {}%";
          interval = 2;
        };

        memory = {
          format = "  {percentage}%";
          interval = 2;
          states.critical = 80;
          tooltip = false;
        };

        pulseaudio = {
          scroll-step = 5;
          max-volume = 150;
          format = "  {volume}%";
          format-bluetooth = "vol {volume}%";
          nospacing = 1;
          on-click = "pavucontrol";
          tooltip = false;
        };

        tray = {
          spacing = 10;
          tooltip = false;
        };

        # Center
        "hyprland/workspaces" = {
          format = "{icon}";
          format-icons = {
            default = "";
            active = "";
            empty = "";
          };
          persistent-workspaces = {
            "eDP-1" = [ 1 2 3 4 5 ];
            "HDMI-A-1" = [ 6 7 8 9 10 ];
          };
          tooltip = false;
        };

        # Left
        clock = {
          format = "{:%a %d %b - %I:%M %p}";
          tooltip = false;
        };

        "custom/power-toggle" = {
          exec = "~/.config/waybar/scripts/current-power.sh";
          interval = 10;
          format = "{text}";
          on-click = "~/.config/waybar/scripts/power-toggle.sh";
          tooltip = false;
        };
      };
    };

    style = ''
      @define-color background #111111;
      @define-color capsule #222222;
      @define-color text #ffffff;
      @define-color warning #dc381f;

      * {
          font-family: "FiraMono Nerd Font";
          font-weight: 800;
          font-size: 19px;
      }

      window#waybar {
          background: @background;
      }

      #clock,
      #custom-power-toggle,
      .modules-center,
      #hardware,
      #tray {
          background: @capsule;
          border-radius: 5px;
      }

      #clock,
      #custom-power-toggle {
          margin: 5px 0px 5px 5px;
      }

      .modules-center {
          margin: 5px 15px 5px 15px;
      }

      #hardware {
          margin: 5px 5px 5px 5px;
      }

      #tray {
          margin: 5px 0px 5px 5px;
      }

      #workspaces button,
      #clock,
      #custom-power-toggle,
      #hardware {
          color: @text;
      }

      #battery.warning,
      #battery.critical,
      #battery.urgent,
      #cpu.critical,
      #memory.critical {
          color: @warning;
      }

      #battery,
      #cpu,
      #memory,
      #pulseaudio,
      #tray {
          padding: 0px 7px;
      }

      #tray menu {
          color: @text;
          background: @capsule;
      }

      #workspaces button {
          padding: 0px 7px 0px 3px;
      }

      #custom-power-toggle,
      #clock {
          padding: 0px 5px;
      }
    '';
  };
}
