{ pkgs, ... }:

{
  # Java 25 for minecraft v26
  environment.systemPackages = with pkgs; [
    jdk25
  ];

  # Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };
}
