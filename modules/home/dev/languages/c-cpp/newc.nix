{ pkgs, ... }:

let
  # Project skeletons live in modules/home/dev/templates. Referencing the path
  # copies it into the store, which makes the scaffolding self-contained —
  # these files used to be read from ~/Projects/Dev/templates at runtime, so
  # `newc` produced a project missing its build files on any host (or any fresh
  # checkout) where that directory did not happen to exist.
  templates = ../../templates/c;
in
{
  home.packages = [
    (pkgs.writeShellScriptBin "newc" ''
      mkdir -p "$1"/{src,include,tests}
      # install, not cp: store paths are read-only, so a plain copy lands as
      # r--r--r-- and the first edit to the new project fails.
      install -m 644 ${templates}/shell.nix      "$1"/shell.nix
      install -m 644 ${templates}/Makefile       "$1"/Makefile
      install -m 644 ${templates}/CMakeLists.txt "$1"/CMakeLists.txt
      ln -s build/compile_commands.json "$1"/compile_commands.json
      touch "$1"/src/main.c
      echo "use nix" > "$1"/.envrc
      cd "$1" && direnv allow
    '')
  ];
}
