{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    "$discord"     = "vesktop";
    "$musicPlayer" = "spotify";

    bind = [
      "$mod,       D,      exec, $discord"
      "$mod,       M,      exec, $musicPlayer"
      "$mod,       G,      exec, heroic"
      "$mod SHIFT, G,      exec, steam"
    ];
  };
}
