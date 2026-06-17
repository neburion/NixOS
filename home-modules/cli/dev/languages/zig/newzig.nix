{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "newzig" ''
      set -e
      DIR="$1"
      [[ -z "$DIR" ]] && { echo "Usage: newzig <project-name>"; exit 1; }
      [[ -d "$DIR" ]]  && { echo "Error: '$DIR' already exists"; exit 1; }

      mkdir -p "$DIR"
      (cd "$DIR" && ${pkgs.zig}/bin/zig init >/dev/null)

      cat > "$DIR/shell.nix" << 'NIXEOF'
{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  buildInputs = with pkgs; [ zig ];
}
NIXEOF

      echo "use nix" > "$DIR/.envrc"

      git init -q "$DIR"
      git -C "$DIR" add -A
      git -C "$DIR" commit -qm "init: $(basename "$DIR")"

      direnv allow "$DIR/.envrc"
      printf '\n→ cd %s\n' "$DIR"
    '')
  ];
}
