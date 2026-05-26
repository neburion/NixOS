{ ... }:

{
  imports = [
    ./shrine-shell.nix
  ];

  programs.fish = {
    enable = true;
    loginShellInit = ''
      exec shrine-shell
    '';
  };
}
