{ ... }:

# Headless. Everything here works over ssh with no display, which is the
# admission test for modules/home/cli — so this list is exactly that directory
# minus what a server has no use for.

{
  home-manager.users.server-admin.imports = [
    ../../modules/home/base.nix

    ../../modules/home/cli/btop.nix
    ../../modules/home/cli/compression.nix
    ../../modules/home/cli/fastfetch.nix
    ../../modules/home/cli/fish.nix
    ../../modules/home/cli/git.nix
    ../../modules/home/cli/neovim
    ../../modules/home/cli/superfile.nix
    ../../modules/home/cli/tree.nix

    ../../modules/tools
  ];
}
