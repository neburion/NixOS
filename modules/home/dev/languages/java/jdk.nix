{ pkgs, ... }:

# Temurin 21, the current LTS.
#
# This is NOT what makes Java work in IntelliJ. IntelliJ ships the JetBrains
# Runtime — a full OpenJDK fork it runs on and will offer as a project SDK —
# along with its own Maven and Gradle. Working entirely inside the IDE, none of
# this module is needed.
#
# It exists for the two paths the IDE does not cover:
#
#   - nvim. jdtls is itself a Java program and needs a JDK on PATH to start,
#     so ./lsp.nix does nothing without this.
#   - the terminal. The JBR lives inside IntelliJ's store path and is never
#     exported, so `javac Foo.java` in a shell had nothing to run, and the
#     shell.nix that ./newjava.nix writes had no toolchain to pull in.
#
# Delete this and IntelliJ keeps working; nvim and the shell stop.

{
  home.packages = with pkgs; [
    temurin-bin-21
  ];

  home.sessionVariables.JAVA_HOME = "${pkgs.temurin-bin-21}";
}
