{ ... }:

{
  users.users.neburion = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };
  users.users.nululy = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };
}
