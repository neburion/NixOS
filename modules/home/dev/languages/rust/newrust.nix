{ pkgs, ... }:

let
  # Only shell.nix, because cargo writes the rest. See ../c-cpp/newc.nix for
  # why templates live in the store rather than under ~/Projects.
  templates = ./templates;
in
{
  home.packages = [
    # Thin on purpose. `cargo new` already writes Cargo.toml, src/main.rs and
    # .gitignore, and runs git init -- the work that ../c-cpp/newc.nix has to
    # do by hand only exists because C ships no build tool. Everything below is
    # the two Nix-side files cargo knows nothing about.
    (pkgs.writeShellScriptBin "newrust" ''
      set -e
      DIR="$1"
      [[ -z "$DIR" ]] && { echo "Usage: newrust <project-name>"; exit 1; }
      [[ -d "$DIR" ]]  && { echo "Error: '$DIR' already exists"; exit 1; }

      # --vcs git is load-bearing, not decoration. cargo detects that it is
      # already inside a repository and then skips both git init and .gitignore
      # -- verified: the new project comes out with no .git and, worse, no
      # ignore rule for target/, so the first build stages a few hundred
      # megabytes of artefacts into the parent repo. Scaffolding under a
      # directory that is itself tracked is the normal case here, so the flag
      # is always passed rather than only when it is needed.
      cargo new --vcs git -q "$DIR"

      install -m 644 ${templates}/shell.nix "$DIR/shell.nix"

      echo "use nix" > "$DIR/.envrc"

      direnv allow "$DIR/.envrc"
      printf '\n→ cd %s\n' "$DIR"
    '')
  ];
}
