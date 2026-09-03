{ pkgs, ... }:

let
  # See ../c-cpp/newc.nix. The shell.nix here used to be a heredoc inside this
  # script, which had drifted from ~/Projects/Dev/templates/python/shell.nix —
  # the two differed only in a comment, but they were two copies of one file.
  templates = ./templates;
in
{
  home.packages = [
    (pkgs.writeShellScriptBin "newpy" ''
      set -e
      DIR="$1"
      [[ -z "$DIR" ]] && { echo "Usage: newpy <project-name>"; exit 1; }
      [[ -d "$DIR" ]]  && { echo "Error: '$DIR' already exists"; exit 1; }

      mkdir -p "$DIR"/{src,tests}

      install -m 644 ${templates}/shell.nix "$DIR/shell.nix"

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
