{ ... }:

{
  programs.fish.enable = true;

  environment.sessionVariables = {
    EDITOR = "nvim";
    SUDO_EDITOR = "nvim";
  };
}
