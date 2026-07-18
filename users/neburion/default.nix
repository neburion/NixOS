{ ... }:

{
  imports = [
    ./account.nix
    ./dirs.nix
    ./home.nix
    ../../modules/system/shell/fish.nix
  ];
}
