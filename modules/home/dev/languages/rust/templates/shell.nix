{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  packages = [
    pkgs.rustc
    pkgs.cargo
    pkgs.clippy
    pkgs.rustfmt

    # Shorthands for the two commands this directory exists to run.
    #
    # Packages rather than fish aliases because an alias is global: it
    # would load on home-server and personal-server too, which import
    # the fish module and have no cargo. A package in mkShell is on
    # PATH only while direnv has this project loaded, so the names
    # exist inside a Rust project and nowhere else. direnv cannot do
    # this with an alias -- it exports environment variables only.
    #
    # `exec cargo <sub> "$@"` and nothing else, deliberately. No flags
    # baked in, no argument rewriting, no wrapper process left in the
    # middle: exec replaces the shell with cargo, so the exit code,
    # the signals, the TTY and stdin/stdout/stderr are cargo's own.
    # `run --release`, `run -- --flag`, `build -p foo` all mean to
    # cargo exactly what they would have meant typed in full.
    (pkgs.writeShellScriptBin "run"   ''exec cargo run   "$@"'')
    (pkgs.writeShellScriptBin "build" ''exec cargo build "$@"'')
  ];

  # rust-analyzer reads this to find the standard library; the nixpkgs rustc
  # does not carry it. Set here as well as in the module because a shell.nix is
  # meant to stand on its own -- the project should build and edit correctly
  # for anyone who enters it, not only on a machine running this config.
  RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
}
