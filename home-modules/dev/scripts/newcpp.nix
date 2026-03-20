{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellScriptBin "newcpp" ''
      mkdir -p "$1"/{src,include,tests}
      cp ~/Projects/Dev/templates/cpp/Makefile "$1"/Makefile
      cp ~/Projects/Dev/templates/cpp/shell.nix "$1"/shell.nix
      touch "$1"/src/main.cpp
      echo "use nix" > "$1"/.envrc
      cd "$1" && direnv allow
    '')
  ];
}
