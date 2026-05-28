{
  imports = [
    ../modules/users/nululy.nix
  ];

  home-manager.users.nululy.imports = [
    ../home-modules/base.nix
    ../home-modules/desktop
    ../home-modules/cli
    ../home-modules/dev
  ];
}
