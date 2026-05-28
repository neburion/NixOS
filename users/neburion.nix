{ pkgs, ... }:

{
  users.users.neburion = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.fish;
  };

  # Allow neburion's user services to run without an active login session.
  systemd.tmpfiles.rules = [
    "f /var/lib/systemd/linger/neburion - - - -"
  ];

  home-manager.users.neburion = { pkgs, zen-browser, ... }: {
    imports = [
      ../home-modules/desktop
      ../home-modules/cli
      ../home-modules/dev
    ];

    home.packages = [
      zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
    programs.nvf.enable = true;

    home.stateVersion = "25.11";
    xdg.configFile."user-dirs.dirs".force = true;
  };
}
