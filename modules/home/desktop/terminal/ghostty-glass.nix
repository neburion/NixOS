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

      # Neutral dark, not a blue-black. The first version tinted both the
      # ground (#0B0E14) and most of the palette toward blue, which read as a
      # blue terminal rather than a glass one. Greys are now near-achromatic
      # and the cool hues are pulled back toward grey; the semantic colours
      # (red, green, yellow) keep enough chroma to still mean something.
      background            = "#101113";
      foreground            = "#E8EAEC";
      cursor-color          = "#E8EAEC";
      selection-background  = "#26282C";
      selection-foreground  = "#E8EAEC";

      palette = [
        "0=#191B1E"  "1=#E8837A"  "2=#8FCFB4"  "3=#D8BE96"
        "4=#9FB0C2"  "5=#B7A9C6"  "6=#9CBCC0"  "7=#C8CBCF"
        "8=#3B3E44"  "9=#F09B92"  "10=#A8E0C7" "11=#E6D0AB"
        "12=#B6C4D4" "13=#C9BCD8" "14=#B2CFD2" "15=#E8EAEC"
      ];
    };
  };
}
