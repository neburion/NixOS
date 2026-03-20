{ ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      #
      # Programs
      #
      # Utils
      "$statusBar" = "waybar";
      "$notificationDaemon" = "mako";
      "$wallpaperEngine" = "sww-daemon";
      "$networkApplet" = "nm-applet";
      "$bluetoothApplet" = "blueman-applet";
      # Apps
      "$terminal" = "ghostty";
      "$appLauncher" = "wofi --show drun";
      "$themeSwitcher" = "wofi-theme-switcher";
      "$powerMenu" = "wofi-power-menu";
      "$fileManager" = "thunar";
      "$wallpaperManager" = "waypaper";
      "$audioManager" = "pavucontrol";
      "$taskManager" = "$terminal -e btop";
      "$webBrowser" = "zen";
      "$musicPlayer" = "spotify";
      "$notesApp" = "obsidian";
      "$messenger" = "signal";
      "$discord" = "discord";

      # Auto Exec
      exec-once = [
        "$statusBar"
        "$notificationDaemon"
        "$wallpaperEngine"
        "$wallpaperManager --restore"
        "$nautilus-fix"
        "$networkApplet"
        "$bluetoothApplet"
      ];

      # Monitors
      "$builtInMonitor" = "eDP-1";
      "$externalMonitor" = "HDMI-A-1";
      monitor = [
        "$builtInMonitor, 1920x1080@120, 0x0, 1"
        "$externalMonitor, 1920x1080@144, 1920x0, 1"
      ];

      #
      # Keybinds
      #
      "$mod" = "SUPER";
      bind = [
        # Apps
        "$mod, Return, exec, $terminal"
        "$mod, Space, exec, $appLauncher"
        "$mod SHIFT, Space, exec, $themeSwitcher"
        "$mod ALT, Space, exec, $powerMenu"
        "$mod, F, exec, $fileManager"
        "$mod, W, exec, $wallpaperManager"
        "$mod, A, exec, $audioManager"
        "$mod SHIFT, Escape, exec, $taskManager"
        "$mod, B, exec, $webBrowser"
        "$mod, M, exec, $musicPlayer"
        "$mod, N, exec, $notesApp"
        "$mod, D, exec, $discord"
        "$mod, G, exec, heroic"
        "$mod SHIFT, G, exec, steam"
        # Windows
        "$mod, Backspace, killactive"
        "$mod SHIFT, S, togglesplit"
        "$mod, T, togglefloating"
        "$mod, H, movefocus, l"
        "$mod, L, movefocus, r"
        "$mod, K, movefocus, u"
        "$mod, J, movefocus, d"
        "$mod SHIFT, H, movewindow, l"
        "$mod SHIFT, L, movewindow, r"
        "$mod SHIFT, K, movewindow, u"
        "$mod SHIFT, J, movewindow, d"
        # Workspaces
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"
        # Other
        # session
        "$mod, Escape, exec, hyprctl dispatch exit"
        # screenshot
        ''
          , Print, exec, sh -c 'f="/home/neburion/Media/Image/Screenshot/$(date +%Y-%m-%d_%H-%M-%S)_screenshot.png"; mkdir -p "$(dirname "$f")"; grim -g "$(slurp)" "$f"; wl-copy < "$f"'
        ''
        ''
          SHIFT, Print, exec, sh -c 'f="/home/neburion/Media/Image/Screenshot/$(date +%Y-%m-%d_%H-%M-%S)_screenshot.png"; mkdir -p "$(dirname "$f")"; grim "$f"; wl-copy < "$f"'
        ''
      ];
      # Windows (mouse)
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, movewindow"
      ];
      bindel = [
        # Audio
        "$mod, equal, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        "$mod, minus, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"

        # Laptop keys
        ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
        ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ",XF86MonBrightnessUp, exec, brightnessctl s 10%+"
        ",XF86MonBrightnessDown, exec, brightnessctl s 10%-"
      ];

      #
      # Looks
      #
      # Workspaces
      workspace = [
        "1, monitor:$builtInMonitor"
        "2, monitor:$builtInMonitor"
        "3, monitor:$builtInMonitor"
        "4, monitor:$builtInMonitor"
        "5, monitor:$builtInMonitor"
        "6, monitor:$externalMonitor"
        "7, monitor:$externalMonitor"
        "8, monitor:$externalMonitor"
        "9, monitor:$externalMonitor"
        "10, monitor:$externalMonitor"
      ];
      # Cursor
      "$cursorSize" = "15";
      "$cursorTime" = "2";
      "$cursorTheme" = "Adwaita";
      cursor = {
        inactive_timeout = "$cursorTime";
        no_hardware_cursors = true;
      };

      # Windows Looks
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 0;
        resize_on_border = true;
        layout = "dwindle";
        allow_tearing = false;
      };
      decoration = {
        rounding = 5;
        rounding_power = 1;
        active_opacity = 1.0;
        inactive_opacity = 1.0;
        shadow = {
          enabled = true;
          range = 4;
          render_power = 3;
          color = "rgba(1a1a1aee)";
        };
        blur = {
          enabled = true;
          size = 3;
          passes = 1;
          vibrancy = 0.1696;
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
      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };
      master = {
        new_status = "master";
      };
      misc = {
        disable_hyprland_logo = true;
      };
      xwayland = {
        force_zero_scaling = true;
      };

      #
      # Envirement Variables
      #
      env = [
        # Cursor
        "HYPRCURSOR_SIZE,$cursorSize"
        "XCURSOR_SIZE,$cursorSize"
        "HYPRCURSOR_THEME,$cursorTheme"
        "XCURSOR_THEME,$cursorTheme"

        # GTK Looks
        "GDK_SCALE,1"
        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_DESKTOP,Hyprland"

        # Nvidia
        "XDG_SESSION_TYPE,wayland"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        "__NV_PRIME_RENDER_OFFLOAD,1"
        "__GL_GSYNC_ALLOWED,1"
        "__GL_VRR_ALLOWED,0"
        "__VK_LAYER_NV_optimus,NVIDIA_only"
        "NVD_BACKEND,direct"
        "GDK_BACKEND,wayland,x11,*"
        "QT_QPA_PLATFORM,wayland;xcb"
        "SDL_VIDEODRIVER,wayland"
      ];

      # Window Rules
      windowrulev2 = [
        # Picture in Picture
        "float, title:(Picture-in-Picture)"
        "pin, title:(Picture-in-Picture)"
        "move 73% 72%, title:(Picture-in-Picture)"
        "keepaspectratio, title:(Picture-in-Picture)"
        "size 426 240, title:(Picture-in-Picture)"

        # Wayperper
        "float, class:(waypaper)"
        "size 800 540, class:(waypaper)"
        "center, class:(waypaper)"

        # Steam
        "tile, title:(Steam)"
      ];
    };
  };
}
