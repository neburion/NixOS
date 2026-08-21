{ pkgs, ... }:

{
  home.packages = [ (pkgs.callPackage ./bb-launcher/package.nix { }) ];
}
