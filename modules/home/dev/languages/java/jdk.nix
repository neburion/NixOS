{ pkgs, ... }:

# Temurin 21, the current LTS. IntelliJ bundles its own JBR for running itself
# but does not put a JDK on PATH, so `java` and `javac` come from here.

{
  home.packages = with pkgs; [
    temurin-bin-21
  ];

  home.sessionVariables.JAVA_HOME = "${pkgs.temurin-bin-21}";
}
