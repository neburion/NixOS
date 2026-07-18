{ pkgs, ... }:

{
  users.users.neburion = {
    isNormalUser = true;
    extraGroups  = [ "wheel" "networkmanager" ];
    shell        = pkgs.fish;
  };
}
