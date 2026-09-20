{ ... }:

{
  imports = [
    ./compiler.nix
    ./lsp.nix
    ./format.nix
    ./gdb.nix
    ./cmake.nix
    ./make.nix
    ./newc.nix
    ./newcpp.nix
  ];
}
