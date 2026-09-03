{ pkgs, ... }:

let
  # See newc.nix — same store-backed templates, C++ variant.
  templates = ../templates/cpp;
in
{
  home.packages = [
    (pkgs.writeShellScriptBin "newcpp" ''
      mkdir -p "$1"/{src,include,tests}
      install -m 644 ${templates}/shell.nix      "$1"/shell.nix
      install -m 644 ${templates}/Makefile       "$1"/Makefile
      install -m 644 ${templates}/CMakeLists.txt "$1"/CMakeLists.txt
      ln -s build/compile_commands.json "$1"/compile_commands.json
      touch "$1"/src/main.cpp
      echo "use nix" > "$1"/.envrc
      cd "$1" && direnv allow
    '')
  ];
}
