{ ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      monitor = [
        "eDP-1,    1920x1080@120, 0x0,    1"
        "HDMI-A-1, 1920x1080@144, 1920x0, 1"
      ];

      exec-once = [
        "ghostty --class=shrine -e sh -c 'shrine-shell; hyprctl dispatch exit'"
      ];

      env = [
        "XDG_SESSION_TYPE,wayland"
        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_DESKTOP,Hyprland"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        "NVD_BACKEND,direct"
        "GDK_BACKEND,wayland,x11,*"
        "QT_QPA_PLATFORM,wayland;xcb"
      ];

      general = {
        gaps_in     = 0;
        gaps_out    = 0;
        border_size = 0;
      };

      decoration = {
        rounding = 0;
        blur.enabled   = false;
        shadow.enabled = false;
      };

      animations.enabled = false;

      misc = {
        disable_hyprland_logo    = true;
        disable_splash_rendering = true;
        background_color         = "0x000000";
        exit_without_warnings    = true;
      };

      windowrulev2 = [
        "fullscreen, class:(shrine)"
        "noblur,     class:(shrine)"
      ];

      bind = [
        # Emergency exit in case something goes wrong
        "SUPER, Escape, exec, hyprctl dispatch exit"
      ];
    };
  };
}
