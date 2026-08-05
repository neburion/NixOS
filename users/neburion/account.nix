{ pkgs, ... }:

{
  users.users.neburion = {
    isNormalUser = true;
    extraGroups  = [ "wheel" "networkmanager" "video" "i2c" ];
    shell        = pkgs.fish;
  };
}
