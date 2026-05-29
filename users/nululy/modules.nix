{ ... }:

{
  users.users.nululy = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };
}
