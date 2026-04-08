{ ... }:

{
  imports = [
    ./options.nix
    ./theme.nix
    ./plugins.nix
    ./languages.nix
    ./keybinds.nix
  ];

  programs.nvf = {
    enable = true;
    settings.vim = {};
  };
}
