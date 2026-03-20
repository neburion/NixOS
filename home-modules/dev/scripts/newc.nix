{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellScriptBin "newc" ''
      mkdir -p "$1"/{src,include,tests}
      cp ~/Projects/Dev/templates/c/Makefile "$1"/Makefile
      cp ~/Projects/Dev/templates/c/shell.nix "$1"/shell.nix
      touch "$1"/src/main.c
      echo "use nix" > "$1"/.envrc
      cd "$1" && direnv allow
    '')
  ];
}
