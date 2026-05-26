{ ... }:

{
  programs.nvf.settings.vim = {
    lsp.enable = true;
    languages = {
      enableTreesitter = true;

      clang.enable  = true; # C/C++
      rust.enable   = true; # Rust
      python.enable = true; # Python
      nix.enable    = true; # Nix
    };
  };
}
