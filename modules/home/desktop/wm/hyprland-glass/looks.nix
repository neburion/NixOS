{ ... }:

# glass looks. Forked from ../hyprland/looks.nix:
#   - gaps 6/12 and rounding 10, to sit with a 12px-cornered floating bar
#   - the shadow colour is a literal; the base reads it from hypr/theme.conf,
#     which only exists when ../hyprland/themes.nix is imported, and it isn't
#   - window blur is stronger (2 passes), since translucent chrome over
#     lightly-blurred windows reads as muddy rather than as glass


{
  wayland.windowManager.hyprland.settings = {
    # Workspaces
    workspace = [
      "1,  monitor:$secondaryMonitor"
      "2,  monitor:$secondaryMonitor"
      "3,  monitor:$secondaryMonitor"
      "4,  monitor:$secondaryMonitor"
      "5,  monitor:$secondaryMonitor"
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
      gaps_in          = 6;
      gaps_out         = 12;
      border_size      = 0;
      resize_on_border = true;
      layout           = "dwindle";
      allow_tearing    = false;
    };

    decoration = {
      rounding         = 10;
      # 1.0 is documented as "a triangular corner" — it is the sharpest value
      # in the range, not the roundest, which is why the corners read as cut
      # rather than curved. 2.0 is a true circle, matching the plain `radius`
      # the QML panels use, so windows and shell chrome share one geometry.
      rounding_power   = 2.0;
      active_opacity   = 1.0;
      inactive_opacity = 1.0;
      shadow = {
        enabled      = true;
        range        = 4;
        render_power = 3;
        # Literal, not sourced from hypr/theme.conf — glass has one palette.
        color        = "rgba(05070Bee)";
      };
      # Window blur. The bar's blur is separate — see layer-rules.nix.
      blur = {
        enabled     = true;
        size        = 6;
        passes      = 2;
        vibrancy    = 0.20;
        noise       = 0.008;
        brightness  = 1.0;
        contrast    = 1.0;
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

    dwindle  = {preserve_split = true;};
    master   = {new_status = "master";};
    misc     = {disable_hyprland_logo = true;};
    xwayland = {force_zero_scaling = true;};
  };
}
