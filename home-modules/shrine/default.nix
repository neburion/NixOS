{ ... }:

{
  imports = [
    ./shrine-shell.nix
    ./kink-quiz.nix
  ];

  programs.fish = {
    enable = true;
    loginShellInit = ''
      exec shrine-shell
    '';
  };
}
