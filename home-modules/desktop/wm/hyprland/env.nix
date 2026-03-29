{ ... }:

{
  wayland.windowManager.hyprland.settings = {
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
      #"__NV_PRIME_RENDER_OFFLOAD,1"
      "__GL_GSYNC_ALLOWED,1"
      "__GL_VRR_ALLOWED,0"
      #"__VK_LAYER_NV_optimus,NVIDIA_only"
      "NVD_BACKEND,direct"
      "GDK_BACKEND,wayland,x11,*"
      "QT_QPA_PLATFORM,wayland;xcb"
      "SDL_VIDEODRIVER,wayland"
    ];
  };
}
