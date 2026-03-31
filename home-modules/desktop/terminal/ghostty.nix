{ ... }:

{
  programs.ghostty = {
    enable = true;
    settings = {
      font-family = "FiraMono Nerd Font";
      font-size = 11;
      cursor-style = "block";
      shell-integration-features = "no-cursor";
    };
  };
}
