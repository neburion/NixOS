{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "nixshrink"
      (builtins.readFile ./nixshrink.sh))
  ];
}
