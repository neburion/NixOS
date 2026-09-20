{ ... }:

# The Rust toolchain.
#
# Shorter than ../c-cpp for a reason: cargo is the build system and the package
# manager, and it ships with the language. There is no cmake.nix or make.nix
# here because there is nothing to choose -- every Rust project is a cargo
# project, and `cargo build` needs no build file beyond Cargo.toml.
#
# Two files that might look missing are absent on purpose:
#
#   - no format.nix. Nothing formats a Rust buffer on save. `cargo fmt` is
#     there when it is wanted; see ./lsp.nix for why nvf leaves this off by
#     itself and why setting enableFormat globally would not change it.
#   - no dap.nix. ../c-cpp/gdb.nix exists because gdb 14+ speaks DAP natively
#     and gcc was already installed. nvf's Rust debugger defaults to codelldb,
#     which drags in the vscode-lldb extension, so neither half of that
#     bargain holds here.

{
  imports = [
    ./toolchain.nix
    ./lsp.nix
    ./newrust.nix
  ];
}
