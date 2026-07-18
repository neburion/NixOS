{ pkgs, ... }:

# Trivial initial password — this user is a family kiosk on a LAN-only
# machine, physical access is the trust boundary. Changing it via `passwd`
# after first login is a no-op because /etc/shadow is on the writable rootfs.

{
  users.users.printer = {
    isNormalUser    = true;
    extraGroups     = [ "wheel" "networkmanager" ];
    shell           = pkgs.fish;
    initialPassword = "1234";
  };
}
