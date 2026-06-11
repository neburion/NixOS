{ pkgs, lib, ... }:

{
  # Java 25 for minecraft v26
  environment.systemPackages = with pkgs; [
    jdk25
    heroic-unwrapped # Epic / GOG / Amazon launcher
  ];

  # Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

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
