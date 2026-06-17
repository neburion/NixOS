{ pkgs, ... }:

{
  users.users.neburion = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.fish;
    hashedPassword = "$y$j9T$ykml5fLEqsNnXB7uG6uJn.$M1VJF06/nxNwgVwv3jBrhDldXdo4OeGuf1AMAA2Dtv6";
  };

  # Allow neburion's user services to run without an active login session.
  systemd.tmpfiles.rules = [
    "f /var/lib/systemd/linger/neburion - - - -"
  ];
}
