{ ... }:

{
  # programs.steam installs steam.desktop system-wide. Shadow it with a
  # NoDisplay=true entry for every home-manager user by default; the
  # home-manager gaming module opts back in via gamingLauncher.enable = true.
  home-manager.sharedModules = [
    ({ config, lib, ... }: {
      options.gamingLauncher.enable = lib.mkEnableOption
        "showing system-wide gaming launchers (Steam, ...) in the application menu";

      config.xdg.desktopEntries.steam = lib.mkIf (!config.gamingLauncher.enable) {
        name = "Steam";
        noDisplay = true;
        exec = "steam %U";
        type = "Application";
      };
    })
  ];
}
