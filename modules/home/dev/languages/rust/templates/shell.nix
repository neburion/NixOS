{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  packages = [
    pkgs.rustc
    pkgs.cargo
    pkgs.clippy
    pkgs.rustfmt
  ];

  # rust-analyzer reads this to find the standard library; the nixpkgs rustc
  # does not carry it. Set here as well as in the module because a shell.nix is
  # meant to stand on its own -- the project should build and edit correctly
  # for anyone who enters it, not only on a machine running this config.
  RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
}
