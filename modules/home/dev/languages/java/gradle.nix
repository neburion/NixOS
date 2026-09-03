{ pkgs, ... }:

# Gradle and Maven. Both, because which one a project uses is the project's
# choice, not this machine's.

{
  home.packages = with pkgs; [
    gradle
    maven
  ];
}
