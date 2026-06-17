{ pkgs, ... }:

{
  # Java 25 for Minecraft v26.
  environment.systemPackages = with pkgs; [
    jdk25
  ];
}
