{ pkgs, ... }:

{
  home.packages = with pkgs; [
    heroic
    prismlauncher
    (pkgs.callPackage ./atlauncher.nix { inherit (pkgs) libGL glfw; })
  ];
}
