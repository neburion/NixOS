{ ... }:

{
  services.mako = {
    enable = true;

    settings = {
      font = "FiraMono Nerd Font 11";
      background-color = "#111111";
      text-color = "#ffffff";
      border-color = "#444444";
      border-size = 1;
      border-radius = 12;
      width = 300;
      height = 100;
      margin = "10";
      padding = "15";
      default-timeout = 5000;

      sort = "-time";
      max-history = 10;
      max-visible = 5;
      ignore-timeout = 0;
      layer = "overlay";
      anchor = "top-right";
      text-alignment = "left";
      progress-color = "over #89b4fa";
      on-button-left = "dismiss";
      on-button-middle = "none";
      on-button-right = "none";
    };
  };
  xdg.configFile."mako/config".force = true;
}
