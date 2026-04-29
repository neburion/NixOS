{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    glfw
  ];

  # Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };
}
