{ pkgs, ... }:

# Pinned to the rolling `unstable` channel so new Claude models land within
# days of upstream release instead of waiting for the next NixOS cut.
# The `unstable` attr is provided by an overlay declared in flake.nix.

{
  home.packages = [ pkgs.unstable.claude-code ];
}
