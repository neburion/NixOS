{ ... }:

# Headless. Individual modules rather than presets/cli.nix — a server has no
# use for half of that set, and cli/ is a folder precisely so it can pick.

{
  home-manager.users.server-admin.imports = [
    ../../modules/home/base.nix

    ../../modules/home/cli/shell/fish
    ../../modules/home/cli/btop.nix
    ../../modules/home/cli/compression.nix
    ../../modules/home/cli/fastfetch.nix
    ../../modules/home/cli/superfile.nix
    ../../modules/home/cli/tree.nix

    ../../modules/home/dev/editors/neovim
    ../../modules/home/dev/tools/git.nix

    ../../modules/tools/presets/fleet.nix
  ];
}
