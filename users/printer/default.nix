{ ... }:

{
  home-manager.users.printer.imports = [
    ../../modules/home/base.nix
    ../../modules/home/cli/btop.nix
    ../../modules/home/cli/neovim
    ../../modules/home/dev/git.nix
  ];

  users.users.printer = {
    isNormalUser    = true;
    extraGroups     = [ "wheel" "networkmanager" ];
    initialPassword = "1234";
  };
}
