{ pkgs, ... }:

# rustc, cargo, and the two binaries cargo shells out to.
#
# From nixpkgs rather than rustup, the same call as ../java/jdk.nix and
# ../python/interpreter.nix: one version off the flake pin, with no second
# package manager living underneath it. The cost is real and worth stating --
# no per-project toolchain pinning and no nightly. A project that needs either
# says so in its own shell.nix; this is the machine's default, not a ceiling.
#
# rust-analyzer is deliberately not here. nvf supplies its own for nvim (see
# ./lsp.nix), exactly as it does jdtls, so listing it would install a second
# copy that nothing ever runs.
#
# clippy and rustfmt are not bundled with cargo in nixpkgs -- they are separate
# derivations providing cargo-clippy and rustfmt. Without them `cargo clippy`
# and `cargo fmt` fail with "no such subcommand". Neither touches an editor
# buffer; there is no format-on-save for Rust in this repo.

{
  home.packages = with pkgs; [
    rustc
    cargo
    clippy
    rustfmt
  ];

  # Without this, rust-analyzer cannot see the standard library.
  #
  # rust-analyzer locates std by running `rustc --print sysroot` and looking for
  # lib/rustlib/src/rust/library underneath it. The nixpkgs rustc does not ship
  # that source tree -- checked, the directory does not exist -- so the lookup
  # fails silently and you get no completion, no hover and no go-to-definition
  # for anything in std. Vec and Option stop resolving; your own code is fine,
  # which is what makes it confusing.
  #
  # rustPlatform.rustLibSrc is that library/ directory packaged on its own, and
  # RUST_SRC_PATH is the override rust-analyzer checks before the sysroot walk.
  # This is the Rust counterpart to JAVA_HOME in ../java/jdk.nix: the language
  # server is a separate program and needs telling where things are.
  home.sessionVariables.RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
}
