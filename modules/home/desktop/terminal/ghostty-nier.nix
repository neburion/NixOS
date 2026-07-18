{ ... }:

# Unit-3 NieR palette in Ghostty. Matches kitty-unit3 colors exactly;
# no window padding (ghostty default = flush edges).

{
  programs.ghostty = {
    enable = true;
    settings = {
      font-family   = "Share Tech Mono";
      font-size     = 12;

      background    = "#0b0906";
      foreground    = "#c8b89a";

      selection-background = "#c8b89a";
      selection-foreground = "#0b0906";

      cursor-color  = "#6e2a2a";
      cursor-style  = "block";
      cursor-style-blink = true;

      background-opacity = 0.92;

      "palette" = [
        "0=#0b0906"
        "1=#6e2a2a"
        "2=#463f2e"
        "3=#7a6a3e"
        "4=#3a4a5a"
        "5=#5a3a4a"
        "6=#3a5a5a"
        "7=#c8b89a"
        "8=#2a2420"
        "9=#8a3a3a"
        "10=#6a5f4a"
        "11=#9a8a5a"
        "12=#4a6a7a"
        "13=#7a4a6a"
        "14=#4a7a7a"
        "15=#d6cfb5"
      ];

      scrollback-limit   = 5000;
      window-decoration  = false;
    };
  };
}
