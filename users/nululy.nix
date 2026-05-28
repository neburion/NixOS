{
  users.users.nululy = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };

  home-manager.users.nululy = { pkgs, zen-browser, ... }: {
    imports = [
      ../home-modules/desktop
      ../home-modules/cli
      ../home-modules/dev
    ];

    home.packages = [
      zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    home.stateVersion = "25.11";
    xdg.configFile."user-dirs.dirs".force = true;
  };
}
