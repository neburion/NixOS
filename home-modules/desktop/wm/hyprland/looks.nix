{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    # Workspaces
    workspace = [
      "1,  monitor:$builtInMonitor"
      "2,  monitor:$builtInMonitor"
      "3,  monitor:$builtInMonitor"
      "4,  monitor:$builtInMonitor"
      "5,  monitor:$builtInMonitor"
      "6,  monitor:$externalMonitor"
      "7,  monitor:$externalMonitor"
      "8,  monitor:$externalMonitor"
      "9,  monitor:$externalMonitor"
      "10, monitor:$externalMonitor"
    ];

    # Cursor
    "$cursorSize"  = "15";
    "$cursorTime"  = "2";
    "$cursorTheme" = "Adwaita";
    cursor = {
      inactive_timeout    = "$cursorTime";
      no_hardware_cursors = true;
    };

    # Windows Looks
    general = {
      gaps_in          = 5;
      gaps_out         = 10;
      border_size      = 0;
      resize_on_border = true;
      layout           = "dwindle";
      allow_tearing    = false;
    };

    decoration = {
      rounding         = 5;
      rounding_power   = 1;
      active_opacity   = 1.0;
      inactive_opacity = 1.0;
      shadow = {
        enabled      = true;
        range        = 4;
        render_power = 3;
        color        = "rgba(1a1a1aee)";
      };
      blur = {
        enabled  = true;
        size     = 3;
        passes   = 1;
        vibrancy = 0.17;
      };
    };

    animations = {
      enabled = true;
      bezier = [
        "easeOutQuint,   0.23, 1,    0.32, 1"
        "easeInOutCubic, 0.65, 0.05, 0.36, 1"
        "linear,         0,    0,    1,    1"
        "almostLinear,   0.5,  0.5,  0.75, 1"
        "quick,          0.15, 0,    0.1,  1"
      ];
      animation = [
        "global,        1, 10,   default"
        "border,        1, 5.39, easeOutQuint"
        "windows,       1, 4.79, easeOutQuint"
        "windowsIn,     1, 4.1,  easeOutQuint, popin 87%"
        "windowsOut,    1, 1.49, linear,       popin 87%"
        "fadeIn,        1, 1.73, almostLinear"
        "fadeOut,       1, 1.46, almostLinear"
        "fade,          1, 3.03, quick"
        "layers,        1, 3.81, easeOutQuint"
        "layersIn,      1, 4,    easeOutQuint, fade"
        "layersOut,     1, 1.5,  linear,       fade"
        "fadeLayersIn,  1, 1.79, almostLinear"
        "fadeLayersOut, 1, 1.39, almostLinear"
        "workspaces,    1, 1.94, almostLinear, fade"
        "workspacesIn,  1, 1.21, almostLinear, fade"
        "workspacesOut, 1, 1.94, almostLinear, fade"
        "zoomFactor,    1, 7,    quick"
      ];
    };

    dwindle  = {pseudotile = true; preserve_split = true;};
    master   = {new_status = "master";};
    misc     = {disable_hyprland_logo = true;};
    xwayland = {force_zero_scaling = true;};

    windowrulev2 = [
      # Picture in Picture
      "float,           title:(Picture-in-Picture)"
      "pin,             title:(Picture-in-Picture)"
      "move 73% 72%,    title:(Picture-in-Picture)"
      "keepaspectratio, title:(Picture-in-Picture)"
      "size 426 240,    title:(Picture-in-Picture)"

      # Wayperper
      "float,        class:(waypaper)"
      "size 800 540, class:(waypaper)"
      "center,       class:(waypaper)"

      # Steam
      "tile, title:(Steam)"
    ];
  };
}
