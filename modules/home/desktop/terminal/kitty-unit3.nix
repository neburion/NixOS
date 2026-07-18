{ lib, ... }:

# Unit-3 Kitty — NieR:Automata palette, Share Tech Mono, cursor trail.
# Provides $terminal = "kitty" (mkForce because programs.nix hardcodes ghostty).

{
  programs.kitty = {
    enable = true;
    font   = { name = "Share Tech Mono"; size = 12; };
    settings = {
      letter_spacing = "0.5";
      line_height    = "1.2";

      foreground           = "#c8b89a";
      background           = "#0b0906";
      selection_foreground = "#0b0906";
      selection_background = "#c8b89a";

      cursor                = "#6e2a2a";
      cursor_trail          = 3;
      cursor_trail_decay    = "0.1 0.4";
      cursor_text_color     = "#0b0906";
      cursor_shape          = "block";
      cursor_blink_interval = "0.8";

      color0  = "#0b0906";
      color1  = "#6e2a2a";
      color2  = "#463f2e";
      color3  = "#7a6a3e";
      color4  = "#3a4a5a";
      color5  = "#5a3a4a";
      color6  = "#3a5a5a";
      color7  = "#c8b89a";
      color8  = "#2a2420";
      color9  = "#8a3a3a";
      color10 = "#6a5f4a";
      color11 = "#9a8a5a";
      color12 = "#4a6a7a";
      color13 = "#7a4a6a";
      color14 = "#4a7a7a";
      color15 = "#d6cfb5";

      window_padding_width     = 20;
      background_opacity       = "0.92";
      dynamic_background_color = "no";

      scrollback_lines = 5000;
      tab_bar_style    = "hidden";

      enable_audio_bell    = "no";
      visual_bell_duration = "0.0";

      url_color = "#7a6a3e";
      url_style = "single";

      title_template = ''"{title}"'';
    };
  };

  wayland.windowManager.hyprland.settings."$terminal" = lib.mkForce "kitty";
}
