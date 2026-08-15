{ pkgs, ... }:

# Trivial initial password — this user is a family kiosk on a LAN-only
# machine, physical access is the trust boundary. Changing it via `passwd`
# after first login is a no-op because /etc/shadow is on the writable rootfs.
#
# Passwordless wheel: home-server is a headless LAN-only host; the trust
# boundary is physical access, not interactive login. Passwordless sudo
# lets `rebuild home-server` from any other fleet member deploy without
# an interactive TTY prompt on the target. If this host ever gains real
# internet-facing services beyond the auth-gated CF tunnel, revisit.

{
  users.users.home-admin = {
    isNormalUser    = true;
    extraGroups     = [ "wheel" "networkmanager" ];
    shell           = pkgs.fish;
    initialPassword = "1234";
  };

  security.sudo.wheelNeedsPassword = false;
}
