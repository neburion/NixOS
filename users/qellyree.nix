{
  imports = [
    ../modules/users/qellyree.nix
  ];

  home-manager.users.qellyree.imports = [
    ../home-modules/base.nix
    ../home-modules/desktop
    ../home-modules/desktop/gaming
    ../home-modules/cli
  ];
}
