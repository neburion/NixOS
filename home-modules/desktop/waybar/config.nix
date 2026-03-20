{ ... }:

{
  programs.waybar = {
    enable = true;

    settings.mainBar = {
      "modules-right"  = [ "tray" "group/hardware" ];
      "modules-center" = [ "hyprland/workspaces" ];
      "modules-left"   = [ "clock" "custom/power-toggle" ];

      "group/hardware" = {
        orientation = "horizontal";
        modules = [ "pulseaudio" "custom/gpu" "memory" "cpu" "battery" ];
      };

      battery = {
        format      = "󰂀 {capacity}%";
        format-100  = "󰁹 {capacity}%";
        format-90   = "󰂂 {capacity}%";
        format-80   = "󰂁 {capacity}%";
        format-70   = "󰂀 {capacity}%";
        format-60   = "󰁿 {capacity}%";
        format-50   = "󰁾 {capacity}%";
        format-40   = "󰁽 {capacity}%";
        format-30   = "󰁼 {capacity}%";
        format-20   = "󰁻 {capacity}%";
        format-10   = "󰁺 {capacity}%";
        interval    = 5;
        states = {
          "100" = 100;
          "90"  = 90;
          "80"  = 80;
          "70"  = 70;
          "60"  = 60;
          "50"  = 50;
          "40"  = 40;
          "30"  = 30;
          "20"  = 20;
          "10"  = 10;
        };
        tooltip = false;
      };

      cpu = {
        format          = "  {usage}%";
        interval        = 2;
        states.critical = 90;
        tooltip         = false;
      };

      "custom/gpu" = {
        exec     = "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits";
        format   = "󰢮 {}%";
        interval = 2;
      };

      memory = {
        format          = "  {percentage}%";
        interval        = 2;
        states.critical = 80;
        tooltip         = false;
      };

      pulseaudio = {
        scroll-step      = 5;
        max-volume       = 150;
        format           = "  {volume}%";
        nospacing        = 1;
        on-click         = "pavucontrol";
        tooltip          = false;
      };

      tray = {
        spacing = 10;
        tooltip = false;
      };

      "hyprland/workspaces" = {
        format = "{icon}";
        format-icons = {
          default = "";
          active  = "";
          empty   = "";
        };
        persistent-workspaces = {
          "eDP-1"    = [ 1 2 3 4 5 ];
          "HDMI-A-1" = [ 6 7 8 9 10 ];
        };
        tooltip = false;
      };

      clock = {
        format  = "{:%a %d %b - %I:%M %p}";
        tooltip = false;
      };

      "custom/power-toggle" = {
        exec     = "~/.config/waybar/scripts/current-power.sh";
        interval = 10;
        format   = "{text}";
        on-click = "~/.config/waybar/scripts/power-toggle.sh";
        tooltip  = false;
      };
    };
  };
}
