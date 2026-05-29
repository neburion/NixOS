{ pkgs, ... }:

{
  users.users.neburion = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.fish;
  };

  # Allow neburion's user services to run without an active login session.
  systemd.tmpfiles.rules = [
    "f /var/lib/systemd/linger/neburion - - - -"
  ];
}
