{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "newodin" ''
      set -e
      DIR="$1"
      [[ -z "$DIR" ]] && { echo "Usage: newodin <project-name>"; exit 1; }
      [[ -d "$DIR" ]]  && { echo "Error: '$DIR' already exists"; exit 1; }

      mkdir -p "$DIR"

      cat > "$DIR/shell.nix" << 'NIXEOF'
{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  buildInputs = with pkgs; [ odin ];
}
NIXEOF

      cat > "$DIR/main.odin" << 'ODINEOF'
package main

import "core:fmt"

main :: proc() {
    fmt.println("Hello, world!")
}
ODINEOF

      echo "use nix" > "$DIR/.envrc"

      git init -q "$DIR"
      git -C "$DIR" add -A
      git -C "$DIR" commit -qm "init: $(basename "$DIR")"

      direnv allow "$DIR/.envrc"
      printf '\n→ cd %s\n' "$DIR"
    '')
  ];
}
