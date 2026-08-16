{ ... }:

# sshd + fleet-wide client config. programs.ssh.extraConfig applies to every
# outbound SSH from this host — so once every fleet member imports this
# module, `ssh <host>` uses the right admin user + skips the interactive
# host-key prompt on first connect. The rebuild wrapper leans on this
# (it passes bare `<host>` to `nixos-rebuild --target-host`).

{
  services.openssh = {
    enable = true;
    # Don't let openssh punch port 22 in the firewall on every interface.
    # sshd still binds 0.0.0.0 (so this module stays host-generic — no
    # per-host tailnet IP to hardcode), but the firewall rule below only
    # admits :22 arriving on tailscale0. On any hostile LAN the box lands
    # on (personal-server roams), port 22 is simply filtered. Deploys and
    # `ssh <host>` are unaffected — bare hostnames resolve to 100.x tailnet
    # IPs via tailnet-hosts.nix, so all fleet SSH already rides tailscale0.
    # Physical recovery stays open via console-autologin on tty1.
    openFirewall = false;
    settings = {
      # Keys only. Every admin key is declared in users/*/account.nix, so
      # access is fully reproducible from the repo — no reliance on a
      # `passwd`-set hash living in mutable /etc/shadow. A lost key is never
      # a lockout: console-autologin.nix gives server-admin a shell on tty1.
      PasswordAuthentication = false;
      # Also close the PAM keyboard-interactive path: with UsePAM=yes it
      # routes through pam_unix and would prompt for the unix password,
      # silently re-opening what PasswordAuthentication=false shuts.
      KbdInteractiveAuthentication = false;
      PermitRootLogin              = "no";
    };
  };

  # Admit SSH only on the tailnet interface. Same pattern the elden-ring
  # tracker uses for its port.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

  # Fleet-wide client config. Add a Host block per admin user; the flake
  # hostname (used in `rebuild <host>`) matches the tailnet MagicDNS name,
  # so no separate hostname mapping is needed.
  programs.ssh.extraConfig = ''
    Host home-server personal-server
      User server-admin

    Host *
      StrictHostKeyChecking accept-new
  '';
}

