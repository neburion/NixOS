{ pkgs, ... }:

# Admin user for headless servers in the fleet (home-server, and the
# forthcoming personal-server that'll travel with me). Called server-admin
# because it's the same admin identity on every server-class host, whether
# it lives at the family home or somewhere else.
#
# Trivial initial password — these are headless LAN-only or tunnel-gated
# hosts, physical access is the trust boundary. Changing via `passwd` after
# first login persists to /etc/shadow on the writable rootfs.
#
# Passwordless wheel: server-class hosts don't have interactive humans at
# a terminal, so requiring a sudo password just breaks `rebuild <host>`
# from fleet peers (which need non-interactive remote sudo). Physical
# access is the trust gate. If any of these hosts later gains real
# internet-facing surface beyond auth-gated CF tunnels, revisit.
#
# Fleet SSH: authorized_keys pinned in the declaration so pod042 (and any
# other fleet workstation with its ed25519 key here) can SSH in as
# server-admin without manual key install steps per host.

{
  users.users.server-admin = {
    isNormalUser    = true;
    extraGroups     = [ "wheel" "networkmanager" ];
    shell           = pkgs.fish;
    initialPassword = "1234";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOvDOUbgxV5PpgA3Q9IR9IXtOAzWzbzXv2Zp4cTfLzi1 neburion@pod042"
    ];
  };

  security.sudo.wheelNeedsPassword = false;
}
