{
  imports = [
    ./modules.nix
  ];

  home-manager.users.neburion.imports = [
    ../../home-modules/base.nix
    ../../home-modules/desktop
    ../../home-modules/desktop/gaming
    ../../home-modules/cli
    ./dirs.nix
    ../../home-modules/dev
  ];
}
