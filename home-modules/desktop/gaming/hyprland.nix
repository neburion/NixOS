{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    "$musicPlayer" = "spotify";

    bind = [
      "$mod,       M,      exec, $musicPlayer"
      "$mod,       G,      exec, heroic"
      "$mod SHIFT, G,      exec, steam"
    ];
  };
}
