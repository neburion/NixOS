''
  @define-color warning #dc381f;

  * {
      font-family: "FiraMono Nerd Font";
      font-weight: 800;
      font-size: 19px;
  }

  window#waybar {
      background: @background;
  }

  /*Capsules*/
  #clock,
  #custom-power-toggle,
  .modules-center,
  #hardware,
  #tray {
      background: @capsule;
      border-radius: 5px;
  }

  #clock,
  #custom-power-toggle { margin: 5px 0px 5px 5px; }

  .modules-center { margin: 5px 15px 5px 15px; }

  #hardware { margin: 5px 5px 5px 5px; }

  #tray { margin: 5px 0px 5px 5px; }

  #workspaces button,
  #clock,
  #custom-power-toggle,
  #hardware { color: @text; }

  #battery.warning,
  #battery.critical,
  #battery.urgent,
  #cpu.critical,
  #memory.critical { color: @warning; }

  #battery,
  #cpu,
  #memory,
  #custom-gpu,
  #pulseaudio,
  #tray { padding: 0px 7px; }

  #tray menu {
      color: @text;
      background: @capsule;
  }

  #workspaces button { padding: 0px 7px 0px 3px; }

  #custom-power-toggle,
  #clock { padding: 0px 5px; }
''
