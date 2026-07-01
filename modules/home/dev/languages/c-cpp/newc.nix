{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "newc" ''
      mkdir -p "$1"/{src,include,tests}
      cp ~/Projects/Dev/templates/c/shell.nix      "$1"/shell.nix
      cp ~/Projects/Dev/templates/c/Makefile       "$1"/Makefile
      cp ~/Projects/Dev/templates/c/CMakeLists.txt "$1"/CMakeLists.txt
      ln -s build/compile_commands.json "$1"/compile_commands.json
      touch "$1"/src/main.c
      echo "use nix" > "$1"/.envrc
      cd "$1" && direnv allow
    '')
  ];
}
