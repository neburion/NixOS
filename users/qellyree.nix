{
  users.users.qellyree = {
    isNormalUser = true;
    extraGroups  = [ "networkmanager" ];
  };

  home-manager.users.qellyree = { pkgs, zen-browser, ... }: {
    imports = [
      ../home-modules/desktop
      ../home-modules/desktop/gaming
      ../home-modules/cli
    ];

    home.packages = [
      zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    home.stateVersion = "25.11";
    xdg.configFile."user-dirs.dirs".force = true;
  };
}
