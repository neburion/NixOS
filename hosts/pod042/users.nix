{ pkgs, ... }:

{
  users.users.neburion = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.fish;
  };
  users.users.nululy = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };
  users.users.qellyree = {
    isNormalUser = true;
    extraGroups  = [ "networkmanager" ];
  };

  # Allow neburion's user services to run without an active login session
  systemd.tmpfiles.rules = [
    "f /var/lib/systemd/linger/neburion - - - -"
  ];
}
