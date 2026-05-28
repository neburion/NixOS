{
  imports = [
    ../modules/users/neburion.nix
  ];

  home-manager.users.neburion.imports = [
    ../home-modules/base.nix
    ../home-modules/desktop
    ../home-modules/cli
    ../home-modules/dev
    ../home-modules/dev/nvf.nix
  ];
}
