{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "newpy" ''
      set -e
      DIR="$1"
      [[ -z "$DIR" ]] && { echo "Usage: newpy <project-name>"; exit 1; }
      [[ -d "$DIR" ]]  && { echo "Error: '$DIR' already exists"; exit 1; }

      mkdir -p "$DIR"/{src,tests}

      cat > "$DIR/shell.nix" << 'NIXEOF'
{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  packages = [
    (pkgs.python3.withPackages (ps: with ps; [
      # add libraries here
    ]))
  ];
}
NIXEOF

      touch "$DIR/src/__init__.py"
      cat > "$DIR/src/main.py" << 'PYEOF'
def main():
    pass

if __name__ == "__main__":
    main()
PYEOF

      echo "use nix" > "$DIR/.envrc"

      git init -q "$DIR"
      git -C "$DIR" add -A
      git -C "$DIR" commit -qm "init: $(basename "$DIR")"

      direnv allow "$DIR/.envrc"
      printf '\n→ cd %s\n' "$DIR"
    '')
  ];
}
