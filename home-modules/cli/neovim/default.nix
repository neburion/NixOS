{ ... }:

{
  imports = [
    ./options.nix
    ./theme.nix
    ./plugins.nix
    ./languages.nix
    ./debugger.nix
    ./keybinds.nix
  ];

  programs.nvf.enable = true;
}
