{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "nixinstall"
      (builtins.readFile ./nixinstall.sh))
  ];
}
