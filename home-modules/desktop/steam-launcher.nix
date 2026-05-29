{ config, lib, ... }:

{
  options.gamingLauncher.enable = lib.mkEnableOption
    "showing system-wide gaming launchers (Steam, ...) in the application menu";

  # `programs.steam.enable` installs steam.desktop system-wide, which puts Steam
  # in every desktop user's app menu. Shadow it with a NoDisplay=true entry in
  # ~/.local/share/applications/ for users who haven't opted in.
  config = lib.mkIf (!config.gamingLauncher.enable) {
    xdg.desktopEntries.steam = {
      name = "Steam";
      noDisplay = true;
      exec = "steam %U";
      type = "Application";
    };
  };
}
