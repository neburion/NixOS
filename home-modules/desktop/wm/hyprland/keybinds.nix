{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    "$mod" = "SUPER";
    bind = [
      # Apps
      "$mod,       Return, exec, $terminal"
      "$mod,       Space,  exec, $appLauncher"
      "$mod SHIFT, Space,  exec, $themeSwitcher"
      "$mod ALT,   Space,  exec, $powerMenu"
      "$mod,       F,      exec, $fileManager"
      "$mod,       W,      exec, $wallpaperManager"
      "$mod,       A,      exec, $audioManager"
      "$mod SHIFT, Escape, exec, $taskManager"
      "$mod,       B,      exec, $webBrowser"
      "$mod,       M,      exec, $musicPlayer"
      "$mod,       N,      exec, $notesApp"
      "$mod,       D,      exec, $discord"
      "$mod,       G,      exec, heroic"
      "$mod SHIFT, G,      exec, steam"

      # Windows
      "$mod,       Backspace, killactive"
      "$mod SHIFT, S,         togglesplit"
      "$mod,       T,         togglefloating"
      "$mod,       H,         movefocus, l"
      "$mod,       L,         movefocus, r"
      "$mod,       K,         movefocus, u"
      "$mod,       J,         movefocus, d"
      "$mod SHIFT, H,         movewindow, l"
      "$mod SHIFT, L,         movewindow, r"
      "$mod SHIFT, K,         movewindow, u"
      "$mod SHIFT, J,         movewindow, d"

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

      # Session
      "$mod, Escape, exec, hyprctl dispatch exit"

      # Screenshot
      ", Print, exec, sh -c 'f=\"$HOME/Media/Image/Screenshot/$(date +%Y-%m-%d_%H-%M-%S)_screenshot.png\"; mkdir -p \"$(dirname \"$f\")\"; grim -g \"$(slurp)\" \"$f\"; wl-copy < \"$f\"'"
      "SHIFT, Print, exec, sh -c 'f=\"$HOME//Media/Image/Screenshot/$(date +%Y-%m-%d_%H-%M-%S)_screenshot.png\"; mkdir -p \"$(dirname \"$f\")\"; grim \"$f\"; wl-copy < \"$f\"'"

      # Audio
      "$mod, equal, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
      "$mod, minus, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
    ];

    # Windows (mouse)
    bindm = [
      "$mod, mouse:272, movewindow"
      "$mod, mouse:273, movewindow"
    ];

    bindel = [
      # Laptop keys
      ",XF86AudioRaiseVolume,  exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
      ",XF86AudioLowerVolume,  exec, wpctl set-volume      @DEFAULT_AUDIO_SINK@ 5%-"
      ",XF86AudioMute,         exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      ",XF86AudioMicMute,      exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
      ",XF86MonBrightnessUp,   exec, brightnessctl s 10%+"
      ",XF86MonBrightnessDown, exec, brightnessctl s 10%-"
    ];
  };
}
