{ pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  environment.systemPackages = with pkgs; [
    git
    rclone
    p7zip
    jq
    (pkgs.writeShellScriptBin "nixinstall"
      (builtins.readFile ./nixinstall.sh))
  ];

  environment.etc."nixinstall-disko.nix".source = ./disko.nix;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
