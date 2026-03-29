{ ... }:

{
  programs.fish.enable = true;
  # Environment Variables
  environment.sessionVariables = {
    EDITOR = "nvim";
    SUDO_EDITOR = "nvim";
  };
}
