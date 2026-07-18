{ ... }:

{
  home-manager.users.printer.imports = [
    ../../modules/home/base.nix
    ../../modules/home/cli/shell/fish.nix
    ../../modules/home/cli/btop.nix
    ../../modules/home/cli/compression.nix
    ../../modules/home/cli/fastfetch.nix
    ../../modules/home/cli/neovim
    ../../modules/home/cli/superfile.nix
    ../../modules/home/cli/tree.nix
    ../../modules/home/dev/git.nix
  ];
}
