{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  packages = [
    pkgs.temurin-bin-21
    pkgs.gradle
  ];
}
