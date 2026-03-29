{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "newpy" ''
      mkdir -p "$1"/{src,tests}
      cp ~/Projects/Dev/templates/python/shell.nix "$1"/shell.nix
      echo "use nix" > "$1"/.envrc
      cd "$1" && direnv allow
    '')
  ];
}
