{ ... }:

# Ghostty for the glass preset — one fixed palette written straight into
# settings.
#
# The clean version generates a theme file per palette and points ghostty at a
# runtime-managed active.conf that theme-set rewrites. With no themes there is
# nothing to rewrite, so there is no themes directory, no activation script and
# no hook: the colours are just settings.
#
# background-opacity is deliberately below 1 so the terminal is part of the
# same material as the bar. It pairs with hyprland-glass/looks.nix, where
# window blur runs at 2 passes.

{
  programs.ghostty = {
    enable = true;
    settings = {
      font-family      = "Geist Mono";
      font-family-bold = "Geist Mono SemiBold";
      font-size        = 11;
      font-feature     = [ "-calt" "-liga" ];

      cursor-style               = "block";
      cursor-style-blink         = false;
      shell-integration-features = "no-cursor";

      window-padding-x     = 12;
      window-padding-y     = 10;
      window-decoration    = false;
      background-opacity   = 0.92;
      background-blur      = true;
      unfocused-split-opacity = 1.0;

      background            = "#0B0E14";
      foreground            = "#EDF0F5";
      cursor-color          = "#EDF0F5";
      selection-background  = "#252A35";
      selection-foreground  = "#EDF0F5";

      # Cool-neutral base16, tuned to sit under translucent chrome rather than
      # to be maximally saturated.
      palette = [
        "0=#1B1F27"  "1=#FF8A80"  "2=#9DEBD0"  "3=#E2C9A2"
        "4=#A2BEE2"  "5=#C4AEE8"  "6=#A2D4E2"  "7=#C6CCD6"
        "8=#3A414F"  "9=#FFA79E"  "10=#B6F2DE" "11=#EDD9BA"
        "12=#BDD1EE" "13=#D6C6F0" "14=#BFE2EC" "15=#EDF0F5"
      ];
    };
  };
}
