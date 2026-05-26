{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "newrust" ''
      set -e
      DIR="$1"
      [[ -z "$DIR" ]] && { echo "Usage: newrust <project-name>"; exit 1; }
      [[ -d "$DIR" ]]  && { echo "Error: '$DIR' already exists"; exit 1; }

      PROJECT_NAME="$(basename "$DIR")"
      mkdir -p "$DIR"/src

      cat > "$DIR/shell.nix" << 'NIXEOF'
{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  buildInputs = with pkgs; [ rustc cargo clippy rustfmt rust-analyzer ];
}
NIXEOF

      cat > "$DIR/Cargo.toml" << TOMLEOF
[package]
name = "$PROJECT_NAME"
version = "0.1.0"
edition = "2021"

[dependencies]
TOMLEOF

      cat > "$DIR/src/main.rs" << 'RSEOF'
fn main() {
    println!("Hello, world!");
}
RSEOF

      echo "use nix" > "$DIR/.envrc"

      git init -q "$DIR"
      git -C "$DIR" add -A
      git -C "$DIR" commit -qm "init: $PROJECT_NAME"

      direnv allow "$DIR/.envrc"
      printf '\n→ cd %s\n' "$DIR"
    '')
  ];
}
