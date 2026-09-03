{ pkgs, ... }:

# Gradle and Maven, for building outside the IDE.
#
# IntelliJ bundles both already and will use its own unless told otherwise, so
# this is the terminal and direnv path — same reason as ./jdk.nix.
#
# Both, because which one a project uses is the project's choice and not this
# machine's. If that stops being true, drop the one you never run.

{
  home.packages = with pkgs; [
    gradle
    maven
  ];
}
