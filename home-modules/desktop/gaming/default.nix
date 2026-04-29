{ pkgs, ... }:

{
  home.packages = with pkgs; [
    heroic
    (pkgs.callPackage ./atlauncher.nix { inherit (pkgs) libGL glfw; })
  ];
}
