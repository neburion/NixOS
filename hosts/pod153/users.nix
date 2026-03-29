{ ... }:

{
  users.users."9s" = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };
}
