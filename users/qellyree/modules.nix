{ ... }:

{
  users.users.qellyree = {
    isNormalUser = true;
    extraGroups  = [ "networkmanager" ];
  };
}
